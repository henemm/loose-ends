import { test } from "node:test";
import assert from "node:assert/strict";
import { createCipheriv, randomBytes } from "node:crypto";
import { join } from "node:path";
import pg from "pg";
import { deleteAccount, findOrCreate } from "../src/accounts.ts";
import { decryptToken, encryptToken, storeRefreshToken } from "../src/apple-vault.ts";
import { migrate } from "../src/migrate.ts";
import { freshPool } from "./db.ts";

const migrations = join(import.meta.dirname, "../migrations");
const KEY = randomBytes(32);
const ID = "0b7d5e3c-1111-4000-8000-000000000001";
const OTHER = "0b7d5e3c-2222-4000-8000-000000000002";
const TOKEN = "r.GEHEIM-123.refresh-token-abc";

// A blob built by hand in the agreed format, so the test does not trust the code under test.
function seal(plain: string, tagLength = 16, key = KEY, id = ID): Buffer {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv, { authTagLength: tagLength });
  cipher.setAAD(Buffer.from(id));
  const ct = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  return Buffer.concat([Buffer.from([0x01]), iv, cipher.getAuthTag(), ct]);
}
const blob = () => encryptToken(KEY, ID, TOKEN);
const flip = (b: Buffer, i: number) => { const c = Buffer.from(b); c[i] ^= 0x01; return c; };
const version = (v: number) => { const c = blob(); c[0] = v; return c; };

// One row per attack: key, account and blob handed to decryptToken.
const ATTACKS: [string, () => [Buffer, string, unknown]][] = [
  ["Version 0x00", () => [KEY, ID, version(0x00)]],
  ["Version 0x02", () => [KEY, ID, version(0x02)]],
  ["Version 0xFF", () => [KEY, ID, version(0xff)]],
  ["IV gekippt", () => [KEY, ID, flip(blob(), 5)]],
  ["Tag gekippt", () => [KEY, ID, flip(blob(), 20)]],
  ["Ciphertext gekippt", () => [KEY, ID, flip(blob(), 30)]],
  ["Tag 15 Byte, Rest verschoben", () => { const b = blob(); return [KEY, ID, Buffer.concat([b.subarray(0, 28), b.subarray(29)])]; }],
  ["Tag 15 Byte, echt gebildet", () => [KEY, ID, seal(TOKEN, 15)]],
  ["28 Byte", () => [KEY, ID, seal("").subarray(0, 28)]],
  ["leerer Buffer", () => [KEY, ID, Buffer.alloc(0)]],
  ["falscher Schlüssel", () => [randomBytes(32), ID, blob()]],
  ["falsches Konto", () => [KEY, OTHER, blob()]],
];
const FOREIGN: [string, () => unknown][] = [
  ["Text", () => "GEHEIM-123"],
  ["Hex-Text eines Blobs", () => blob().toString("hex")],
  ["Base64-Text eines Blobs", () => blob().toString("base64")],
  ["Uint8Array", () => new Uint8Array(blob())],
  ["undefined", () => undefined],
  ["null", () => null],
  ["Zahl", () => 42],
  ["Objekt", () => ({ data: [...blob()] })],
];
const BAD_KEYS = [randomBytes(31), randomBytes(33), Buffer.alloc(0)];

async function migrated(t: Parameters<typeof freshPool>[0]): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}
const rows = async (pool: pg.Pool) => (await pool.query("SELECT * FROM apple_tokens")).rows;

test("roundtrip: blobform", () => {
  for (const token of ["a.b", "x".repeat(4096), "Grüße 🧵 Ärger"]) {
    const b = encryptToken(KEY, ID, token);
    assert.equal(b[0], 0x01);
    assert.equal(b.length, 29 + Buffer.byteLength(token));
    assert.equal(decryptToken(KEY, ID, b), token);
  }
});

test("attack: manipuliert, falsch, zu kurz", () => {
  for (const [name, args] of ATTACKS) assert.equal(decryptToken(...args()), null, name);
});

test("attack: kein Buffer", () => {
  for (const [name, value] of FOREIGN) assert.equal(decryptToken(KEY, ID, value()), null, name);
});

test("decrypt: schlüssellänge", () => {
  for (const key of BAD_KEYS) assert.equal(decryptToken(key, ID, blob()), null, `${key.length} Byte`);
});

test("decrypt: 29 Byte", () => {
  const smallest = seal("");
  assert.equal(smallest.length, 29);
  assert.equal(decryptToken(KEY, ID, smallest), "");
  assert.equal(decryptToken(KEY, ID, flip(smallest, 20)), null);
});

