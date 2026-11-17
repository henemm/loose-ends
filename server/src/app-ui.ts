// The window a host with MCP Apps shows next to get_view (#624, extension io.modelcontextprotocol/ui, spec 2026-01-26).
// Schnitt 2a: the four views on the app's paper (Gestalt A), light and dark. Schnitt 2b-1: a round button completes a task
// through complete_task, only when the host passes tools/call on (hostCapabilities.serverTools). The protocol is spoken by
// hand in exactly one inline script; no outside source (no _meta.ui.csp, so the host allows nothing external). The pure
// functions below are tested from this module and embedded into the script with Function.prototype.toString().
export const UI_URI = "ui://loose-ends/view.html";
export const UI_MIME = "text/html;profile=mcp-app";

type Doc = Record<string, any>;
type Today = { day: string; timeZone: string };
// caps from the handshake; pending: request id → purpose; rows: taskID → { order?, phase?, polls, retried? } (S2b-1).
type State = { ready: boolean; context: Doc; result?: Doc | null; caps?: Doc; nextId?: number; pending?: Record<string, Doc>; rows?: Record<string, Doc>; ended?: boolean };
// later: timers only the shell runs, { ms, event }.
type Step = { state: State; out: Doc[]; draw: boolean; later?: Doc[] };

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

// While the window may complete tasks: a row's class, its button cell and its quiet line by phase (S2b-1).
function rowAct(row: Doc, entry: Doc | undefined): Doc {
  const phase = entry?.phase;
  const lines: Record<string, string> = {
    waiting: "Abgehakt, wartet auf dein Gerät …", rejected: "Nicht übernommen – die Aufgabe hat sich geändert.",
    late: "Noch nicht übernommen – dein Gerät holt es beim nächsten Öffnen.", failed: "Hat nicht geklappt.",
  };
  const button = `<button class="ring" type="button" aria-label="Abhaken" data-act="complete" data-id="${escape(row.id)}"></button>`;
  const tick = '<span class="tick"><svg width="18" height="18" viewBox="0 0 18 18" fill="none" aria-label="Abgehakt"><path d="M3.5 9.5l3.5 3.5 7.5-8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg></span>';
  const cell = phase === "done" ? tick : phase === undefined || phase === "failed" ? button : "<span></span>";
  return { cls: ` with-act${phase ? ` is-${phase}` : ""}`, cell, note: lines[phase] ? `<span class="note">${lines[phase]}</span>` : "" };
}

// acts (S2b-1): the rows' states when the host allows tools/call; without it the list is the one of Schnitt 2a.
export function rowsHtml(view: string, rows: Doc[], today: Today, acts?: Record<string, Doc>): string {
  if (rows.length === 0) return '<p class="quiet">Hier steht gerade nichts.</p>';
  const items = rows.map((row) => {
    const act = acts ? rowAct(row, acts[row.id]) : { cls: "", cell: "", note: "" };
    return `<li class="row${row.group === "waiting" ? " waiting" : ""}${act.cls}">${mark(view, row, today)}${act.cell}<span class="t">${escape(row.title)}${act.note}</span></li>`;
  });
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
    const acts = state.caps?.serverTools ? (state.rows ?? {}) : undefined;
    return { theme, head, list: rowsHtml(doc.view, doc.rows, { day: dayIn(new Date().toISOString(), timeZone), timeZone }, acts) };
  } catch {
    return quiet;
  }
}

// A tools/call of the window under the next id (the first after the handshake is 2), remembered with its purpose (S2b-1).
function toolCall(state: State, name: string, args: Doc, purpose: Doc): Doc {
  const id = state.nextId ?? 2;
  const next = { ...state, nextId: id + 1, pending: { ...(state.pending ?? {}), [id]: purpose } };
  return { state: next, message: { jsonrpc: "2.0", id, method: "tools/call", params: { name, arguments: args } } };
}

// A row's new state, drawn; with reread the same view is asked again (S2b-1).
function settle(state: State, taskID: string, entry: Doc, reread: boolean): Step {
  const next = { ...state, rows: { ...(state.rows ?? {}), [taskID]: entry } };
  if (!reread) return { state: next, out: [], draw: true };
  const call = toolCall(next, "get_view", { view: state.result?.view }, { purpose: "reread", taskID });
  return { state: call.state, out: [call.message], draw: true };
}

// An event of the shell (S2b-1): tap completes a row of the view read, tick asks for the order's result.
function onEvent(state: State, event: Doc): Step {
  const none = { state, out: [], draw: false };
  const entry = state.rows?.[event.taskID];
  if (state.ended || !state.caps?.serverTools) return none;
  if (event.kind === "tap") {
    const known = state.result && state.result.rows.some((row: Doc) => row.id === event.taskID);
    if (!known || entry?.phase === "waiting") return none;
    const args = { taskID: event.taskID, generatedAt: state.result!.generatedAt };
    const call = toolCall(state, "complete_task", args, { purpose: "complete", taskID: event.taskID });
    return { ...settle(call.state, event.taskID, { phase: "waiting", polls: 0, retried: entry?.retried }, false), out: [call.message] };
  }
  if (entry?.phase !== "waiting" || !entry.order) return none;
  const call = toolCall(state, "get_order_result", { orderID: entry.order }, { purpose: "poll", taskID: event.taskID });
  return { state: settle(call.state, event.taskID, { ...entry, polls: entry.polls + 1 }, false).state, out: [call.message], draw: false };
}

