import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { migrate } from "../src/migrate.ts";
import { putTranscript } from "../src/transcripts.ts";
import { checkOrder, claimOrder, putOrder } from "../src/orders.ts";
import { mcpHandler } from "../src/mcp.ts";
import { freshPool } from "./db.ts";

// #622: the order tools beyond capture, complete and set_due: set_next, park_task and add_subtask. Like the others they only
// make an order from the latest transcript; the device runs it and answers with a result.

type Doc = Record<string, any>;
type T = Parameters<typeof freshPool>[0];
const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const ID = (n: number) => `6F1C2B0A-0000-4000-8000-${String(n).padStart(12, "0")}`;
const [MUELL, ANGEBOT, STEUER] = [ID(1), ID(2), ID(3)];

const example = (): Doc => JSON.parse([...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)][0][1]);
const orderRows = async (pool: pg.Pool) => (await pool.query("SELECT kind, doc, account_id FROM orders ORDER BY created_at")).rows;

type Options = { transcript?: Doc | null; wake?: (account: string) => Promise<void> };
async function setup(t: T, account: string | null = "henning", { transcript = example(), wake }: Options = {}) {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  if (transcript !== null) await putTranscript(pool, "henning", transcript);
  const handler = mcpHandler(pool, { wake });
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
const GEN = "2026-03-12T09:00:00Z";

test("set_next: stores a setNext order with the status and the rank the transcript showed", async (t) => {
  const { pool, client } = await setup(t);
  const on = await call(client, "set_next", { taskID: MUELL, generatedAt: GEN, on: true });
  assert.equal(on.isError, false);
  const off = await call(client, "set_next", { taskID: ANGEBOT.toLowerCase(), generatedAt: GEN, on: false });
  assert.equal(off.isError, false);
  const [first, second] = await orderRows(pool);
  assert.equal(first.kind, "setNext");
  assert.equal(first.account_id, "henning");
  const { id: _a, ...a } = first.doc;
  assert.deepEqual(a, { version: 1, kind: "setNext", taskID: MUELL, expectedStatus: "active", on: true });
  const { id: _b, ...b } = second.doc;
  assert.deepEqual(b, { version: 1, kind: "setNext", taskID: ANGEBOT, expectedStatus: "active", on: false, expectedNextRank: 0 });
  assert.doesNotThrow(() => checkOrder(first.doc));
});

test("park_task: stores a park order with the expected status", async (t) => {
  const { pool, client } = await setup(t);
  const answer = await call(client, "park_task", { taskID: STEUER, generatedAt: GEN });
  assert.equal(answer.isError, false);
  assert.equal(JSON.parse(answer.text).state, "waiting");
  const [row] = await orderRows(pool);
  const { id, ...doc } = row.doc;
  assert.match(id, /^[0-9A-F-]{36}$/);
  assert.deepEqual(doc, { version: 1, kind: "park", taskID: STEUER, expectedStatus: "active" });
});

test("add_subtask: stores the line as typed; an empty line is refused before an order exists", async (t) => {
  const { pool, client } = await setup(t);
  const answer = await call(client, "add_subtask", { taskID: ANGEBOT, generatedAt: GEN, text: "  Kunden anrufen " });
  assert.equal(answer.isError, false);
  const [row] = await orderRows(pool);
  assert.equal(row.kind, "addSubtask");
  assert.equal(row.doc.text, "  Kunden anrufen ", "the app trims, the service passes it as typed");
  const empty = await call(client, "add_subtask", { taskID: ANGEBOT, generatedAt: GEN, text: "  \n" });
  assert.equal(empty.isError, true);
  assert.match(empty.text, /Text fehlt/);
  const bad = await call(client, "add_subtask", { taskID: ANGEBOT, generatedAt: GEN, text: "Eins\u0000Zwei" });
  assert.equal(bad.isError, true);
  assert.equal((await orderRows(pool)).length, 1);
});

test("the three tools refuse a changed transcript, an unknown task and a missing account, and store nothing", async (t) => {
  const { pool, client } = await setup(t);
  const inputs: Array<[string, Doc]> = [
    ["set_next", { on: true }], ["park_task", {}], ["add_subtask", { text: "Eins" }],
  ];
  for (const [name, extra] of inputs) {
    const old = await call(client, name, { taskID: MUELL, generatedAt: "2026-03-11T09:00:00Z", ...extra });
    assert.equal(old.isError, true, name);
    assert.match(old.text, /neu lesen/, name);
    const unknown = await call(client, name, { taskID: ID(99), generatedAt: GEN, ...extra });
    assert.equal(unknown.isError, true, name);
    assert.match(unknown.text, /nicht in der Abschrift/, name);
  }
  assert.equal((await orderRows(pool)).length, 0);
  const none = await setup(t, null);
  for (const [name, extra] of inputs) {
    const answer = await call(none.client, name, { taskID: MUELL, generatedAt: GEN, ...extra });
    assert.equal(answer.isError, true, name);
    assert.match(answer.text, /kein Konto/, name);
  }
  assert.equal((await orderRows(none.pool)).length, 0);
});

test("the tools are write tools without idempotence and never destructive; there is no delete tool", async (t) => {
  const { client } = await setup(t);
  const tools = (await client.listTools()).tools;
  for (const name of ["set_next", "park_task", "add_subtask"]) {
    const note = tools.find((tool) => tool.name === name)?.annotations;
    assert.equal(note?.readOnlyHint, false, name);
    assert.equal(note?.destructiveHint, false, name);
    assert.equal(note?.idempotentHint, false, name);
  }
  assert.deepEqual(tools.map((tool) => tool.name).filter((name) => /delete|remove|replace|bulk/i.test(name)), []);
});

test("the service takes the three new kinds in their form and refuses every other", async (t) => {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  const base = { version: 1, id: "0B7D5E3C-0000-4000-8000-000000000020", taskID: MUELL, expectedStatus: "active" };
  const good: Doc[] = [
    { ...base, kind: "setNext", on: true }, { ...base, kind: "setNext", on: false, expectedNextRank: 3 },
    { ...base, kind: "park" }, { ...base, kind: "addSubtask", text: "Eins" },
  ];
  for (const [i, doc] of good.entries()) {
    const withId = { ...doc, id: `0B7D5E3C-0000-4000-8000-0000000001${i}0` };
    assert.equal(await putOrder(pool, "henning", withId), "stored", doc.kind);
  }
  const bad: Array<[string, Doc]> = [
    ["setNext ohne on", { ...base, kind: "setNext" }],
    ["setNext on kein Wahrheitswert", { ...base, kind: "setNext", on: "yes" }],
    ["setNext Rang negativ", { ...base, kind: "setNext", on: true, expectedNextRank: -1 }],
    ["setNext Rang Bruch", { ...base, kind: "setNext", on: true, expectedNextRank: 1.5 }],
    ["park mit Text", { ...base, kind: "park", text: "x" }],
    ["park ohne Status", { version: 1, id: base.id, kind: "park", taskID: MUELL }],
    ["addSubtask ohne Text", { ...base, kind: "addSubtask" }],
    ["addSubtask Text mit NUL", { ...base, kind: "addSubtask", text: "a\u0000b" }],
    ["addSubtask mit on", { ...base, kind: "addSubtask", text: "x", on: true }],
    ["unbekannte Art", { ...base, kind: "delete" }],
  ];
  for (const [name, doc] of bad) assert.throws(() => checkOrder(doc), /Auftrag ungültig/, name);
  // The database knows the kinds too, and a device can claim them like any other order.
  const claimed = [await claimOrder(pool, "henning", "iphone"), await claimOrder(pool, "henning", "iphone")];
  assert.ok(claimed.every((doc) => doc !== undefined));
  assert.equal((await pool.query("SELECT count(*)::int AS n FROM orders")).rows[0].n, 4);
  await assert.rejects(pool.query("INSERT INTO orders (doc, account_id) VALUES ($1::jsonb, 'x')",
    [JSON.stringify({ version: 1, id: "0B7D5E3C-0000-4000-8000-000000000099", kind: "delete" })]), /orders_kind_known/);
});

// #932 Schnitt 3: update_task. The expected state names only the fields that change, from the transcript's row.
// ANGEBOT gets a due date here, so one task carries title, tags, project and due date; MUELL has no tags and no project.
const DUE = "2026-03-13T10:00:00Z";
const full = (): Doc => {
  const doc = example();
  Object.assign(doc.tasks.find((task: Doc) => task.id === ANGEBOT), { dueDate: DUE, dueHasTime: true });
  return doc;
};
const bare = (): Doc => {
  const doc = example();
  const task = doc.tasks.find((t: Doc) => t.id === ANGEBOT);
  delete task.project;
  task.contexts = [];
  return doc;
};
const storedDoc = async (pool: pg.Pool) => {
  const rows = await orderRows(pool);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].kind, "update");
  const { id, ...doc } = rows[0].doc;
  assert.match(id, /^[0-9A-F-]{36}$/);
  assert.doesNotThrow(() => checkOrder(rows[0].doc));
  return doc;
};

