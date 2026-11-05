import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { join } from "node:path";
import type pg from "pg";
import { findOrCreate } from "../src/accounts.ts";
import { migrate } from "../src/migrate.ts";
import { PgAdapter } from "../src/oauth-adapter.ts";
import { freshPool } from "./db.ts";

type Doc = Record<string, any>;
type Clock = { now: () => Date; advance: (seconds: number) => void };

const migrations = join(import.meta.dirname, "../migrations");
const T0 = Date.parse("2026-11-05T10:00:00Z");
const sha256 = (id: string): Buffer => createHash("sha256").update(id).digest();

// The clock is handed in, so a test jumps in time instead of sleeping.
function clock(): Clock {
  let ms = T0;
  return { now: () => new Date(ms), advance: (seconds) => { ms += seconds * 1000; } };
}

async function setup(t: Parameters<typeof freshPool>[0]) {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  const account = await findOrCreate(pool, "sub.oauth");
  const time = clock();
  const adapter = (name: string) => new PgAdapter(pool, name, time.now);
  return { pool, account, time, adapter };
}

// Every column, in a fixed order, for unchanged-checks.
const rows = async (pool: pg.Pool) =>
  (await pool.query("SELECT * FROM oauth_records ORDER BY model, id_hash")).rows;
const row = async (pool: pg.Pool, model: string, id: string) =>
  (await pool.query("SELECT * FROM oauth_records WHERE model = $1 AND id_hash = $2", [model, sha256(id)])).rows[0];

function payloads(account: string): Array<[string, string, Doc]> {
  return [
    ["AccessToken", "at-1", { jti: "at-1", kind: "AccessToken", accountId: account, clientId: "claude", grantId: "g-1", scope: "tasks" }],
    ["AuthorizationCode", "ac-1", { jti: "ac-1", kind: "AuthorizationCode", accountId: account, grantId: "g-1", codeChallenge: "abc" }],
    ["RefreshToken", "rt-1", { jti: "rt-1", kind: "RefreshToken", accountId: account, grantId: "g-1", rotations: 0 }],
    ["Grant", "g-1", { jti: "g-1", kind: "Grant", accountId: account, clientId: "claude", openid: { scope: "tasks" } }],
    ["Session", "s-1", { jti: "s-1", kind: "Session", accountId: account, uid: "uid-s1", loginTs: 1 }],
    ["Interaction", "i-1", { jti: "i-1", kind: "Interaction", uid: "uid-i1", params: { client_id: "claude" } }],
  ];
}

test("oauth-adapter: upsert und find", async (t) => {
  const { pool, account, time, adapter } = await setup(t);
  for (const [model, id, payload] of payloads(account)) {
    const store = adapter(model);
    await store.upsert(id, payload, 60);
    assert.deepEqual(await store.find(id), { ...payload, jti: id }, model);

    const replaced = { ...payload, replaced: true };
    await store.upsert(id, replaced, 120);
    time.advance(90);
    assert.deepEqual(await store.find(id), { ...replaced, jti: id }, `${model} ersetzt, Ablauf neu`);
    time.advance(-90);
    const count = await pool.query("SELECT count(*)::int AS n FROM oauth_records WHERE model = $1", [model]);
    assert.equal(count.rows[0].n, 1, model);
  }
});

test("oauth-adapter: unbekannt und modelle getrennt", async (t) => {
  const { account, adapter } = await setup(t);
  const access = adapter("AccessToken");
  const refresh = adapter("RefreshToken");
  assert.equal(await access.find("gibt-es-nicht"), undefined);

  await access.upsert("gleich", { kind: "AccessToken", accountId: account }, 60);
  await refresh.upsert("gleich", { kind: "RefreshToken", accountId: account }, 60);
  assert.equal((await access.find("gleich"))?.kind, "AccessToken");
  assert.equal((await refresh.find("gleich"))?.kind, "RefreshToken");

  await access.destroy("gleich");
  assert.equal(await access.find("gleich"), undefined);
  assert.deepEqual(await refresh.find("gleich"), { kind: "RefreshToken", accountId: account, jti: "gleich" });
});

