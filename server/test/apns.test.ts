import { test } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync, verify } from "node:crypto";
import http2 from "node:http2";
import type { AddressInfo } from "node:net";
import { join } from "node:path";
import type pg from "pg";
import { migrate } from "../src/migrate.ts";
import { findOrCreate } from "../src/accounts.ts";
import { dropToken, listTokens, putDevice } from "../src/devices.ts";
import { apnsConfigFromEnv, apnsIds, createWaker, sendHttp2, type ApnsConfig, type ApnsRequest, type ApnsResponse } from "../src/apns.ts";
import { freshPool } from "./db.ts";

type T = { after: (fn: () => Promise<void>) => void };
type Env = "sandbox" | "production";
type Answer = (r: ApnsRequest, n: number) => ApnsResponse;
const migrations = join(import.meta.dirname, "../migrations");
const ec = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
const pem = (k: { export: (o: object) => string | Buffer }) => String(k.export({ type: "pkcs8", format: "pem" }));
const ENV = { APNS_TEAM_ID: "TEAMGEHEIM1", APNS_KEY_ID: "KEYGEHEIM1", APNS_PRIVATE_KEY: pem(ec.privateKey), APNS_TOPIC: "com.henning.looseends" };
const config = apnsConfigFromEnv(ENV) as ApnsConfig;
const BODY = { aps: { "content-available": 1 }, looseends: { v: 1 } };
const dev = (n: number) => `d0000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
// Tokens carry their device number, so a stub can answer per device.
const tok = (n: number) => `abcdef${n.toString(16).padStart(58, "0")}`;
const nr = (r: ApnsRequest) => Number.parseInt(r.token.slice(6), 16);
const MIN = 60_000;
const T0 = Date.UTC(2026, 10, 14, 8, 0, 0);
const part = (jwt: string, i: number) => JSON.parse(Buffer.from(jwt.split(".")[i], "base64url").toString("utf8"));
const iat = (r: ApnsRequest) => part(r.jwt, 1).iat as number;
// Apple's ids as it sends them (apns-id upper case), and the one form a log line may take (#960).
const A = "4D3E1B2C-1111-4222-8333-444455556666";
const U = "0a9b8c7d-5555-4666-8777-888899990000";
const UUID = "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}";
const LINE = new RegExp(`^apns (wake devices=\\d+|jwt failed|send failed list|send failed error (sandbox|production)|(sent|send failed|token dropped) \\d{3} (sandbox|production)( id=${UUID})?( unique=${UUID})?)$`);
const sorted = (l: string[]) => [...l].sort();

// An account with one device per entry, plus a foreign account with one device that must never be touched.
async function setup(t: T, envs: Env[], from = 1) {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  const account = await findOrCreate(pool, "sub.apns");
  for (const [i, environment] of envs.entries()) await putDevice(pool, account, dev(from + i), { token: tok(from + i), environment });
  await putDevice(pool, await findOrCreate(pool, "sub.other"), dev(99), { token: tok(99), environment: "production" });
  const count = async () => (await pool.query("SELECT token FROM device_tokens ORDER BY token")).rows.map((r) => r.token as string);
  return { pool, account, count };
}

// A stub send that records every request; the answer can be swapped between wakes.
function stub(answer: Answer = () => ({ status: 200 })) {
  const s = { calls: [] as ApnsRequest[], answer, send: async (r: ApnsRequest) => { s.calls.push(r); return s.answer(r, s.calls.length); } };
  return s;
}
const waker = (pool: pg.Pool, s: ReturnType<typeof stub>, logs: string[] = [], now = () => T0) =>
  createWaker({ config, pool, send: s.send, now, log: (e) => logs.push(e) });

test("apns: config alles oder nichts", () => {
  assert.equal(apnsConfigFromEnv({}), undefined);
  assert.equal(apnsConfigFromEnv({ APNS_TEAM_ID: " ", APNS_KEY_ID: "", APNS_PRIVATE_KEY: "\n", APNS_TOPIC: "  " }), undefined);
  for (const key of [ENV.APNS_PRIVATE_KEY, ENV.APNS_PRIVATE_KEY.replaceAll("\n", "\\n")]) {
    const c = apnsConfigFromEnv({ ...ENV, APNS_PRIVATE_KEY: key })!;
    assert.deepEqual([c.teamId, c.keyId, c.topic, c.privateKey.asymmetricKeyType], ["TEAMGEHEIM1", "KEYGEHEIM1", "com.henning.looseends", "ec"]);
  }
  const bad: Array<[string, Record<string, string>]> = Object.keys(ENV).map((name) => [name, { ...ENV, [name]: "" }]);
  for (const key of ["kein-pem-GEHEIM", pem(generateKeyPairSync("rsa", { modulusLength: 2048 }).privateKey),
    pem(generateKeyPairSync("ec", { namedCurve: "secp384r1" }).privateKey)]) bad.push(["APNS_PRIVATE_KEY", { ...ENV, APNS_PRIVATE_KEY: key }]);
  for (const [name, env] of bad) {
    assert.throws(() => apnsConfigFromEnv(env), (e: unknown) => e instanceof Error && e.message.includes(name)
      && !["GEHEIM", "PRIVATE KEY", "MII", "com.henning"].some((s) => e.message.includes(s)), name);
  }
});

test("apns: anbieter-jwt", async (t) => {
  const { pool, account } = await setup(t, ["production"]);
  const s = stub();
  await waker(pool, s).wake(account);
  const [h, p, sig] = s.calls[0].jwt.split(".");
  assert.deepEqual([part(s.calls[0].jwt, 0), part(s.calls[0].jwt, 1), Buffer.from(sig, "base64url").length],
    [{ alg: "ES256", kid: "KEYGEHEIM1" }, { iss: "TEAMGEHEIM1", iat: T0 / 1000 }, 64]);
  assert.ok(verify("sha256", Buffer.from(`${h}.${p}`), { key: ec.publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(sig, "base64url")));
});

test("apns: jwt cache und erneuerung", async (t) => {
  const { pool, account } = await setup(t, ["production"]);
  const s = stub();
  let now = T0;
  const w = waker(pool, s, [], () => now);
  for (const m of [0, 19, 49, 50, 60]) { now = T0 + m * MIN; await w.wake(account); }
  assert.deepEqual(s.calls.map(iat), [0, 0, 0, 50, 50].map((m) => (T0 + m * MIN) / 1000));
  assert.deepEqual([s.calls[1].jwt, s.calls[2].jwt, s.calls[4].jwt], [s.calls[0].jwt, s.calls[0].jwt, s.calls[3].jwt]);
});

test("apns: expiredprovidertoken genau ein wiederholversuch", async (t) => {
  const expired = { status: 403, reason: "ExpiredProviderToken" };
  // First wake at T0 fills the cache; the second at T0 + at minutes meets the given answers.
  const run = async (envs: Env[], at: number, answer: Answer) => {
    const { pool, account, count } = await setup(t, envs);
    const [before, logs, s] = [await count(), [] as string[], stub()];
    let now = T0;
    const w = waker(pool, s, logs, () => now);
    await w.wake(account);
    [s.calls.length, s.answer, now, logs.length] = [0, answer, T0 + at * MIN, 0];
    await w.wake(account);
    assert.deepEqual(await count(), before);
    return { calls: s.calls, logs };
  };
  const a = await run(["production"], 25, (_r, n) => (n === 1 ? expired : { status: 200 }));
  assert.deepEqual([a.calls.length, iat(a.calls[1]), a.logs], [2, (T0 + 25 * MIN) / 1000, ["apns wake devices=1", "apns sent 200 production"]]);
  assert.notEqual(a.calls[1].jwt, a.calls[0].jwt);
  const b = await run(["production"], 10, () => expired);
  assert.deepEqual([b.calls.length, b.logs], [1, ["apns wake devices=1", "apns send failed 403 production"]]);
  const c = await run(["production", "sandbox"], 30, (r) => (iat(r) === T0 / 1000 ? expired : { status: 200 }));
  assert.deepEqual([c.calls.length, c.calls[3].jwt, sorted(c.logs)], [4, c.calls[2].jwt, ["apns sent 200 production", "apns sent 200 sandbox", "apns wake devices=2"]]);
  assert.notEqual(c.calls[2].jwt, c.calls[0].jwt);
  const d = await run(["production"], 30, () => expired);
  assert.deepEqual([d.calls.length, d.logs], [2, ["apns wake devices=1", "apns send failed 403 production"]]);
});

test("apns: anfrage kopfzeilen und koerper", async (t) => {
  const { pool, account } = await setup(t, ["sandbox", "production"]);
  const s = stub();
  await waker(pool, s).wake(account);
  const by = Object.fromEntries(s.calls.map((r) => [r.origin, r.token]));
  assert.deepEqual([s.calls.length, by], [2, { "https://api.sandbox.push.apple.com": tok(1), "https://api.push.apple.com": tok(2) }]);
  for (const r of s.calls) assert.deepEqual([r.topic, JSON.parse(r.body)], ["com.henning.looseends", BODY]);
});

test("apns: ungueltige tokens loeschen", async (t) => {
  const { pool, account, count } = await setup(t, ["production", "sandbox", "production", "production"]);
  const answers = [{ status: 410, reason: "Unregistered" }, { status: 400, reason: "BadDeviceToken" }, { status: 400, reason: "DeviceTokenNotForTopic" }, { status: 200 }];
  const logs: string[] = [];
  await waker(pool, stub((r) => answers[nr(r) - 1]), logs).wake(account);
  assert.deepEqual([await count(), logs[0], sorted(logs)], [[tok(4), tok(99)], "apns wake devices=4", ["apns sent 200 production",
    "apns token dropped 400 production", "apns token dropped 400 sandbox", "apns token dropped 410 production", "apns wake devices=4"]]);
});

const failures: Array<() => ApnsResponse> = [() => ({ status: 500 }), () => ({ status: 503 }), () => ({ status: 429, reason: "TooManyRequests" }),
  () => ({ status: 403, reason: "InvalidProviderToken" }), () => ({ status: 403, reason: "ExpiredProviderToken" }), () => ({ status: 400, reason: "PayloadEmpty" }),
  () => ({ status: 410 }), () => ({ status: 400 }), () => { throw new Error("connect ECONNREFUSED"); }, () => { throw new Error("apns timeout"); }];
const failing: Answer = (r) => (nr(r) <= failures.length ? failures[nr(r) - 1]() : { status: 200 });
// The line each case of failures leaves, then the success after them.
const outcomes = [...[500, 503, 429, 403, 403, 400, 410, 400].map((s) => `apns send failed ${s} production`),
  "apns send failed error production", "apns send failed error production", "apns sent 200 production"];

// putDevice keeps at most MAX_DEVICES = 10 per account, so the cases run in parts of at most ten devices.
test("apns: andere fehler loeschen nichts", async (t) => {
  for (const [from, to] of [[1, 5], [6, failures.length + 1]]) {
    const envs: Env[] = Array(to - from + 1).fill("production");
    const { pool, account, count } = await setup(t, envs, from);
    const [before, logs, s] = [await count(), [] as string[], stub(failing)];
    await waker(pool, s, logs).wake(account);
    assert.deepEqual([s.calls.length, await count(), logs[0], sorted(logs)],
      [envs.length, before, `apns wake devices=${envs.length}`, sorted([`apns wake devices=${envs.length}`, ...outcomes.slice(from - 1, to)])]);
  }
});

test("apns: sendeergebnis im log", async (t) => {
  const { pool, account } = await setup(t, ["production", "sandbox", "production", "production", "sandbox"]);
  const answers: ApnsResponse[] = [{ status: 200, apnsId: A, uniqueId: U }, { status: 200 }, { status: 200, apnsId: A },
    { status: 200, uniqueId: U }, { status: 500, apnsId: A }];
  const logs: string[] = [];
  await waker(pool, stub((r) => answers[nr(r) - 1]), logs).wake(account);
  assert.deepEqual([logs.length, logs[0], sorted(logs)], [6, "apns wake devices=5", sorted(["apns wake devices=5",
    `apns sent 200 production id=${A} unique=${U}`, "apns sent 200 sandbox", `apns sent 200 production id=${A}`,
    `apns sent 200 production unique=${U}`, `apns send failed 500 sandbox id=${A}`])]);
});

test("apns: ids nur als kanonische uuid", () => {
  const read = (h: Record<string, unknown>) => apnsIds(h as http2.IncomingHttpHeaders);
  assert.deepEqual(read({ "apns-id": A, "apns-unique-id": U }), { apnsId: A, uniqueId: U });
  assert.deepEqual(read({ ":status": 200 }), {});
  assert.deepEqual(read({ "apns-unique-id": U }), { uniqueId: U });
  for (const bad of ["kein-uuid GEHEIM", `${A} `, ` ${A}`, `x${A}`, `{${A}}`, A.replaceAll("-", ""), `${A}0`, "", [A, A], [A], 42]) {
    assert.deepEqual(read({ "apns-id": bad, "apns-unique-id": bad }), {}, String(bad));
  }
});

test("apns: wake wirft nie", async (t) => {
  const [unhandled, onUnhandled] = [[] as unknown[], (e: unknown) => { unhandled.push(e); }];
  process.on("unhandledRejection", onUnhandled);
  t.after(async () => { process.off("unhandledRejection", onUnhandled); });
  const { pool, account } = await setup(t, ["production"]);
  const thrower = (m: string) => () => { throw new Error(m); };
  const broken = { query: thrower("db down"), connect: thrower("db down") } as unknown as pg.Pool;
  const listLogs: string[] = [];
  for (const [name, opts] of [["pool", { config, pool: broken, send: stub().send, now: () => T0, log: (e: string) => listLogs.push(e) }],
    ["send sync", { config, pool, send: thrower("sync") as never, now: () => T0 }],
    ["send reject", { config, pool, send: async () => { throw new Error("reject"); }, now: () => T0 }],
    ["log", { config, pool, send: stub(() => ({ status: 500 })).send, now: () => T0, log: thrower("log") }]] as const) {
    await assert.doesNotReject(createWaker(opts).wake(account), name);
  }
  const [e, f, logs, empty] = [stub(), stub(), [] as string[], [] as string[]];
  await waker(pool, e, empty).wake(await findOrCreate(pool, "sub.empty"));
  await assert.doesNotReject(waker(pool, f, logs, () => Number.NaN).wake(account));
  assert.deepEqual([e.calls.length, f.calls.length, logs, empty, listLogs], [0, 0, ["apns wake devices=1", "apns jwt failed"], ["apns wake devices=0"], ["apns send failed list"]]);
  await new Promise((r) => setImmediate(r));
  assert.deepEqual(unhandled, []);
});

test("apns: log nur feste namen", async (t) => {
  const [printed, error, log] = [[] as unknown[], console.error, console.log];
  console.error = console.log = (...a: unknown[]) => { printed.push(a); };
  t.after(async () => { console.error = error; console.log = log; });
  const dropped = [{ status: 410, reason: "Unregistered" }, { status: 400, reason: "BadDeviceToken" }, { status: 400, reason: "DeviceTokenNotForTopic" }];
  const [logs, accounts] = [[] as string[], [] as string[]];
  // Every second device answers with Apple's ids, so lines with and without them both pass the format.
  const base: Answer = (r, n) => (nr(r) <= failures.length ? failing(r, n) : dropped[nr(r) - failures.length - 1]);
  const s = stub((r, n) => { const a = base(r, n); return nr(r) % 2 ? a : { ...a, apnsId: A, uniqueId: U }; });
  // At most MAX_DEVICES = 10 per account, so two parts; every case must really be sent.
  for (const [from, to] of [[1, 7], [8, failures.length + 3]]) {
    const { pool, account } = await setup(t, Array(to - from + 1).fill("production"), from);
    accounts.push(account);
    await waker(pool, s, logs).wake(account);
    await waker(pool, s, logs, () => Number.NaN).wake(account);
  }
  assert.deepEqual(s.calls.map(nr), Array.from({ length: failures.length + 3 }, (_, i) => i + 1));
  // The retry after an expired provider token, an account without devices and a database that fails.
  const { pool, account } = await setup(t, ["sandbox"]);
  accounts.push(account, await findOrCreate(pool, "sub.empty"));
  const r = stub();
  let now = T0;
  const w = waker(pool, r, logs, () => now);
  await w.wake(account);
  [r.answer, now] = [(_q, n) => (n === 2 ? { status: 403, reason: "ExpiredProviderToken", apnsId: A } : { status: 200, apnsId: A }), T0 + 25 * MIN];
  await w.wake(account);
  await w.wake(accounts.at(-1)!);
  const broken = { query: () => { throw new Error("db down GEHEIM"); } } as unknown as pg.Pool;
  await createWaker({ config, pool: broken, send: r.send, now: () => T0, log: (e) => logs.push(e) }).wake(account);
  for (const line of ["apns wake devices=0", "apns send failed list", "apns jwt failed", "apns send failed error production",
    `apns sent 200 sandbox id=${A}`, `apns token dropped 400 production id=${A} unique=${U}`]) assert.ok(logs.includes(line), line);
  for (const l of logs) assert.match(l, LINE);
  assert.ok(!logs.some((l) => accounts.some((a) => l.includes(a))
    || /abcdef|Unregistered|BadDevice|NotForTopic|Expired|InvalidProvider|TooMany|PayloadEmpty|ECONNREFUSED|timeout|GEHEIM|db down|bearer|eyJ/.test(l)));
  assert.deepEqual(printed, []);
});

test("apns: http2 rahmung", async (t) => {
  const seen: Array<{ headers: http2.IncomingHttpHeaders; body: string }> = [];
  let [mode, open] = ["answer" as "answer" | "empty" | "ids" | "badids" | "hang" | "kill", 0];
  const server = http2.createServer();
  server.on("session", (s) => { open++; s.on("close", () => { open--; }); });
  server.on("stream", (stream: http2.ServerHttp2Stream, headers: http2.IncomingHttpHeaders) => {
    const chunks: Buffer[] = [];
    stream.on("data", (c: Buffer) => chunks.push(c));
    stream.on("end", () => {
      seen.push({ headers, body: Buffer.concat(chunks).toString() });
      if (mode === "answer") stream.respond({ ":status": 410 }), stream.end(JSON.stringify({ reason: "Unregistered" }));
      if (mode === "empty") stream.respond({ ":status": 200 }), stream.end();
      if (mode === "ids") stream.respond({ ":status": 200, "apns-id": A, "apns-unique-id": U }), stream.end();
      if (mode === "badids") stream.respond({ ":status": 410, "apns-id": "kein-uuid GEHEIM", "apns-unique-id": [U, U] }), stream.end(JSON.stringify({ reason: "Unregistered" }));
      if (mode === "kill") stream.session?.destroy();
    });
  });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  t.after(async () => { await new Promise((r) => server.close(r)); });
  const origin = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
  const request = { origin, token: tok(1), jwt: "a.b.c", topic: "com.henning.looseends", body: JSON.stringify(BODY) };
  assert.deepEqual(await sendHttp2(request), { status: 410, reason: "Unregistered" });
  const h = seen[0].headers;
  assert.deepEqual([h[":method"], h[":path"], h.authorization, h["apns-topic"], h["apns-push-type"], h["apns-priority"], h["content-type"], JSON.parse(seen[0].body)],
    ["POST", `/3/device/${tok(1)}`, "bearer a.b.c", "com.henning.looseends", "background", "5", "application/json", BODY]);
  mode = "empty";
  assert.deepEqual(await sendHttp2(request), { status: 200 });
  mode = "ids";
  assert.deepEqual(await sendHttp2(request), { status: 200, apnsId: A, uniqueId: U });
  mode = "badids";
  assert.deepEqual(await sendHttp2(request), { status: 410, reason: "Unregistered" });
  mode = "hang";
  await assert.rejects(sendHttp2(request, { timeoutMs: 200 }));
  for (let i = 0; i < 50 && open > 0; i++) await new Promise((r) => setTimeout(r, 20));
  assert.equal(open, 0);
  mode = "kill";
  await assert.rejects(sendHttp2(request, { timeoutMs: 2000 }));
  // The waker reaches the same server through the origins option and the real transport.
  const { pool, account, count } = await setup(t, ["sandbox"]);
  const logs: string[] = [];
  const real = createWaker({ config, pool, now: () => T0, origins: { sandbox: origin, production: origin }, log: (e) => logs.push(e) });
  mode = "ids";
  await real.wake(account);
  mode = "answer";
  await real.wake(account);
  assert.deepEqual([seen.at(-1)?.headers[":path"], await count(), logs], [`/3/device/${tok(1)}`, [tok(99)],
    ["apns wake devices=1", `apns sent 200 sandbox id=${A} unique=${U}`, "apns wake devices=1", "apns token dropped 410 sandbox"]]);
});

test("apns: listtokens und droptoken", async (t) => {
  const { pool, account, count } = await setup(t, ["sandbox", "production"]);
  assert.deepEqual(await listTokens(pool, account), [{ token: tok(1), environment: "sandbox" }, { token: tok(2), environment: "production" }]);
  assert.deepEqual(await listTokens(pool, await findOrCreate(pool, "sub.none")), []);
  const before = await count();
  assert.deepEqual([await dropToken(pool, tok(1), "production"), await dropToken(pool, tok(50), "sandbox"), await count()], [false, false, before]);
  await putDevice(pool, account, dev(2), { token: tok(3), environment: "production" });
  assert.deepEqual([await dropToken(pool, tok(2), "production"), await count()], [false, [tok(1), tok(3), tok(99)]]);
  assert.deepEqual([await dropToken(pool, tok(1).toUpperCase(), "sandbox"), await count()], [true, [tok(3), tok(99)]]);
});
