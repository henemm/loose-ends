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
  const clicks: Array<(event: Doc) => void> = [];
  const element = (key: string) => {
    if (!elements.has(key)) {
      elements.set(key, {
        innerHTML: "", textContent: "", setAttribute() {}, style: {},
        addEventListener: (type: string, listener: (event: Doc) => void) => { if (type === "click") clicks.push(listener); },
      });
    }
    return elements.get(key)!;
  };
  // Timers the test fires by hand; a cleared one stays in the list so a test can force it.
  const timers: Array<{ id: number; ms: number; fn: () => void; cleared: boolean; fired: boolean }> = [];
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
    setTimeout: (fn: () => void, ms: number) => { const id = timers.length + 1; timers.push({ id, ms, fn, cleared: false, fired: false }); return id; },
    clearTimeout: (id: number) => { const timer = timers.find((t) => t.id === id); if (timer) timer.cleared = true; },
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
  // A click on the button of a row: the target is the button itself, read like the DOM does (attributes unescaped).
  const click = (taskID: string) => {
    const attrs: Record<string, string> = { "data-act": "complete", "data-id": taskID };
    const button: Doc = { getAttribute: (name: string) => attrs[name] ?? null, dataset: { act: "complete", id: taskID }, tagName: "BUTTON" };
    button.closest = () => button;
    for (const listener of clicks) listener({ target: button, currentTarget: element("#list"), preventDefault() {} });
  };
  const pending = () => timers.filter((t) => !t.cleared && !t.fired);
  // Fires the timers due now; with force also the cleared ones.
  const fire = (force = false) => {
    for (const timer of timers.filter((t) => !t.fired && (force || !t.cleared))) { timer.fired = true; timer.fn(); }
  };
  return { sent, receive, attributes, shown, click, timers, pending, fire };
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

// --- #624 Schnitt 2b-1: the round button completes a task from the window ---

const text = (doc: unknown) => ({ content: [{ type: "text", text: JSON.stringify(doc) }] });
const WAITING_LINE = "Abgehakt, wartet auf dein Gerät …";
const REJECTED_LINE = "Nicht übernommen – die Aufgabe hat sich geändert.";
const LATE_LINE = "Noch nicht übernommen – dein Gerät holt es beim nächsten Öffnen.";
const FAILED_LINE = "Hat nicht geklappt.";
const STALE = "Abschrift hat sich geändert, bitte neu lesen";
const KNAEUEL = { id: ID(3), title: "Knäuel lösen", dueHasTime: false, status: "active", isKnaeuel: true, group: "knaeuel" };

// A window after the handshake with or without serverTools that has read the given view.
function reading(view: Doc = VIEW, serverTools = true) {
  const host = windowWithScript();
  const hostCapabilities = serverTools ? { serverTools: {} } : {};
  host.receive({ jsonrpc: "2.0", id: host.sent[0].id, result: { protocolVersion: "2026-01-26", hostInfo: { name: "test", version: "1" }, hostCapabilities, hostContext: { theme: "light", timeZone: "Europe/Berlin" } } });
  host.receive(toolResult(text(view)));
  return host;
}
const calls = (host: Doc, name: string) => host.sent.filter((m: Doc) => m.method === "tools/call" && m.params?.name === name);
const answer = (host: Doc, request: Doc, result: Doc) => host.receive({ jsonrpc: "2.0", id: request.id, result });
const rowOf = (host: Doc, title: string) => segments(host.shown()).find((s) => s.includes(title)) ?? "";

// Taps the first row and lets the order wait for its first poll.
function ordered(view: Doc = VIEW) {
  const host = reading(view);
  host.click(view.rows[0].id);
  answer(host, calls(host, "complete_task")[0], text({ orderID: "O-1", state: "waiting" }));
  return host;
}
// Fires the poll timer and answers that poll.
function poll(host: Doc, state: Doc) {
  host.fire();
  const asked = calls(host, "get_order_result");
  answer(host, asked[asked.length - 1], text(state));
}
const result = (outcome: string, reason?: string) => ({ state: "result", result: { orderID: "O-1", outcome, ...(reason ? { reason } : {}) } });

