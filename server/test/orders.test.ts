import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import pg from "pg";
import { migrate } from "../src/migrate.ts";
import { checkOrder, checkResult, claimOrder, putOrder, putResult } from "../src/orders.ts";
import { checkTranscript } from "../src/transcripts.ts";
import { freshPool } from "./db.ts";

type Doc = Record<string, any>;

const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");

// Order (block 2) and result (block 3) are read from the contract, never copied.
function blocks(): Doc[] {
  const found = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  assert.equal(found.length, 3, "der Vertrag muss genau drei ```json-Blöcke enthalten");
  return found.map((b) => JSON.parse(b[1]));
}
const complete = (): Doc => blocks()[1];
const rejected = (): Doc => blocks()[2];

const TASK = "6f1c2b0a-0000-4000-8000-000000000001";
const uuid = (n: number) => `0b7d5e3c-0000-4000-8000-${String(n).padStart(12, "0")}`;
const capture = (n: number, text = "Milch kaufen"): Doc => ({ version: 1, id: uuid(n), kind: "capture", text });
const setDue = (n: number): Doc => ({ version: 1, id: uuid(n), kind: "setDue", taskID: TASK, hasTime: false });

function changed(change: (copy: Doc) => void, doc: Doc): Doc {
  const copy = structuredClone(doc);
  change(copy);
  return copy;
}

async function migrated(t: Parameters<typeof freshPool>[0]): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

async function second(pool: pg.Pool, t: { after: (fn: () => Promise<void>) => void }): Promise<pg.Pool> {
  const searchPath = (await pool.query("SHOW search_path")).rows[0].search_path;
  const other = new pg.Pool({ connectionString: process.env.DATABASE_URL, options: `-c search_path=${searchPath}` });
  t.after(() => other.end());
  return other;
}

const count = async (pool: pg.Pool, table = "orders") => Number((await pool.query(`SELECT count(*) AS n FROM ${table}`)).rows[0].n);
const order = async (pool: pg.Pool, id: string) => (await pool.query("SELECT * FROM orders WHERE id = $1", [id])).rows[0];
const results = async (pool: pg.Pool) => (await pool.query("SELECT * FROM order_results")).rows;

test("AC-1: the contract order is stored, ON CONFLICT works on the generated id", async (t) => {
  const pool = await migrated(t);
  const doc = complete();
  assert.equal(await putOrder(pool, "henning", doc), "stored");
  const stored = await order(pool, doc.id.toLowerCase());
  assert.equal(stored.kind, doc.kind);
  assert.equal(stored.id, doc.id.toLowerCase());
  assert.equal(stored.claimed_by, null);
});

test("AC-2: contract examples and small orders and results are accepted", () => {
  checkOrder(complete());
  checkOrder(capture(1, ""));
  for (const status of ["unprocessed", "unverified", "active", "parked", "done", "removed"]) {
    checkOrder({ version: 1, id: uuid(2), kind: "complete", taskID: TASK, expectedStatus: status });
  }
  checkOrder(setDue(3));
  checkResult(rejected());
  checkResult({ orderID: uuid(4), outcome: "done" });
  for (const reason of ["invalid", "missing", "stale"]) checkResult({ orderID: uuid(4), outcome: "rejected", reason });
});

// Each row of the deviation table: refused with subject and field path, nothing is stored.
const orderTable: Array<[string, Doc, Array<[(d: Doc) => void, string]>]> = [
  ["AC-3 (Z1) version", complete(), [[(d) => { delete d.version; }, "version"], [(d) => { d.version = "1"; }, "version"], [(d) => { d.version = 2; }, "version"]]],
  ["AC-4 (Z2) id", complete(), [[(d) => { delete d.id; }, "id"], [(d) => { d.id = "abc"; }, "id"], [(d) => { d.id = 5; }, "id"]]],
  ["AC-4 (Z3) kind", complete(), [[(d) => { delete d.kind; }, "kind"], [(d) => { d.kind = "delete"; }, "kind"], [(d) => { d.kind = 5; }, "kind"]]],
  ["AC-5 (Z4) capture", capture(5), [[(d) => { delete d.text; }, "text"], [(d) => { d.text = 5; }, "text"], [(d) => { d.taskID = TASK; }, "taskID"]]],
  ["AC-6 (Z5) complete", complete(), [
    [(d) => { delete d.taskID; }, "taskID"], [(d) => { d.taskID = "abc"; }, "taskID"],
    [(d) => { delete d.expectedStatus; }, "expectedStatus"], [(d) => { d.expectedStatus = "finished"; }, "expectedStatus"], [(d) => { d.expectedStatus = 5; }, "expectedStatus"],
  ]],
  ["AC-7 (Z6) complete times and keys", complete(), [[(d) => { d.expectedDueDate = "2026-03-12T09:00:00"; }, "expectedDueDate"], [(d) => { d.hasTime = true; }, "hasTime"]]],
  ["AC-8 (Z7) setDue", setDue(6), [
    [(d) => { delete d.hasTime; }, "hasTime"], [(d) => { d.hasTime = "yes"; }, "hasTime"], [(d) => { d.date = "2026-03-12T09:00:00"; }, "date"],
    [(d) => { d.expectedDueDate = "morgen"; }, "expectedDueDate"], [(d) => { d.text = "x"; }, "text"],
  ]],
];

