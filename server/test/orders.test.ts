import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import pg from "pg";
import { migrate } from "../src/migrate.ts";
import { checkOrder, checkResult, claimOrder, getResult, putOrder, putResult } from "../src/orders.ts";
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

const ORDER_ID = uuid(77).toUpperCase();
const open = (): Doc => ({ ...capture(77), id: ORDER_ID });

test("AC-1 (C4b-1): getResult is unknown for a never stored id, another account's id and a non-UUID", async (t) => {
  const pool = await migrated(t);
  await putOrder(pool, "henning", open());
  assert.deepEqual(await getResult(pool, "henning", uuid(1)), { state: "unknown" });
  assert.deepEqual(await getResult(pool, "anna", ORDER_ID), { state: "unknown" });
  for (const bad of ["", "keine-uuid", "'; DROP TABLE orders; --"]) {
    assert.deepEqual(await getResult(pool, "henning", bad), { state: "unknown" }, bad);
  }
});

test("AC-2 (C4b-1): getResult goes waiting, claimed, result and reads the id in any case", async (t) => {
  for (const [label, result] of [
    ["done", { orderID: ORDER_ID, outcome: "done" }],
    ["rejected mit Grund", { orderID: ORDER_ID, outcome: "rejected", reason: "stale" }],
  ] as const) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      await putOrder(pool, "henning", open());
      assert.deepEqual(await getResult(pool, "henning", ORDER_ID), { state: "waiting" });
      assert.deepEqual(await getResult(pool, "henning", ORDER_ID.toLowerCase()), { state: "waiting" });
      assert.ok(await claimOrder(pool, "henning", "iphone"));
      assert.deepEqual(await getResult(pool, "henning", ORDER_ID), { state: "claimed" });
      assert.equal(await putResult(pool, "henning", "iphone", result), "stored");
      assert.deepEqual(await getResult(pool, "henning", ORDER_ID.toLowerCase()), { state: "result", result });
      assert.deepEqual(await getResult(pool, "anna", ORDER_ID), { state: "unknown" });
    });
  }
});

// #932 Schnitt 2: fields at capture. The capture example is the ```jsonc block of the contract, read, never copied.
function captureExample(): Doc {
  const found = [...readFileSync(contractPath, "utf8").matchAll(/```jsonc\n([\s\S]*?)\n```/g)].map((b) => JSON.parse(b[1]));
  const doc = found.find((d) => d.kind === "capture");
  assert.ok(doc, "der Vertrag muss ein ```jsonc-Beispiel capture enthalten");
  return doc;
}
const withFields = (fields: unknown): Doc => ({ ...capture(60), fields });

test("AC-1 (#932 S2): capture with fields of every key, single keys and empty fields is accepted", () => {
  checkOrder(withFields(captureExample().fields));
  checkOrder(withFields({}));
  for (const fields of [
    { title: "Hecke schneiden" }, { title: "" }, { notes: "beim Nachbarn" }, { dueDate: "2026-03-14T08:00:00Z", dueHasTime: false },
    { importance: "low" }, { urgency: "medium" }, { duration: "minutes5" }, { duration: "hours2plus" },
    { energy: -3 }, { energy: 0 }, { energy: 3 }, { contexts: [] }, { contexts: ["Garten", "Haus"] }, { project: "Haus" },
  ]) checkOrder(withFields(fields));
});

// Each wrong value is refused with its path under fields, nothing is stored.
const fieldsTable: Array<[unknown, string]> = [
  [{ importance: "urgent" }, "fields.importance"], [{ urgency: 1 }, "fields.urgency"], [{ duration: "hour3" }, "fields.duration"],
  [{ energy: 4 }, "fields.energy"], [{ energy: -4 }, "fields.energy"], [{ energy: 1.5 }, "fields.energy"], [{ energy: "1" }, "fields.energy"],
  [{ dueDate: "2026-03-14T08:00:00Z" }, "fields.dueHasTime"], [{ dueHasTime: true }, "fields.dueDate"],
  [{ dueDate: "morgen", dueHasTime: true }, "fields.dueDate"], [{ dueDate: "2026-03-14T08:00:00Z", dueHasTime: "ja" }, "fields.dueHasTime"],
  [{ contexts: "Garten" }, "fields.contexts"], [{ contexts: ["Garten", 5] }, "fields.contexts"],
  [{ project: 5 }, "fields.project"], [{ title: 5 }, "fields.title"], [{ notes: 5 }, "fields.notes"],
  [{ titel: "Hecke" }, "fields.titel"],
  [5, "fields"], ["Hecke", "fields"], [[], "fields"], [null, "fields"],
];

test("AC-2/AC-3 (#932 S2): wrong values, a foreign key and fields that is no object are refused with the path", async (t) => {
  const pool = await migrated(t);
  for (const [fields, path] of fieldsTable) {
    const doc = withFields(fields);
    assert.throws(() => checkOrder(doc), (e: Error) => e.message.startsWith(`Auftrag ungültig: ${path}: `), `${JSON.stringify(fields)} → ${path}`);
    await assert.rejects(putOrder(pool, "henning", doc), (e: Error) => e.message.startsWith(`Auftrag ungültig: ${path}: `));
  }
  assert.equal(await count(pool), 0);
});