test("oauth-adapter: find by uid", async (t) => {
  const { account, time, adapter } = await setup(t);
  const sessions = adapter("Session");
  const interactions = adapter("Interaction");
  const payload = { jti: "s-1", kind: "Session", accountId: account, uid: "uid-1", loginTs: 1 };
  await sessions.upsert("s-1", payload, 60);
  await sessions.upsert("s-2", { jti: "s-2", kind: "Session", accountId: account, uid: "uid-2" }, 10);
  await interactions.upsert("i-1", { kind: "Interaction", uid: "uid-x" }, 60);

  const { jti: _jti, ...withoutJti } = payload;
  assert.deepEqual(await sessions.findByUid("uid-1"), withoutJti);
  time.advance(11);
  const cases: Array<[string, PgAdapter, string]> = [
    ["unbekannte uid", sessions, "uid-nie"],
    ["abgelaufene Session", sessions, "uid-2"],
    ["uid eines anderen Modells", sessions, "uid-x"],
    ["Session-uid im Modell Interaction", interactions, "uid-1"],
  ];
  for (const [name, store, uid] of cases) assert.equal(await store.findByUid(uid), undefined, name);
});

test("oauth-adapter: destroy", async (t) => {
  const { pool, account, adapter } = await setup(t);
  const access = adapter("AccessToken");
  await access.upsert("weg", { kind: "AccessToken", accountId: account }, 60);

  await access.destroy("weg");
  assert.equal(await access.find("weg"), undefined);
  assert.equal(await row(pool, "AccessToken", "weg"), undefined);
  await access.destroy("nie-gesehen");
});

test("oauth-adapter: revoke by grant id", async (t) => {
  const { pool, account, adapter } = await setup(t);
  const granted: Array<[string, string]> = [["AccessToken", "at-g1"], ["RefreshToken", "rt-g1"], ["AuthorizationCode", "ac-g1"], ["Interaction", "i-g1"]];
  for (const [model, id] of granted) {
    await adapter(model).upsert(id, { kind: model, grantId: "g-1", ...(model === "Interaction" ? {} : { accountId: account }) }, 60);
  }
  await adapter("AccessToken").upsert("at-g2", { kind: "AccessToken", accountId: account, grantId: "g-2" }, 60);
  await adapter("Client").upsert("claude", { client_id: "claude" });
  const others = (await rows(pool)).filter((r) => r.grant_id !== "g-1");

  await adapter("AccessToken").revokeByGrantId("g-1");
  for (const [model, id] of granted) assert.equal(await adapter(model).find(id), undefined, model);
  assert.deepEqual(await rows(pool), others);
});

test("oauth-adapter: ids nur als hash", async (t) => {
  const { pool, account, adapter } = await setup(t);
  const cases: Array<[string, string]> = [["AccessToken", "geheim-token-123"], ["RefreshToken", "geheim-refresh-456"], ["AuthorizationCode", "geheim-code-789"]];
  for (const [model, id] of cases) {
    const payload = { jti: id, kind: model, accountId: account, grantId: "g-1" };
    await adapter(model).upsert(id, payload, 60);

    const dump = await pool.query("SELECT row_to_json(r)::text AS line, r.payload::text AS payload FROM oauth_records r");
    for (const r of dump.rows) {
      assert.ok(!r.line.includes(id) && !r.payload.includes(id), `${model}: Klartext in der Tabelle`);
    }
    const stored = await row(pool, model, id);
    assert.ok(stored, model);
    assert.equal(stored.id_hash.length, 32);
    assert.deepEqual(stored.id_hash, sha256(id));
    assert.equal("jti" in stored.payload, false, `${model}: jti im Payload`);
    assert.equal("consumed" in stored.payload, false, `${model}: consumed im Payload`);
    assert.deepEqual(await adapter(model).find(id), payload);
  }
});

test("oauth-adapter: abgelaufenes verborgen", async (t) => {
  const { pool, account, time, adapter } = await setup(t);
  const access = adapter("AccessToken");
  await access.upsert("kurz", { kind: "AccessToken", accountId: account }, 60);

  const steps: Array<[number, boolean]> = [[59, true], [1, false], [3600, false]];
  for (const [seconds, visible] of steps) {
    time.advance(seconds);
    assert.equal((await access.find("kurz")) !== undefined, visible, `nach +${seconds} s`);
  }
  assert.ok(await row(pool, "AccessToken", "kurz"), "Zeile bleibt bis zum Aufräumen");
});

