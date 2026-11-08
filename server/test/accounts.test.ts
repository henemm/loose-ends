import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type pg from "pg";
import * as accountsModule from "../src/accounts.ts";
import { createSession, deleteAccount, endSession, findOrCreate, resolveSession } from "../src/accounts.ts";
import { migrate, MIGRATE_LOCK_ID } from "../src/migrate.ts";
import { PgAdapter } from "../src/oauth-adapter.ts";
import { freshPool } from "./db.ts";

type Doc = Record<string, any>;

const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const TABLES = ["accounts", "sessions", "apple_tokens", "transcripts", "orders", "order_results"];

// Transcript (block 1) is read from the contract, never copied.
function transcript(): Doc {
  const found = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  assert.equal(found.length, 3, "der Vertrag muss genau drei ```json-Blöcke enthalten");
  return JSON.parse(found[0][1]);
}
const uuid = (n: number) => `0b7d5e3c-0000-4000-8000-${String(n).padStart(12, "0")}`;

async function migrated(t: Parameters<typeof freshPool>[0]): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

const APP = "com.henning.looseends";
const WEB = "com.henning.looseends.web";

// An account with a session, an Apple token, a transcript and a claimed, answered order.
async function filled(pool: pg.Pool, sub: string, n: number, appleToken: Buffer | null, clientId = APP) {
  const id = await findOrCreate(pool, sub);
  const token = await createSession(pool, id);
  if (appleToken) await pool.query("INSERT INTO apple_tokens (account_id, refresh_token_enc, client_id) VALUES ($1, $2, $3)", [id, appleToken, clientId]);
  const doc = transcript();
  await pool.query("INSERT INTO transcripts (account_id, doc, generated_at) VALUES ($1, $2::jsonb, $3)", [id, JSON.stringify(doc), doc.generatedAt]);
  await pool.query("INSERT INTO orders (doc, account_id, claimed_by, claimed_at) VALUES ($1::jsonb, $2, 'claude-1', now())", [
    JSON.stringify({ version: 1, id: uuid(n), kind: "capture", text: "Milch kaufen" }), id,
  ]);
  await pool.query("INSERT INTO order_results (doc, reported_by) VALUES ($1::jsonb, 'iphone')", [JSON.stringify({ orderID: uuid(n), outcome: "done" })]);
  return { id, token };
}

async function counts(pool: pg.Pool, account: string): Promise<Record<string, number>> {
  const result: Record<string, number> = {};
  for (const table of TABLES) {
    const sql = table === "accounts" ? "SELECT count(*)::int AS n FROM accounts WHERE id = $1"
      : table === "order_results" ? "SELECT count(*)::int AS n FROM order_results r JOIN orders o ON o.id = r.order_id WHERE o.account_id = $1"
      : `SELECT count(*)::int AS n FROM ${table} WHERE account_id = $1`;
    result[table] = (await pool.query(sql, [account])).rows[0].n;
  }
  return result;
}
const totalResults = async (pool: pg.Pool) => (await pool.query("SELECT count(*)::int AS n FROM order_results")).rows[0].n;

test("AC-1: the migrations apply 001 and 002 once, and the three account tables exist", async (t) => {
  const pool = await freshPool(t);

  assert.deepEqual(await migrate(pool, migrations), [
    "001_claude_schema.sql", "002_accounts.sql", "003_apple_client_id.sql", "004_oauth.sql", "005_apple_tokens_per_client.sql", "006_transcript_views.sql", "007_order_kinds.sql",
  ]);
  assert.deepEqual(await migrate(pool, migrations), []);
  for (const table of ["accounts", "sessions", "apple_tokens"]) {
    assert.notEqual((await pool.query("SELECT to_regclass($1) AS oid", [table])).rows[0].oid, null, table);
  }
});

test("AC-2: findOrCreate gives one account per apple_sub, also when called at the same time", async (t) => {
  const pool = await migrated(t);

  const [a, b] = await Promise.all([findOrCreate(pool, "sub.henning"), findOrCreate(pool, "sub.henning")]);
  assert.equal(a, b);
  assert.equal(await findOrCreate(pool, "sub.henning"), a);
  assert.equal((await pool.query("SELECT count(*)::int AS n FROM accounts")).rows[0].n, 1);
  assert.notEqual(await findOrCreate(pool, "sub.andere"), a);
});