test("AC-1 (S2b-1): the button shows only with serverTools, on every row of all four views, the Knäuel too", () => {
  for (const view of ["now", "due", "next", "open"]) {
    const doc = { ...VIEW, view, rows: [...VIEW.rows, KNAEUEL] };
    const rows = segments(reading(doc).shown());
    assert.equal(rows.length, 3, `${view}: Zeilen fehlen`);
    for (const row of rows) {
      assert.ok(row.includes('aria-label="Abhaken"') && row.includes('data-act="complete"'), `${view}: Knopf fehlt in ${row}`);
    }
    const without = reading(doc, false);
    assert.ok(!without.shown().includes("Abhaken"), `${view}: Knopf ohne serverTools`);
    without.click(VIEW.rows[0].id);
    assert.equal(without.sent.filter((m: Doc) => m.method === "tools/call").length, 0, `${view}: tools/call ohne serverTools`);
  }
  // Without serverTools the list is byte for byte the one of Schnitt 2a.
  const plain = reading({ ...VIEW, rows: [...VIEW.rows, KNAEUEL] }, false).shown();
  assert.ok(plain.includes(pure.rowsHtml("now", [...VIEW.rows, KNAEUEL], BERLIN)), "Liste ohne serverTools weicht ab");
  assert.equal(pure.rowsHtml("due", [{ id: "C", title: "D", dueDate: "2026-03-14T10:00:00Z" }], BERLIN),
    '<ul><li class="row"><span class="mark">14.3.</span><span class="t">D</span></li></ul>');
});

test("AC-2 (S2b-1): a tap sends exactly one complete_task with taskID and generatedAt; again or foreign sends nothing", () => {
  const host = reading();
  host.click(ID(1));
  const [call, ...more] = calls(host, "complete_task");
  assert.ok(call, "kein complete_task");
  assert.equal(more.length, 0);
  assert.equal(call.jsonrpc, "2.0");
  assert.ok(typeof call.id === "number" && call.id >= 2, `id ${call.id}`);
  assert.deepEqual(call.params.arguments, { taskID: ID(1), generatedAt: VIEW.generatedAt });
  host.click(ID(1));
  host.click("6F1C2B0A-0000-4000-8000-999999999999");
  assert.equal(host.sent.filter((m: Doc) => m.method === "tools/call").length, 1, "zweiter oder fremder Tipp gesendet");
});

test("AC-3 (S2b-1): after the tap the row says it waits for the device and has no button", () => {
  const host = reading();
  host.click(ID(1));
  const row = rowOf(host, "Zahnarzt anrufen");
  assert.ok(row.includes(WAITING_LINE), "Wartezeile fehlt");
  assert.ok(!row.includes("Abhaken"), "Knopf trotz Warten");
  assert.ok(rowOf(host, "Steuer sortieren").includes("Abhaken"), "andere Zeile verlor ihren Knopf");
});

test("AC-4, AC-5 (S2b-1): polls every 3 s while waiting or claimed; done shows the green tick, then the view is read again", () => {
  const host = ordered();
  assert.deepEqual(host.pending().map((t: Doc) => t.ms), [3000], "kein Takt von 3 s");
  poll(host, { state: "waiting" });
  assert.deepEqual(host.pending().map((t: Doc) => t.ms), [3000]);
  poll(host, { state: "claimed" });
  poll(host, result("done"));
  const asked = calls(host, "get_order_result");
  assert.equal(asked.length, 3);
  for (const request of asked) assert.deepEqual(request.params.arguments, { orderID: "O-1" });
  const row = rowOf(host, "Zahnarzt anrufen");
  assert.match(row, /class="[^"]*\bdone\b/, "kein Haken-Zustand");
  assert.ok(!row.includes(WAITING_LINE));
  assert.equal(host.pending().length, 0, "Takt läuft nach dem Ergebnis weiter");
  for (const colour of ["#3E8C5F", "#35925A", "line-through"]) assert.ok(ui.viewHtml.includes(colour), `${colour} fehlt im CSS`);
  const [reread, ...more] = calls(host, "get_view");
  assert.ok(reread, "kein Neulesen");
  assert.equal(more.length, 0);
  assert.deepEqual(reread.params.arguments, { view: "now" });
  answer(host, reread, text({ ...VIEW, generatedAt: "2026-03-12T09:05:00Z", nowCount: 2, rows: [VIEW.rows[1]] }));
  assert.ok(!host.shown().includes("Zahnarzt anrufen"), "neue Ansicht nicht gezeichnet");
  assert.ok(rowOf(host, "Steuer sortieren").includes("Abhaken"));
});

