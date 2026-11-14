import type pg from "pg";
import { createMcpHandler, McpServer, type CallToolResult, type McpHttpHandler, type ServerContext } from "@modelcontextprotocol/server";
import { z } from "zod";
import { randomUUID } from "node:crypto";
import { checkOrder, getResult, putOrder } from "./orders.ts";
import { getTranscript, type Transcript, type TranscriptTask } from "./transcripts.ts";
import { anleitung } from "./anleitung.ts";

type Group = "knaeuel" | "today" | "lined" | "waiting";

const reply = (text: string): CallToolResult => ({ content: [{ type: "text", text }] });

// The account comes only from authInfo (C6 fills it from a real token); the handler checks no token itself.
function account(ctx: ServerContext): string | undefined {
  const value = ctx.http?.authInfo?.extra?.account;
  return typeof value === "string" && value !== "" ? value : undefined;
}

// The rows of "Now" in the app's order: the Knäuel first, then today, lined, waiting; nothing is recounted or matched.
function nowRows(doc: Transcript) {
  const groups: Array<[Group, string[]]> = [
    ["knaeuel", doc.now.knaeuel === undefined ? [] : [doc.now.knaeuel]],
    ["today", doc.now.today], ["lined", doc.now.lined], ["waiting", doc.now.waiting],
  ];
  const tasks = new Map(doc.tasks.map((task) => [task.id, task]));
  return groups.flatMap(([group, ids]) => ids.map((id) => {
    const task = tasks.get(id);
    if (task === undefined) return { id, group };
    const { title, dueDate, dueHasTime, status, isKnaeuel } = task;
    return { id, title, ...(dueDate === undefined ? {} : { dueDate }), dueHasTime, status, isKnaeuel, group };
  }));
}

type View = "now" | "due" | "next" | "open";
const VIEWS: [View, ...View[]] = ["now", "due", "next", "open"];

// One row of a list: what the app's row shows, never more than the transcript holds.
function summary(task: TranscriptTask) {
  const { id, title, dueDate, dueHasTime, status, isKnaeuel, project, contexts, nextRank } = task;
  return {
    id, title, status, dueHasTime, isKnaeuel, contexts, ...(dueDate === undefined ? {} : { dueDate }),
    ...(project === undefined ? {} : { project }), ...(nextRank === undefined ? {} : { nextRank }),
  };
}

// "Due", "Next up" and "Loose ends" are the app's own lists (ids in the transcript); "now" is nowRows. Nothing is recomputed here.
function viewRows(doc: Transcript, view: View): unknown[] | undefined {
  if (view === "now") return nowRows(doc);
  if (doc.views === undefined) return undefined;
  const tasks = new Map(doc.tasks.map((task) => [task.id, task]));
  return doc.views[view].flatMap((id) => { const task = tasks.get(id); return task === undefined ? [] : [summary(task)]; });
}

const plain = (text: string): string => text.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();

// Names with the number of open tasks that carry them, from the transcript's tasks (the catalog itself is not in it).
function counted(names: string[]) {
  const counts = new Map<string, number>();
  for (const name of names) counts.set(name, (counts.get(name) ?? 0) + 1);
  return [...counts].sort(([a], [b]) => a.localeCompare(b)).map(([name, open]) => ({ name, open }));
}

// A read tool: without an account it refuses before reading, without a transcript it says so without an error.
function reading<A = Record<string, never>>(pool: pg.Pool, render: (doc: Transcript, args: A) => unknown) {
  return async (args: A, ctx: ServerContext): Promise<CallToolResult> => {
    const owner = account(ctx);
    if (owner === undefined) return { ...reply("kein Konto"), isError: true };
    const doc = await getTranscript(pool, owner);
    if (doc === undefined) return reply("noch keine Abschrift");
    const out = render(doc, args);
    return typeof out === "string" ? { ...reply(out), isError: true } : reply(JSON.stringify(out));
  };
}

// The service gives the id; the form check is checkOrder's, its message goes back as it is. Neither text nor id is logged.
function capturing(pool: pg.Pool, wake?: Wake) {
  return async ({ text }: { text: string }, ctx: ServerContext): Promise<CallToolResult> => {
    const owner = account(ctx);
    if (owner === undefined) return { ...reply("kein Konto"), isError: true };
    if (text.trim() === "") return { ...reply("Text fehlt"), isError: true };
    return storeOrder(pool, owner, { version: 1, id: randomUUID().toUpperCase(), kind: "capture", text }, wake);
  };
}

type Target = { owner: string; taskID: string; expectedStatus: string; expectedDueDate?: string; expectedNextRank?: number };

