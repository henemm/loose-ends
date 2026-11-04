import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, randomBytes, sign } from "node:crypto";
import { loadAppleConfig, verifyIdentityToken } from "../src/apple.ts";
import { createJwks } from "../src/apple-jwks.ts";

type Doc = Record<string, unknown>;
type Answer = () => Response | Promise<Response>;

const HOUR = 3_600_000;
const LOCK = 60_000;
const T0 = 1_800_000_000_000;
const URL_APPLE = "https://appleid.apple.com/auth/keys";
const FIXED = new Set(["unknown_kid", "keys_unavailable"]);
const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const key = (kid: string): Doc => ({ kty: "RSA", kid, alg: "RS256", use: "sig", n: `n-${kid}`, e: "AQAB" });
const body = (keys: unknown, status = 200) => new Response(JSON.stringify({ keys }), { status });
const ok = (...kids: string[]): Answer => () => body(kids.map(key));
const results: unknown[] = [];

// Stub fetch with a call counter, the last arguments and a replaceable answer; the clock is a plain number.
function rig(answer: Answer = ok("k1", "k2", "k3"), url?: string) {
  const r = {
    calls: 0, args: [] as unknown[][], answer, clock: T0,
    // Not async: an answer that throws makes fetch itself throw synchronously.
    fetch: ((...a: unknown[]) => { r.calls++; r.args.push(a); return Promise.resolve(r.answer()); }) as unknown as typeof fetch,
  };
  const jwks = createJwks({ fetch: r.fetch, now: () => r.clock, ...(url ? { url } : {}) });
  const keys = async (kid: string) => { const v = await jwks.keys(kid); results.push(v); return v; };
  return Object.assign(r, { keys });
}

// One row per failure; every row is a fetch that must not change the cache.
const FAILURES: [string, Answer][] = [
  ["Ausnahme", () => Promise.reject(new Error("GEHEIM-123"))],
  ["synchroner Wurf", () => { throw new Error("GEHEIM-123"); }],
  ["Zeitüberschreitung", () => Promise.reject(new DOMException("GEHEIM-123", "TimeoutError"))],
  ["Status 500", () => body([key("k1"), key("neu")], 500)],
  ["200 ohne JSON", () => new Response("GEHEIM-123 <html>", { status: 200 })],
  ["leeres Objekt", () => new Response("{}", { status: 200 })],
  ["keys Text", () => new Response('{"keys":"x"}', { status: 200 })],
  ["keys leer", () => body([])],
  ["nur ungültige", () => body([null, 1, [], { kid: "" }, { kid: 7 }, { n: "x" }])],
];

test("cache: laden und wiederverwenden", async () => {
  const r = rig();
  assert.deepEqual(await r.keys("k1"), key("k1"));
  assert.equal(r.calls, 1);
  assert.deepEqual(await r.keys("k1"), key("k1"));
  assert.deepEqual(await r.keys("k2"), key("k2"));
  assert.equal(r.calls, 1);
});

test("kid: unbekannt lädt einmal nach", async () => {
  const r = rig();
  await r.keys("k1");
  r.clock += LOCK;
  assert.equal(await r.keys("fremd"), "unknown_kid");
  assert.equal(r.calls, 2);
  assert.deepEqual(await r.keys("k1"), key("k1"));
  assert.equal(r.calls, 2);
});

test("sperre: 59 s und 60 s", async () => {
  const r = rig();
  await r.keys("k1");
  r.clock += LOCK;
  assert.equal(await r.keys("fremd1"), "unknown_kid");
  assert.equal(r.calls, 2);
  r.clock += LOCK - 1000;
  assert.equal(await r.keys("fremd2"), "unknown_kid");
  assert.equal(r.calls, 2);
  r.clock += 1000;
  assert.equal(await r.keys("fremd2"), "unknown_kid");
  assert.equal(r.calls, 3);
});

