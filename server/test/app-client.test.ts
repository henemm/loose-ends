import { test } from "node:test";
import assert from "node:assert/strict";
import vm from "node:vm";
import * as ui from "../src/app-ui.ts";

// #624 Schnitt 2a: the window shows the app's view. The pure functions are tested from the module; the script embedded in
// viewHtml runs in node:vm against a fake window whose parent collects every outgoing message (no browser, no dependency).

type Doc = Record<string, any>;
const pure = ui as unknown as Doc;
const BERLIN = { day: "2026-03-13", timeZone: "Europe/Berlin" };
const ID = (n: number) => `6F1C2B0A-0000-4000-8000-${String(n).padStart(12, "0")}`;
const segments = (html: string) => html.split("<li").slice(1);
const red = /class="[^"]*\bred\b/;

test("AC-1: a title is only shown escaped", () => {
  const nasty = `<b>&"'`;
  assert.equal(pure.escape(nasty), "&lt;b&gt;&amp;&quot;&#39;");
  const html: string = pure.rowsHtml("open", [{ id: ID(1), title: nasty, status: "active", dueHasTime: false, isKnaeuel: false, contexts: [] }], BERLIN);
  assert.ok(html.includes("&lt;b&gt;&amp;&quot;&#39;"));
  assert.ok(!html.includes("<b>"), "rohes <b> im HTML");
});

test("AC-2: rows of now carry the margin mark of their group", () => {
  const groups = ["knaeuel", "today", "lined", "waiting"];
  const rows = groups.map((group, n) => ({ id: ID(n), title: `Aufgabe ${n}`, status: "active", dueHasTime: false, isKnaeuel: group === "knaeuel", group }));
  const [knaeuel, today, lined, waiting] = segments(pure.rowsHtml("now", rows, BERLIN));
  assert.ok(knaeuel.includes("<svg"), "Knäuel-Zeichen fehlt");
  assert.match(today, /class="[^"]*\bred\b[^"]*">Heute</);
  assert.ok(lined.includes("Nächstes") && !red.test(lined));
  assert.ok(waiting.includes("Wartet") && !red.test(waiting));
});

test("AC-3: in due, next and open the mark comes from dueDate, day against day in the host's time zone", () => {
  const row = (n: number, dueDate?: string) => ({ id: ID(n), title: `Aufgabe ${n}`, status: "active", dueHasTime: true, isKnaeuel: false, contexts: [], ...(dueDate ? { dueDate } : {}) });
  // 23:30Z on the 12th is the 13th in Berlin; 23:30Z on the 13th is already the 14th there.
  const rows = [row(1, "2026-03-11T10:00:00Z"), row(2, "2026-03-12T23:30:00Z"), row(3, "2026-03-13T23:30:00Z"), row(4)];
  for (const view of ["due", "next", "open"]) {
    const [yesterday, today, tomorrow, none] = segments(pure.rowsHtml(view, rows, BERLIN));
    assert.ok(red.test(yesterday), `${view}: überfällig nicht rot`);
    assert.ok(red.test(today), `${view}: heute nicht rot`);
    assert.ok(!red.test(tomorrow) && tomorrow.includes("14"), `${view}: morgen nicht grau mit Datum`);
    assert.ok(!none.includes('class="mark'), `${view}: Marke ohne Datum`);
  }
  // The same instant in UTC is the 13th, so today.
  const [, , utcTomorrow] = segments(pure.rowsHtml("due", rows, { day: "2026-03-13", timeZone: "UTC" }));
  assert.ok(red.test(utcTomorrow), "UTC: 13. nicht als heute erkannt");
});