// The expected state comes from the latest transcript, and only if Claude read that one; the id is the transcript's.
// A string is the refusal, before anything is written.
async function expected(pool: pg.Pool, ctx: ServerContext, taskID: string, generatedAt: string): Promise<Target | string> {
  const owner = account(ctx);
  if (owner === undefined) return "kein Konto";
  const doc = await getTranscript(pool, owner);
  if (doc === undefined) return "noch keine Abschrift";
  if (doc.generatedAt !== generatedAt) return "Abschrift hat sich geändert, bitte neu lesen";
  const task = doc.tasks.find((x) => x.id.toUpperCase() === taskID.toUpperCase());
  if (task === undefined) return "Aufgabe nicht in der Abschrift";
  const { id, status, dueDate, nextRank } = task;
  return {
    owner, taskID: id, expectedStatus: status,
    ...(dueDate === undefined ? {} : { expectedDueDate: dueDate }), ...(nextRank === undefined ? {} : { expectedNextRank: nextRank }),
  };
}

export type Wake = (account: string) => Promise<void>;

// checkOrder's message goes back as it is; nothing is logged. Only a newly stored order wakes the account's devices,
// detached: a throwing, rejecting or slow wake changes neither the answer nor its timing (the app also fetches by itself).
export async function storeOrder(
  pool: pg.Pool, owner: string, doc: Record<string, unknown> & { id: string }, wake?: Wake,
): Promise<CallToolResult> {
  try {
    checkOrder(doc);
  } catch (error) {
    return { ...reply((error as Error).message), isError: true };
  }
  const stored = await putOrder(pool, owner, doc);
  if (stored === "stored" && wake !== undefined) void Promise.resolve().then(() => wake(owner)).catch(() => {});
  return reply(JSON.stringify({ orderID: doc.id, state: "waiting" }));
}

function completing(pool: pg.Pool, wake?: Wake) {
  return async ({ taskID, generatedAt }: { taskID: string; generatedAt: string }, ctx: ServerContext): Promise<CallToolResult> => {
    const target = await expected(pool, ctx, taskID, generatedAt);
    if (typeof target === "string") return { ...reply(target), isError: true };
    const { owner, taskID: id, expectedStatus, expectedDueDate } = target;
    return storeOrder(pool, owner, {
      version: 1, id: randomUUID().toUpperCase(), kind: "complete", taskID: id, expectedStatus,
      ...(expectedDueDate === undefined ? {} : { expectedDueDate }),
    }, wake);
  };
}

// Into "Next up" (on) or out of it; the rank the transcript showed is the expected state, so a moved list is refused by the device.
function lining(pool: pg.Pool, wake?: Wake) {
  return async (args: { taskID: string; generatedAt: string; on: boolean }, ctx: ServerContext): Promise<CallToolResult> => {
    const target = await expected(pool, ctx, args.taskID, args.generatedAt);
    if (typeof target === "string") return { ...reply(target), isError: true };
    const { owner, taskID, expectedStatus, expectedNextRank } = target;
    return storeOrder(pool, owner, {
      version: 1, id: randomUUID().toUpperCase(), kind: "setNext", taskID, expectedStatus, on: args.on,
      ...(expectedNextRank === undefined ? {} : { expectedNextRank }),
    }, wake);
  };
}

function parking(pool: pg.Pool, wake?: Wake) {
  return async ({ taskID, generatedAt }: { taskID: string; generatedAt: string }, ctx: ServerContext): Promise<CallToolResult> => {
    const target = await expected(pool, ctx, taskID, generatedAt);
    if (typeof target === "string") return { ...reply(target), isError: true };
    const { owner, taskID: id, expectedStatus } = target;
    return storeOrder(pool, owner, { version: 1, id: randomUUID().toUpperCase(), kind: "park", taskID: id, expectedStatus }, wake);
  };
}

// The line goes as typed; an empty one is refused here, before an order is made. The app trims it and answers invalid for a parent that cannot take one.
function subtasking(pool: pg.Pool, wake?: Wake) {
  return async (args: { taskID: string; generatedAt: string; text: string }, ctx: ServerContext): Promise<CallToolResult> => {
    if (args.text.trim() === "") return { ...reply("Text fehlt"), isError: true };
    const target = await expected(pool, ctx, args.taskID, args.generatedAt);
    if (typeof target === "string") return { ...reply(target), isError: true };
    const { owner, taskID, expectedStatus } = target;
    return storeOrder(pool, owner, { version: 1, id: randomUUID().toUpperCase(), kind: "addSubtask", taskID, expectedStatus, text: args.text }, wake);
  };
}