test("AC-3 to AC-8: orders off the table are refused with the field path, nothing is stored", async (t) => {
  const pool = await migrated(t);
  for (const [name, base, cases] of orderTable) {
    await t.test(name, async () => {
      for (const [change, path] of cases) {
        const doc = changed(change, base);
        assert.throws(() => checkOrder(doc), (e: Error) => e.message.startsWith(`Auftrag ungültig: ${path}: `), `${name} → ${path}`);
        await assert.rejects(putOrder(pool, "henning", doc), (e: Error) => e.message.startsWith(`Auftrag ungültig: ${path}: `));
        assert.equal(await count(pool), 0, `${name} → ${path}`);
      }
    });
  }
});

test("AC-7: complete without expectedDueDate is accepted", () => {
  checkOrder(changed((d) => { delete d.expectedDueDate; }, complete()));
});

test("AC-9: an order that is no object names the root", () => {
  for (const doc of [[], "x", null]) {
    assert.throws(() => checkOrder(doc), (e: Error) => e.message.includes("Wurzel") && e.message.includes("kein Objekt"));
  }
});

const resultTable: Array<[string, Array<[(d: Doc) => void, string]>]> = [
  ["AC-10 (Z9) result", [
    [(d) => { delete d.orderID; }, "orderID"], [(d) => { d.orderID = "abc"; }, "orderID"], [(d) => { d.outcome = "ok"; }, "outcome"],
    [(d) => { d.taskID = "abc"; }, "taskID"], [(d) => { d.note = "x"; }, "note"],
  ]],
  ["AC-11 (Z10) reason", [[(d) => { delete d.reason; }, "reason"], [(d) => { d.outcome = "done"; }, "reason"], [(d) => { d.reason = "broken"; }, "reason"]]],
];

test("AC-10/11: results off the table are refused with the field path, nothing is stored", async (t) => {
  const pool = await migrated(t);
  for (const [name, cases] of resultTable) {
    await t.test(name, async () => {
      for (const [change, path] of cases) {
        const doc = changed(change, rejected());
        assert.throws(() => checkResult(doc), (e: Error) => e.message.startsWith(`Ergebnis ungültig: ${path}: `), `${name} → ${path}`);
        await assert.rejects(putResult(pool, "henning", "iphone", doc), (e: Error) => e.message.startsWith(`Ergebnis ungültig: ${path}: `));
        assert.equal(await count(pool, "order_results"), 0, `${name} → ${path}`);
      }
    });
  }
});

test("AC-12: transcript messages stay, other errors carry no prefix", async (t) => {
  assert.throws(() => checkTranscript({}), (e: Error) => e.message === "Abschrift ungültig: version: fehlt");
  const dead = new pg.Pool({ connectionString: "postgres://127.0.0.1:1/none" });
  t.after(() => dead.end());
  await assert.rejects(putOrder(dead, "henning", capture(7)), (e: Error) => !e.message.includes("ungültig"));
});

test("AC-13: a new order is stored for the account, unclaimed", async (t) => {
  const pool = await migrated(t);
  const doc = capture(8);
  assert.equal(await putOrder(pool, "henning", doc), "stored");
  const stored = await order(pool, doc.id);
  assert.equal(stored.account_id, "henning");
  assert.deepEqual(stored.doc, doc);
  assert.equal(stored.claimed_by, null);
  assert.equal(stored.claimed_at, null);
});

test("AC-14: the same id again, even upper case with other content, changes nothing", async (t) => {
  const pool = await migrated(t);
  const doc = capture(9);
  await putOrder(pool, "henning", doc);
  const again = { ...doc, id: doc.id.toUpperCase(), text: "etwas anderes" };
  assert.equal(await putOrder(pool, "henning", again), "duplicate");
  assert.equal(await count(pool), 1);
  assert.deepEqual((await order(pool, doc.id)).doc, doc);
});

