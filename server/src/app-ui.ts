// The window a host with MCP Apps shows next to get_view (#624, extension io.modelcontextprotocol/ui, spec 2026-01-26).
// Schnitt 2a: the four views on the app's paper (Gestalt A), light and dark, no buttons yet (S2b). The protocol is spoken by
// hand in exactly one inline script; no outside source (no _meta.ui.csp, so the host allows nothing external). The pure
// functions below are tested from this module and embedded into the script with Function.prototype.toString().
export const UI_URI = "ui://loose-ends/view.html";
export const UI_MIME = "text/html;profile=mcp-app";

type Doc = Record<string, any>;
type Today = { day: string; timeZone: string };
type State = { ready: boolean; context: Doc; result?: Doc | null };
type Step = { state: State; out: Doc[]; draw: boolean };

export function escape(text: unknown): string {
  const entities: Record<string, string> = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" };
  return String(text).replace(/[&<>"']/g, (c) => entities[c]);
}

// The calendar day of an instant in a time zone, as YYYY-MM-DD.
export function dayIn(iso: string, timeZone: string): string {
  return new Intl.DateTimeFormat("sv-SE", { timeZone, year: "numeric", month: "2-digit", day: "2-digit" }).format(new Date(iso));
}

// The margin mark: in now from the group, elsewhere from the due day (today or overdue red, later grey, none without date).
export function mark(view: string, row: Doc, today: Today): string {
  if (view === "now") {
    if (row.group === "knaeuel") return '<span class="mark"><svg width="26" height="16" viewBox="0 0 26 16" fill="none" aria-label="Knäuel"><path d="M2 13c5 0 7-2 9-6s5-5 7-3-1 6-4 5-3-5 1-6 7 2 9 8" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></svg></span>';
    const words: Record<string, string> = { today: '<span class="mark red">Heute</span>', lined: '<span class="mark">Nächstes</span>', waiting: '<span class="mark">Wartet</span>' };
    return words[row.group] ?? "<span></span>";
  }
  if (typeof row.dueDate !== "string") return "<span></span>";
  const day = dayIn(row.dueDate, today.timeZone);
  if (day === today.day) return '<span class="mark red">Heute</span>';
  const label = escape(new Intl.DateTimeFormat("de-DE", { timeZone: today.timeZone, day: "numeric", month: "numeric" }).format(new Date(row.dueDate)));
  return `<span class="mark${day < today.day ? " red" : ""}">${label}</span>`;
}

export function rowsHtml(view: string, rows: Doc[], today: Today): string {
  if (rows.length === 0) return '<p class="quiet">Hier steht gerade nichts.</p>';
  const items = rows.map((row) => `<li class="row${row.group === "waiting" ? " waiting" : ""}">${mark(view, row, today)}<span class="t">${escape(row.title)}</span></li>`);
  return `<ul>${items.join("")}</ul>`;
}

// The view from a tool result, or null for an error, unreadable JSON or an unknown form.
export function readView(result: Doc): Doc | null {
  if (!result || result.isError) return null;
  try {
    const doc = JSON.parse(result.content?.[0]?.text);
    const known = ["now", "due", "next", "open"].includes(doc?.view);
    return known && typeof doc.generatedAt === "string" && Array.isArray(doc.rows) ? doc : null;
  } catch {
    return null;
  }
}

// What the window shows for a state: theme, head and list, all from escaped strings.
export function paint(state: State, fallbackZone: string): Doc {
  const theme = state.context.theme === "dark" || state.context.theme === "light" ? state.context.theme : null;
  const quiet = { theme, head: "<b>Loose Ends</b>", list: '<p class="quiet">Die Ansicht ist gerade nicht lesbar.</p>' };
  if (state.result === undefined) return { ...quiet, list: "" };
  if (state.result === null) return quiet;
  try {
    const timeZone = state.context.timeZone || fallbackZone;
    const doc = state.result;
    const names: Record<string, string> = { now: "Jetzt", due: "Fällig", next: "Als nächstes", open: "Offen" };
    const stand = new Intl.DateTimeFormat("de-DE", { timeZone, hour: "2-digit", minute: "2-digit" }).format(new Date(doc.generatedAt));
    const count = doc.view === "now" ? doc.nowCount : doc.count;
    const head = `<span>${names[doc.view]} <b>${escape(count)}</b></span><span class="s">Stand ${escape(stand)}</span>`;
    return { theme, head, list: rowsHtml(doc.view, doc.rows, { day: dayIn(new Date().toISOString(), timeZone), timeZone }) };
  } catch {
    return quiet;
  }
}

// One incoming message: the new state, the messages to send and whether to draw again. Nothing before the handshake.
export function reduce(state: State, message: Doc): Step {
  const none = { state, out: [], draw: false };
  if (!message || message.jsonrpc !== "2.0") return none;
  if (!state.ready) {
    if (message.id !== 1 || !message.result) return none;
    const ready = { ...state, ready: true, context: { ...(message.result.hostContext ?? {}) } };
    return { state: ready, out: [{ jsonrpc: "2.0", method: "ui/notifications/initialized" }], draw: true };
  }
  if (message.method === "ui/notifications/host-context-changed") {
    return { state: { ...state, context: { ...state.context, ...(message.params ?? {}) } }, out: [], draw: true };
  }
  if (message.method === "ui/notifications/tool-result") return { state: { ...state, result: readView(message.params) }, out: [], draw: true };
  if (message.method === "ui/resource-teardown" && message.id !== undefined) return { state, out: [{ jsonrpc: "2.0", id: message.id, result: {} }], draw: false };
  return none;
}

const shell = `
var state = { ready: false, context: {} };
var post = function (message) { window.parent.postMessage(message, "*"); };
var draw = function () {
  var root = document.documentElement;
  var view = paint(state, Intl.DateTimeFormat().resolvedOptions().timeZone);
  if (view.theme) root.setAttribute("data-theme", view.theme); else root.removeAttribute("data-theme");
  document.getElementById("head").innerHTML = view.head;
  document.getElementById("list").innerHTML = view.list;
  post({ jsonrpc: "2.0", method: "ui/notifications/size-changed", params: { width: root.scrollWidth, height: root.scrollHeight } });
};
window.addEventListener("message", function (event) {
  if (event.source !== window.parent) return;
  var step = reduce(state, event.data);
  state = step.state;
  step.out.forEach(post);
  if (step.draw) draw();
});
post({ jsonrpc: "2.0", id: 1, method: "ui/initialize", params: { protocolVersion: "2026-01-26", appInfo: { name: "Loose Ends", version: "1" }, appCapabilities: {} } });
`;

const script = [escape, dayIn, mark, rowsHtml, readView, paint, reduce].map(String).join("\n") + shell;

const dark = "--paper: #171816; --ink: #ECECE6; --quiet: #8E8F88; --rule: #2E2F2B; --red: #FF5A52; color-scheme: dark;";

export const viewHtml: string = `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Loose Ends</title>
<style>
:root { --paper: #F4F3EE; --ink: #1B1C19; --quiet: #77786F; --rule: #DCDBD3; --red: #E5322D; color-scheme: light;
  --serif: ui-serif, "New York", Georgia, "Times New Roman", serif;
  --sans: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", Roboto, sans-serif; }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { ${dark} } }
:root[data-theme="dark"] { ${dark} }
body { margin: 0; background: var(--paper); color: var(--ink); font-family: var(--sans); overflow: hidden; }
header { display: grid; grid-template-columns: 1fr auto; align-items: baseline; padding: 12px 10px 6px 0; font-size: 12px; color: var(--quiet); }
header > span:first-child { padding-left: 72px; }
header b { color: var(--ink); font-weight: 600; }
header .s { font-size: 11px; }
ul { list-style: none; margin: 0; padding: 0; }
.row { display: grid; grid-template-columns: 62px 1fr; align-items: baseline; border-top: 1px solid var(--rule); padding: 10px 10px 10px 0; }
.row > span:first-child { text-align: right; padding-right: 10px; font-size: 11.5px; font-weight: 600; color: var(--quiet); }
.row .red { color: var(--red); }
.row .t { font-family: var(--serif); font-size: 17px; line-height: 1.3; min-width: 0; overflow-wrap: anywhere; }
.row.waiting .t { color: var(--quiet); }
.quiet { margin: 0; padding: 10px 10px 12px 72px; border-top: 1px solid var(--rule); font-family: var(--serif); font-style: italic; font-size: 14px; color: var(--quiet); }
</style>
</head>
<body>
<header id="head"></header>
<main id="list"></main>
<script>
${script}
</script>
</body>
</html>
`;
