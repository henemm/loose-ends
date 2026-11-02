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

// Only the state and the result document go out, never the order's text.
function resulting(pool: pg.Pool) {
  return async ({ orderID }: { orderID: string }, ctx: ServerContext): Promise<CallToolResult> => {
    const owner = account(ctx);
    if (owner === undefined) return { ...reply("kein Konto"), isError: true };
    return reply(JSON.stringify(await getResult(pool, owner, orderID)));
  };
}

// Stateless: a fresh server with the read tools, capture_task and get_order_result for every request, so nothing is cached.
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
    return server;
  });
}
