import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { migrate } from "../src/migrate.ts";
import { getTranscript, putTranscript } from "../src/transcripts.ts";
import { checkOrder, claimOrder, putResult } from "../src/orders.ts";
import { mcpHandler } from "../src/mcp.ts";
import { freshPool } from "./db.ts";

type Doc = Record<string, any>;
type T = Parameters<typeof freshPool>[0];

const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const [steuer, muell, angebot] = ["…0003", "…0001", "…0002"];

// The transcript example is read from the contract, never copied (first of the three ```json blocks).
function example(): Doc {
  const blocks = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  assert.equal(blocks.length, 3, "der Vertrag muss genau drei ```json-Blöcke enthalten");
  return JSON.parse(blocks[0][1]);
}

const changed = (change: (copy: Doc) => void): Doc => { const copy = example(); change(copy); return copy; };
const byEnd = (doc: Doc, end: string) => doc.tasks.find((task: Doc) => task.id.endsWith(end.slice(1))).id;
const fakeID = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

// A client in the process, no port: every request goes straight to handler.fetch with the account in authInfo.
async function connect(t: T, pool: pg.Pool, account?: string): Promise<Client> {
  const handler = mcpHandler(pool);
  const authInfo = account === undefined ? undefined : { token: "test", clientId: "test", scopes: [], extra: { account } };
  const transport = new StreamableHTTPClientTransport(new URL("http://mcp.test/mcp"), {
    fetch: (url, init) => handler.fetch(new Request(url, init), { authInfo }),
  });
  const client = new Client({ name: "test", version: "1" });
  await client.connect(transport);
  t.after(async () => { await client.close(); await handler.close(); });
  return client;
}

async function call(client: Client, name: string, args: Doc = {}): Promise<{ text: string; isError: boolean }> {
  const result: Doc = await client.callTool({ name, arguments: args });
  return { text: result.content.map((part: Doc) => part.text).join(""), isError: result.isError === true };
}
const json = async (client: Client, name: string) => JSON.parse((await call(client, name)).text);
const titles = (doc: Doc) => doc.tasks.map((task: Doc) => task.title as string);

test("AC-1/AC-3: tools/list names the tools, with the annotations of the write and read tools", async (t) => {
  const client = await connect(t, await migrated(t), "henning");
  const tools = (await client.listTools()).tools;
  assert.deepEqual(tools.map((tool) => tool.name).sort(), ["capture_task", "complete_task", "get_now", "get_order_result", "get_task", "get_view", "list_contexts", "list_projects", "list_tasks", "search_tasks", "set_due"]);
  const note = (name: string) => tools.find((tool) => tool.name === name)?.annotations;
  assert.equal(note("capture_task")?.readOnlyHint, false);
  assert.equal(note("capture_task")?.destructiveHint, false);
  assert.equal(note("capture_task")?.idempotentHint, false);
  assert.equal(note("get_order_result")?.readOnlyHint, true);
});

test("AC-2: without an account the read tools refuse and reads nothing", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool);
  for (const name of ["get_now", "list_tasks"]) {
    await t.test(name, async () => {
      const { text, isError } = await call(client, name);
      assert.equal(isError, true);
      assert.match(text, /kein Konto/);
      for (const title of titles(example())) assert.ok(!text.includes(title), `${title} darf nicht vorkommen`);
    });
  }
});

test("AC-3/AC-4: another account and an account without transcript get „noch keine Abschrift“", async (t) => {
  for (const [label, stored] of [["AC-3 fremdes Konto", true], ["AC-4 keine Abschrift", false]] as const) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      if (stored) await putTranscript(pool, "henning", example());
      const client = await connect(t, pool, "anna");
      for (const name of ["get_now", "list_tasks"]) {
        const { text, isError } = await call(client, name);
        assert.equal(isError, false, name);
        assert.match(text, /noch keine Abschrift/, name);
        for (const title of titles(example())) assert.ok(!text.includes(title), `${name}: ${title}`);
      }
    });
  }
});

test("AC-5: get_now passes nowCount through and never recounts", async (t) => {
  for (const [label, doc, expected] of [["Vertrag", example(), example().nowCount], ["7 bei drei Zeilen", changed((d) => { d.nowCount = 7; }), 7]] as const) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      await putTranscript(pool, "henning", doc);
      assert.equal((await json(await connect(t, pool, "henning"), "get_now")).nowCount, expected);
    });
  }
});

