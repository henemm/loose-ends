import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { migrate } from "../src/migrate.ts";
import { putTranscript } from "../src/transcripts.ts";
import * as mcp from "../src/mcp.ts";
import { freshPool } from "./db.ts";

// #795 S5a-2b: every newly stored order wakes the account's devices, detached and fault-proof; a known id or a refusal never does.

type Doc = Record<string, any>;
type T = Parameters<typeof freshPool>[0];
type Wake = (account: string) => Promise<void>;
const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const ID = (n: number) => `6F1C2B0A-0000-4000-8000-${String(n).padStart(12, "0")}`;
const [MUELL, ANGEBOT, STEUER] = [ID(1), ID(2), ID(3)];
const GEN = "2026-03-12T09:00:00Z";

const example = (): Doc => JSON.parse([...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)][0][1]);
const orderCount = async (pool: pg.Pool) => (await pool.query("SELECT count(*)::int AS n FROM orders")).rows[0].n as number;
const settle = (ms = 50) => new Promise((done) => setTimeout(done, ms));
// The handler's own signature grows a second argument in this cut; the cast keeps the call legal before it exists.
const handlerWith = mcp.mcpHandler as unknown as (pool: pg.Pool, options?: { wake?: Wake }) => ReturnType<typeof mcp.mcpHandler>;
const storeOrder = (mcp as Doc).storeOrder as
  | ((pool: pg.Pool, owner: string, doc: Doc, wake?: Wake) => Promise<{ content: Array<{ text: string }>; isError?: boolean }>)
  | undefined;

function counting() {
  const calls: string[] = [];
  return { calls, wake: async (account: string) => { calls.push(account); } };
}

async function setup(t: T, wake?: Wake, account: string | null = "henning") {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  await putTranscript(pool, "henning", example());
  const handler = wake === undefined ? handlerWith(pool) : handlerWith(pool, { wake });
  const authInfo = account === null ? undefined : { token: "t", clientId: "c", scopes: [], extra: { account } };
  const transport = new StreamableHTTPClientTransport(new URL("http://mcp.test/mcp"), {
    fetch: (url, init) => handler.fetch(new Request(url, init), { authInfo }),
  });
  const client = new Client({ name: "test", version: "1" });
  await client.connect(transport);
  t.after(async () => { await client.close(); await handler.close(); });
  return { pool, client };
}
async function call(client: Client, name: string, args: Doc) {
  const result: Doc = await client.callTool({ name, arguments: args });
  return { text: result.content.map((part: Doc) => part.text).join("") as string, isError: result.isError === true };
}

const SIX: Array<[string, Doc]> = [
  ["capture_task", { text: "Milch kaufen" }],
  ["complete_task", { taskID: MUELL, generatedAt: GEN }],
  ["set_due", { taskID: ANGEBOT, generatedAt: GEN, date: "2026-03-14T08:30:00Z", hasTime: true }],
  ["set_next", { taskID: MUELL, generatedAt: GEN, on: true }],
  ["park_task", { taskID: STEUER, generatedAt: GEN }],
  ["add_subtask", { taskID: ANGEBOT, generatedAt: GEN, text: "Kunden anrufen" }],
];

// Collects unhandled rejections for the duration of one test.
function rejections(t: T) {
  const seen: unknown[] = [];
  const onRejection = (reason: unknown) => { seen.push(reason); };
  process.on("unhandledRejection", onRejection);
  t.after(async () => { process.off("unhandledRejection", onRejection); });
  return seen;
}

test("mcp-wake: jedes auftragswerkzeug weckt genau einmal", async (t) => {
  const counter = counting();
  const { client } = await setup(t, counter.wake);
  for (const [i, [name, args]] of SIX.entries()) {
    const answer = await call(client, name, args);
    assert.equal(answer.isError, false, `${name}: ${answer.text}`);
    assert.equal(JSON.parse(answer.text).state, "waiting", name);
    await settle();
    assert.equal(counter.calls.length, i + 1, `${name}: Weckrufe`);
  }
  assert.deepEqual(counter.calls, Array(6).fill("henning"));
});

