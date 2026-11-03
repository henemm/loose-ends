import { test } from "node:test";
import assert from "node:assert/strict";
import { generateKeyPairSync, randomBytes, sign, verify } from "node:crypto";
import { loadAppleConfig } from "../src/apple.ts";
import { clientSecret, redeemCode } from "../src/apple-client.ts";

type Doc = Record<string, unknown>;
type Answer = (...a: unknown[]) => Response | Promise<Response>;

const NOW = 1_800_000_000_000;
const SEC = NOW / 1000;
const URL_APPLE = "https://appleid.apple.com/auth/token";
const IDS = ["com.henning.looseends", "com.henning.looseends.connector"];
const CODE = "GEHEIM-CODE";
const TOKEN = "GEHEIM-TOKEN";
const SUB = "001234.abcdef0123456789.0042";
const APPLE_ERRORS = ["invalid_request", "invalid_client", "invalid_grant", "unauthorized_client", "unsupported_grant_type", "invalid_scope"];
const REASONS = new Set([...APPLE_ERRORS.map((e) => `apple:${e}`), "apple_status", "unavailable", "malformed_response"]);
const ec = generateKeyPairSync("ec", { namedCurve: "P-256" });
const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const PEM = ec.privateKey.export({ type: "pkcs8", format: "pem" }) as string;
const config = loadAppleConfig({
  APPLE_TEAM_ID: "TEAM123456", APPLE_KEY_ID: "KEY1234567", APPLE_CLIENT_IDS: IDS.join(","),
  APPLE_PRIVATE_KEY: PEM.replace(/\n/g, "\\n"), APPLE_TOKEN_KEY: randomBytes(32).toString("base64"),
});
const seen: { name: string; text: string }[] = [];
const secrets: string[] = [];

const seg = (x: unknown) => Buffer.from(typeof x === "string" ? x : JSON.stringify(x)).toString("base64url");
const decode = (s: string) => JSON.parse(Buffer.from(s, "base64url").toString("utf8")) as Doc;
const flip = (s: string, i: number) => s.slice(0, i) + (s[i] === "A" ? "B" : "A") + s.slice(i + 1);
function idToken(over: Doc = {}, aud = IDS[0]): string {
  const data = `${seg({ alg: "RS256", kid: "K1" })}.${seg({ iss: "https://appleid.apple.com", aud, sub: SUB, iat: SEC, exp: SEC + 600, ...over })}`;
  return `${data}.${sign("sha256", Buffer.from(data), rsa.privateKey).toString("base64url")}`;
}
const json = (x: unknown, status = 200) => new Response(typeof x === "string" ? x : JSON.stringify(x), { status });
const success = (over: Doc = {}, aud = IDS[0]): Doc =>
  ({ access_token: TOKEN, token_type: "Bearer", expires_in: 3600, refresh_token: TOKEN, id_token: idToken({}, aud), ...over });
const ok = (aud = IDS[0]): Answer => () => json(success({}, aud));
const without = (key: string): Doc => { const d = success(); delete d[key]; return d; };