test("oauth-adapter: ohne ablauf bleibt", async (t) => {
  const { pool, time, adapter } = await setup(t);
  const clients = adapter("Client");
  await clients.upsert("claude", { client_id: "claude", redirect_uris: ["https://claude.ai/cb"] });

  assert.equal((await row(pool, "Client", "claude")).expires_at, null);
  time.advance(365 * 24 * 3600);
  assert.deepEqual(await clients.find("claude"), { client_id: "claude", redirect_uris: ["https://claude.ai/cb"], jti: "claude" });
});

test("oauth-adapter: consume einmal", async (t) => {
  const { pool, account, time, adapter } = await setup(t);
  const codes = adapter("AuthorizationCode");
  const payload = { kind: "AuthorizationCode", accountId: account, grantId: "g-1" };
  await codes.upsert("code-1", payload, 60);

  await codes.consume("code-1");
  assert.ok((await codes.find("code-1"))?.consumed, "find meldet consumed");
  assert.notEqual((await row(pool, "AuthorizationCode", "code-1")).consumed_at, null);
  await assert.rejects(codes.consume("code-1"), "zweites consume");
  await assert.rejects(codes.consume("nie-gesehen"), "unbekannt");

  await codes.upsert("code-alt", payload, 10);
  time.advance(11);
  await assert.rejects(codes.consume("code-alt"), "abgelaufen");

  await codes.upsert("code-1", { ...payload, consumed: 1 }, 60);
  assert.ok((await codes.find("code-1"))?.consumed, "upsert belebt nicht wieder");
  assert.equal("consumed" in (await row(pool, "AuthorizationCode", "code-1")).payload, false);
});

test("oauth-adapter: zwei gleichzeitige consume", async (t) => {
  const { pool, account, adapter } = await setup(t);
  const codes = adapter("AuthorizationCode");
  await codes.upsert("code-race", { kind: "AuthorizationCode", accountId: account }, 60);

  const results = await Promise.allSettled(Array.from({ length: 20 }, () => codes.consume("code-race")));
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
  assert.equal(results.filter((r) => r.status === "rejected").length, 19);
  const stored = (await pool.query("SELECT consumed_at FROM oauth_records WHERE consumed_at IS NOT NULL")).rows;
  assert.equal(stored.length, 1);
});

test("oauth-adapter: replay detection atomar", async (t) => {
  const { time, adapter } = await setup(t);
  const replay = adapter("ReplayDetection");
  await replay.upsert("r-1", { iat: 1 }, 60);
  await assert.rejects(replay.upsert("r-1", { iat: 2 }, 60), "zweites upsert vor Ablauf");
  assert.deepEqual(await replay.find("r-1"), { iat: 1, jti: "r-1" });

  time.advance(60);
  await replay.upsert("r-1", { iat: 3 }, 60);
  assert.deepEqual(await replay.find("r-1"), { iat: 3, jti: "r-1" });

  const results = await Promise.allSettled(Array.from({ length: 20 }, (_, i) => replay.upsert("r-2", { iat: i }, 60)));
  assert.equal(results.filter((r) => r.status === "fulfilled").length, 1);
});

test("oauth-adapter: find by user code nicht unterstuetzt", async () => {
  let touched = false;
  const pool = { query: async () => { touched = true; return { rows: [], rowCount: 0 }; }, connect: async () => { touched = true; } };
  const store = new PgAdapter(pool as unknown as pg.Pool, "DeviceCode", clock().now);

  await assert.rejects(async () => store.findByUserCode("ABCD-EFGH"), { message: "findByUserCode not supported" });
  assert.equal(touched, false);
});