test("AC-4 (#932 S2): the contract's capture example passes checkOrder, the three ```json blocks stay", () => {
  checkOrder(captureExample());
  assert.equal(blocks().length, 3);
});

test("AC-5 (#932 S2): fields are stored as given", async (t) => {
  const pool = await migrated(t);
  const doc = captureExample();
  assert.equal(await putOrder(pool, "henning", doc), "stored");
  assert.deepEqual((await order(pool, doc.id.toLowerCase())).doc, doc);
});

// #932 Schnitt 3: the update order. The example is the ```jsonc block of the contract with kind update, read, never copied.
function updateExample(): Doc {
  const found = [...readFileSync(contractPath, "utf8").matchAll(/```jsonc\n([\s\S]*?)\n```/g)].map((b) => JSON.parse(b[1]));
  const doc = found.find((d) => d.kind === "update");
  assert.ok(doc, "der Vertrag muss ein ```jsonc-Beispiel update enthalten");
  return doc;
}
const update = (fields: unknown, extra: Doc = {}): Doc =>
  ({ version: 1, id: uuid(70), kind: "update", taskID: TASK, expectedStatus: "active", fields, ...extra });
const without = (doc: Doc, key: string): Doc => changed((d) => { delete d[key]; }, doc);

test("AC-1 (#932 S3): migration 009 lets update into orders, an unknown kind still breaks orders_kind_known", async (t) => {
  const pool = await migrated(t);
  assert.equal((await pool.query("SELECT 1 FROM schema_migrations WHERE name = '009_order_update.sql'")).rowCount, 1);
  await pool.query("INSERT INTO orders (doc, account_id) VALUES ($1::jsonb, 'henning')", [JSON.stringify(updateExample())]);
  assert.equal(await count(pool), 1);
  await assert.rejects(pool.query("INSERT INTO orders (doc, account_id) VALUES ($1::jsonb, 'henning')",
    [JSON.stringify({ ...update({ title: "x" }), id: uuid(71), kind: "rename" })]), /orders_kind_known/);
});

test("AC-2 (#932 S3): the contract's update example passes checkOrder and is stored as given", async (t) => {
  checkOrder(updateExample());
  for (const fields of [{ title: "Hecke" }, { dueDate: "2026-03-14T08:00:00Z", dueHasTime: false }, { energy: 0 }, { contexts: [] }]) {
    checkOrder(update(fields));
  }
  checkOrder(update({ project: "Haus" }, {
    expectedTitle: "Hecke", expectedDueDate: "2026-03-12T17:00:00Z", expectedContexts: ["Garten"], expectedProject: "Haus",
  }));
  const pool = await migrated(t);
  const doc = updateExample();
  assert.equal(await putOrder(pool, "henning", doc), "stored");
  assert.deepEqual((await order(pool, doc.id.toLowerCase())).doc, doc);
});

const updateTable: Array<[string, Doc, string]> = [
  ["leeres fields", update({}), "fields"],
  ["notes in fields", update({ notes: "x" }), "fields.notes"],
  ["ohne expectedStatus", without(update({ title: "x" }), "expectedStatus"), "expectedStatus"],
  ["ohne taskID", without(update({ title: "x" }), "taskID"), "taskID"],
  ["dueDate ohne dueHasTime", update({ dueDate: "2026-03-14T08:00:00Z" }), "fields.dueHasTime"],
  ["ohne fields", without(update({ title: "x" }), "fields"), "fields"],
  ["fields kein Objekt", update("Hecke"), "fields"],
  ["expectedTitle keine Zeichenkette", update({ title: "x" }, { expectedTitle: 5 }), "expectedTitle"],
  ["expectedContexts kein Feld", update({ contexts: [] }, { expectedContexts: "Garten" }), "expectedContexts"],
  ["expectedDueDate ohne Z", update({ title: "x" }, { expectedDueDate: "2026-03-12T17:00:00" }), "expectedDueDate"],
  ["text gehört zu capture", update({ title: "x" }, { text: "x" }), "text"],
];

test("AC-3 (#932 S3): an update off its form is refused with the path, nothing is stored; capture keeps empty fields", async (t) => {
  const pool = await migrated(t);
  for (const [name, doc, path] of updateTable) {
    assert.throws(() => checkOrder(doc), (e: Error) => e.message.startsWith(`Auftrag ungültig: ${path}: `), `${name} → ${path}`);
    await assert.rejects(putOrder(pool, "henning", doc), (e: Error) => e.message.startsWith(`Auftrag ungültig: ${path}: `), name);
  }
  assert.equal(await count(pool), 0);
  checkOrder(withFields({}));
});

