import { test } from "node:test";
import assert from "node:assert/strict";
import { join } from "node:path";
import pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { migrate } from "../src/migrate.ts";
import { mcpHandler } from "../src/mcp.ts";
import { anleitung } from "../src/anleitung.ts";
import { freshPool } from "./db.ts";

type T = Parameters<typeof freshPool>[0];

const migrations = join(import.meta.dirname, "../migrations");

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

// A client in the process, no port: every request goes straight to handler.fetch with the account in authInfo.
async function connect(t: T, pool: pg.Pool): Promise<Client> {
  const handler = mcpHandler(pool);
  const authInfo = { token: "test", clientId: "test", scopes: [], extra: { account: "henning" } };
  const transport = new StreamableHTTPClientTransport(new URL("http://mcp.test/mcp"), {
    fetch: (url, init) => handler.fetch(new Request(url, init), { authInfo }),
  });
  const client = new Client({ name: "test", version: "1" });
  await client.connect(transport);
  t.after(async () => { await client.close(); await handler.close(); });
  return client;
}

test("AC-1: initialize carries the instructions of anleitung.ts", async (t) => {
  const client = await connect(t, await migrated(t));
  assert.equal(client.getInstructions(), anleitung);
});

test("AC-2: the instructions fit two kilobytes", () => {
  assert.ok(anleitung.length > 0);
  assert.ok(Buffer.byteLength(anleitung, "utf8") <= 2048);
});

test("AC-3: the instructions name only existing tools", async (t) => {
  const client = await connect(t, await migrated(t));
  const tools = (await client.listTools()).tools.map((tool) => tool.name);
  const named: string[] = anleitung.match(/[a-z]+_[a-z_]+/g) ?? [];
  for (const word of named) assert.ok(tools.includes(word), `${word} ist kein Werkzeug`);
  for (const must of ["get_view", "capture_task", "add_subtask", "get_order_result"]) assert.ok(named.includes(must), `${must} fehlt`);
});

test("AC-4: the instructions hold the rules and no review", () => {
  for (const word of ["Jetzt", "Fällig", "löschen", "Knäuel", "Perle"]) assert.ok(anleitung.includes(word), `${word} fehlt`);
  assert.ok(!anleitung.includes("Rückblick"));
});