test("AC-6: get_now orders knaeuel, today, lined, waiting and keeps the order inside a group", async (t) => {
  const doc = example();
  const many = changed((d) => {
    d.now = { today: [fakeID(2), fakeID(1)], lined: [fakeID(4), fakeID(3)], waiting: [fakeID(6), fakeID(5)] };
  });
  const cases: Array<[string, Doc, Array<[string, string]>]> = [
    ["Vertrag", doc, [[byEnd(doc, steuer), "knaeuel"], [byEnd(doc, muell), "today"], [byEnd(doc, angebot), "lined"]]],
    ["ohne Knäuel, mehrere je Gruppe", many, [[fakeID(2), "today"], [fakeID(1), "today"], [fakeID(4), "lined"],
      [fakeID(3), "lined"], [fakeID(6), "waiting"], [fakeID(5), "waiting"]]],
  ];
  for (const [label, input, expected] of cases) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      await putTranscript(pool, "henning", input);
      const rows = (await json(await connect(t, pool, "henning"), "get_now")).rows;
      assert.deepEqual(rows.map((row: Doc) => [row.id, row.group]), expected);
    });
  }
});

test("AC-7: each row of get_now carries the task's fields; an id without task stays id and group", async (t) => {
  const doc = changed((d) => { d.now.waiting = [fakeID(9)]; });
  const pool = await migrated(t);
  await putTranscript(pool, "henning", doc);
  const out = await json(await connect(t, pool, "henning"), "get_now");
  assert.equal(out.generatedAt, doc.generatedAt);
  const row = (id: string) => out.rows.find((r: Doc) => r.id === id);
  const take = (task: Doc, group: string) => {
    const { id, title, dueDate, dueHasTime, status, isKnaeuel } = task;
    return { id, title, ...(dueDate === undefined ? {} : { dueDate }), dueHasTime, status, isKnaeuel, group };
  };
  const task = (end: string) => doc.tasks.find((x: Doc) => x.id === byEnd(doc, end));
  assert.deepEqual(row(byEnd(doc, muell)), take(task(muell), "today"));
  assert.equal(row(byEnd(doc, muell)).dueDate, "2026-03-12T17:00:00Z");
  assert.equal(row(byEnd(doc, muell)).dueHasTime, true);
  assert.equal(row(byEnd(doc, muell)).status, "active");
  assert.deepEqual(row(byEnd(doc, steuer)), take(task(steuer), "knaeuel"));
  assert.equal(row(byEnd(doc, steuer)).isKnaeuel, true);
  assert.deepEqual(row(byEnd(doc, angebot)), take(task(angebot), "lined"));
  assert.deepEqual(row(fakeID(9)), { id: fakeID(9), group: "waiting" });
});

test("AC-8: list_tasks returns every task as delivered, with generatedAt", async (t) => {
  for (const [label, doc] of [["Vertrag", example()], ["vertauscht", changed((d) => { d.tasks.reverse(); })]] as const) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      await putTranscript(pool, "henning", doc);
      const out = await json(await connect(t, pool, "henning"), "list_tasks");
      assert.deepEqual(out, { generatedAt: doc.generatedAt, tasks: doc.tasks });
    });
  }
});

test("AC-9: no raw text or note in any answer, nothing on console or stdout", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool, "henning");
  const log = t.mock.method(console, "log");
  const write = t.mock.method(process.stdout, "write");
  const texts = [(await call(client, "get_now")).text, (await call(client, "list_tasks")).text];
  const [logs, writes] = [log.mock.callCount(), write.mock.callCount()];
  t.mock.restoreAll();
  assert.equal(logs, 0, "console.log");
  assert.equal(writes, 0, "process.stdout.write");
  for (const text of texts) assert.ok(!/"rawText"|"note"/.test(text), text);
});

test("AC-10: a newer upload is read on the next call, nothing is cached", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool, "henning");
  assert.equal((await json(client, "list_tasks")).generatedAt, example().generatedAt);
  const newer = changed((d) => { d.generatedAt = "2026-03-13T09:00:00+01:00"; d.nowCount = 5; });
  assert.equal(await putTranscript(pool, "henning", newer), "stored");
  assert.equal((await json(client, "list_tasks")).generatedAt, newer.generatedAt);
  assert.equal((await json(client, "get_now")).nowCount, 5);
});