test("AC-6 (S2b-1): rejected says the task changed and reads again; unknown says it did not work", () => {
  for (const reason of ["invalid", "missing", "stale"]) {
    const host = ordered();
    poll(host, result("rejected", reason));
    assert.ok(rowOf(host, "Zahnarzt anrufen").includes(REJECTED_LINE), `${reason}: Zeile fehlt`);
    assert.equal(calls(host, "get_view").length, 1, `${reason}: kein Neulesen`);
    assert.equal(host.pending().length, 0);
  }
  const host = ordered();
  poll(host, { state: "unknown" });
  assert.ok(rowOf(host, "Zahnarzt anrufen").includes(FAILED_LINE), "unknown: Zeile fehlt");
  assert.equal(host.pending().length, 0);
});

test("AC-7 (S2b-1): a changed transcript reads the view once and frees the row; the same refusal again fails without a third read", () => {
  const host = reading();
  host.click(ID(1));
  answer(host, calls(host, "complete_task")[0], { isError: true, content: [{ type: "text", text: STALE }] });
  const [reread, ...more] = calls(host, "get_view");
  assert.ok(reread, "kein Neulesen");
  assert.equal(more.length, 0);
  assert.deepEqual(reread.params.arguments, { view: "now" });
  const fresh = { ...VIEW, generatedAt: "2026-03-12T09:07:00Z" };
  answer(host, reread, text(fresh));
  const row = rowOf(host, "Zahnarzt anrufen");
  assert.ok(row.includes("Abhaken") && !row.includes(WAITING_LINE), "Zeile nicht zurück");
  host.click(ID(1));
  const second = calls(host, "complete_task");
  assert.equal(second.length, 2);
  assert.equal(second[1].params.arguments.generatedAt, fresh.generatedAt, "alte Abschrift erneut gesendet");
  answer(host, second[1], { isError: true, content: [{ type: "text", text: STALE }] });
  assert.ok(rowOf(host, "Zahnarzt anrufen").includes(FAILED_LINE), "zweite Ablehnung ohne Zeile");
  assert.equal(calls(host, "get_view").length, 1, "drittes Lesen");
});

test("AC-4 (S2b-1): after 20 polls without a result the row says the device fetches it later, and polling stops", () => {
  const host = ordered();
  for (let n = 0; n < 20; n++) poll(host, { state: n % 2 ? "claimed" : "waiting" });
  assert.equal(calls(host, "get_order_result").length, 20);
  assert.ok(rowOf(host, "Zahnarzt anrufen").includes(LATE_LINE), "Zeile der Zeitgrenze fehlt");
  assert.equal(host.pending().length, 0, "Takt nach 20 Abfragen");
  host.fire();
  assert.equal(calls(host, "get_order_result").length, 20, "21. Abfrage");
});

test("AC-6 (S2b-1): JSON-RPC errors and other refusals say it did not work, never the host's text", () => {
  const cases: Array<(host: Doc) => void> = [
    (host) => host.receive({ jsonrpc: "2.0", id: calls(host, "complete_task")[0].id, error: { code: -32000, message: "kaputt <geheim>" } }),
    (host) => answer(host, calls(host, "complete_task")[0], { isError: true, content: [{ type: "text", text: "kein Konto <geheim>" }] }),
    (host) => {
      answer(host, calls(host, "complete_task")[0], text({ orderID: "O-1", state: "waiting" }));
      host.fire();
      host.receive({ jsonrpc: "2.0", id: calls(host, "get_order_result")[0].id, error: { code: -32000, message: "weg <geheim>" } });
    },
  ];
  for (const [n, step] of cases.entries()) {
    const host = reading();
    host.click(ID(1));
    step(host);
    assert.ok(rowOf(host, "Zahnarzt anrufen").includes(FAILED_LINE), `Fall ${n}: Zeile fehlt`);
    assert.ok(!host.shown().includes("geheim"), `Fall ${n}: Host-Text sichtbar`);
    assert.equal(host.pending().length, 0, `Fall ${n}: Takt läuft weiter`);
  }
});