test("AC-3: createSession hands out 43-character tokens and stores only their SHA-256", async (t) => {
  const pool = await migrated(t);
  const id = await findOrCreate(pool, "sub.henning");

  const first = await createSession(pool, id);
  const second = await createSession(pool, id);
  assert.match(first, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(first, second);
  for (const token of [first, second]) {
    const hash = createHash("sha256").update(token).digest();
    const row = await pool.query("SELECT account_id FROM sessions WHERE token_hash = $1", [hash]);
    assert.equal(row.rows[0]?.account_id, id);
  }
  const rows = await pool.query("SELECT s::text AS line FROM sessions s");
  for (const { line } of rows.rows) {
    assert.ok(!line.includes(first) && !line.includes(second), "Klartext in sessions");
  }
});

test("AC-4/AC-5: resolveSession finds a valid session, refreshes it, and ends only the one session", async (t) => {
  const pool = await migrated(t);
  const id = await findOrCreate(pool, "sub.henning");
  const token = await createSession(pool, id);
  const other = await createSession(pool, id);
  await pool.query("UPDATE sessions SET last_used_at = '2026-01-01T00:00:00Z'");

  assert.equal(await resolveSession(pool, token), id);
  const used = await pool.query("SELECT last_used_at > '2026-01-01T00:00:00Z' AS later FROM sessions WHERE token_hash = $1", [
    createHash("sha256").update(token).digest(),
  ]);
  assert.equal(used.rows[0].later, true);
  const flipped = (token[0] === "A" ? "B" : "A") + token.slice(1);
  for (const bad of ["unbekannt", "", flipped, undefined, 42] as unknown[]) {
    assert.equal(await resolveSession(pool, bad as string), null, String(bad));
  }

  assert.equal(await endSession(pool, token), true);
  assert.equal(await resolveSession(pool, token), null);
  assert.equal(await resolveSession(pool, other), id);
  assert.equal(await endSession(pool, token), false);
  assert.equal(await endSession(pool, "unbekannt"), false);
});

test("AC-6: createSession for an unknown account is refused by the foreign key", async (t) => {
  const pool = await migrated(t);

  await assert.rejects(createSession(pool, "kein-konto"), (error: Error & { code?: string }) => {
    assert.equal(error.code, "23503", error.message);
    return true;
  });
});

test("AC-7/AC-8/AC-10: deleteAccount removes every row of the account and leaves the other one untouched", async (t) => {
  const pool = await migrated(t);
  const apple = Buffer.from([1, 2, 3, 250]);
  const first = await filled(pool, "sub.erstes", 1, apple, APP);
  const second = await filled(pool, "sub.zweites", 2, Buffer.from([9]));
  const before = await counts(pool, second.id);

  assert.deepEqual(await deleteAccount(pool, first.id), { deleted: true, tokens: [{ blob: apple, clientId: APP }] });
  assert.deepEqual(await counts(pool, first.id), Object.fromEntries(TABLES.map((table) => [table, 0])));
  assert.equal(await totalResults(pool), 1, "Ergebnis des ersten Kontos bleibt nicht verwaist zurück");
  assert.equal(await resolveSession(pool, first.token), null);
  assert.deepEqual(await counts(pool, second.id), before);
  assert.equal(await resolveSession(pool, second.token), second.id);
});

test("deleteAccount: zwei token-zeilen kommen als sortierte liste, konto ganz weg", async (t) => {
  const pool = await migrated(t);
  const [web, app] = [Buffer.from([1, 1, 1]), Buffer.from([2, 2])];
  // Web first: the list follows client_id, not the order of insertion.
  const me = await filled(pool, "sub.zwei", 5, web, WEB);
  await pool.query("INSERT INTO apple_tokens (account_id, refresh_token_enc, client_id) VALUES ($1, $2, $3)", [me.id, app, APP]);
  const other = await filled(pool, "sub.anderes", 6, Buffer.from([3]));
  const before = await counts(pool, other.id);

  assert.deepEqual(await deleteAccount(pool, me.id), { deleted: true, tokens: [{ blob: app, clientId: APP }, { blob: web, clientId: WEB }] });
  assert.deepEqual(await counts(pool, me.id), Object.fromEntries(TABLES.map((table) => [table, 0])));
  assert.equal(await resolveSession(pool, me.token), null);
  assert.deepEqual(await counts(pool, other.id), before);
});

test("deleteAccount: ohne token-zeile und unbekanntes konto", async (t) => {
  const pool = await migrated(t);
  const account = await filled(pool, "sub.ohne", 3, null);
  const other = await filled(pool, "sub.bleibt", 4, Buffer.from([7]));
  const before = await counts(pool, other.id);

  assert.deepEqual(await deleteAccount(pool, account.id), { deleted: true, tokens: [] });
  assert.deepEqual(await counts(pool, account.id), Object.fromEntries(TABLES.map((table) => [table, 0])));
  assert.equal(await totalResults(pool), 1);
  assert.deepEqual(await deleteAccount(pool, "kein-konto"), { deleted: false, tokens: [] });
  assert.deepEqual(await counts(pool, other.id), before);
});

test("delete: rundweg mit client_id", async (t) => {
  const pool = await migrated(t);
  const blob = Buffer.from([5, 6, 7]);
  const cases: [string, Buffer | null, string, Array<{ blob: Buffer; clientId: string }>][] = [
    ["mit Token und client_id", blob, WEB, [{ blob, clientId: WEB }]],
    ["ohne Token", null, APP, []],
  ];
  for (const [i, [name, token, clientId, tokens]] of cases.entries()) {
    const account = await filled(pool, `sub.rund-${i}`, 20 + i, token, clientId);
    assert.deepEqual(await deleteAccount(pool, account.id), { deleted: true, tokens }, name);
    assert.deepEqual(await counts(pool, account.id), Object.fromEntries(TABLES.map((table) => [table, 0])), name);
  }
  assert.deepEqual(await deleteAccount(pool, "kein-konto"), { deleted: false, tokens: [] });
});

test("accounts: delete nimmt oauth zeilen mit", async (t) => {
  const pool = await migrated(t);
  const first = await filled(pool, "sub.oauth-a", 30, Buffer.from([1]));
  const second = await filled(pool, "sub.oauth-b", 31, Buffer.from([2]));
  const store = (model: string) => new PgAdapter(pool, model);
  // Per account: its grant, a token of that grant, an interaction known only by the grant, a session by account.
  const oauthRows = (account: string, tag: string): Array<[string, string, Record<string, unknown>]> => [
    ["Grant", `grant-${tag}`, { accountId: account, clientId: "claude" }],
    ["AccessToken", `at-${tag}`, { accountId: account, grantId: `grant-${tag}` }],
    ["Interaction", `i-${tag}`, { grantId: `grant-${tag}`, uid: `uid-i-${tag}` }],
    ["Session", `s-${tag}`, { accountId: account, uid: `uid-s-${tag}` }],
  ];
  for (const [model, id, payload] of [...oauthRows(first.id, "a"), ...oauthRows(second.id, "b")]) await store(model).upsert(id, payload, 3600);
  await store("Client").upsert("claude", { client_id: "claude" });
  const kept = (await pool.query(
    "SELECT * FROM oauth_records WHERE account_id IS DISTINCT FROM $1 AND grant_id IS DISTINCT FROM 'grant-a' ORDER BY model, id_hash", [first.id],
  )).rows;
  assert.equal(kept.length, 5, "vier Zeilen von B und der Client");
  const before = await counts(pool, second.id);

  assert.deepEqual(await deleteAccount(pool, first.id), { deleted: true, tokens: [{ blob: Buffer.from([1]), clientId: APP }] });
  for (const [model, id] of oauthRows(first.id, "a")) assert.equal(await store(model).find(id), undefined, model);
  assert.deepEqual((await pool.query("SELECT * FROM oauth_records ORDER BY model, id_hash")).rows, kept);
  assert.deepEqual(await counts(pool, first.id), Object.fromEntries(TABLES.map((table) => [table, 0])));
  assert.deepEqual(await counts(pool, second.id), before);
});

test("AC-12: the account functions write nothing to the console, and an error names neither token nor apple_sub", async (t) => {
  const pool = await migrated(t);
  const written: string[] = [];
  const saved = { log: console.log, error: console.error, warn: console.warn, write: process.stdout.write };
  const capture = (...args: unknown[]) => { written.push(args.map(String).join(" ")); return true; };
  console.log = console.error = console.warn = capture;
  process.stdout.write = capture as typeof process.stdout.write;
  let failure: Error | undefined;
  let token = "";
  try {
    const id = await findOrCreate(pool, "sub.geheim");
    token = await createSession(pool, id);
    await resolveSession(pool, token);
    await endSession(pool, token);
    await createSession(pool, "kein-konto").catch((error: Error) => { failure = error; });
    await deleteAccount(pool, id);
  } finally {
    Object.assign(console, { log: saved.log, error: saved.error, warn: saved.warn });
    process.stdout.write = saved.write;
  }
  assert.deepEqual(written, []);
  assert.ok(failure, "createSession für ein unbekanntes Konto muss scheitern");
  assert.ok(!failure.message.includes(token) && !failure.message.includes("sub.geheim"), failure.message);
});

// #621 S6a: the door. Read through the module so the file runs before admit exists.
type Door = {
  admit: (pool: pg.Pool, appleSub: string, allowed?: ReadonlySet<string>) => Promise<string | null>;
  allowedSubsFromEnv: (env: NodeJS.ProcessEnv) => ReadonlySet<string> | undefined;
  ACCOUNT_LOCK_ID: number;
};
const door = accountsModule as unknown as Door;
const accountCount = async (pool: pg.Pool) => (await pool.query("SELECT count(*)::int AS n FROM accounts")).rows[0].n;

test("tuer: erstes konto schliesst die tuer, vorhandenes bleibt nutzbar", async (t) => {
  const pool = await migrated(t);

  const first = await door.admit(pool, "sub-a", undefined);
  assert.equal(typeof first, "string");
  assert.equal(await accountCount(pool), 1);
  assert.equal(await door.admit(pool, "sub-b", undefined), null);
  assert.equal(await accountCount(pool), 1);
  assert.equal(await door.admit(pool, "sub-a", undefined), first);
  assert.equal(await door.admit(pool, "sub-a"), first, "ohne Argument wie undefined");
  assert.equal(await accountCount(pool), 1);
  assert.notEqual(door.ACCOUNT_LOCK_ID, MIGRATE_LOCK_ID);
});

test("tuer: gleichzeitige erstanmeldungen ergeben genau ein konto", async (t) => {
  const pool = await migrated(t);
  const subs = Array.from({ length: 8 }, (_, i) => `sub-${i}`);

  const results = await Promise.all(subs.map((sub) => door.admit(pool, sub, undefined)));
  assert.equal(results.filter((id) => typeof id === "string").length, 1, `Ergebnisse: ${JSON.stringify(results)}`);
  assert.equal(results.filter((id) => id === null).length, 7);
  assert.equal(await accountCount(pool), 1);

  const fresh = await migrated(t);
  const same = await Promise.all(subs.map(() => door.admit(fresh, "sub-gleich", undefined)));
  assert.equal(new Set(same).size, 1);
  assert.equal(typeof same[0], "string");
  assert.equal(await accountCount(fresh), 1);
});

test("tuer: liste entscheidet, auch ueber vorhandene konten", async (t) => {
  const pool = await migrated(t);
  const list = new Set(["sub-a"]);

  assert.equal(await door.admit(pool, "sub-x", list), null, "die Liste schlägt das erste Konto");
  assert.equal(await accountCount(pool), 0);
  const a = await door.admit(pool, "sub-a", list);
  assert.equal(typeof a, "string");
  assert.equal(await door.admit(pool, "sub-a", list), a);

  const b = await findOrCreate(pool, "sub-b");
  const before = (await pool.query("SELECT * FROM accounts WHERE id = $1", [b])).rows;
  assert.equal(await door.admit(pool, "sub-b", list), null, "vorhandenes Konto ohne Listeneintrag");
  assert.deepEqual((await pool.query("SELECT * FROM accounts WHERE id = $1", [b])).rows, before);
  assert.equal(await door.admit(pool, "sub-b", new Set(["sub-a", "sub-b"])), b);
  assert.equal(await accountCount(pool), 2);
});

test("tuer: allowedSubsFromEnv liest streng und nennt nie den wert", () => {
  for (const value of [undefined, "", "   ", "\t\n"]) {
    const env = value === undefined ? {} : { ALLOWED_APPLE_SUBS: value };
    assert.equal(door.allowedSubsFromEnv(env), undefined, JSON.stringify(value));
  }
  assert.deepEqual(door.allowedSubsFromEnv({ ALLOWED_APPLE_SUBS: "a, b ,c" }), new Set(["a", "b", "c"]));
  assert.deepEqual(door.allowedSubsFromEnv({ ALLOWED_APPLE_SUBS: "a" }), new Set(["a"]));
  for (const value of ["sub-geheim,,b", "sub-geheim,", ",sub-geheim", " , ", ","]) {
    assert.throws(() => door.allowedSubsFromEnv({ ALLOWED_APPLE_SUBS: value }), (error: Error) => {
      assert.equal(error.message, "ALLOWED_APPLE_SUBS", value);
      assert.ok(!String(error.stack).includes("sub-geheim"), `${value}: Wert im Stack`);
      return true;
    }, value);
  }
});
