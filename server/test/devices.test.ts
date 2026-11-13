import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import { createServer } from "node:net";
import { join } from "node:path";
import pg from "pg";
import { start } from "../src/main.ts";
import { migrate } from "../src/migrate.ts";
import { createSession, deleteAccount, endSession, findOrCreate } from "../src/accounts.ts";
import { FormError } from "../src/transcripts.ts";
import { checkDevice, putDevice } from "../src/devices.ts";
import { freshPool } from "./db.ts";

type T = { after: (fn: () => Promise<void>) => void };
const databaseUrl = process.env.DATABASE_URL!;
const migrations = join(import.meta.dirname, "../migrations");
const dev = (n: number) => `d0000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const tok = (n: number) => n.toString(16).padStart(64, "0");
const rows = async (pool: pg.Pool, account?: string) => (await pool.query(
  `SELECT account_id, device, token, environment, updated_at FROM device_tokens ${account ? "WHERE account_id = $1" : ""} ORDER BY account_id, device`, account ? [account] : [])).rows;
const migrated = async (t: T) => { const pool = await freshPool(t); await migrate(pool, migrations); return pool; };
const seed = (pool: pg.Pool, account: string, device: string, token: string, minsAgo: number) =>
  pool.query("INSERT INTO device_tokens VALUES ($1, $2, $3, 'production', now() - make_interval(mins => $4))", [account, device, token, minsAgo]);

// The real route table of start(), without the auth option, on its own schema.
async function service(t: T) {
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  const admin = new pg.Pool({ connectionString: databaseUrl });
  await admin.query(`CREATE SCHEMA ${schema}`);
  const url = new URL(databaseUrl);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const running = await start({ databaseUrl: url.toString(), port: 0, migrationsDir: migrations });
  await running.ready;
  const pool = new pg.Pool({ connectionString: url.toString() });
  t.after(async () => { await pool.end(); await running.close(); await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  const account = await findOrCreate(pool, `sub.${schema}`);
  return { url: running.url, pool, account, token: await createSession(pool, account) };
}
const post = (url: string, headers: Record<string, string>, body?: string, method = "POST") =>
  fetch(`${url}/app/device`, { method, headers, body: method === "GET" ? undefined : body });

test("devices: migration 008 einmal angewendet", async (t) => {
  const pool = await migrated(t);
  const defs = (await pool.query("SELECT contype, pg_get_constraintdef(oid) AS def FROM pg_constraint WHERE conrelid = 'device_tokens'::regclass")).rows;
  const has = (type: string, part: string) => defs.some((d) => d.contype === type && d.def.includes(part));
  assert.ok(has("p", "(account_id, device)") && has("u", "(token)") && has("f", "REFERENCES accounts(id) ON DELETE CASCADE") && has("c", "environment"), JSON.stringify(defs));
  const account = await findOrCreate(pool, "sub.migration");
  await assert.rejects(pool.query("INSERT INTO device_tokens (account_id, device, token, environment) VALUES ($1, $2, $3, 'staging')", [account, dev(1), tok(1)]));
  assert.deepEqual(await migrate(pool, migrations), []);
  assert.equal((await pool.query("SELECT 1 FROM schema_migrations WHERE name = '008_device_tokens.sql'")).rowCount, 1);
});

test("devices: checkDevice Formfaelle", () => {
  for (const doc of [{ token: "a".repeat(64), environment: "sandbox" }, { token: "0".repeat(200), environment: "production" },
    { token: "AB".repeat(32), environment: "production" }, { token: "f".repeat(200), environment: "sandbox" }]) assert.doesNotThrow(() => checkDevice(doc));
  const ok = { token: "ab".repeat(32), environment: "sandbox" };
  const refused: Array<[string, unknown]> = [["null", null], ["array", []], ["text", "x"], ["ohne token", { environment: "sandbox" }],
    ["ohne environment", { token: ok.token }], ["zusatz", { ...ok, extra: 1 }], ["63", { ...ok, token: "a".repeat(63) }],
    ["201", { ...ok, token: "a".repeat(201) }], ["65", { ...ok, token: "a".repeat(65) }], ["g", { ...ok, token: `g${"a".repeat(63)}` }],
    ["leer", { ...ok, token: `${"a".repeat(63)} ` }], ["umbruch", { ...ok, token: `${"a".repeat(63)}\n` }], ["zahl", { ...ok, token: 42 }],
    ["Sandbox", { ...ok, environment: "Sandbox" }], ["prod", { ...ok, environment: "prod" }], ["leere umgebung", { ...ok, environment: "" }], ["umgebung zahl", { ...ok, environment: 1 }]];
  for (const [name, doc] of refused) {
    const token = (doc as { token?: unknown } | null)?.token;
    assert.throws(() => checkDevice(doc), (e: unknown) => e instanceof FormError && (typeof token !== "string" || !e.message.includes(token.trim())), name);
  }
});

test("devices: neu und aktualisieren", async (t) => {
  const pool = await migrated(t);
  const account = await findOrCreate(pool, "sub.a");
  await putDevice(pool, account, dev(1), { token: "AB".repeat(32), environment: "sandbox" });
  const [first] = await rows(pool);
  assert.deepEqual({ ...first, updated_at: undefined }, { account_id: account, device: dev(1), token: "ab".repeat(32), environment: "sandbox", updated_at: undefined });
  await putDevice(pool, account, dev(1), { token: tok(2), environment: "production" });
  const now = await rows(pool);
  assert.equal(now.length, 1);
  assert.deepEqual([now[0].token, now[0].environment], [tok(2), "production"]);
  assert.ok(now[0].updated_at > first.updated_at);
});

test("devices: token zieht um", async (t) => {
  const pool = await migrated(t);
  const [a, b] = [await findOrCreate(pool, "sub.a"), await findOrCreate(pool, "sub.b")];
  await putDevice(pool, a, dev(1), { token: "ab".repeat(32), environment: "production" });
  await putDevice(pool, a, dev(9), { token: tok(9), environment: "production" });
  await putDevice(pool, b, dev(2), { token: "AB".repeat(32), environment: "sandbox" });
  assert.deepEqual((await rows(pool)).map((r) => [r.account_id, r.device, r.token]).sort(), [[a, dev(9), tok(9)], [b, dev(2), "ab".repeat(32)]].sort());
  await putDevice(pool, b, dev(3), { token: "ab".repeat(32), environment: "sandbox" });
  assert.deepEqual((await rows(pool, b)).map((r) => r.device), [dev(3)]);
});

test("devices: elftes geraet verdraengt aeltestes", async (t) => {
  const pool = await migrated(t);
  const [a, b] = [await findOrCreate(pool, "sub.a"), await findOrCreate(pool, "sub.b")];
  for (let i = 0; i < 10; i++) await seed(pool, a, dev(i), tok(i), 20 - i);
  await pool.query("INSERT INTO device_tokens SELECT $1, $2 || lpad(i::text, 12, '0'), lpad(to_hex(256 + i), 64, '0'), 'production', now() - interval '30 minutes' FROM generate_series(9, 0, -1) i",
    [b, "d0000000-0000-4000-8000-"]);
  const other = await rows(pool, b);
  await putDevice(pool, a, dev(10), { token: tok(10), environment: "sandbox" });
  assert.deepEqual((await rows(pool, a)).map((r) => r.device), Array.from({ length: 10 }, (_, i) => dev(i + 1)));
  await putDevice(pool, a, dev(5), { token: tok(55), environment: "sandbox" });
  assert.equal((await rows(pool, a)).length, 10, "ein bekanntes Gerät verdrängt niemanden");
  await putDevice(pool, b, dev(20), { token: tok(120), environment: "sandbox" });
  assert.deepEqual((await rows(pool, b)).map((r) => r.device), [...other.slice(1).map((r) => r.device), dev(20)], "bei Gleichstand fällt die kleinere Kennung");
  assert.equal((await rows(pool, a)).length, 10);
});

test("devices: weg meldet token", async (t) => {
  const s = await service(t);
  const headers = { authorization: `Bearer ${s.token}`, "x-device": dev(7).toUpperCase(), "content-type": "application/json; charset=utf-8" };
  const answer = await post(s.url, headers, JSON.stringify({ token: "AB".repeat(40), environment: "sandbox" }));
  assert.deepEqual([answer.status, answer.headers.get("cache-control"), await answer.text()], [204, "no-store", ""]);
  assert.deepEqual((await rows(s.pool)).map((r) => [r.device, r.token, r.environment]), [[dev(7), "ab".repeat(40), "sandbox"]]);
  assert.equal((await post(s.url, headers, JSON.stringify({ token: tok(3), environment: "production" }))).status, 204);
  assert.deepEqual((await rows(s.pool)).map((r) => [r.device, r.token, r.environment]), [[dev(7), tok(3), "production"]]);
});

test("devices: weg jede ablehnung", async (t) => {
  const s = await service(t);
  const logged: string[] = [];
  t.mock.method(console, "error", (...args: unknown[]) => { logged.push(args.map(String).join(" ")); });
  await putDevice(s.pool, s.account, dev(1), { token: tok(1), environment: "sandbox" });
  const before = await rows(s.pool);
  const [expired, ended] = [await createSession(s.pool, s.account), await createSession(s.pool, s.account)];
  await s.pool.query("UPDATE sessions SET last_used_at = now() - interval '91 days' WHERE token_hash = $1", [createHash("sha256").update(expired).digest()]);
  await endSession(s.pool, ended);
  const good = { authorization: `Bearer ${s.token}`, "x-device": dev(2), "content-type": "application/json" };
  const body = JSON.stringify({ token: tok(2), environment: "sandbox" });
  const pad = (size: number) => `{"pad":"${"x".repeat(size - 10)}"}`;
  const cases: Array<[string, number, Record<string, string>, string, string?]> = [
    ...["GET", "PUT", "DELETE"].map((m): [string, number, Record<string, string>, string, string] => [m, 405, good, body, m]),
    ["ohne auth", 401, { ...good, authorization: "" }, body], ["Basic", 401, { ...good, authorization: "Basic eDp5" }, body],
    ["Bearer leer", 401, { ...good, authorization: "Bearer " }, body], ["Bearer a b", 401, { ...good, authorization: "Bearer a b" }, body],
    ["unbekannt", 401, { ...good, authorization: "Bearer unbekannt" }, body], ["abgelaufen", 401, { ...good, authorization: `Bearer ${expired}` }, body],
    ["beendet", 401, { ...good, authorization: `Bearer ${ended}` }, body], ["ohne geraet", 400, { ...good, "x-device": "" }, body],
    ["gerät", 400, { ...good, "x-device": "gerät" }, body], ["ohne striche", 400, { ...good, "x-device": dev(2).replaceAll("-", "") }, body],
    ["35 zeichen", 400, { ...good, "x-device": dev(2).slice(1) }, body], ["text/plain", 415, { ...good, "content-type": "text/plain" }, body],
    ["ohne typ", 415, { ...good, "content-type": "" }, body], ["256 KiB", 400, good, pad(256 * 1024)], ["256 KiB + 1", 413, good, pad(256 * 1024 + 1)],
    ["kaputt", 400, good, "{"], ["zusatz", 400, good, JSON.stringify({ token: tok(2), environment: "sandbox", x: 1 })],
    ["63", 400, good, JSON.stringify({ token: "a".repeat(63), environment: "sandbox" })], ["umgebung", 400, good, JSON.stringify({ token: tok(2), environment: "prod" })],
    ["unbekannt ohne geraet", 401, { ...good, authorization: "Bearer unbekannt", "x-device": "" }, body],
    ["unbekannt falscher typ", 401, { ...good, authorization: "Bearer unbekannt", "content-type": "text/plain" }, body],
  ];
  for (const [name, code, headers, raw, method] of cases) {
    const sent = Object.fromEntries(Object.entries(headers).filter(([, v]) => v !== ""));
    const answer = await post(s.url, sent, raw, method);
    assert.deepEqual([answer.status, await answer.text(), answer.headers.get("cache-control")], [code, "", "no-store"], name);
    if (code === 405) assert.equal(answer.headers.get("allow"), "POST", name);
    assert.deepEqual(await rows(s.pool), before, name);
  }
  assert.deepEqual(logged, []);
});

test("devices: konto loeschen entfernt tokens", async (t) => {
  const pool = await migrated(t);
  const [a, b] = [await findOrCreate(pool, "sub.a"), await findOrCreate(pool, "sub.b")];
  for (const [account, n] of [[a, 1], [a, 2], [b, 3], [b, 4]] as const) await putDevice(pool, account, dev(n), { token: tok(n), environment: "sandbox" });
  const kept = await rows(pool, b);
  await deleteAccount(pool, a);
  assert.deepEqual(await rows(pool, a), []);
  assert.deepEqual(await rows(pool, b), kept);
});

test("devices: einhaengen vor migrate und abmelden", async (t) => {
  const probe = createServer();
  await new Promise<void>((done) => probe.listen(0, "127.0.0.1", done));
  const port = (probe.address() as { port: number }).port;
  await new Promise((done) => probe.close(done));
  const down = await start({ databaseUrl: `postgres://postgres@127.0.0.1:${port}/postgres`, port: 0, migrationsDir: migrations, retryMs: 50, maxAttempts: 20 });
  const refused = assert.rejects(down.ready);
  const early = await post(down.url, { authorization: "Bearer x", "x-device": dev(1), "content-type": "application/json" }, "{}");
  assert.deepEqual([early.status, await early.text()], [503, ""]);
  await refused;
  await down.close();
  const s = await service(t);
  const answer = await post(s.url, { authorization: `Bearer ${s.token}`, "x-device": dev(1), "content-type": "application/json" }, JSON.stringify({ token: tok(1), environment: "sandbox" }));
  assert.equal(answer.status, 204);
  assert.ok(await endSession(s.pool, s.token));
  assert.equal((await rows(s.pool)).length, 1, "Abmelden lässt das Token stehen");
});

test("devices: vertrag und doku", () => {
  const contract = readFileSync(join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md"), "utf8");
  const section = contract.split(/^## /m).find((part) => /^[^\n]*Wege der App/.test(part)) ?? "";
  for (const word of ["/app/device", "token", "environment", "X-Device", "Abmelden", "S5b"]) assert.ok(section.includes(word), `Vertrag ohne ${word}`);
  assert.match(section, /(10|zehn) Geräte/);
  assert.match(section, /vier Wege/);
  assert.equal([...contract.matchAll(/```json\n/g)].length, 3, "genau drei ```json-Blöcke");
  const claude = readFileSync(join(import.meta.dirname, "../../CLAUDE.md"), "utf8");
  const line = claude.split("\n").find((l) => l.includes("src/devices.ts"));
  assert.ok(line && line.includes("/app/device") && line.includes("008") && !line.includes("src/app-routes.ts"), "CLAUDE.md-Zeile zu devices.ts fehlt");
});