test("parallel: ein Abruf", async () => {
  const empty = rig();
  const cold = await Promise.all([1, 2, 3, 4, 5].map(() => empty.keys("k1")));
  assert.equal(empty.calls, 1);
  for (const v of cold) assert.deepEqual(v, key("k1"));
  const warm = rig();
  await warm.keys("k1");
  warm.clock += LOCK;
  const unknown = await Promise.all([1, 2, 3, 4, 5].map((i) => warm.keys(`fremd${i}`)));
  assert.equal(warm.calls, 2);
  assert.deepEqual(unknown, Array(5).fill("unknown_kid"));
});

test("fehlschlag: ohne Cache", async () => {
  for (const [name, answer] of FAILURES) {
    const r = rig(answer);
    assert.equal(await r.keys("k1"), "keys_unavailable", name);
    assert.equal(r.calls, 1, name);
  }
});

test("fehlschlag: alter Cache bleibt", async () => {
  for (const [name, answer] of FAILURES) {
    const r = rig();
    await r.keys("k1");
    r.answer = answer;
    r.clock += LOCK;
    assert.equal(await r.keys("neu"), "unknown_kid", name);
    assert.equal(r.calls, 2, name);
    assert.deepEqual(await r.keys("k1"), key("k1"), name);
    assert.deepEqual(await r.keys("k3"), key("k3"), name);
    assert.equal(r.calls, 2, name);
  }
});

test("sperre: auch nach Fehlschlag", async () => {
  const empty = rig(FAILURES[0][1]);
  assert.equal(await empty.keys("k1"), "keys_unavailable");
  empty.clock += LOCK - 1;
  assert.equal(await empty.keys("k1"), "keys_unavailable");
  assert.equal(empty.calls, 1);
  empty.answer = ok("k1");
  empty.clock += 1;
  assert.deepEqual(await empty.keys("k1"), key("k1"));
  assert.equal(empty.calls, 2);
  const full = rig();
  await full.keys("k1");
  full.answer = FAILURES[3][1];
  full.clock += LOCK;
  assert.equal(await full.keys("fremd1"), "unknown_kid");
  full.clock += LOCK - 1;
  assert.equal(await full.keys("fremd2"), "unknown_kid");
  assert.equal(full.calls, 2);
  full.clock += 1;
  assert.equal(await full.keys("fremd2"), "unknown_kid");
  assert.equal(full.calls, 3);
});

test("ttl: nach einer Stunde neuer Stand", async () => {
  const r = rig(ok("k1"));
  await r.keys("k1");
  r.answer = ok("k1", "neu");
  r.clock += HOUR - 1000;
  assert.deepEqual(await r.keys("k1"), key("k1"));
  assert.equal(r.calls, 1);
  r.clock += 1000;
  assert.deepEqual(await r.keys("k1"), key("k1"));
  assert.equal(r.calls, 2);
  assert.deepEqual(await r.keys("neu"), key("neu"));
  assert.equal(r.calls, 2);
});

test("ttl: abgelaufen und Abruf misslingt", async () => {
  const r = rig();
  await r.keys("k1");
  r.answer = FAILURES[0][1];
  r.clock += HOUR;
  assert.equal(await r.keys("k1"), "keys_unavailable");
  assert.equal(r.calls, 2);
  r.clock += LOCK - 1;
  assert.equal(await r.keys("k1"), "keys_unavailable");
  assert.equal(await r.keys("fremd"), "keys_unavailable");
  assert.equal(r.calls, 2);
  r.answer = ok("k1");
  r.clock += 1;
  assert.deepEqual(await r.keys("k1"), key("k1"));
  assert.equal(r.calls, 3);
});

test("rotation: entfernter kid", async () => {
  const r = rig(ok("k1", "k2"));
  await r.keys("k1");
  r.answer = ok("k2", "k4");
  r.clock += LOCK;
  assert.deepEqual(await r.keys("k4"), key("k4"));
  assert.equal(r.calls, 2);
  assert.equal(await r.keys("k1"), "unknown_kid");
  assert.deepEqual(await r.keys("k2"), key("k2"));
});