// The secret is valid when its ES256 signature (raw r||s) verifies with the public key.
function checkSecret(secret: string, clientId: string, now = NOW) {
  const parts = secret.split(".");
  assert.equal(parts.length, 3);
  assert.ok(parts.every((p) => /^[A-Za-z0-9_-]+$/.test(p)));
  assert.deepEqual(decode(parts[0]), { alg: "ES256", kid: "KEY1234567" });
  const iat = Math.floor(now / 1000);
  assert.deepEqual(decode(parts[1]), { iss: "TEAM123456", iat, exp: iat + 300, aud: "https://appleid.apple.com", sub: clientId });
  const signature = Buffer.from(parts[2], "base64url");
  assert.equal(signature.length, 64);
  assert.ok(valid(secret));
}
function valid(secret: string): boolean {
  const [h, p, s] = secret.split(".");
  return verify("sha256", Buffer.from(`${h}.${p}`), { key: ec.publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(s, "base64url"));
}

// Stub fetch with a call counter, the last arguments and a replaceable answer; the clock is fixed.
function rig(answer: Answer = ok()) {
  const r = {
    calls: 0, args: [] as unknown[][], answer,
    // Not async: an answer that throws makes fetch itself throw synchronously.
    fetch: ((...a: unknown[]) => { r.calls++; r.args.push(a); return Promise.resolve(r.answer(...a)); }) as unknown as typeof fetch,
  };
  return r;
}
async function redeem(name: string, answer: Answer, clientId = IDS[0], url?: string) {
  const r = rig(answer);
  const result = await redeemCode(CODE, clientId, { config, fetch: r.fetch, now: () => NOW, ...(url ? { url } : {}) });
  seen.push({ name, text: JSON.stringify(result) });
  for (const a of r.args) secrets.push(new URLSearchParams(String((a[1] as RequestInit).body)).get("client_secret") ?? "");
  return { r, result: result as Doc };
}

const MISUSE: [string, () => unknown][] = [
  ["secret: fremde ID", () => clientSecret(config, "com.fremd.app", NOW)],
  ["secret: anders geschrieben", () => clientSecret(config, "COM.henning.looseends", NOW)],
  ["secret: NaN", () => clientSecret(config, IDS[0], NaN)],
  ["secret: Infinity", () => clientSecret(config, IDS[0], Infinity)],
  ["secret: Text", () => clientSecret(config, IDS[0], "jetzt" as unknown as number)],
];
const MISUSE_REDEEM: [string, string, string][] = [
  ["redeem: fremde ID", "GEHEIM-123", "com.fremd.app"],
  ["redeem: anders geschrieben", "GEHEIM-123", "Com.Henning.LooseEnds"],
  ["redeem: leerer Code", "", IDS[0]],
];
const STATUS: [string, Answer][] = [
  ...[400, 401].flatMap((s) => APPLE_ERRORS.map((e): [string, Answer] => [`${s} ${e}`, () => json({ error: e }, s)])),
  ...["GEHEIM-123", "<script>", "", 42, {}, []].map((e): [string, Answer] => [`400 error ${JSON.stringify(e)}`, () => json({ error: e }, 400)]),
  ["400 ohne error", () => json({ error_description: "GEHEIM-123" }, 400)],
  ["400 ohne JSON", () => json("GEHEIM-123 <html>", 400)],
  ["500 mit Erfolgsrumpf", () => json(success(), 500)],
  ["503 Text", () => json("GEHEIM-123", 503)],
  ["302 leer", () => json("", 302)],
];
const MALFORMED: [string, Answer][] = [
  ["kaputtes JSON", () => json("{GEHEIM-123", 200)],
  ["Array", () => json([success()])],
  ["null", () => json("null")],
  ["leeres Objekt", () => json({})],
  ["refresh_token fehlt", () => json(without("refresh_token"))],
  ["refresh_token leer", () => json(success({ refresh_token: "" }))],
  ["refresh_token Zahl", () => json(success({ refresh_token: 42 }))],
  ["id_token fehlt", () => json(without("id_token"))],
  ["id_token leer", () => json(success({ id_token: "" }))],
  ["id_token Zahl", () => json(success({ id_token: 42 }))],
];
const BAD_ID: [string, () => string][] = [
  ["zwei Segmente", () => idToken().split(".").slice(0, 2).join(".")],
  ["vier Segmente", () => `${idToken()}.AAAA`],
  ["nicht base64url", () => `${seg({ alg: "RS256" })}.**GEHEIM**.AAAA`],
  ["Nutzlast kein JSON", () => `${seg({ alg: "RS256" })}.${seg("GEHEIM-123")}.AAAA`],
  ["Nutzlast Array", () => `${seg({ alg: "RS256" })}.${seg([SUB])}.AAAA`],
  ["iss falsch", () => idToken({ iss: "https://evil.example" })],
  ["aud andere Client-ID", () => idToken({}, IDS[1])],
  ["aud fremd", () => idToken({}, "com.fremd.app")],
  ["sub fehlt", () => idToken({ sub: undefined })],
  ["sub leer", () => idToken({ sub: "" })],
  ["sub Zahl", () => idToken({ sub: 42 })],
];
const UNAVAILABLE: [string, Answer][] = [
  ["Ausnahme", () => Promise.reject(new Error("GEHEIM-123"))],
  ["synchroner Wurf", () => { throw new Error("GEHEIM-123"); }],
  ["TimeoutError", () => Promise.reject(new DOMException("GEHEIM-123", "TimeoutError"))],
  ["abgelehnt ohne Fehler", () => Promise.reject("GEHEIM-123")],
];

test("secret: kopf, nutzlast, signatur", () => {
  for (const id of IDS) checkSecret(clientSecret(config, id, NOW), id);
  checkSecret(clientSecret(config, IDS[0], NOW + 999), IDS[0], NOW + 999);
});

test("secret: je aufruf neu, manipulation fällt auf", () => {
  const a = clientSecret(config, IDS[0], NOW);
  const b = clientSecret(config, IDS[0], NOW + 61_000);
  assert.notEqual(decode(a.split(".")[1]).iat, decode(b.split(".")[1]).iat);
  assert.equal(decode(b.split(".")[1]).exp, SEC + 61 + 300);
  const [h, p, s] = a.split(".");
  const sig = Buffer.from(s, "base64url");
  sig[10] ^= 1;
  assert.equal(valid(`${h}.${p}.${sig.toString("base64url")}`), false);
  assert.equal(valid(`${h}.${flip(p, 5)}.${s}`), false);
});

test("fehlbedienung: wirft ohne netz", async () => {
  const leaks = (m: string) => [CODE, "GEHEIM", "com.fremd", "COM.", "Com.", PEM.split("\n")[1]].some((x) => m.includes(x));
  for (const [name, call] of MISUSE) {
    assert.throws(call, (e: Error) => { seen.push({ name, text: e.message }); return !leaks(e.message); }, name);
  }
  for (const [name, code, id] of MISUSE_REDEEM) {
    const r = rig();
    await assert.rejects(async () => redeemCode(code, id, { config, fetch: r.fetch, now: () => NOW }),
      (e: Error) => { seen.push({ name, text: e.message }); return !leaks(e.message) && !e.message.includes(id); }, name);
    assert.equal(r.calls, 0, name);
  }
});

test("redeem: anfrage", async () => {
  for (const [id, url] of [[IDS[0], undefined], [IDS[1], "https://stub.test/token"]] as const) {
    const { r } = await redeem(`anfrage ${id}`, ok(id), id, url);
    assert.equal(r.calls, 1);
    const [target, init] = r.args[0] as [string, RequestInit];
    assert.equal(target, url ?? URL_APPLE);
    assert.equal(init.method, "POST");
    assert.deepEqual(init.headers, { "content-type": "application/x-www-form-urlencoded" });
    assert.ok(init.signal instanceof AbortSignal && !init.signal.aborted);
    const form = new URLSearchParams(String(init.body));
    assert.deepEqual([...form.keys()].sort(), ["client_id", "client_secret", "code", "grant_type"]);
    assert.equal(form.get("grant_type"), "authorization_code");
    assert.equal(form.get("client_id"), id);
    assert.equal(form.get("code"), CODE);
    checkSecret(form.get("client_secret") ?? "", id);
  }
});

test("redeem: erfolg", async () => {
  for (const id of IDS) assert.deepEqual((await redeem(`erfolg ${id}`, ok(id), id)).result, { ok: true, refreshToken: TOKEN, sub: SUB });
});

test("redeem: apple-fehler und status (Fallliste)", async () => {
  for (const [name, answer] of STATUS) {
    const known = /^40[01] (\w+)$/.exec(name);
    const reason = known && APPLE_ERRORS.includes(known[1]) ? `apple:${known[1]}` : "apple_status";
    assert.deepEqual((await redeem(name, answer)).result, { ok: false, reason }, name);
  }
});

test("redeem: malformed 200 (Fallliste)", async () => {
  for (const [name, answer] of MALFORMED) assert.deepEqual((await redeem(name, answer)).result, { ok: false, reason: "malformed_response" }, name);
});

test("redeem: id_token geprüft (Fallliste)", async () => {
  for (const [name, token] of BAD_ID) {
    const { result } = await redeem(name, () => json(success({ id_token: token() })));
    assert.deepEqual(result, { ok: false, reason: "malformed_response" }, name);
  }
});

test("redeem: unavailable und zeitlimit (Fallliste)", async (t) => {
  for (const [name, answer] of UNAVAILABLE) assert.deepEqual((await redeem(name, answer)).result, { ok: false, reason: "unavailable" }, name);
  const limits: number[] = [];
  const ctrl = new AbortController();
  t.mock.method(AbortSignal, "timeout", (ms: number) => { limits.push(ms); return ctrl.signal; });
  const hang: Answer = (_url, init) => new Promise<Response>((_, reject) => {
    const signal = (init as RequestInit).signal as AbortSignal;
    signal.addEventListener("abort", () => reject(signal.reason));
  });
  const pending = redeem("hängt bis zum Zeitlimit", hang);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(ctrl.signal.aborted, false);
  ctrl.abort(new DOMException("GEHEIM-123", "TimeoutError"));
  assert.deepEqual((await pending).result, { ok: false, reason: "unavailable" });
  t.mock.restoreAll();
  assert.equal(limits.length, 1);
  assert.ok(limits[0] > 0 && limits[0] <= 5000);
});

test("reason: feste menge, keine geheimnisse", () => {
  assert.ok(seen.length >= 60 && secrets.length >= 4);
  const parts = secrets.flatMap((s) => [s, ...s.split(".")]).filter((s) => s.length > 8);
  for (const { name, text } of seen) {
    const reason = /"reason":"([^"]*)"/.exec(text)?.[1];
    if (reason !== undefined) assert.ok(REASONS.has(reason), `${name}: ${reason}`);
    const forbidden = [CODE, "GEHEIM-123", "<html>", "<script>", ...parts];
    if (!text.includes('"ok":true')) forbidden.push(TOKEN);
    for (const f of forbidden) assert.ok(!text.includes(f), `${name} enthält ein Geheimnis`);
  }
});

test("silence", async (t) => {
  const out: unknown[] = [];
  const record = (...a: unknown[]) => { out.push(a); return true; };
  for (const name of ["log", "info", "warn", "error", "debug"] as const) t.mock.method(console, name, record);
  t.mock.method(process.stdout, "write", record);
  t.mock.method(process.stderr, "write", record);
  for (const id of IDS) clientSecret(config, id, NOW);
  for (const [, call] of MISUSE) { try { call(); } catch { /* expected */ } }
  for (const [, code, id] of MISUSE_REDEEM) await redeemCode(code, id, { config, fetch: rig().fetch, now: () => NOW }).catch(() => null);
  for (const [name, answer] of [["ok", ok()] as [string, Answer], ...STATUS, ...MALFORMED, ...UNAVAILABLE]) await redeem(name, answer);
  for (const [name, token] of BAD_ID) await redeem(name, () => json(success({ id_token: token() })));
  t.mock.restoreAll();
  assert.deepEqual(out, []);
});