// F001: the mark is the row's first span, so the grey :first-child rule must not beat the red one. Specificity as
// [ids, classes/attributes/pseudo-classes, elements], enough for the simple selectors of this stylesheet.
function specificity(selector: string): number[] {
  const ids = (selector.match(/#[\w-]+/g) ?? []).length;
  const classes = (selector.match(/\.[\w-]+|:[\w-]+|\[[^\]]*\]/g) ?? []).length;
  const elements = (selector.replace(/[.#:][\w-]+|\[[^\]]*\]/g, "").match(/[a-z][\w-]*/gi) ?? []).length;
  return [ids, classes, elements];
}
const notLess = (a: number[], b: number[]) => (a[0] - b[0] || a[1] - b[1] || a[2] - b[2]) >= 0;

test("AC-2, AC-3 (F001): a red mark is red in effect, not overruled by the grey first-child rule", () => {
  const css = ui.viewHtml.slice(ui.viewHtml.indexOf("<style>"), ui.viewHtml.indexOf("</style>"));
  const rules = [...css.matchAll(/^([^{}\n]+)\{([^}]*)\}/gm)].map((m) => ({ selector: m[1].trim(), body: m[2], at: m.index! }));
  const grey = rules.find((r) => r.selector === ".row > span:first-child" && r.body.includes("color: var(--quiet)"));
  assert.ok(grey, "graue Regel der Randmarke fehlt");
  const reds = rules.filter((r) => r.body.includes("color: var(--red)") && /\.red\b/.test(r.selector) && /span/.test(r.selector));
  assert.ok(reds.some((r) => notLess(specificity(r.selector), specificity(grey.selector)) && r.at > grey.at),
    `keine rote Regel für die Marke schlägt ${grey.selector} ${JSON.stringify(specificity(grey.selector))}`);
});

test("AC-5: an empty list is one quiet line, no rows", () => {
  const html: string = pure.rowsHtml("due", [], BERLIN);
  assert.equal(segments(html).length, 0);
  assert.ok(html.replace(/<[^>]*>/g, "").trim().length > 0, "keine Zeile");
});

// --- the embedded script in a fake window ---

function windowWithScript() {
  const sent: Doc[] = [];
  const parent = { postMessage: (message: Doc) => sent.push(JSON.parse(JSON.stringify(message))) };
  const listeners: Array<(event: Doc) => void> = [];
  const attributes: Record<string, string> = {};
  const elements = new Map<string, Doc>();
  const element = (key: string) => {
    if (!elements.has(key)) elements.set(key, { innerHTML: "", textContent: "", setAttribute() {}, style: {} });
    return elements.get(key)!;
  };
  const root = {
    setAttribute: (name: string, value: string) => { attributes[name] = value; },
    getAttribute: (name: string) => attributes[name] ?? null,
    removeAttribute: (name: string) => { delete attributes[name]; },
    scrollHeight: 321, scrollWidth: 400, offsetHeight: 321, offsetWidth: 400,
    getBoundingClientRect: () => ({ width: 400, height: 321 }),
  };
  const document = {
    documentElement: root, body: { ...element("body"), scrollHeight: 321, scrollWidth: 400 },
    getElementById: (id: string) => element(`#${id}`), querySelector: (selector: string) => element(selector),
  };
  const window: Doc = {
    parent, document, Intl, Date, JSON, Math, console,
    addEventListener: (type: string, listener: (event: Doc) => void) => { if (type === "message") listeners.push(listener); },
    matchMedia: () => ({ matches: false, addEventListener() {} }),
  };
  window.window = window;
  window.self = window;
  window.globalThis = window;
  const script = ui.viewHtml.match(/<script>([\s\S]*?)<\/script>/)?.[1];
  assert.ok(script, "kein inline-Skript in viewHtml");
  vm.runInNewContext(script, window);
  const receive = (data: Doc, source: Doc = parent) => {
    for (const listener of listeners) listener({ data, source });
    if (typeof window.onmessage === "function") window.onmessage({ data, source });
  };
  const shown = () => [...elements.values()].map((el) => `${el.innerHTML}${el.textContent}`).join("\n");
  return { sent, receive, attributes, shown };
}

const VIEW = {
  view: "now", generatedAt: "2026-03-12T09:00:00Z", nowCount: 3, count: 2,
  rows: [
    { id: ID(1), title: "Zahnarzt anrufen", dueDate: "2026-03-12T17:00:00Z", dueHasTime: true, status: "active", isKnaeuel: false, group: "today" },
    { id: ID(2), title: "Steuer sortieren", dueHasTime: false, status: "active", isKnaeuel: false, group: "lined" },
  ],
};
const toolResult = (result: Doc) => ({ jsonrpc: "2.0", method: "ui/notifications/tool-result", params: result });

// Starts the window and answers its ui/initialize with the given host context.
function initialized(hostContext: Doc = {}) {
  const host = windowWithScript();
  const init = host.sent[0];
  host.receive({ jsonrpc: "2.0", id: init.id, result: { protocolVersion: "2026-01-26", hostInfo: { name: "test", version: "1" }, hostCapabilities: {}, hostContext } });
  return host;
}

test("AC-6: the window opens with ui/initialize and sends initialized only after the answer", () => {
  const host = windowWithScript();
  assert.equal(host.sent.length, 1, "vor der Antwort ging mehr als ui/initialize hinaus");
  const [init] = host.sent;
  assert.equal(init.jsonrpc, "2.0");
  assert.equal(init.method, "ui/initialize");
  assert.ok(init.id !== undefined);
  assert.equal(init.params.protocolVersion, "2026-01-26");
  assert.equal(init.params.appInfo.name, "Loose Ends");
  assert.equal(typeof init.params.appInfo.version, "string");
  assert.deepEqual(init.params.appCapabilities, {});
  host.receive({ jsonrpc: "2.0", id: init.id, result: { protocolVersion: "2026-01-26", hostInfo: { name: "test", version: "1" }, hostCapabilities: {}, hostContext: {} } });
  assert.equal(host.sent[1]?.method, "ui/notifications/initialized");
  assert.equal(host.sent[1]?.id, undefined);
});

test("AC-4, AC-7: a tool result draws head and rows in the host's theme, then reports its size", () => {
  const host = initialized({ theme: "dark", timeZone: "Europe/Berlin" });
  const before = host.sent.length;
  host.receive(toolResult({ content: [{ type: "text", text: JSON.stringify(VIEW) }] }));
  assert.equal(host.attributes["data-theme"], "dark");
  const shown = host.shown();
  assert.ok(shown.includes("Jetzt"), "Ansichtsname fehlt");
  assert.ok(shown.includes(">3<") || /\b3\b/.test(shown.replace(/<[^>]*>/g, " ")), "nowCount fehlt");
  assert.ok(shown.includes("10:00"), "Stand aus generatedAt (Berlin) fehlt");
  assert.ok(shown.includes("Zahnarzt anrufen") && shown.includes("Steuer sortieren"));
  const size = host.sent.slice(before).find((message) => message.method === "ui/notifications/size-changed");
  assert.ok(size, "kein size-changed nach dem Zeichnen");
  assert.equal(typeof size.params.height, "number");
  assert.equal(typeof size.params.width, "number");
  // A partial context keeps the theme.
  host.receive({ jsonrpc: "2.0", method: "ui/notifications/host-context-changed", params: { timeZone: "UTC" } });
  assert.equal(host.attributes["data-theme"], "dark");
  host.receive({ jsonrpc: "2.0", method: "ui/notifications/host-context-changed", params: { theme: "light" } });
  assert.equal(host.attributes["data-theme"], "light");
});

test("AC-5: an error result or unreadable JSON shows one quiet line, never the raw text", () => {
  for (const result of [
    { isError: true, content: [{ type: "text", text: "Abschrift fehlt <geheim>" }] },
    { content: [{ type: "text", text: "kein JSON <geheim>" }] },
    { content: [{ type: "text", text: JSON.stringify({ unbekannt: true }) }] },
  ]) {
    const host = initialized({ theme: "light" });
    host.receive(toolResult(result));
    const shown = host.shown();
    assert.ok(!shown.includes("<li"), "Liste trotz Fehler");
    assert.ok(!shown.includes("geheim"), "Rohtext sichtbar");
    assert.ok(shown.replace(/<[^>]*>/g, "").trim().length > 0, "keine ruhige Zeile");
  }
});

test("AC-8: teardown is answered with {}, unknown and foreign messages are ignored, no tools/call ever", () => {
  const host = initialized({ theme: "light" });
  host.receive(toolResult({ content: [{ type: "text", text: JSON.stringify(VIEW) }] }));
  host.receive({ jsonrpc: "2.0", method: "ui/notifications/something-new", params: {} });
  const beforeForeign = host.shown();
  host.receive(toolResult({ content: [{ type: "text", text: JSON.stringify({ ...VIEW, rows: [] }) }] }), {});
  assert.equal(host.shown(), beforeForeign, "Nachricht einer fremden Quelle angenommen");
  host.receive({ jsonrpc: "2.0", id: 7, method: "ui/resource-teardown", params: {} });
  const answer = host.sent.find((message) => message.id === 7);
  assert.deepEqual(answer, { jsonrpc: "2.0", id: 7, result: {} });
  assert.ok(!host.sent.some((message) => message.method === "tools/call"), "tools/call gesendet");
});