test("AC-13: getTranscript returns the stored document or undefined", async (t) => {
  const pool = await migrated(t);
  assert.equal(await getTranscript(pool, "henning"), undefined);
  await putTranscript(pool, "henning", example());
  assert.deepEqual(await getTranscript(pool, "henning"), example());
  assert.equal(await getTranscript(pool, "anna"), undefined);
});

const orderCount = async (pool: pg.Pool) => Number((await pool.query("SELECT count(*) AS n FROM orders")).rows[0].n);
const capture = (client: Client, text: string) => call(client, "capture_task", { text });
const result = (client: Client, orderID: string) => call(client, "get_order_result", { orderID });
const UUID = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/;

test("AC-4 (C4b-1): without an account both new tools refuse and capture_task stores nothing", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool);
  for (const [name, args] of [["capture_task", { text: "Milch kaufen" }], ["get_order_result", { orderID: fakeID(1) }]] as const) {
    const { text, isError } = await call(client, name, args);
    assert.equal(isError, true, name);
    assert.match(text, /kein Konto/, name);
  }
  assert.equal(await orderCount(pool), 0);
});

test("AC-5/AC-6 (C4b-1): capture_task stores one capture order per call, waiting, for the account from authInfo", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, "henning");
  const first = await capture(client, "Milch kaufen");
  assert.equal(first.isError, false);
  const { orderID, state } = JSON.parse(first.text);
  assert.match(orderID, UUID);
  assert.equal(state, "waiting");
  assert.equal(await orderCount(pool), 1);
  const row = (await pool.query("SELECT * FROM orders WHERE id = $1", [orderID])).rows[0];
  assert.equal(row.kind, "capture");
  assert.equal(row.account_id, "henning");
  assert.equal(row.claimed_by, null);
  assert.equal(row.doc.text, "Milch kaufen");
  assert.doesNotThrow(() => checkOrder(row.doc));
  const second = JSON.parse((await capture(client, "Milch kaufen")).text);
  assert.notEqual(second.orderID, orderID);
  assert.equal(await orderCount(pool), 2);
});

test("AC-7 (C4b-1): empty, blank and invalid text store nothing and answer isError", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, "henning");
  for (const text of ["", "   \n\t"]) {
    const answer = await capture(client, text);
    assert.equal(answer.isError, true, JSON.stringify(text));
    assert.match(answer.text, /Text fehlt/);
  }
  for (const text of ["Milch\u0000kaufen", "Milch\ud800kaufen"]) {
    const answer = await capture(client, text);
    assert.equal(answer.isError, true, JSON.stringify(text));
    assert.match(answer.text, /Auftrag/);
  }
  assert.equal(await orderCount(pool), 0);
});

test("AC-8/AC-9 (C4b-1): get_order_result goes waiting, claimed, result; unknown and foreign ids are unknown, no order text", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, "henning");
  const { orderID } = JSON.parse((await capture(client, "Geheimer Auftragstext")).text);
  const state = async (c: Client, id = orderID) => {
    const answer = await result(c, id);
    assert.equal(answer.isError, false);
    assert.ok(!answer.text.includes("Geheimer Auftragstext"), answer.text);
    return JSON.parse(answer.text);
  };
  assert.deepEqual(await state(client), { state: "waiting" });
  assert.ok(await claimOrder(pool, "henning", "iphone"));
  assert.deepEqual(await state(client), { state: "claimed" });
  const doc = { orderID, outcome: "rejected", reason: "stale" };
  assert.equal(await putResult(pool, "henning", "iphone", doc), "stored");
  assert.deepEqual(await state(client), { state: "result", result: doc });
  assert.deepEqual(await state(client, fakeID(5)), { state: "unknown" });
  assert.deepEqual(await state(await connect(t, pool, "anna")), { state: "unknown" });
});

test("AC-10 (C4b-1): neither new tool writes to console or stdout", async (t) => {
  const pool = await migrated(t);
  const client = await connect(t, pool, "henning");
  const log = t.mock.method(console, "log");
  const write = t.mock.method(process.stdout, "write");
  const { orderID } = JSON.parse((await capture(client, "Milch kaufen")).text);
  await result(client, orderID);
  await capture(client, "");
  const [logs, writes] = [log.mock.callCount(), write.mock.callCount()];
  t.mock.restoreAll();
  assert.equal(logs, 0, "console.log");
  assert.equal(writes, 0, "process.stdout.write");
});