test("mcp-wake: duplicate weckt nicht", async (t) => {
  assert.equal(typeof storeOrder, "function", "storeOrder fehlt");
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  const counter = counting();
  const doc = { version: 1, id: ID(40), kind: "capture", text: "Zweimal" };
  const first = await storeOrder!(pool, "henning", doc, counter.wake);
  await settle();
  assert.equal(counter.calls.length, 1, "neue ID weckt einmal");
  const again = await storeOrder!(pool, "henning", { ...doc, id: doc.id.toLowerCase() }, counter.wake);
  await settle();
  assert.equal(again.isError === true, false);
  assert.deepEqual(JSON.parse(again.content[0].text), { orderID: doc.id.toLowerCase(), state: "waiting" }, "Antwort wie bisher");
  assert.deepEqual(JSON.parse(first.content[0].text), { orderID: doc.id, state: "waiting" });
  assert.deepEqual(counter.calls, ["henning"], "bekannte ID weckt nicht");
  assert.equal(await orderCount(pool), 1);
});

test("mcp-wake: weckfehler stoert nicht", async (t) => {
  const seen = rejections(t);
  const state = { called: 0, resolved: false };
  const cases: Array<[string, Wake]> = [
    ["wirft synchron", ((_: string) => { state.called++; throw new Error("weck-wurf"); }) as unknown as Wake],
    ["lehnt ab", async () => { state.called++; throw new Error("weck-ablehnung"); }],
    ["langsam", () => { state.called++; return new Promise<void>((done) => setTimeout(() => { state.resolved = true; done(); }, 200)); }],
  ];
  for (const [name, wake] of cases) {
    state.called = 0;
    const { pool, client } = await setup(t, wake);
    const answer = await call(client, "capture_task", { text: `Fall ${name}` });
    if (name === "langsam") assert.equal(state.resolved, false, "Antwort wartet nicht auf den Weckruf");
    assert.equal(answer.isError, false, `${name}: ${answer.text}`);
    assert.equal(JSON.parse(answer.text).state, "waiting", name);
    assert.equal(await orderCount(pool), 1, `${name}: Auftrag liegt`);
    await settle();
    assert.equal(state.called, 1, `${name}: Weckruf versucht`);
  }
  await settle(300);
  assert.equal(state.resolved, true);
  assert.deepEqual(seen, [], "unbehandelte Ablehnung");
});

test("mcp-wake: abgelehnte werkzeuge wecken nicht", async (t) => {
  const counter = counting();
  const { pool, client } = await setup(t, counter.wake);
  const refused: Array<[string, Doc, RegExp]> = [
    ["capture_task", { text: "   " }, /Text fehlt/],
    ["set_due", { taskID: ANGEBOT, generatedAt: "2026-03-11T09:00:00Z", date: "2026-03-14T08:30:00Z" }, /neu lesen/],
    ["complete_task", { taskID: ID(99), generatedAt: GEN }, /nicht in der Abschrift/],
  ];
  for (const [name, args, message] of refused) {
    const answer = await call(client, name, args);
    assert.equal(answer.isError, true, name);
    assert.match(answer.text, message, name);
  }
  const none = await setup(t, counter.wake, null);
  const anonymous = await call(none.client, "capture_task", { text: "Ohne Konto" });
  assert.equal(anonymous.isError, true);
  assert.match(anonymous.text, /kein Konto/);
  assert.equal(typeof storeOrder, "function", "storeOrder fehlt");
  const bad = await storeOrder!(pool, "henning", { version: 1, id: ID(41), kind: "delete" }, counter.wake);
  assert.equal(bad.isError, true);
  assert.match(bad.content[0].text, /Auftrag ungültig/);
  await settle();
  assert.equal(await orderCount(pool), 0);
  assert.equal(await orderCount(none.pool), 0);
  assert.deepEqual(counter.calls, [], "abgelehnt weckt nie");
});

test("mcp-wake: ohne wake wie bisher", async (t) => {
  const seen = rejections(t);
  const { pool, client } = await setup(t);
  for (const [name, args] of SIX) {
    const answer = await call(client, name, args);
    assert.equal(answer.isError, false, `${name}: ${answer.text}`);
    assert.equal(JSON.parse(answer.text).state, "waiting", name);
  }
  assert.equal(await orderCount(pool), 6);
  assert.equal(typeof storeOrder, "function", "storeOrder fehlt");
  const direct = await storeOrder!(pool, "henning", { version: 1, id: ID(42), kind: "capture", text: "Direkt" });
  assert.deepEqual(JSON.parse(direct.content[0].text), { orderID: ID(42), state: "waiting" });
  assert.equal(await orderCount(pool), 7);
  await settle();
  assert.deepEqual(seen, [], "unbehandelte Ablehnung");
});