test("AC-8 (S2b-1): teardown answers {}, stops the timers, and nothing is asked afterwards", () => {
  const host = ordered();
  assert.equal(host.pending().length, 1);
  host.receive({ jsonrpc: "2.0", id: 7, method: "ui/resource-teardown", params: {} });
  assert.deepEqual(host.sent.find((m: Doc) => m.id === 7 && !m.method), { jsonrpc: "2.0", id: 7, result: {} });
  assert.equal(host.pending().length, 0, "Timer nicht beendet");
  const before = host.sent.filter((m: Doc) => m.method === "tools/call").length;
  host.fire(true);
  host.click(ID(2));
  assert.equal(host.sent.filter((m: Doc) => m.method === "tools/call").length, before, "tools/call nach dem Teardown");
});

test("AC-9 (S2b-1): title and data-id are escaped in every state of a row", () => {
  const nasty = `<b>&"'`;
  const id = `x"><b>`;
  const view = { ...VIEW, rows: [{ ...VIEW.rows[0], id, title: nasty }] };
  const accept = (host: Doc) => { host.click(id); answer(host, calls(host, "complete_task")[0], text({ orderID: "O-1", state: "waiting" })); };
  const states: Record<string, (host: Doc) => void> = {
    button: () => {},
    waiting: (host) => host.click(id),
    done: (host) => { accept(host); poll(host, result("done")); },
    rejected: (host) => { accept(host); poll(host, result("rejected", "stale")); },
    late: (host) => { accept(host); for (let n = 0; n < 20; n++) poll(host, { state: "waiting" }); },
    failed: (host) => { host.click(id); answer(host, calls(host, "complete_task")[0], { isError: true, content: [{ type: "text", text: "x" }] }); },
  };
  for (const [name, step] of Object.entries(states)) {
    const host = reading(view);
    step(host);
    const shown = host.shown();
    assert.ok(shown.includes("&lt;b&gt;&amp;&quot;&#39;"), `${name}: Titel nicht escaped`);
    assert.ok(!shown.includes("<b>&"), `${name}: rohes <b> im HTML`);
    assert.ok(!shown.includes(`data-id="x"`), `${name}: data-id roh`);
  }
  const tapped = reading(view);
  tapped.click(id);
  assert.equal(calls(tapped, "complete_task")[0]?.params.arguments.taskID, id, "Tipp mit escaped data-id nicht erkannt");
});

test("AC-2, AC-4 (S2b-1): reduce stays pure and hands timers back as later", () => {
  let state: Doc = { ready: false, context: {} };
  const step = (message: Doc) => { const next = pure.reduce(state, message); state = next.state; return next; };
  step({ jsonrpc: "2.0", id: 1, result: { hostCapabilities: { serverTools: {} }, hostContext: {} } });
  step(toolResult(text(VIEW)));
  const tap = step({ kind: "tap", taskID: ID(1) });
  const [call] = tap.out;
  assert.equal(call?.method, "tools/call");
  assert.equal(call.params.name, "complete_task");
  const answered = step({ jsonrpc: "2.0", id: call.id, result: text({ orderID: "O-1", state: "waiting" }) });
  assert.deepEqual(answered.later, [{ ms: 3000, event: { kind: "tick", taskID: ID(1) } }]);
  const tick = step({ kind: "tick", taskID: ID(1) });
  assert.equal(tick.out[0]?.params?.name, "get_order_result");
  assert.deepEqual(tick.out[0].params.arguments, { orderID: "O-1" });
});