test("update_task: a new title carries only expectedStatus and expectedTitle", async (t) => {
  const { pool, client } = await setup(t, "henning", { transcript: full() });
  const answer = await call(client, "update_task", { taskID: ANGEBOT, generatedAt: GEN, fields: { title: "Angebot an Müller" } });
  assert.equal(answer.isError, false, answer.text);
  assert.equal(JSON.parse(answer.text).state, "waiting");
  assert.deepEqual(await storedDoc(pool), {
    version: 1, kind: "update", taskID: ANGEBOT, expectedStatus: "active", expectedTitle: "Angebot schreiben",
    fields: { title: "Angebot an Müller" },
  });
});

test("update_task: tags, project and due date carry the row's values; a row without them leaves the keys out", async (t) => {
  const fields = { contexts: ["Computer", "Telefon"], project: "Büro", dueDate: "2026-03-14T08:00:00Z", dueHasTime: true };
  const { pool, client } = await setup(t, "henning", { transcript: full() });
  const answer = await call(client, "update_task", { taskID: ANGEBOT, generatedAt: GEN, fields });
  assert.equal(answer.isError, false, answer.text);
  assert.deepEqual(await storedDoc(pool), {
    version: 1, kind: "update", taskID: ANGEBOT, expectedStatus: "active", fields,
    expectedContexts: ["Computer"], expectedProject: "Haus", expectedDueDate: DUE,
  });
  const empty = await setup(t, "henning", { transcript: bare() });
  const again = await call(empty.client, "update_task", { taskID: ANGEBOT, generatedAt: GEN, fields });
  assert.equal(again.isError, false, again.text);
  assert.deepEqual(await storedDoc(empty.pool), { version: 1, kind: "update", taskID: ANGEBOT, expectedStatus: "active", fields });
  // Importance, urgency, duration and energy are not in the transcript: only the status is expected.
  const levels = await setup(t, "henning", { transcript: full() });
  const quiet = { importance: "high", urgency: "low", duration: "minutes30", energy: -1 };
  assert.equal((await call(levels.client, "update_task", { taskID: ANGEBOT, generatedAt: GEN, fields: quiet })).isError, false);
  assert.deepEqual(await storedDoc(levels.pool), { version: 1, kind: "update", taskID: ANGEBOT, expectedStatus: "active", fields: quiet });
});