test("oauth-adapter: aufraeumen hoechstens alle 10 minuten", async (t) => {
  const { pool, account, time, adapter } = await setup(t);
  const access = adapter("AccessToken");
  const count = async (sql: string) => (await pool.query(`SELECT count(*)::int AS n FROM oauth_records WHERE ${sql}`)).rows[0].n;
  for (const id of ["alt-1", "alt-2", "alt-3"]) await access.upsert(id, { kind: "AccessToken", accountId: account }, 60);
  await access.upsert("lang", { kind: "AccessToken", accountId: account }, 3 * 3600);
  await adapter("Client").upsert("claude", { client_id: "claude" });

  const steps: Array<[number, number, string]> = [[5 * 60, 3, "nach 5 min: noch nicht"], [5 * 60, 0, "nach 10 min: aufgeräumt"]];
  for (const [seconds, expired, name] of steps) {
    time.advance(seconds);
    await adapter("Session").upsert(`s-${seconds}-${expired}`, { kind: "Session", uid: name }, 3600);
    assert.equal(await count(`model = 'AccessToken' AND expires_at <= '${time.now().toISOString()}'`), expired, name);
  }
  for (const id of ["neu-1", "neu-2"]) await access.upsert(id, { kind: "AccessToken", accountId: account }, 60);
  time.advance(5 * 60);
  await access.upsert("tick", { kind: "AccessToken", accountId: account }, 3600);
  assert.ok(await access.find("lang"), "unabgelaufen bleibt");
  assert.ok(await row(pool, "AccessToken", "neu-1"), "keine 10 min seit dem letzten Aufräumen");
  assert.ok(await adapter("Client").find("claude"), "ohne Ablauf bleibt");

  // A cleanup that fails must not fail the upsert. A trigger refuses every DELETE; renaming the table
  // (as the spec puts it) would fail the upsert's own insert as well.
  await pool.query(`CREATE FUNCTION refuse_delete() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'kein delete'; END $$`);
  await pool.query("CREATE TRIGGER refuse_delete BEFORE DELETE ON oauth_records FOR EACH STATEMENT EXECUTE FUNCTION refuse_delete()");
  time.advance(10 * 60);
  await access.upsert("trotzdem", { kind: "AccessToken", accountId: account }, 3600);
  assert.ok(await access.find("trotzdem"));
  assert.ok(await row(pool, "AccessToken", "neu-1"), "Aufräumen scheiterte, Zeile noch da");
});

test("oauth-adapter: unbekanntes konto wirft", async (t) => {
  const { pool, adapter } = await setup(t);
  type Failure = Error & { code?: string; cause?: { code?: string } };
  let failure: Failure | undefined;
  await adapter("AccessToken").upsert("waise-token", { jti: "waise-token", accountId: "kein-konto-42" }, 60)
    .catch((error: Failure) => { failure = error; });

  assert.ok(failure, "upsert mit unbekanntem Konto muss scheitern");
  assert.equal(failure.code ?? failure.cause?.code, "23503");
  for (const secret of ["waise-token", "kein-konto-42"]) assert.ok(!failure.message.includes(secret), failure.message);
  assert.deepEqual(await rows(pool), []);
});

test("oauth-adapter: nichts im log", async (t) => {
  const { account, time, adapter } = await setup(t);
  const written: string[] = [];
  const saved = { log: console.log, error: console.error, warn: console.warn, info: console.info, debug: console.debug,
    out: process.stdout.write, err: process.stderr.write };
  const capture = (...args: unknown[]) => { written.push(args.map(String).join(" ")); return true; };
  Object.assign(console, { log: capture, error: capture, warn: capture, info: capture, debug: capture });
  process.stdout.write = capture as typeof process.stdout.write;
  process.stderr.write = capture as typeof process.stderr.write;
  try {
    for (const [model, id, payload] of payloads(account)) {
      const store = adapter(model);
      await store.upsert(id, payload, 60);
      await store.find(id);
      await store.findByUid("uid-s1");
    }
    const codes = adapter("AuthorizationCode");
    await codes.consume("ac-1");
    await codes.consume("ac-1").catch(() => undefined);
    await adapter("ReplayDetection").upsert("rp-1", { iat: 1 }, 60);
    await adapter("ReplayDetection").upsert("rp-1", { iat: 2 }, 60).catch(() => undefined);
    await adapter("AccessToken").upsert("waise-log", { accountId: "konto-log-geheim" }, 60).catch(() => undefined);
    await adapter("AccessToken").findByUserCode("USER-CODE").catch(() => undefined);
    time.advance(11 * 60);
    await adapter("Client").upsert("claude", { client_id: "claude" });
    await adapter("AccessToken").revokeByGrantId("g-1");
    await adapter("Session").destroy("s-1");
  } finally {
    Object.assign(console, { log: saved.log, error: saved.error, warn: saved.warn, info: saved.info, debug: saved.debug });
    process.stdout.write = saved.out;
    process.stderr.write = saved.err;
  }
  const log = written.join("\n");
  const secrets = ["at-1", "ac-1", "rt-1", "s-1", "uid-s1", "rp-1", "waise-log", "konto-log-geheim", "USER-CODE", account];
  for (const secret of secrets) assert.ok(!log.includes(secret), `im Log: ${secret}`);
});