test("AC-15: a claimed order is not reset by a second put", async (t) => {
  const pool = await migrated(t);
  const doc = capture(10);
  await putOrder(pool, "henning", doc);
  assert.deepEqual(await claimOrder(pool, "henning", "iphone"), doc);
  const before = await order(pool, doc.id);
  assert.equal(await putOrder(pool, "henning", doc), "duplicate");
  const after = await order(pool, doc.id);
  assert.equal(after.claimed_by, "iphone");
  assert.deepEqual(after.claimed_at, before.claimed_at);
  assert.equal(await claimOrder(pool, "henning", "mac"), undefined);
});

test("AC-16: three orders are claimed one by one, then nothing", async (t) => {
  const pool = await migrated(t);
  assert.equal(await claimOrder(pool, "henning", "iphone"), undefined);
  const docs = [capture(11), capture(12), capture(13)];
  for (const doc of docs) await putOrder(pool, "henning", doc);
  for (const doc of docs) assert.deepEqual(await claimOrder(pool, "henning", "iphone"), doc);
  assert.equal(await claimOrder(pool, "henning", "iphone"), undefined);
  const row = await order(pool, docs[0].id);
  assert.equal(row.claimed_by, "iphone");
  assert.ok(row.claimed_at);
});

test("AC-17: two connections claim ten orders, each exactly once", async (t) => {
  const pool = await migrated(t);
  const other = await second(pool, t);
  for (let n = 20; n < 30; n++) await putOrder(pool, "henning", capture(n));
  const drain = async (p: pg.Pool, device: string) => {
    const got: Doc[] = [];
    for (let i = 0; i < 10; i++) {
      const doc = await claimOrder(p, "henning", device);
      if (!doc) break;
      got.push(doc);
    }
    return got;
  };
  const [a, b] = await Promise.all([drain(pool, "iphone"), drain(other, "mac")]);
  const rest: Doc[] = [];
  for (let doc = await claimOrder(pool, "henning", "iphone"); doc; doc = await claimOrder(pool, "henning", "iphone")) rest.push(doc);
  const all = [...a, ...b, ...rest];
  assert.equal(all.length, 10);
  assert.equal(new Set(all.map((d) => d.id)).size, 10);
  for (const [device, docs] of [["iphone", [...a, ...rest]], ["mac", b]] as const) {
    for (const doc of docs) assert.equal((await order(pool, doc.id)).claimed_by, device);
  }
});

test("AC-18: two accounts never cross", async (t) => {
  const pool = await migrated(t);
  const h = capture(40), a = capture(41);
  await putOrder(pool, "henning", h);
  await putOrder(pool, "anna", a);
  assert.deepEqual(await claimOrder(pool, "anna", "iphone"), a);
  assert.equal(await claimOrder(pool, "anna", "iphone"), undefined);
  assert.equal((await order(pool, h.id)).claimed_by, null);
  assert.deepEqual(await claimOrder(pool, "henning", "mac"), h);
});

async function held(pool: pg.Pool, device = "iphone"): Promise<Doc> {
  const doc = complete();
  await putOrder(pool, "henning", doc);
  await claimOrder(pool, "henning", device);
  return doc;
}
const resultFor = (order: Doc, extra: Doc = {}): Doc => ({ ...rejected(), orderID: order.id, ...extra });

test("AC-19: the result of the holding device is stored", async (t) => {
  const pool = await migrated(t);
  const doc = await held(pool);
  const result = resultFor(doc);
  assert.equal(await putResult(pool, "henning", "iphone", result), "stored");
  const [row] = await results(pool);
  assert.equal(row.order_id, doc.id.toLowerCase());
  assert.equal(row.outcome, result.outcome);
  assert.equal(row.reason, result.reason);
  assert.equal(row.task_id, result.taskID.toLowerCase());
  assert.equal(row.reported_by, "iphone");
});

test("AC-20: results for orders not held by the reporter are refused", async (t) => {
  const pool = await migrated(t);
  const doc = await held(pool, "mac");
  assert.equal(await putResult(pool, "henning", "iphone", resultFor(doc)), "refused");
  assert.equal(await putResult(pool, "anna", "mac", resultFor(doc)), "refused");
  assert.equal(await putResult(pool, "henning", "iphone", resultFor({ id: uuid(99) })), "refused");
  const open = capture(50);
  await putOrder(pool, "henning", open);
  assert.equal(await putResult(pool, "henning", "iphone", resultFor(open)), "refused");
  assert.equal(await count(pool, "order_results"), 0);
});

test("AC-21: a second result changes nothing", async (t) => {
  const pool = await migrated(t);
  const doc = await held(pool);
  assert.equal(await putResult(pool, "henning", "iphone", { orderID: doc.id, outcome: "done" }), "stored");
  const [before] = await results(pool);
  assert.equal(await putResult(pool, "henning", "iphone", resultFor(doc)), "duplicate");
  assert.deepEqual(await results(pool), [before]);
});