test("update_task: a foreign key, notes, empty fields and wrong values are refused, no order exists", async (t) => {
  const { pool, client } = await setup(t, "henning", { transcript: full() });
  for (const fields of [
    { titel: "Hecke" }, { notes: "x" }, {}, { importance: "urgent" }, { energy: 4 }, { dueDate: "2026-03-14T08:00:00Z" },
  ]) {
    const answer = await call(client, "update_task", { taskID: ANGEBOT, generatedAt: GEN, fields });
    assert.equal(answer.isError, true, JSON.stringify(fields));
  }
  assert.equal((await call(client, "update_task", { taskID: ANGEBOT, generatedAt: GEN })).isError, true, "ohne fields");
  assert.equal((await orderRows(pool)).length, 0);
});

test("update_task: refuses like the other write tools, and stores nothing", async (t) => {
  const fields = { title: "Neu" };
  const { pool, client } = await setup(t);
  for (const [args, reason] of [
    [{ taskID: ID(99), generatedAt: GEN, fields }, /Aufgabe nicht in der Abschrift/],
    [{ taskID: MUELL, generatedAt: "2026-03-11T09:00:00Z", fields }, /Abschrift hat sich geändert, bitte neu lesen/],
  ] as const) {
    const answer = await call(client, "update_task", args);
    assert.equal(answer.isError, true);
    assert.match(answer.text, reason);
  }
  assert.equal((await orderRows(pool)).length, 0);
  const blank = await setup(t, "henning", { transcript: null });
  const first = await call(blank.client, "update_task", { taskID: MUELL, generatedAt: GEN, fields });
  assert.equal(first.isError, true);
  assert.match(first.text, /noch keine Abschrift/);
  assert.equal((await orderRows(blank.pool)).length, 0);
  const none = await setup(t, null);
  const nobody = await call(none.client, "update_task", { taskID: MUELL, generatedAt: GEN, fields });
  assert.equal(nobody.isError, true);
  assert.match(nobody.text, /kein Konto/);
  assert.equal((await orderRows(none.pool)).length, 0);
});