const mutate = (client: Client, name: "complete_task" | "set_due", input: Doc) => call(client, name, input);
const rowOf = async (pool: pg.Pool, answer: { text: string }) => (await pool.query("SELECT * FROM orders WHERE id = $1", [JSON.parse(answer.text).orderID])).rows[0];
const tools2 = [["complete_task", {}], ["set_due", { date: "2026-03-13T10:00:00Z", hasTime: true }]] as const;
// One task with a due date and one without, from the contract's example.
const [dated, undated] = [byEnd(example(), muell), byEnd(example(), angebot)];
const input = (taskID: string, extra: Doc = {}, generatedAt = example().generatedAt) => ({ taskID, generatedAt, ...extra });

test("AC-1 (C4b-2): complete_task and set_due are write tools without idempotence and point to list_tasks and get_order_result", async (t) => {
  const tools = (await (await connect(t, await migrated(t), "henning")).listTools()).tools;
  for (const name of ["complete_task", "set_due"]) {
    const found = tools.find((x) => x.name === name);
    assert.equal(found?.annotations?.readOnlyHint, false, name);
    assert.equal(found?.annotations?.destructiveHint, false, name);
    assert.equal(found?.annotations?.idempotentHint, false, name);
    assert.match(found?.description ?? "", /list_tasks/, name);
    assert.match(found?.description ?? "", /get_order_result/, name);
  }
});

test("AC-2/AC-3 (C4b-2): without an account or without a transcript both tools refuse and store nothing", async (t) => {
  for (const [label, account, text] of [["AC-2 kein Konto", undefined, /kein Konto/], ["AC-3 keine Abschrift", "henning", /noch keine Abschrift/]] as const) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      const client = await connect(t, pool, account);
      for (const [name, extra] of tools2) {
        const answer = await mutate(client, name, input(dated, extra));
        assert.equal(answer.isError, true, name);
        assert.match(answer.text, text, name);
      }
      assert.equal(await orderCount(pool), 0);
    });
  }
});

test("AC-4 (C4b-2): a generatedAt that differs from the stored transcript stores nothing; the same one stores an order", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool, "henning");
  for (const [name, extra] of tools2) {
    const stale = await mutate(client, name, input(dated, extra, "2026-03-12T08:00:00Z"));
    assert.equal(stale.isError, true, name);
    assert.match(stale.text, /Abschrift hat sich geändert, bitte neu lesen/, name);
  }
  assert.equal(await orderCount(pool), 0);
  for (const [name, extra] of tools2) assert.equal((await mutate(client, name, input(dated, extra))).isError, false, name);
  assert.equal(await orderCount(pool), 2);
});

test("AC-5 (C4b-2): a task the transcript no longer carries is refused; a lowercase id finds a task and the order carries the transcript's id", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", changed((d) => { d.tasks.push({ ...d.tasks[0], id: fakeID(7) }); }));
  const newer = changed((d) => { d.generatedAt = "2026-03-13T09:00:00Z"; });
  assert.equal(await putTranscript(pool, "henning", newer), "stored");
  const client = await connect(t, pool, "henning");
  for (const [name, extra] of tools2) {
    for (const id of [fakeID(7), fakeID(8)]) {
      const answer = await mutate(client, name, input(id, extra, newer.generatedAt));
      assert.equal(answer.isError, true, name);
      assert.match(answer.text, /Aufgabe nicht in der Abschrift/, name);
    }
  }
  assert.equal(await orderCount(pool), 0);
  const found = await mutate(client, "complete_task", input(dated.toLowerCase(), {}, newer.generatedAt));
  assert.equal(found.isError, false);
  assert.equal((await rowOf(pool, found)).doc.taskID, dated);
});