// Without a date the due date is removed, and then hasTime is always false.
function setting(pool: pg.Pool, wake?: Wake) {
  return async (args: { taskID: string; generatedAt: string; date?: string; hasTime?: boolean }, ctx: ServerContext): Promise<CallToolResult> => {
    const target = await expected(pool, ctx, args.taskID, args.generatedAt);
    if (typeof target === "string") return { ...reply(target), isError: true };
    const { owner, taskID, expectedDueDate } = target;
    const { date } = args;
    const hasTime = date !== undefined && (args.hasTime ?? false);
    return storeOrder(pool, owner, {
      version: 1, id: randomUUID().toUpperCase(), kind: "setDue", taskID, hasTime,
      ...(date === undefined ? {} : { date }), ...(expectedDueDate === undefined ? {} : { expectedDueDate }),
    }, wake);
  };
}

// Only the state and the result document go out, never the order's text.
function resulting(pool: pg.Pool) {
  return async ({ orderID }: { orderID: string }, ctx: ServerContext): Promise<CallToolResult> => {
    const owner = account(ctx);
    if (owner === undefined) return { ...reply("kein Konto"), isError: true };
    return reply(JSON.stringify(await getResult(pool, owner, orderID)));
  };
}

// Stateless: a fresh server with the read tools, the order tools and get_order_result for every request, so nothing is cached.
// With wake, every newly stored order wakes the caller's devices; without it nothing is woken.
export function mcpHandler(pool: pg.Pool, { wake }: { wake?: Wake } = {}): McpHttpHandler {
  return createMcpHandler(() => {
    const server = new McpServer({ name: "loose-ends", version: "1" }, { instructions: anleitung });
    server.registerTool("get_now", {
      description: "Die Zahl über „Jetzt“ und die Zeilen von „Jetzt“ aus der letzten Abschrift",
      inputSchema: z.object({}),
    }, reading(pool, (doc) => ({ nowCount: doc.nowCount, generatedAt: doc.generatedAt, rows: nowRows(doc) })));
    server.registerTool("list_tasks", {
      description: "Alle Aufgaben der letzten Abschrift samt generatedAt",
      inputSchema: z.object({}),
    }, reading(pool, (doc) => ({ generatedAt: doc.generatedAt, tasks: doc.tasks })));
    server.registerTool("get_view", {
      description: "Eine Ansicht der App, in der Reihenfolge der App: now („Jetzt“, mit der Zahl über „Jetzt“), due (Fällig: heute und "
        + "überfällig), next (Als nächstes) oder open (Lose Enden: alles Offene, Geparktes am Ende). Mit generatedAt der Abschrift",
      inputSchema: z.object({ view: z.enum(VIEWS) }),
      annotations: { readOnlyHint: true },
    }, reading<{ view: View }>(pool, (doc, { view }) => {
      const rows = viewRows(doc, view);
      if (rows === undefined) return "Die Abschrift enthält diese Ansicht noch nicht, bitte die App öffnen und aktualisieren";
      return { view, generatedAt: doc.generatedAt, ...(view === "now" ? { nowCount: doc.nowCount } : {}), count: rows.length, rows };
    }));
    server.registerTool("search_tasks", {
      description: "Sucht offene Aufgaben nach Wörtern im Titel (ohne Groß-/Kleinschreibung und Akzente, alle Wörter müssen vorkommen)",
      inputSchema: z.object({ query: z.string() }),
      annotations: { readOnlyHint: true },
    }, reading<{ query: string }>(pool, (doc, { query }) => {
      const words = plain(query).split(/\s+/).filter((word) => word !== "");
      if (words.length === 0) return "Suchtext fehlt";
      const found = doc.tasks.filter((task) => words.every((word) => plain(task.title).includes(word)));
      return { generatedAt: doc.generatedAt, count: found.length, tasks: found.slice(0, 50).map(summary) };
    }));
    server.registerTool("get_task", {
      description: "Eine Aufgabe mit allem, was die Abschrift von ihr kennt, und den Ansichten, in denen sie steht",
      inputSchema: z.object({ taskID: z.string() }),
      annotations: { readOnlyHint: true },
    }, reading<{ taskID: string }>(pool, (doc, { taskID }) => {
      const wanted = taskID.toUpperCase();
      const task = doc.tasks.find((x) => x.id.toUpperCase() === wanted);
      if (task === undefined) return "Aufgabe nicht in der Abschrift";
      const standsIn = (ids: string[] | undefined) => ids?.some((id) => id.toUpperCase() === wanted) ?? false;
      const now = standsIn([...(doc.now.knaeuel === undefined ? [] : [doc.now.knaeuel]), ...doc.now.today, ...doc.now.lined, ...doc.now.waiting]);
      return {
        generatedAt: doc.generatedAt, task,
        views: { now, ...(doc.views === undefined ? {} : { due: standsIn(doc.views.due), next: standsIn(doc.views.next), open: standsIn(doc.views.open) }) },
      };
    }));
    server.registerTool("list_projects", {
      description: "Die Projekte, denen offene Aufgaben zugeordnet sind, mit der Zahl dieser Aufgaben",
      inputSchema: z.object({}),
      annotations: { readOnlyHint: true },
    }, reading(pool, (doc) => ({ generatedAt: doc.generatedAt, projects: counted(doc.tasks.flatMap((task) => task.project === undefined ? [] : [task.project])) })));
    server.registerTool("list_contexts", {
      description: "Die Kontexte (Tags), die offene Aufgaben tragen, mit der Zahl dieser Aufgaben",
      inputSchema: z.object({}),
      annotations: { readOnlyHint: true },
    }, reading(pool, (doc) => ({ generatedAt: doc.generatedAt, contexts: counted(doc.tasks.flatMap((task) => task.contexts)) })));
    server.registerTool("capture_task", {
      description: "Legt einen Auftrag zum Erfassen einer Aufgabe an; erfasst wird sie auf einem Gerät, sobald eines den Auftrag "
        + "abholt. Den Stand liefert get_order_result mit der zurückgegebenen orderID",
      inputSchema: z.object({ text: z.string() }),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
    }, capturing(pool, wake));
    server.registerTool("get_order_result", {
      description: "Stand eines Auftrags: unknown, waiting (wartet auf ein Gerät), claimed (bei einem Gerät) oder result mit dem Ergebnis",
      inputSchema: z.object({ orderID: z.string() }),
      annotations: { readOnlyHint: true },
    }, resulting(pool));
    server.registerTool("complete_task", {
      description: "Legt einen Auftrag zum Abhaken einer Aufgabe an. Zuerst list_tasks oder get_now lesen und deren generatedAt "
        + "mitgeben; abgehakt wird auf einem Gerät, den Stand liefert get_order_result mit der zurückgegebenen orderID",
      inputSchema: z.object({ taskID: z.string(), generatedAt: z.string() }),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
    }, completing(pool, wake));
    server.registerTool("set_due", {
      description: "Legt einen Auftrag zum Setzen der Fälligkeit an; ohne date wird sie entfernt. date als Zeitpunkt in UTC, ganze "
        + "Sekunden, mit Z (z. B. 2026-03-14T08:30:00Z); hasTime sagt, ob die Uhrzeit gilt. Zuerst list_tasks oder get_now lesen "
        + "und deren generatedAt mitgeben; ausgeführt wird auf einem Gerät, den Stand liefert get_order_result. Derselbe "
        + "Zeitpunkt, den die Aufgabe schon hat, mit nur geändertem hasTime wird vom Gerät als invalid abgelehnt. Das ist auch das "
        + "Verschieben auf einen anderen Tag",
      inputSchema: z.object({ taskID: z.string(), generatedAt: z.string(), date: z.string().optional(), hasTime: z.boolean().optional() }),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
    }, setting(pool, wake));
    const write = { readOnlyHint: false, destructiveHint: false, idempotentHint: false };
    const how = "Zuerst list_tasks oder get_now lesen und deren generatedAt mitgeben; ausgeführt wird auf einem Gerät, den Stand liefert get_order_result mit der zurückgegebenen orderID";
    server.registerTool("set_next", {
      description: `Legt einen Auftrag an, die Aufgabe ans Ende von „Als nächstes“ zu stellen (on true) oder herauszunehmen (on false). ${how}. `
        + "Geparkte Aufgaben lehnt das Gerät als invalid ab",
      inputSchema: z.object({ taskID: z.string(), generatedAt: z.string(), on: z.boolean() }),
      annotations: write,
    }, lining(pool, wake));
    server.registerTool("park_task", {
      description: `Legt einen Auftrag an, eine offene Aufgabe zu parken (sie verlässt „Als nächstes“). ${how}`,
      inputSchema: z.object({ taskID: z.string(), generatedAt: z.string() }),
      annotations: write,
    }, parking(pool, wake));
    server.registerTool("add_subtask", {
      description: `Legt einen Auftrag an, unter einer Aufgabe eine Zeile (Unteraufgabe) hinzuzufügen; sie bleibt, wie getippt. ${how}`,
      inputSchema: z.object({ taskID: z.string(), generatedAt: z.string(), text: z.string() }),
      annotations: write,
    }, subtasking(pool, wake));
    return server;
  });
}
