import { test } from "node:test";
import assert from "node:assert/strict";
import { copyFileSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
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

  assert.deepEqual(await migrate(pool, migrations), [
    "001_claude_schema.sql", "002_accounts.sql", "003_apple_client_id.sql", "004_oauth.sql", "005_apple_tokens_per_client.sql", "006_transcript_views.sql", "007_order_kinds.sql", "008_device_tokens.sql",
  ]);
  for (const table of ["transcripts", "orders", "order_results"]) {
    const result = await pool.query("SELECT to_regclass($1) AS oid", [table]);
    assert.notEqual(result.rows[0].oid, null, table);
  }
  assert.equal((await pool.query("SELECT name FROM schema_migrations")).rowCount, 8);
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

test("migration 003: additiv auf bestandsdaten", async (t) => {
  const pool = await freshPool(t);
  const old = mkdtempSync(join(tmpdir(), "le-mig-"));
  t.after(() => rmSync(old, { recursive: true, force: true }));
  for (const name of ["001_claude_schema.sql", "002_accounts.sql"]) copyFileSync(join(migrations, name), join(old, name));
  assert.deepEqual(await migrate(pool, old), ["001_claude_schema.sql", "002_accounts.sql"]);
  const account = (await pool.query("INSERT INTO accounts (apple_sub) VALUES ('sub.alt') RETURNING id")).rows[0].id;
  await pool.query("INSERT INTO apple_tokens (account_id, refresh_token_enc) VALUES ($1, $2)", [account, Buffer.from([1, 2, 3])]);
  const before = (await pool.query("SELECT refresh_token_enc, created_at FROM apple_tokens")).rows[0];

  copyFileSync(join(migrations, "003_apple_client_id.sql"), join(old, "003_apple_client_id.sql"));
  assert.deepEqual(await migrate(pool, old), ["003_apple_client_id.sql"]);
  const after = (await pool.query("SELECT refresh_token_enc, created_at, client_id FROM apple_tokens")).rows;
  assert.equal(after.length, 1);
  assert.deepEqual(after[0].refresh_token_enc, before.refresh_token_enc);
  assert.deepEqual(after[0].created_at, before.created_at);
  assert.equal(after[0].client_id, null);
  const column = (await pool.query(
    "SELECT data_type, is_nullable FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'apple_tokens' AND column_name = 'client_id'",
  )).rows;
  assert.deepEqual(column, [{ data_type: "text", is_nullable: "YES" }]);
  assert.deepEqual(await migrate(pool, old), []);
});

test("migration 004: additiv auf bestandsdaten", async (t) => {
  const pool = await freshPool(t);
  const old = mkdtempSync(join(tmpdir(), "le-mig-"));
  t.after(() => rmSync(old, { recursive: true, force: true }));
  for (const name of ["001_claude_schema.sql", "002_accounts.sql", "003_apple_client_id.sql"]) copyFileSync(join(migrations, name), join(old, name));
  await migrate(pool, old);
  const [transcript, order] = contractExamples();
  const account = (await pool.query("INSERT INTO accounts (apple_sub) VALUES ('sub.alt') RETURNING id")).rows[0].id;
  await pool.query("INSERT INTO sessions (token_hash, account_id) VALUES ($1, $2)", [Buffer.from([4, 5]), account]);
  await pool.query("INSERT INTO apple_tokens (account_id, refresh_token_enc, client_id) VALUES ($1, $2, 'web')", [account, Buffer.from([1, 2, 3])]);
  await insertTranscript(pool, transcript, account);
  await insertOrder(pool, order, account);
  const tables = ["accounts", "sessions", "apple_tokens", "transcripts", "orders"];
  const snapshot = () => Promise.all(tables.map(async (table) => (await pool.query(`SELECT * FROM ${table} ORDER BY 1`)).rows));
  const before = await snapshot();

  copyFileSync(join(migrations, "004_oauth.sql"), join(old, "004_oauth.sql"));
  assert.deepEqual(await migrate(pool, old), ["004_oauth.sql"]);
  assert.deepEqual(await snapshot(), before);
  assert.deepEqual(await migrate(pool, old), []);

  const columns = (await pool.query(
    `SELECT column_name, data_type, is_nullable FROM information_schema.columns
     WHERE table_schema = current_schema() AND table_name = 'oauth_records' ORDER BY column_name`,
  )).rows;
  const tz = "timestamp with time zone";
  assert.deepEqual(columns, [
    ["account_id", "text", "YES"], ["consumed_at", tz, "YES"], ["created_at", tz, "NO"], ["expires_at", tz, "YES"],
    ["grant_id", "text", "YES"], ["id_hash", "bytea", "NO"], ["model", "text", "NO"], ["payload", "jsonb", "NO"], ["uid", "text", "YES"],
  ].map(([column_name, data_type, is_nullable]) => ({ column_name, data_type, is_nullable })));
  const keys = (await pool.query(
    `SELECT contype, confdeltype, pg_get_constraintdef(oid) AS def FROM pg_constraint
     WHERE conrelid = 'oauth_records'::regclass AND contype IN ('p', 'f') ORDER BY contype`,
  )).rows;
  assert.equal(keys.length, 2);
  assert.equal(keys[0].def, "FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE");
  assert.equal(keys[0].confdeltype, "c");
  assert.equal(keys[1].def, "PRIMARY KEY (model, id_hash)");
  const indexes = (await pool.query("SELECT indexdef FROM pg_indexes WHERE schemaname = current_schema() AND tablename = 'oauth_records'")).rows;
  for (const column of ["grant_id", "uid", "account_id", "expires_at"]) {
    assert.ok(indexes.some((index: { indexdef: string }) => index.indexdef.endsWith(`(${column})`)), `Index auf ${column}`);
  }
});

const MIG_005 = "005_apple_tokens_per_client.sql";
const APP = "com.henning.looseends";

// A schema at 001 to 004 in its own folder; next() adds 005 and migrates.
async function before005(t: Parameters<typeof freshPool>[0]) {
  const pool = await freshPool(t);
  const old = mkdtempSync(join(tmpdir(), "le-mig-"));
  t.after(async () => rmSync(old, { recursive: true, force: true }));
  for (const name of ["001_claude_schema.sql", "002_accounts.sql", "003_apple_client_id.sql", "004_oauth.sql"]) copyFileSync(join(migrations, name), join(old, name));
  await migrate(pool, old);
  const next = () => { copyFileSync(join(migrations, MIG_005), join(old, MIG_005)); return migrate(pool, old); };
  return { pool, old, next };
}
const account = async (pool: pg.Pool, sub: string): Promise<string> =>
  (await pool.query("INSERT INTO accounts (apple_sub) VALUES ($1) RETURNING id", [sub])).rows[0].id;
const tokenKeys = async (pool: pg.Pool) => (await pool.query(
  `SELECT conname, confdeltype, pg_get_constraintdef(oid) AS def FROM pg_constraint
   WHERE conrelid = 'apple_tokens'::regclass AND contype IN ('p', 'f') ORDER BY contype`,
)).rows;

test("migration 005: zeile ohne client_id faellt weg, rest bleibt", async (t) => {
  const { pool, old, next } = await before005(t);
  const [a, b] = [await account(pool, "sub.a"), await account(pool, "sub.b")];
  await pool.query("INSERT INTO sessions (token_hash, account_id) VALUES ($1, $2), ($3, $4)", [Buffer.from([1]), a, Buffer.from([2]), b]);
  await pool.query("INSERT INTO apple_tokens (account_id, refresh_token_enc) VALUES ($1, $2)", [a, Buffer.from([1, 1])]);
  await pool.query(
    "INSERT INTO apple_tokens (account_id, refresh_token_enc, client_id, created_at) VALUES ($1, $2, $3, now() - interval '1 day')",
    [b, Buffer.from([2, 2, 2]), APP],
  );
  const [transcript, order] = contractExamples();
  await insertTranscript(pool, transcript, b);
  await insertOrder(pool, order, b);
  const tables = ["accounts", "sessions", "transcripts", "orders", "order_results", "oauth_records"];
  const snapshot = () => Promise.all(tables.map(async (table) => (await pool.query(`SELECT * FROM ${table} ORDER BY 1`)).rows));
  const kept = (await pool.query("SELECT * FROM apple_tokens WHERE account_id = $1", [b])).rows;
  const others = await snapshot();

  assert.deepEqual(await next(), [MIG_005]);
  assert.deepEqual((await pool.query("SELECT * FROM apple_tokens")).rows, kept);
  assert.deepEqual(await snapshot(), others);
  assert.deepEqual(await migrate(pool, old), []);
});

test("migration 005: form von apple_tokens", async (t) => {
  const { pool, next } = await before005(t);
  // The name DROP CONSTRAINT relies on, read in the state after 004.
  assert.deepEqual((await tokenKeys(pool)).map((k: { conname: string; def: string }) => [k.conname, k.def]), [
    ["apple_tokens_account_id_fkey", "FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE"],
    ["apple_tokens_pkey", "PRIMARY KEY (account_id)"],
  ]);

  await next();
  const column = (await pool.query(
    "SELECT is_nullable FROM information_schema.columns WHERE table_schema = current_schema() AND table_name = 'apple_tokens' AND column_name = 'client_id'",
  )).rows;
  assert.deepEqual(column, [{ is_nullable: "NO" }]);
  const after = await tokenKeys(pool);
  assert.equal(after.length, 2, "ein Fremdschlüssel, genau ein Primärschlüssel");
  assert.equal(after[0].def, "FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE");
  assert.equal(after[0].confdeltype, "c");
  assert.equal(after[1].conname, "apple_tokens_pkey");
  assert.equal(after[1].def, "PRIMARY KEY (account_id, client_id)");
});

test("migration 005: zwei clients je konto, null und doppelt abgelehnt, kaskade", async (t) => {
  const { pool, next } = await before005(t);
  await next();
  const id = await account(pool, "sub.zwei");
  const insert = (clientId: string | null) =>
    pool.query("INSERT INTO apple_tokens (account_id, refresh_token_enc, client_id) VALUES ($1, $2, $3)", [id, Buffer.from([9]), clientId]);
  const total = async () => (await pool.query("SELECT count(*)::int AS n FROM apple_tokens")).rows[0].n;

  await refused(insert(null), "23502", "client_id NULL");
  await insert(APP);
  await insert(`${APP}.web`);
  assert.equal(await total(), 2);
  await refused(insert(APP), "23505", "gleiches Paar");
  await pool.query("DELETE FROM accounts WHERE id = $1", [id]);
  assert.equal(await total(), 0);
});