test("einträge: ungültige übersprungen", async () => {
  const first = { ...key("dup"), n: "erster" };
  const r = rig(() => body([{ n: "ohne" }, 5, null, [], { kid: "" }, { kid: 9 }, key("gut"), first, { ...key("dup"), n: "zweiter" }]));
  assert.deepEqual(await r.keys("gut"), key("gut"));
  assert.deepEqual(await r.keys("dup"), first);
  assert.equal(r.calls, 1);
});

test("fetch: url und signal", async () => {
  const std = rig();
  await std.keys("k1");
  assert.equal(String(std.args[0][0]), URL_APPLE);
  assert.ok((std.args[0][1] as { signal?: unknown })?.signal instanceof AbortSignal);
  const own = rig(ok("k1"), "https://example.test/keys");
  await own.keys("k1");
  assert.equal(String(own.args[0][0]), "https://example.test/keys");
  assert.ok((own.args[0][1] as { signal?: unknown })?.signal instanceof AbortSignal);
});

test("zusammenspiel: verifyIdentityToken", async () => {
  const ec = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const pem = (ec.privateKey.export({ type: "pkcs8", format: "pem" }) as string).replace(/\n/g, "\\n");
  const config = loadAppleConfig({
    APPLE_TEAM_ID: "TEAM123456", APPLE_KEY_ID: "KEY1234567", APPLE_CLIENT_IDS: "com.henning.looseends",
    APPLE_PRIVATE_KEY: pem, APPLE_TOKEN_KEY: randomBytes(32).toString("base64"),
  });
  const jwk = { ...rsa.publicKey.export({ format: "jwk" }), kid: "R1", alg: "RS256", use: "sig" };
  const seg = (x: unknown) => Buffer.from(JSON.stringify(x)).toString("base64url");
  const sec = T0 / 1000;
  const token = (kid: string) => {
    const data = `${seg({ alg: "RS256", kid })}.${seg({
      iss: "https://appleid.apple.com", aud: "com.henning.looseends", exp: sec + 600, iat: sec,
      nonce: createHash("sha256").update("roh").digest("hex"), sub: "001.abc.002",
    })}`;
    return `${data}.${sign("sha256", Buffer.from(data), rsa.privateKey).toString("base64url")}`;
  };
  const good = rig(() => body([jwk]));
  const opts = { config, keys: good.keys, now: T0 };
  assert.deepEqual(await verifyIdentityToken(token("R1"), "roh", opts), { ok: true, sub: "001.abc.002", aud: "com.henning.looseends" });
  good.clock += LOCK;
  assert.deepEqual(await verifyIdentityToken(token("R9"), "roh", opts), { ok: false, reason: "unknown_kid" });
  const bad = rig(FAILURES[0][1]);
  assert.deepEqual(await verifyIdentityToken(token("R1"), "roh", { config, keys: bad.keys, now: T0 }),
    { ok: false, reason: "keys_unavailable" });
});

// Runs every scenario above again with the outputs replaced, then checks every result seen so far.
test("silence und feste Werte", async (t) => {
  const written: string[] = [];
  const record = (...a: unknown[]) => { written.push(a.map(String).join(" ")); return true; };
  for (const name of ["log", "info", "warn", "error", "debug"] as const) t.mock.method(console, name, record);
  t.mock.method(process.stdout, "write", record);
  t.mock.method(process.stderr, "write", record);
  for (const [, answer] of FAILURES) {
    const r = rig(answer);
    await r.keys("k1");
    r.answer = ok("k1");
    r.clock += LOCK;
    await r.keys("k1");
    r.answer = answer;
    r.clock += HOUR;
    await r.keys("k1");
    await r.keys("fremd");
  }
  t.mock.restoreAll();
  assert.deepEqual(written, []);
  assert.ok(results.length > 40);
  for (const v of results) {
    if (typeof v === "string") assert.ok(FIXED.has(v), `fester Wert erwartet: ${v}`);
    else assert.ok(v !== null && typeof v === "object" && typeof (v as Doc).kid === "string", "JWK erwartet");
    assert.ok(!JSON.stringify(v).includes("GEHEIM"), "Fehlertext im Ergebnis");
  }
});