// #938 Schnitt 2: repeat (capture and update) and link (capture only). The example is the ```jsonc capture with
// fields.repeat from the contract, read, never copied; captureExample() stays with the first one.
function repeatExample(): Doc {
  const found = [...readFileSync(contractPath, "utf8").matchAll(/```jsonc\n([\s\S]*?)\n```/g)].map((b) => JSON.parse(b[1]));
  const doc = found.find((d) => d.kind === "capture" && d.fields?.repeat !== undefined);
  assert.ok(doc, "der Vertrag muss ein ```jsonc-Beispiel capture mit fields.repeat enthalten");
  return doc;
}
// The path itself or one element of the list under it, then the reason.
const refusedAt = (path: string) => (e: Error) =>
  new RegExp(`^Auftrag ungültig: ${path.replaceAll(".", "\\.")}(\\[\\d+\\])?: `).test(e.message);

test("AC-1 (#938 S2): the contract's capture with repeat and link passes checkOrder and is stored as given", async (t) => {
  const doc = repeatExample();
  assert.ok(doc.fields.link, "das Beispiel trägt link");
  checkOrder(doc);
  const pool = await migrated(t);
  assert.equal(await putOrder(pool, "henning", doc), "stored");
  assert.deepEqual((await order(pool, doc.id.toLowerCase())).doc, doc);
});

const goodRepeats: unknown[] = [
  { frequency: "daily" }, { frequency: "weekly" }, { frequency: "monthly" }, { frequency: "yearly" },
  { frequency: "weekly", weekdays: [2, 4], interval: 1 }, { frequency: "weekly", weekdays: [1, 7], interval: 52 },
  { frequency: "monthly", interval: 3, basis: "fromCompletion" }, { frequency: "yearly", basis: "fromDueDate" },
  { frequency: "daily", interval: 2, basis: "fromCompletion" },
];

test("AC-2 (#938 S2): repeat with frequency alone and with interval, weekdays and basis is accepted at capture and update", () => {
  for (const repeat of goodRepeats) {
    checkOrder(withFields({ repeat }));
    checkOrder(update({ repeat }));
  }
});

const repeatTable: Array<[unknown, string]> = [
  [{ frequency: "weekly", interval: 0 }, "fields.repeat.interval"], [{ frequency: "weekly", interval: 53 }, "fields.repeat.interval"],
  [{ frequency: "weekly", interval: 1.5 }, "fields.repeat.interval"], [{ frequency: "weekly", interval: "2" }, "fields.repeat.interval"],
  [{ frequency: "hourly" }, "fields.repeat.frequency"], [{ frequency: "weekly", basis: "fromStart" }, "fields.repeat.basis"],
  [{ frequency: "weekly", weekdays: [] }, "fields.repeat.weekdays"], [{ frequency: "weekly", weekdays: [0] }, "fields.repeat.weekdays"],
  [{ frequency: "weekly", weekdays: [8] }, "fields.repeat.weekdays"], [{ frequency: "weekly", weekdays: [1.5] }, "fields.repeat.weekdays"],
  [{ frequency: "weekly", weekdays: 2 }, "fields.repeat.weekdays"], [{ frequency: "monthly", weekdays: [2] }, "fields.repeat.weekdays"],
  [{ frequency: "weekly", intervall: 2 }, "fields.repeat.intervall"], [{ interval: 2 }, "fields.repeat.frequency"],
  ["weekly", "fields.repeat"], [null, "fields.repeat"], [[], "fields.repeat"],
];

test("AC-3 (#938 S2): a repeat off its form is refused with the path, nothing is stored", async (t) => {
  const pool = await migrated(t);
  for (const [repeat, path] of repeatTable) {
    for (const doc of [withFields({ repeat }), update({ repeat })]) {
      assert.throws(() => checkOrder(doc), refusedAt(path), `${JSON.stringify(repeat)} → ${path}`);
      await assert.rejects(putOrder(pool, "henning", doc), refusedAt(path));
    }
  }
  assert.equal(await count(pool), 0);
});

test("AC-4 (#938 S2): link with http or https and a host is accepted at capture, everything else refused at fields.link", () => {
  for (const link of ["https://www.example.org/praxis/termine", "http://example.org", "https://example.org/a?b=c#d"]) {
    checkOrder(withFields({ link }));
  }
  for (const link of ["ftp://example.org/datei", "https://", "example.org", "mailto:a@example.org", "", 5, null]) {
    assert.throws(() => checkOrder(withFields({ link })), refusedAt("fields.link"), JSON.stringify(link));
  }
});

test("AC-5 (#938 S2): link at update is refused even when valid; update with repeat alone is accepted", async (t) => {
  for (const fields of [{ link: "https://www.example.org/praxis/termine" }, { link: "x", repeat: { frequency: "daily" } }]) {
    assert.throws(() => checkOrder(update(fields)), refusedAt("fields.link"), JSON.stringify(fields));
  }
  checkOrder(update({ repeat: { frequency: "weekly", interval: 26 } }));
  const pool = await migrated(t);
  await assert.rejects(putOrder(pool, "henning", update({ link: "https://example.org" })), refusedAt("fields.link"));
  assert.equal(await count(pool), 0);
});