// The answer to one of the window's own calls (S2b-1); the host's error text is never shown.
function onAnswer(state: State, message: Doc): Step {
  const { [message.id]: purpose, ...pending } = state.pending ?? {};
  const rest = { ...state, pending };
  const taskID = purpose.taskID;
  if (purpose.purpose === "reread") {
    const view = message.error ? null : readView(message.result);
    const ids = view ? view.rows.map((row: Doc) => row.id) : [];
    const rows = view ? Object.fromEntries(Object.entries(rest.rows ?? {}).filter(([id]) => ids.includes(id))) : rest.rows;
    return { state: { ...rest, result: view, rows }, out: [], draw: true };
  }
  const entry = rest.rows?.[taskID] ?? {};
  const result = message.error ? null : message.result;
  let doc: Doc | null = null;
  try {
    doc = result && !result.isError ? JSON.parse(result.content?.[0]?.text) : null;
  } catch {
    doc = null;
  }
  const tick = [{ ms: 3000, event: { kind: "tick", taskID } }];
  const failed = settle(rest, taskID, { phase: "failed", polls: 0 }, false);
  if (purpose.purpose === "complete") {
    const stale = result?.isError && result.content?.[0]?.text === "Abschrift hat sich geändert, bitte neu lesen";
    if (stale && !entry.retried) return settle(rest, taskID, { polls: 0, retried: true }, true);
    if (typeof doc?.orderID !== "string") return failed;
    return { ...settle(rest, taskID, { order: doc.orderID, phase: "waiting", polls: 0 }, false), later: tick };
  }
  if (doc?.state === "waiting" || doc?.state === "claimed") {
    return entry.polls >= 20 ? settle(rest, taskID, { ...entry, phase: "late" }, false) : { state: rest, out: [], draw: false, later: tick };
  }
  const outcome = doc?.state === "result" ? doc.result?.outcome : undefined;
  if (outcome === "done" || outcome === "rejected") return settle(rest, taskID, { ...entry, phase: outcome }, true);
  return failed;
}

// One incoming message or shell event: the new state, the messages to send, whether to draw again and the timers.
export function reduce(state: State, message: Doc): Step {
  const none = { state, out: [], draw: false };
  if (message && message.jsonrpc === undefined && (message.kind === "tap" || message.kind === "tick")) return onEvent(state, message);
  if (!message || message.jsonrpc !== "2.0") return none;
  if (!state.ready) {
    if (message.id !== 1 || !message.result) return none;
    const caps = { serverTools: Boolean(message.result.hostCapabilities?.serverTools) };
    const ready = { ...state, ready: true, context: { ...(message.result.hostContext ?? {}) }, caps };
    return { state: ready, out: [{ jsonrpc: "2.0", method: "ui/notifications/initialized" }], draw: true };
  }
  if (message.method === "ui/notifications/host-context-changed") {
    return { state: { ...state, context: { ...state.context, ...(message.params ?? {}) } }, out: [], draw: true };
  }
  if (message.method === "ui/notifications/tool-result") return { state: { ...state, result: readView(message.params) }, out: [], draw: true };
  if (message.method === "ui/resource-teardown" && message.id !== undefined) return { state: { ...state, ended: true }, out: [{ jsonrpc: "2.0", id: message.id, result: {} }], draw: false };
  if (message.method === undefined && !state.ended && state.pending?.[message.id]) return onAnswer(state, message);
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
var timers = [];
var run = function (message) {
  var step = reduce(state, message);
  state = step.state;
  step.out.forEach(post);
  if (step.draw) draw();
  if (state.ended) { timers.forEach(function (timer) { clearTimeout(timer); }); timers = []; return; }
  (step.later || []).forEach(function (item) {
    var timer = setTimeout(function () {
      timers = timers.filter(function (t) { return t !== timer; });
      if (!state.ended) run(item.event);
    }, item.ms);
    timers.push(timer);
  });
};
window.addEventListener("message", function (event) {
  if (event.source !== window.parent) return;
  run(event.data);
});
document.getElementById("list").addEventListener("click", function (event) {
  var button = event.target && event.target.closest ? event.target.closest("[data-act]") : null;
  if (button && button.getAttribute("data-act") === "complete") run({ kind: "tap", taskID: button.getAttribute("data-id") });
});
post({ jsonrpc: "2.0", id: 1, method: "ui/initialize", params: { protocolVersion: "2026-01-26", appInfo: { name: "Loose Ends", version: "1" }, appCapabilities: {} } });
`;

const script = [escape, dayIn, mark, rowAct, rowsHtml, readView, paint, toolCall, settle, onEvent, onAnswer, reduce].map(String).join("\n") + shell;

const dark = "--paper: #171816; --ink: #ECECE6; --quiet: #8E8F88; --rule: #2E2F2B; --red: #FF5A52; --accent: #5FC4C9; --green: #35925A; color-scheme: dark;";

export const viewHtml: string = `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Loose Ends</title>
<style>
:root { --paper: #F4F3EE; --ink: #1B1C19; --quiet: #77786F; --rule: #DCDBD3; --red: #E5322D; --accent: #0F6E73; --green: #3E8C5F; color-scheme: light;
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
.row .red, .row > span.red { color: var(--red); }
.row .t { font-family: var(--serif); font-size: 17px; line-height: 1.3; min-width: 0; overflow-wrap: anywhere; }
.row.waiting .t { color: var(--quiet); }
.row.with-act { grid-template-columns: 62px 44px 1fr; }
.ring { align-self: center; display: grid; place-items: center; width: 44px; height: 44px; margin: -12px 0; padding: 0; border: 0; background: none; cursor: pointer; }
.ring::before { content: ""; width: 20px; height: 20px; box-sizing: border-box; border: 1.6px solid var(--accent); border-radius: 50%; }
.tick { align-self: center; display: grid; place-items: center; color: var(--green); }
.row.is-done .t { text-decoration: line-through; color: var(--quiet); }
.note { display: block; font-style: italic; font-size: 14px; color: var(--quiet); }
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
