import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, randomBytes, sign, verify } from "node:crypto";
import { loadAppleConfig, verifyIdentityToken, type AppleConfig } from "../src/apple.ts";
import { appleReturnUrl, authorizeUrl, clientSecret, redeemCode, revokeToken } from "../src/apple-client.ts";

type Doc = Record<string, unknown>;
type Answer = (...a: unknown[]) => Response | Promise<Response>;

const NOW = 1_800_000_000_000;
const SEC = NOW / 1000;
const URL_APPLE = "https://appleid.apple.com/auth/token";
const URL_REVOKE = "https://appleid.apple.com/auth/revoke";
const IDS = ["com.henning.looseends", "com.henning.looseends.connector"];
const CODE = "GEHEIM-CODE";
const TOKEN = "GEHEIM-TOKEN";
const SUB = "001234.abcdef0123456789.0042";
const APPLE_ERRORS = ["invalid_request", "invalid_client", "invalid_grant", "unauthorized_client", "unsupported_grant_type", "invalid_scope"];
const REASONS = new Set([...APPLE_ERRORS.map((e) => `apple:${e}`), "apple_status", "unavailable", "malformed_response"]);
const ec = generateKeyPairSync("ec", { namedCurve: "P-256" });
const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const PEM = ec.privateKey.export({ type: "pkcs8", format: "pem" }) as string;
const ENV = {
  APPLE_TEAM_ID: "TEAM123456", APPLE_KEY_ID: "KEY1234567", APPLE_CLIENT_IDS: IDS.join(","),
  APPLE_PRIVATE_KEY: PEM.replace(/\n/g, "\\n"), APPLE_TOKEN_KEY: randomBytes(32).toString("base64"),
};
const config = loadAppleConfig(ENV);
const WEB = "com.henning.looseends.web";
const webConfig = loadAppleConfig({ ...ENV, APPLE_WEB_CLIENT_ID: WEB });
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
  ...[200, 400].map((status): [string, Answer] => [`Rumpf bricht ab ${status}`, () => new Response(new ReadableStream({
    pull() { throw new Error("GEHEIM-123"); },
  }), { status })]),
];

async function revoke(name: string, answer: Answer, clientId = IDS[0], url?: string) {
  const r = rig(answer);
  const result = await revokeToken(TOKEN, clientId, { config, fetch: r.fetch, now: () => NOW, ...(url ? { url } : {}) });
  seen.push({ name, text: JSON.stringify(result) });
  for (const a of r.args) secrets.push(new URLSearchParams(String((a[1] as RequestInit).body)).get("client_secret") ?? "");
  return { r, result: result as Doc };
}
const MISUSE_REVOKE: [string, unknown, string][] = [
  ["revoke: leeres Token", "", IDS[0]],
  ["revoke: Token Zahl", 42, IDS[0]],
  ["revoke: Token undefined", undefined, IDS[0]],
  ["revoke: fremde ID", TOKEN, "com.fremd.app"],
  ["revoke: anders geschrieben", TOKEN, "Com.Henning.LooseEnds"],
];
const REVOKE_NET = UNAVAILABLE.filter(([name]) => name !== "Rumpf bricht ab 200");

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

test("revoke: anfrage", async () => {
  for (const [id, url] of [[IDS[0], undefined], [IDS[1], "https://stub.test/revoke"]] as const) {
    const { r } = await revoke(`revoke anfrage ${id}`, () => json(""), id, url);
    assert.equal(r.calls, 1);
    const [target, init] = r.args[0] as [string, RequestInit];
    assert.equal(target, url ?? URL_REVOKE);
    assert.equal(init.method, "POST");
    assert.deepEqual(init.headers, { "content-type": "application/x-www-form-urlencoded" });
    assert.ok(init.signal instanceof AbortSignal && !init.signal.aborted);
    const form = new URLSearchParams(String(init.body));
    assert.deepEqual([...form.keys()].sort(), ["client_id", "client_secret", "token", "token_type_hint"]);
    assert.equal(form.get("token_type_hint"), "refresh_token");
    assert.equal(form.get("client_id"), id);
    assert.equal(form.get("token"), TOKEN);
    checkSecret(form.get("client_secret") ?? "", id);
  }
});

