import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type pg from "pg";
import { migrate } from "../src/migrate.ts";
import { freshPool } from "./db.ts";

type Doc = Record<string, any>;
type Expect = string | RegExp;

const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");

// AC-2: the examples are read from the contract, never copied; in contract order transcript, order, result.
function contractExamples(): [Doc, Doc, Doc] {
  const blocks = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  assert.equal(blocks.length, 3, "der Vertrag muss genau drei ```json-Blöcke enthalten");
  const [transcript, order, result] = blocks.map((block) => JSON.parse(block[1]));
  return [transcript, order, result];
}

async function migrated(t: Parameters<typeof freshPool>[0]): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

function changed(doc: Doc, change: (copy: Doc) => void): Doc {
  const copy = structuredClone(doc);
  change(copy);
  return copy;
}

const insertTranscript = (pool: pg.Pool, doc: Doc | string, account: string | null = "henning", at?: string) =>
  pool.query("INSERT INTO transcripts (account_id, doc, generated_at) VALUES ($1, $2::jsonb, $3)", [
    account, typeof doc === "string" ? doc : JSON.stringify(doc), at ?? (typeof doc === "string" ? JSON.parse(doc) : doc).generatedAt,
  ]);

const insertOrder = (pool: pg.Pool, doc: Doc | string, account: string | null = "henning", claimedBy: string | null = null, claimedAt: string | null = null) =>
  pool.query("INSERT INTO orders (doc, account_id, claimed_by, claimed_at) VALUES ($1::jsonb, $2, $3, $4)", [
    typeof doc === "string" ? doc : JSON.stringify(doc), account, claimedBy, claimedAt,
  ]);

const insertResult = (pool: pg.Pool, doc: Doc, reportedBy: string | null = "iphone") =>
  pool.query("INSERT INTO order_results (doc, reported_by) VALUES ($1::jsonb, $2)", [JSON.stringify(doc), reportedBy]);

async function refused(promise: Promise<unknown>, expected: Expect, name: string): Promise<void> {
  await assert.rejects(promise, (error: Error & { code?: string }) => {
    if (typeof expected === "string") assert.equal(error.code, expected, `${name}: ${error.message}`);
    else assert.match(error.code ?? "", expected, `${name}: ${error.message}`);
    return true;
  }, name);
}

test("AC-1: the real migrations folder applies 001 once and creates the three tables", async (t) => {
  const pool = await freshPool(t);

  assert.deepEqual(await migrate(pool, migrations), ["001_claude_schema.sql"]);
  for (const table of ["transcripts", "orders", "order_results"]) {
    const result = await pool.query("SELECT to_regclass($1) AS oid", [table]);
    assert.notEqual(result.rows[0].oid, null, table);
  }
  assert.equal((await pool.query("SELECT name FROM schema_migrations")).rowCount, 1);
  assert.deepEqual(await migrate(pool, migrations), []);
});

test("AC-2: the three contract examples are accepted in contract order", async (t) => {
  const pool = await migrated(t);
  const [transcript, order, result] = contractExamples();

  await insertTranscript(pool, transcript);
  await insertOrder(pool, order);
  await insertResult(pool, result);

  const row = await pool.query("SELECT generated_at = $1::timestamptz AS same FROM transcripts", [transcript.generatedAt]);
  assert.equal(row.rows[0].same, true);
  assert.equal((await pool.query("SELECT outcome, reason FROM order_results")).rows[0].reason, "stale");
});

test("AC-3: transcripts refuse what the contract does not allow", async (t) => {
  const pool = await migrated(t);
  const [transcript] = contractExamples();
  const cases: Array<{ name: string; doc?: Doc; account?: null; at?: string; expect: Expect }> = [
    { name: "rawText an einer Aufgabe", doc: changed(transcript, (d) => { d.tasks[0].rawText = "Müll"; }), expect: "23514" },
    { name: "note an einer Aufgabe", doc: changed(transcript, (d) => { d.tasks[1].note = "privat"; }), expect: "23514" },
    { name: "fremder Schlüssel oben", doc: changed(transcript, (d) => { d.revisions = []; }), expect: "23514" },
    { name: "version fehlt", doc: changed(transcript, (d) => { delete d.version; }), expect: "23514" },
    { name: "version als Text", doc: changed(transcript, (d) => { d.version = "1"; }), expect: "23514" },
    { name: "generated_at weicht ab", at: "2026-03-12T10:00:00Z", expect: "23514" },
    { name: "generatedAt fehlt", doc: changed(transcript, (d) => { delete d.generatedAt; }), at: transcript.generatedAt, expect: "23514" },
    { name: "generatedAt ohne Zeitzone", doc: changed(transcript, (d) => { d.generatedAt = "2026-03-12T09:00:00"; }), at: "2026-03-12T09:00:00", expect: "23514" },
    { name: "generatedAt als Array", doc: changed(transcript, (d) => { d.generatedAt = [transcript.generatedAt]; }), at: transcript.generatedAt, expect: "23514" },
    { name: "Nicht-Objekt in tasks", doc: changed(transcript, (d) => { d.tasks = ["Text"]; }), expect: /^2203/ },
    { name: "account_id fehlt", account: null, expect: "23502" },
  ];
  for (const c of cases) {
    await refused(insertTranscript(pool, c.doc ?? transcript, c.account === null ? null : `konto-${c.name}`, c.at), c.expect, c.name);
  }

  await insertTranscript(pool, transcript);
  await refused(insertTranscript(pool, transcript), "23505", "zweite Zeile desselben Kontos");
});