test("update_task: a stored order wakes the account once, a refusal never", async (t) => {
  const calls: string[] = [];
  const wake = async (account: string) => { calls.push(account); };
  const { pool, client } = await setup(t, "henning", { wake });
  assert.equal((await call(client, "update_task", { taskID: MUELL, generatedAt: GEN, fields: { title: "Tonne raus" } })).isError, false);
  await new Promise((done) => setTimeout(done, 50));
  assert.deepEqual(calls, ["henning"]);
  assert.equal((await call(client, "update_task", { taskID: MUELL, generatedAt: GEN, fields: {} })).isError, true);
  assert.equal((await call(client, "update_task", { taskID: ID(99), generatedAt: GEN, fields: { title: "x" } })).isError, true);
  await new Promise((done) => setTimeout(done, 50));
  assert.deepEqual(calls, ["henning"]);
  assert.equal((await orderRows(pool)).length, 1);
});

test("update_task: a write tool whose fields are strict and hold exactly capture's keys without notes", async (t) => {
  const { client } = await setup(t);
  const tools = (await client.listTools()).tools;
  const tool = tools.find((one) => one.name === "update_task");
  assert.ok(tool, "update_task fehlt");
  assert.equal(tool.annotations?.readOnlyHint, false);
  assert.equal(tool.annotations?.destructiveHint, false);
  assert.equal(tool.annotations?.idempotentHint, false);
  const schema = tool.inputSchema as Doc;
  assert.deepEqual([...(schema.required ?? [])].sort(), ["fields", "generatedAt", "taskID"]);
  const fields = schema.properties.fields;
  assert.equal(fields.additionalProperties, false, "fields muss .strict() sein");
  const capture = (tools.find((one) => one.name === "capture_task")!.inputSchema as Doc).properties.fields;
  const captureKeys = Object.keys(capture.properties).filter((key) => key !== "notes").sort();
  assert.deepEqual(Object.keys(fields.properties).sort(), captureKeys);
  assert.equal(captureKeys.length, 9);
});