test("AC-6 (C4b-2): complete_task stores one complete order with the expected state from the transcript", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", changed((d) => { d.tasks.find((task: Doc) => task.id === undated).status = "parked"; }));
  const client = await connect(t, pool, "henning");
  const first = await mutate(client, "complete_task", input(dated));
  assert.equal(first.isError, false);
  const { orderID, state, ...rest } = JSON.parse(first.text);
  assert.match(orderID, UUID);
  assert.equal(state, "waiting");
  assert.deepEqual(rest, {}, "nur orderID und state");
  const row = await rowOf(pool, first);
  assert.equal(row.kind, "complete");
  assert.equal(row.account_id, "henning");
  assert.equal(row.claimed_by, null);
  assert.deepEqual(row.doc, { version: 1, id: orderID, kind: "complete", taskID: dated, expectedStatus: "active", expectedDueDate: "2026-03-12T17:00:00Z" });
  assert.doesNotThrow(() => checkOrder(row.doc));
  const bare = (await rowOf(pool, await mutate(client, "complete_task", input(undated)))).doc;
  assert.equal(bare.expectedStatus, "parked");
  assert.ok(!Object.hasOwn(bare, "expectedDueDate"), "Schlüssel fehlt ohne Fälligkeit");
  assert.doesNotThrow(() => checkOrder(bare));
});

test("AC-7 (C4b-2): set_due stores the date and hasTime as given, with the expected due date; without date the key is missing", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool, "henning");
  const when = "2026-03-14T08:30:00Z";
  const cases: Array<[string, string, Doc, Doc]> = [
    ["mit Datum und hasTime", dated, { date: when, hasTime: true }, { date: when, hasTime: true, expectedDueDate: "2026-03-12T17:00:00Z" }],
    ["ohne hasTime", undated, { date: when }, { date: when, hasTime: false }],
    ["ohne Datum, hasTime wahr", dated, { hasTime: true }, { hasTime: false, expectedDueDate: "2026-03-12T17:00:00Z" }],
  ];
  for (const [label, id, extra, expected] of cases) {
    const answer = await mutate(client, "set_due", input(id, extra));
    assert.equal(answer.isError, false, label);
    const row = await rowOf(pool, answer);
    assert.equal(row.kind, "setDue", label);
    assert.deepEqual(row.doc, { version: 1, id: JSON.parse(answer.text).orderID, kind: "setDue", taskID: id, ...expected }, label);
    assert.doesNotThrow(() => checkOrder(row.doc), label);
  }
});

test("AC-8 (C4b-2): set_due with an invalid date stores nothing and answers with checkOrder's message", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool, "henning");
  for (const date of ["", "morgen", "2026-03-12T17:00:00", "2026-02-30T10:00:00Z"]) {
    const answer = await mutate(client, "set_due", input(dated, { date }));
    assert.equal(answer.isError, true, date);
    const form = { version: 1, id: fakeID(1), kind: "setDue", taskID: dated, hasTime: false, date, expectedDueDate: "2026-03-12T17:00:00Z" };
    assert.throws(() => checkOrder(form), (error: Error) => { assert.equal(answer.text, error.message, date); return true; });
  }
  assert.equal(await orderCount(pool), 0);
});

test("AC-9/AC-10 (C4b-2): equal calls give two orders; no title in an answer; another account changes nothing", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool, "henning");
  const [a, b] = [await mutate(client, "complete_task", input(dated)), await mutate(client, "complete_task", input(dated))];
  const [first, second] = [JSON.parse(a.text).orderID, JSON.parse(b.text).orderID];
  assert.notEqual(first, second);
  assert.deepEqual(JSON.parse((await result(client, first)).text), { state: "waiting" });
  for (const text of [a.text, b.text]) for (const title of titles(example())) assert.ok(!text.includes(title), title);
  const anna = await connect(t, pool, "anna");
  for (const [name, extra] of tools2) {
    const answer = await mutate(anna, name, input(dated, extra));
    assert.equal(answer.isError, true, name);
    assert.match(answer.text, /noch keine Abschrift|Aufgabe nicht in der Abschrift/, name);
  }
  assert.equal(await orderCount(pool), 2);
});

test("AC-11 (C4b-2): neither new tool writes to console or stdout", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool, "henning");
  const log = t.mock.method(console, "log");
  const write = t.mock.method(process.stdout, "write");
  await mutate(client, "complete_task", input(dated));
  await mutate(client, "set_due", input(dated, { date: "2026-03-14T08:30:00Z" }));
  await mutate(client, "set_due", input(dated, { date: "morgen" }));
  const [logs, writes] = [log.mock.callCount(), write.mock.callCount()];
  t.mock.restoreAll();
  assert.equal(logs, 0, "console.log");
  assert.equal(writes, 0, "process.stdout.write");
});