test("revoke: erfolg", async () => {
  const bodies: [string, Answer][] = [["leer", () => json("")], ["JSON", () => json({ a: 1 })], ["kein JSON", () => json("GEHEIM-123 <html>")], ["bricht ab", UNAVAILABLE[4][1]]];
  for (const [name, answer] of bodies) assert.deepEqual((await revoke(`revoke erfolg ${name}`, answer)).result, { ok: true }, name);
});

test("revoke: apple-fehler und status (Fallliste)", async () => {
  for (const [name, answer] of STATUS) {
    const known = /^40[01] (\w+)$/.exec(name);
    const reason = known && APPLE_ERRORS.includes(known[1]) ? `apple:${known[1]}` : "apple_status";
    assert.deepEqual((await revoke(`revoke ${name}`, answer)).result, { ok: false, reason }, name);
  }
});

test("revoke: unavailable und zeitlimit (Fallliste)", async (t) => {
  for (const [name, answer] of REVOKE_NET) assert.deepEqual((await revoke(`revoke ${name}`, answer)).result, { ok: false, reason: "unavailable" }, name);
  const limits: number[] = [];
  const ctrl = new AbortController();
  t.mock.method(AbortSignal, "timeout", (ms: number) => { limits.push(ms); return ctrl.signal; });
  const hang: Answer = (_url, init) => new Promise<Response>((_, reject) => {
    const signal = (init as RequestInit).signal as AbortSignal;
    signal.addEventListener("abort", () => reject(signal.reason));
  });
  const pending = revoke("revoke hängt bis zum Zeitlimit", hang);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(ctrl.signal.aborted, false);
  ctrl.abort(new DOMException("GEHEIM-123", "TimeoutError"));
  assert.deepEqual((await pending).result, { ok: false, reason: "unavailable" });
  t.mock.restoreAll();
  assert.equal(limits.length, 1);
  assert.ok(limits[0] > 0 && limits[0] <= 5000);
});