test("AC-4: orders refuse a wrong version, kind, id, account or half a claim, and take all three kinds", async (t) => {
  const pool = await migrated(t);
  const [, order] = contractExamples();
  const cases: Array<{ name: string; doc?: Doc; account?: null; claim?: [string | null, string | null]; expect: Expect }> = [
    { name: "version fehlt", doc: changed(order, (d) => { delete d.version; }), expect: "23514" },
    { name: "version als Text", doc: changed(order, (d) => { d.version = "1"; }), expect: "23514" },
    { name: "kind unbekannt", doc: changed(order, (d) => { d.kind = "delete"; }), expect: "23514" },
    { name: "kind fehlt", doc: changed(order, (d) => { delete d.kind; }), expect: "23502" },
    { name: "id fehlt", doc: changed(order, (d) => { delete d.id; }), expect: "23502" },
    { name: "id keine UUID", doc: changed(order, (d) => { d.id = "kein-uuid"; }), expect: "22P02" },
    { name: "account_id fehlt", account: null, expect: "23502" },
    { name: "claimed_by ohne claimed_at", claim: ["claude-1", null], expect: "23514" },
    { name: "claimed_at ohne claimed_by", claim: [null, "2026-03-12T09:05:00Z"], expect: "23514" },
  ];
  for (const c of cases) {
    const [by, at] = c.claim ?? [null, null];
    await refused(insertOrder(pool, c.doc ?? order, c.account === null ? null : "henning", by, at), c.expect, c.name);
  }

  await insertOrder(pool, order, "henning", "claude-1", "2026-03-12T09:05:00Z");
  await refused(insertOrder(pool, order), "23505", "doppelte id");
  await insertOrder(pool, { id: "0B7D5E3C-0000-4000-8000-000000000011", kind: "capture", text: "Milch kaufen", version: 1 });
  await insertOrder(pool, {
    date: "2026-03-13T00:00:00Z", expectedDueDate: "2026-03-12T17:00:00Z", hasTime: false,
    id: "0B7D5E3C-0000-4000-8000-000000000012", kind: "setDue", taskID: "6F1C2B0A-0000-4000-8000-000000000001", version: 1,
  });
  const kinds = await pool.query("SELECT kind FROM orders ORDER BY kind");
  assert.deepEqual(kinds.rows.map((row: { kind: string }) => row.kind), ["capture", "complete", "setDue"]);
});

test("AC-5: order results belong to exactly one existing order and carry a reason only when rejected", async (t) => {
  const pool = await migrated(t);
  const [, order, result] = contractExamples();
  await insertOrder(pool, order);
  const done = { orderID: order.id, outcome: "done", taskID: order.taskID };
  const cases: Array<{ name: string; doc: Doc; reportedBy?: null; expect: Expect }> = [
    { name: "unbekannter Auftrag", doc: changed(result, (d) => { d.orderID = "0B7D5E3C-0000-4000-8000-000000000099"; }), expect: "23503" },
    { name: "orderID fehlt", doc: changed(result, (d) => { delete d.orderID; }), expect: "23502" },
    { name: "rejected ohne reason", doc: changed(result, (d) => { delete d.reason; }), expect: "23514" },
    { name: "done mit reason", doc: { ...done, reason: "stale" }, expect: "23514" },
    { name: "reason unbekannt", doc: changed(result, (d) => { d.reason = "gone"; }), expect: "23514" },
    { name: "outcome unbekannt", doc: { ...done, outcome: "maybe" }, expect: "23514" },
    { name: "outcome fehlt", doc: changed(done, (d) => { delete d.outcome; }), expect: "23502" },
    { name: "reported_by fehlt", doc: result, reportedBy: null, expect: "23502" },
  ];
  for (const c of cases) {
    await refused(insertResult(pool, c.doc, c.reportedBy === null ? null : "iphone"), c.expect, c.name);
  }

  await insertResult(pool, result);
  await refused(insertResult(pool, done), "23505", "zweites Ergebnis zum selben Auftrag");
  const capture = { id: "0B7D5E3C-0000-4000-8000-000000000011", kind: "capture", text: "Milch kaufen", version: 1 };
  await insertOrder(pool, capture);
  await insertResult(pool, { orderID: capture.id, outcome: "done" });
});

test("AC-6: ids keep their case in the document, the uuid columns compare regardless of case", async (t) => {
  const pool = await migrated(t);
  const [, order] = contractExamples();
  await insertOrder(pool, order);

  const row = await pool.query("SELECT id::text AS id, doc->>'id' AS raw FROM orders WHERE id = $1::uuid", [order.id.toLowerCase()]);
  assert.equal(row.rowCount, 1);
  assert.equal(row.rows[0].id, order.id.toLowerCase());
  assert.equal(row.rows[0].raw, order.id);
});

test("AC-6: known limit, version 1.0 is accepted because jsonb compares numbers numerically", async (t) => {
  // Harmless: the app decodes 1.0 as 1. Not a fault of the schema.
  const pool = await migrated(t);
  const [transcript, order] = contractExamples();

  await insertOrder(pool, JSON.stringify(order).replace('"version":1', '"version":1.0'));
  await insertTranscript(pool, JSON.stringify(transcript).replace('"version":1', '"version":1.0'));
  assert.equal((await pool.query("SELECT doc->>'version' AS v FROM orders")).rows[0].v, "1.0");
});
