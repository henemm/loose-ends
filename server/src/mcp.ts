import type pg from "pg";
import { createMcpHandler, McpServer, type CallToolResult, type McpHttpHandler, type ServerContext } from "@modelcontextprotocol/server";
import { z } from "zod";
import { randomUUID } from "node:crypto";
import { checkOrder, getResult, putOrder } from "./orders.ts";
import { getTranscript, type Transcript } from "./transcripts.ts";

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

// A read tool: without an account it refuses before reading, without a transcript it says so without an error.
function reading(pool: pg.Pool, render: (doc: Transcript) => unknown) {
  return async (_args: Record<string, never>, ctx: ServerContext): Promise<CallToolResult> => {
    const owner = account(ctx);
    if (owner === undefined) return { ...reply("kein Konto"), isError: true };
    const doc = await getTranscript(pool, owner);
    return reply(doc === undefined ? "noch keine Abschrift" : JSON.stringify(render(doc)));
  };
}

// The service gives the id; the form check is checkOrder's, its message goes back as it is. Neither text nor id is logged.
function capturing(pool: pg.Pool) {
  return async ({ text }: { text: string }, ctx: ServerContext): Promise<CallToolResult> => {
    const owner = account(ctx);
    if (owner === undefined) return { ...reply("kein Konto"), isError: true };
    if (text.trim() === "") return { ...reply("Text fehlt"), isError: true };
    const doc = { version: 1, id: randomUUID().toUpperCase(), kind: "capture", text };
    try {
      checkOrder(doc);
    } catch (error) {
      return { ...reply((error as Error).message), isError: true };
    }
    await putOrder(pool, owner, doc);
    return reply(JSON.stringify({ orderID: doc.id, state: "waiting" }));
  };
}

type Target = { owner: string; taskID: string; expectedStatus: string; expectedDueDate?: string };

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
  const { id, status, dueDate } = task;
  return { owner, taskID: id, expectedStatus: status, ...(dueDate === undefined ? {} : { expectedDueDate: dueDate }) };
}

// checkOrder's message goes back as it is; nothing is logged.
async function storing(pool: pg.Pool, owner: string, doc: Record<string, unknown> & { id: string }): Promise<CallToolResult> {
  try {
    checkOrder(doc);
  } catch (error) {
    return { ...reply((error as Error).message), isError: true };
  }
  await putOrder(pool, owner, doc);
  return reply(JSON.stringify({ orderID: doc.id, state: "waiting" }));
}

function completing(pool: pg.Pool) {
  return async ({ taskID, generatedAt }: { taskID: string; generatedAt: string }, ctx: ServerContext): Promise<CallToolResult> => {
    const target = await expected(pool, ctx, taskID, generatedAt);
    if (typeof target === "string") return { ...reply(target), isError: true };
    const { owner, ...state } = target;
    return storing(pool, owner, { version: 1, id: randomUUID().toUpperCase(), kind: "complete", ...state });
  };
}

// Without a date the due date is removed, and then hasTime is always false.
function setting(pool: pg.Pool) {
  return async (args: { taskID: string; generatedAt: string; date?: string; hasTime?: boolean }, ctx: ServerContext): Promise<CallToolResult> => {
    const target = await expected(pool, ctx, args.taskID, args.generatedAt);
    if (typeof target === "string") return { ...reply(target), isError: true };
    const { owner, taskID, expectedDueDate } = target;
    const { date } = args;
    const hasTime = date !== undefined && (args.hasTime ?? false);
    return storing(pool, owner, {
      version: 1, id: randomUUID().toUpperCase(), kind: "setDue", taskID, hasTime,
      ...(date === undefined ? {} : { date }), ...(expectedDueDate === undefined ? {} : { expectedDueDate }),
    });
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
export function mcpHandler(pool: pg.Pool): McpHttpHandler {
  return createMcpHandler(() => {
    const server = new McpServer({ name: "loose-ends", version: "1" });
    server.registerTool("get_now", {
      description: "Die Zahl über „Jetzt“ und die Zeilen von „Jetzt“ aus der letzten Abschrift",
      inputSchema: z.object({}),
    }, reading(pool, (doc) => ({ nowCount: doc.nowCount, generatedAt: doc.generatedAt, rows: nowRows(doc) })));
    server.registerTool("list_tasks", {
      description: "Alle Aufgaben der letzten Abschrift samt generatedAt",
      inputSchema: z.object({}),
    }, reading(pool, (doc) => ({ generatedAt: doc.generatedAt, tasks: doc.tasks })));
    server.registerTool("capture_task", {
      description: "Legt einen Auftrag zum Erfassen einer Aufgabe an; erfasst wird sie auf einem Gerät, sobald eines den Auftrag "
        + "abholt. Den Stand liefert get_order_result mit der zurückgegebenen orderID",
      inputSchema: z.object({ text: z.string() }),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
    }, capturing(pool));
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
    }, completing(pool));
    server.registerTool("set_due", {
      description: "Legt einen Auftrag zum Setzen der Fälligkeit an; ohne date wird sie entfernt. date als Zeitpunkt in UTC, ganze "
        + "Sekunden, mit Z (z. B. 2026-03-14T08:30:00Z); hasTime sagt, ob die Uhrzeit gilt. Zuerst list_tasks oder get_now lesen "
        + "und deren generatedAt mitgeben; ausgeführt wird auf einem Gerät, den Stand liefert get_order_result. Derselbe "
        + "Zeitpunkt, den die Aufgabe schon hat, mit nur geändertem hasTime wird vom Gerät als invalid abgelehnt",
      inputSchema: z.object({ taskID: z.string(), generatedAt: z.string(), date: z.string().optional(), hasTime: z.boolean().optional() }),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false },
    }, setting(pool));
    return server;
  });
}