test("encrypt: wirft bei Fehleingabe", () => {
  const secrets = [KEY.toString("hex"), KEY.toString("base64"), TOKEN, ID];
  const cases: [string, () => unknown][] = [
    ["Schlüssel 31 Byte", () => encryptToken(KEY.subarray(0, 31), ID, TOKEN)],
    ["Schlüssel 33 Byte", () => encryptToken(Buffer.concat([KEY, Buffer.from([1])]), ID, TOKEN)],
    ["leerer Token", () => encryptToken(KEY, ID, "")],
    ["leeres Konto", () => encryptToken(KEY, "", TOKEN)],
  ];
  for (const [name, call] of cases) {
    assert.throws(call, (e: Error) => {
      for (const s of secrets) assert.ok(!`${e.message}\n${e.stack}`.includes(s), `${name}: Fehlertext verrät ${s.slice(0, 6)}…`);
      return true;
    }, name);
  }
});

test("encrypt: iv je blob verschieden", () => {
  const blobs = Array.from({ length: 1000 }, blob);
  assert.equal(new Set(blobs.map((b) => b.subarray(1, 13).toString("hex"))).size, 1000);
  assert.equal(new Set(blobs.map((b) => b.toString("hex"))).size, 1000);
});

test("encrypt: kein klartext im blob", () => {
  for (const token of [TOKEN, "y".repeat(4096)]) assert.equal(encryptToken(KEY, ID, token).includes(Buffer.from(token)), false);
});

test("store: überschreibt", async (t) => {
  const pool = await migrated(t);
  const id = await findOrCreate(pool, "apple-sub-1");
  const [a, b] = [encryptToken(KEY, id, "A-token"), encryptToken(KEY, id, "B-token")];
  assert.equal(await storeRefreshToken(pool, id, a), true);
  await pool.query("UPDATE apple_tokens SET created_at = now() - interval '1 hour'");
  const before: Date = (await rows(pool))[0].created_at;
  assert.equal(await storeRefreshToken(pool, id, b), true);
  const after = await rows(pool);
  assert.equal(after.length, 1);
  assert.deepEqual(after[0].refresh_token_enc, b);
  assert.ok(after[0].created_at > before, "created_at rückt beim Überschreiben vor");
});

test("store: unbekanntes konto", async (t) => {
  const pool = await migrated(t);
  assert.equal(await storeRefreshToken(pool, OTHER, blob()), false);
  assert.equal((await rows(pool)).length, 0);
  const dead = new pg.Pool({ connectionString: process.env.DATABASE_URL });
  await dead.end();
  await assert.rejects(storeRefreshToken(dead, OTHER, blob()));
});

test("store: rundweg über deleteAccount", async (t) => {
  const pool = await migrated(t);
  const id = await findOrCreate(pool, "apple-sub-1");
  assert.equal(await storeRefreshToken(pool, id, encryptToken(KEY, id, TOKEN)), true);
  const gone = await deleteAccount(pool, id);
  assert.ok(Buffer.isBuffer(gone.appleToken));
  assert.equal(decryptToken(KEY, id, gone.appleToken), TOKEN);
  assert.equal((await rows(pool)).length, 0);
});

test("store: blob gehört zum konto", async (t) => {
  const pool = await migrated(t);
  const [one, two] = [await findOrCreate(pool, "apple-sub-1"), await findOrCreate(pool, "apple-sub-2")];
  await storeRefreshToken(pool, one, encryptToken(KEY, one, TOKEN));
  const read = async (id: string) => (await pool.query("SELECT refresh_token_enc FROM apple_tokens WHERE account_id = $1", [id])).rows[0].refresh_token_enc;
  const copied: Buffer = await read(one);
  assert.equal(await storeRefreshToken(pool, two, copied), true);
  assert.equal(decryptToken(KEY, two, await read(two)), null);
  assert.equal(decryptToken(KEY, one, await read(one)), TOKEN);
});

test("silence", async (t) => {
  const out: unknown[] = [];
  const record = (...a: unknown[]) => { out.push(a); return true; };
  for (const name of ["log", "info", "warn", "error", "debug"] as const) t.mock.method(console, name, record);
  t.mock.method(process.stdout, "write", record);
  t.mock.method(process.stderr, "write", record);
  const pool = await migrated(t);
  const id = await findOrCreate(pool, "apple-sub-1");
  const results: unknown[] = [decryptToken(KEY, ID, blob()), decryptToken(KEY, ID, seal(""))];
  for (const [, args] of ATTACKS) results.push(decryptToken(...args()));
  for (const [, value] of FOREIGN) results.push(decryptToken(KEY, ID, value()));
  for (const key of BAD_KEYS) results.push(decryptToken(key, ID, blob()));
  for (const [k, i, tok] of [[BAD_KEYS[0], ID, TOKEN], [KEY, ID, ""], [KEY, "", TOKEN]] as const) assert.throws(() => encryptToken(k, i, tok));
  const stored = [await storeRefreshToken(pool, id, encryptToken(KEY, id, TOKEN)), await storeRefreshToken(pool, OTHER, blob())];
  await deleteAccount(pool, id);
  t.mock.restoreAll();
  assert.deepEqual(out, []);
  assert.deepEqual(stored, [true, false]);
  for (const r of results) assert.ok(r === null || typeof r === "string");
});