test("revoke fehlbedienung: wirft ohne netz", async () => {
  const leaks = (m: string) => ["GEHEIM", "com.fremd", "COM.", "Com.", PEM.split("\n")[1]].some((x) => m.includes(x));
  const nan = rig();
  await assert.rejects(async () => revokeToken(TOKEN, IDS[0], { config, fetch: nan.fetch, now: () => NaN }), (e: Error) => !leaks(e.message));
  assert.equal(nan.calls, 0);
  for (const [name, token, id] of MISUSE_REVOKE) {
    const r = rig();
    await assert.rejects(async () => revokeToken(token as string, id, { config, fetch: r.fetch, now: () => NOW }),
      (e: Error) => { seen.push({ name, text: e.message }); return !leaks(e.message) && !e.message.includes(id); }, name);
    assert.equal(r.calls, 0, name);
  }
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

test("revoke: silence", async (t) => {
  const out: unknown[] = [];
  const record = (...a: unknown[]) => { out.push(a); return true; };
  for (const name of ["log", "info", "warn", "error", "debug"] as const) t.mock.method(console, name, record);
  t.mock.method(process.stdout, "write", record);
  t.mock.method(process.stderr, "write", record);
  for (const [, token, id] of MISUSE_REVOKE) await revokeToken(token as string, id, { config, fetch: rig().fetch, now: () => NOW }).catch(() => null);
  for (const [name, answer] of [["ok", ok()] as [string, Answer], ...STATUS, ...UNAVAILABLE]) await revoke(name, answer);
  t.mock.restoreAll();
  assert.deepEqual(out, []);
});

// #621 S4a: the web flow's building blocks. Every misuse message is collected and checked for values at the end.
const RETURN = "https://loose-ends.test/oauth/apple/return";
const AUTH = { redirectUri: RETURN, state: "state-123", nonce: "roh-456" };
const sha = (s: string) => createHash("sha256").update(s).digest("hex");
const misuse: string[] = [];
const collect = (e: Error) => { misuse.push(e.message); return true; };
async function redeemWeb(name: string, answer: Answer, extra: { redirectUri?: string } = { redirectUri: RETURN }) {
  const r = rig(answer);
  const result = await redeemCode(CODE, WEB, { config: webConfig, fetch: r.fetch, now: () => NOW, ...extra });
  seen.push({ name, text: JSON.stringify(result) });
  return { r, result: result as Doc };
}
const bodyOf = (r: ReturnType<typeof rig>) => String((r.args[0][1] as RequestInit).body);

test("redeem: app-formular bytegleich ohne redirect_uri", async () => {
  const { r } = await redeem("app bytegleich", ok());
  const secret = new URLSearchParams(bodyOf(r)).get("client_secret") ?? "";
  assert.equal(bodyOf(r), `client_id=${IDS[0]}&client_secret=${secret}&code=${CODE}&grant_type=authorization_code`);
});

test("redeem: redirect_uri nur mit option, leer wirft", async () => {
  const { r, result } = await redeemWeb("web mit redirect_uri", ok(WEB));
  assert.deepEqual(result, { ok: true, refreshToken: TOKEN, sub: SUB });
  assert.equal(bodyOf(r).split("redirect_uri=https%3A%2F%2Floose-ends.test%2Foauth%2Fapple%2Freturn").length, 2);
  const form = new URLSearchParams(bodyOf(r));
  assert.deepEqual([...form.keys()].sort(), ["client_id", "client_secret", "code", "grant_type", "redirect_uri"]);
  assert.equal(form.get("client_id"), WEB);
  checkSecret(form.get("client_secret") ?? "", WEB);
  const empty = rig();
  await assert.rejects(redeemCode(CODE, WEB, { config: webConfig, fetch: empty.fetch, now: () => NOW, redirectUri: "" }), collect);
  assert.equal(empty.calls, 0);
});

test("redeem: id_token aud gleich web-id", async () => {
  assert.deepEqual((await redeemWeb("web aud web", ok(WEB))).result, { ok: true, refreshToken: TOKEN, sub: SUB });
  assert.deepEqual((await redeemWeb("web aud app", ok(IDS[0]))).result, { ok: false, reason: "malformed_response" });
});

test("client: web-id zugelassen, fremde id wirft", async () => {
  checkSecret(clientSecret(webConfig, WEB, NOW), WEB);
  const r = rig(() => json(""));
  assert.deepEqual(await revokeToken(TOKEN, WEB, { config: webConfig, fetch: r.fetch, now: () => NOW }), { ok: true });
  const form = new URLSearchParams(bodyOf(r));
  assert.equal(form.get("client_id"), WEB);
  checkSecret(form.get("client_secret") ?? "", WEB);
  const refused = (e: Error) => collect(e) && e.message === "client id is not configured";
  for (const [name, cfg, id] of [["fremde ID", webConfig, "com.fremd.app"], ["web-id ohne webClientId", config, WEB]] as const) {
    const net = rig();
    assert.throws(() => clientSecret(cfg, id, NOW), refused, name);
    await assert.rejects(redeemCode(CODE, id, { config: cfg, fetch: net.fetch, now: () => NOW }), refused, name);
    await assert.rejects(revokeToken(TOKEN, id, { config: cfg, fetch: net.fetch, now: () => NOW }), refused, name);
    assert.equal(net.calls, 0, name);
  }
});

test("authorizeUrl: parameter vollständig, ohne scope", () => {
  const url = authorizeUrl(webConfig, AUTH);
  assert.ok(url.startsWith("https://appleid.apple.com/auth/authorize?"), url);
  const params = new URL(url).searchParams;
  assert.equal([...params.keys()].length, 6);
  assert.deepEqual(Object.fromEntries(params), {
    client_id: WEB, redirect_uri: RETURN, response_type: "code", response_mode: "form_post", state: "state-123", nonce: sha("roh-456"),
  });
  assert.match(params.get("nonce") ?? "", /^[0-9a-f]{64}$/);
  assert.equal(params.has("scope"), false);
});

test("authorizeUrl: nonce passt zu verifyIdentityToken", async () => {
  const nonce = new URL(authorizeUrl(webConfig, AUTH)).searchParams.get("nonce");
  const token = idToken({ nonce }, WEB);
  const jwk = { ...rsa.publicKey.export({ format: "jwk" }), kid: "K1", alg: "RS256" } as JsonWebKey;
  const check = (raw: string) => verifyIdentityToken(token, raw, { config: webConfig, keys: async () => jwk, now: NOW, audiences: [WEB] });
  assert.deepEqual(await check("roh-456"), { ok: true, sub: SUB, aud: WEB });
  assert.deepEqual(await check("anders"), { ok: false, reason: "nonce" });
});

test("authorizeUrl: wirft ohne web-id und bei leeren feldern", () => {
  const cases: [string, AppleConfig, typeof AUTH][] = [
    ["webClientId", config, AUTH], ["redirectUri", webConfig, { ...AUTH, redirectUri: "" }],
    ["state", webConfig, { ...AUTH, state: "" }], ["nonce", webConfig, { ...AUTH, nonce: "" }],
  ];
  for (const [field, cfg, input] of cases) {
    assert.throws(() => authorizeUrl(cfg, input), (e: Error) => collect(e) && e.message.includes(field), field);
  }
});

test("appleReturnUrl: origin plus fester pfad", () => {
  const live = "https://loose-ends.henemm.com/oauth/apple/return";
  const rows: [string, string][] = [
    ["https://loose-ends.henemm.com", live], ["https://loose-ends.henemm.com/", live],
    ["https://loose-ends.henemm.com/mcp?x=1", live], ["http://localhost:8780", "http://localhost:8780/oauth/apple/return"],
  ];
  for (const [input, expected] of rows) assert.equal(appleReturnUrl(input), expected, input);
  for (const bad of ["kein-url", ""]) assert.throws(() => appleReturnUrl(bad), collect, JSON.stringify(bad));
});

test("silence: web-bausteine", async (t) => {
  const out: unknown[] = [];
  const record = (...a: unknown[]) => { out.push(a); return true; };
  for (const name of ["log", "info", "warn", "error", "debug"] as const) t.mock.method(console, name, record);
  t.mock.method(process.stdout, "write", record);
  t.mock.method(process.stderr, "write", record);
  clientSecret(webConfig, WEB, NOW);
  authorizeUrl(webConfig, AUTH);
  appleReturnUrl("https://loose-ends.henemm.com/mcp");
  for (const call of [() => authorizeUrl(config, AUTH), () => appleReturnUrl("kein-url"), () => clientSecret(config, WEB, NOW)]) {
    try { call(); } catch { /* expected */ }
  }
  await redeemWeb("silence web", ok(WEB)).catch(() => null);
  await redeemWeb("silence leer", ok(WEB), { redirectUri: "" }).catch(() => null);
  t.mock.restoreAll();
  assert.deepEqual(out, []);
  assert.ok(misuse.length >= 13, `zu wenige Meldungen gesammelt: ${misuse.length}`);
  const values = [WEB, IDS[0], "com.fremd.app", "state-123", "roh-456", sha("roh-456"), RETURN, "loose-ends.test", "kein-url",
    PEM.split("\n")[1], ENV.APPLE_TOKEN_KEY];
  for (const m of misuse) for (const v of values) assert.ok(!m.includes(v), `Wert in der Meldung: ${m}`);
});
