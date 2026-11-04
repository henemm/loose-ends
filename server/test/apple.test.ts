import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash, createHmac, generateKeyPairSync, randomBytes, sign, type KeyObject } from "node:crypto";
import { loadAppleConfig, verifyIdentityToken } from "../src/apple.ts";

type Doc = Record<string, unknown>;
type Lookup = (kid: string) => Promise<JsonWebKey | "unknown_kid" | "keys_unavailable">;

const REASONS = ["malformed", "alg", "unknown_kid", "signature", "iss", "aud", "expired", "iat", "nonce", "keys_unavailable"];
const NOW = 1_800_000_000_000;
const SEC = NOW / 1000;
const RAW = "rohwert-0815";
const SUB = "001234.abcdef0123456789.0042";
const IDS = ["com.henning.looseends", "com.henning.looseends.web"];
const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const otherRsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const ec = generateKeyPairSync("ec", { namedCurve: "P-256" });
const JWK = { ...rsa.publicKey.export({ format: "jwk" }), kid: "K1", alg: "RS256", use: "sig" } as JsonWebKey;
const hash = (s: string) => createHash("sha256").update(s).digest("hex");
const seg = (x: unknown) => Buffer.from(typeof x === "string" ? x : JSON.stringify(x)).toString("base64url");
const claims = (over: Doc = {}): Doc => ({
  iss: "https://appleid.apple.com", aud: IDS[0], exp: SEC + 600, iat: SEC, nonce: hash(RAW), sub: SUB, ...over,
});
const drop = (key: string) => { const c = claims(); delete c[key]; return c; };

function jwt(payload: Doc = claims(), header: Doc = { alg: "RS256", kid: "K1" }, key: KeyObject = rsa.privateKey): string {
  const data = `${seg(header)}.${seg(payload)}`;
  return `${data}.${sign("sha256", Buffer.from(data), key).toString("base64url")}`;
}
function hs256(secret: string | Buffer): string {
  const data = `${seg({ alg: "HS256", kid: "K1" })}.${seg(claims())}`;
  return `${data}.${createHmac("sha256", secret).update(data).digest("base64url")}`;
}
function es256(): string {
  const data = `${seg({ alg: "ES256", kid: "K1" })}.${seg(claims())}`;
  return `${data}.${sign("sha256", Buffer.from(data), { key: ec.privateKey, dsaEncoding: "ieee-p1363" }).toString("base64url")}`;
}
const flip = (s: string, i: number) => s.slice(0, i) + (s[i] === "A" ? "B" : "A") + s.slice(i + 1);
const tamper = (t: string) => { const [h, , s] = t.split("."); return `${h}.${seg(claims({ sub: "fremd" }))}.${s}`; };
const flipSig = (t: string) => { const [h, p, s] = t.split("."); return `${h}.${p}.${flip(s, 100)}`; };

function stub(answer: (kid: string) => JsonWebKey | "unknown_kid" | "keys_unavailable" = (k) => (k === "K1" ? JWK : "unknown_kid")) {
  const lookup = { calls: 0, keys: (async (kid: string) => { lookup.calls++; return answer(kid); }) as Lookup };
  return lookup;
}
function validEnv(over: Record<string, string | undefined> = {}): Record<string, string | undefined> {
  const pem = ec.privateKey.export({ type: "pkcs8", format: "pem" }) as string;
  return {
    APPLE_TEAM_ID: "TEAM123456", APPLE_KEY_ID: "KEY1234567", APPLE_CLIENT_IDS: IDS.join(","),
    APPLE_PRIVATE_KEY: pem.replace(/\n/g, "\\n"), APPLE_TOKEN_KEY: randomBytes(32).toString("base64"), ...over,
  };
}
const config = loadAppleConfig(validEnv());
const seen: { name: string; result: Doc }[] = [];

async function verify(token: unknown, raw = RAW, keys: Lookup = stub().keys) {
  return verifyIdentityToken(token as string, raw, { config, keys, now: NOW }) as Promise<Doc>;
}
async function expectReason(name: string, reason: string, token: unknown, raw = RAW, keys?: Lookup) {
  const result = await verify(token, raw, keys);
  seen.push({ name, result });
  assert.deepEqual(result, { ok: false, reason }, name);
}
const direct = (token: string, raw: unknown, now = NOW) => verifyIdentityToken(token, raw as string, { config, keys: stub().keys, now });
async function table(rows: [string, unknown, string?][], reason: string) {
  for (const [name, token, raw] of rows) await expectReason(name, reason, token, raw ?? RAW);
}

test("config: gültige Umgebung", () => {
  const c = loadAppleConfig(validEnv({ APPLE_CLIENT_IDS: " a.b , c.d ," }));
  assert.equal(c.teamId, "TEAM123456");
  assert.equal(c.keyId, "KEY1234567");
  assert.deepEqual(c.clientIds, ["a.b", "c.d"]);
  assert.equal(c.privateKey.asymmetricKeyType, "ec");
  assert.equal(c.privateKey.asymmetricKeyDetails?.namedCurve, "prime256v1");
  assert.equal(c.tokenKey.length, 32);
  const plain = loadAppleConfig(validEnv({ APPLE_PRIVATE_KEY: ec.privateKey.export({ type: "pkcs8", format: "pem" }) as string }));
  assert.equal(plain.privateKey.asymmetricKeyType, "ec");
});

test("config: fehlend und ungültig", () => {
  const rsaPem = rsa.privateKey.export({ type: "pkcs8", format: "pem" }) as string;
  const cases: [string, string | undefined][] = [
    ...Object.keys(validEnv()).flatMap((k): [string, string | undefined][] => [[k, undefined], [k, ""]]),
    ["APPLE_PRIVATE_KEY", rsaPem], ["APPLE_PRIVATE_KEY", "GEHEIM-123"],
    ["APPLE_TOKEN_KEY", randomBytes(31).toString("base64")], ["APPLE_TOKEN_KEY", randomBytes(33).toString("base64")],
    ["APPLE_TOKEN_KEY", "GEHEIM-123!"], ["APPLE_CLIENT_IDS", " , ,"],
  ];
  for (const [name, value] of cases) {
    assert.throws(() => loadAppleConfig(validEnv({ [name]: value })), (e: Error) => {
      assert.ok(e.message.includes(name), `${name}: Name fehlt in „${e.message}“`);
      if (value) assert.ok(!e.message.includes(value.trim()) && !e.message.includes("GEHEIM"), `${name}: Wert im Fehlertext`);
      return true;
    }, `${name}=${value === undefined ? "fehlt" : JSON.stringify(value.slice(0, 20))}`);
  }
});

test("verify: aud im erfolg", async () => {
  for (const aud of IDS) {
    const result = await verify(jwt(claims({ aud })));
    assert.deepEqual(result, { ok: true, sub: SUB, aud });
    assert.deepEqual(Object.keys(result).sort(), ["aud", "ok", "sub"]);
  }
});

test("verify: gültiges Token", async () => {
  assert.deepEqual(await verify(jwt()), { ok: true, sub: SUB, aud: IDS[0] });
  assert.deepEqual(await verify(jwt(claims({ aud: IDS[1] }))), { ok: true, sub: SUB, aud: IDS[1] });
  const { alg: _alg, ...noAlg } = JWK;
  assert.deepEqual(await verify(jwt(), RAW, stub(() => noAlg).keys), { ok: true, sub: SUB, aud: IDS[0] });
});

test("attack: malformed", async () => {
  const h = seg({ alg: "RS256", kid: "K1" });
  const p = seg(claims());
  await table([
    ["undefined", undefined], ["Zahl", 42], ["leer", ""], ["zwei Segmente", `${h}.${p}`], ["vier Segmente", `${h}.${p}.x.y`],
    ["kein base64url", `${h}.${p}.ab+/=`], ["Header Array", `${seg("[1]")}.${p}.x`], ["Header null", `${seg("null")}.${p}.x`],
    ["Header Text", `${seg('"x"')}.${p}.x`], ["Payload Array", `${h}.${seg("[1]")}.x`], ["Payload null", `${h}.${seg("null")}.x`],
    ["Payload Text", `${h}.${seg('"x"')}.x`], ["sub leer", jwt(claims({ sub: "" }))], ["sub fehlt", jwt(drop("sub"))],
  ], "malformed");
});

test("attack: alg none", async () => {
  const lookup = stub();
  for (const alg of ["none", "NONE"]) {
    const unsigned = `${seg({ alg, kid: "K1" })}.${seg(claims())}`;
    await expectReason(`alg ${alg}`, "alg", `${unsigned}.`, RAW, lookup.keys);
    await expectReason(`alg ${alg} mit Signatur`, "alg", `${unsigned}.${jwt().split(".")[2]}`, RAW, lookup.keys);
  }
  assert.equal(lookup.calls, 0, "die Schlüsselsuche darf bei alg none nicht laufen");
});

test("attack: HS256 mit öffentlichem Schlüssel", async () => {
  await table([
    ["HS256 PEM", hs256(rsa.publicKey.export({ type: "spki", format: "pem" }) as string)],
    ["HS256 Modulus", hs256(Buffer.from(JWK.n as string, "base64url"))],
  ], "alg");
});

test("attack: ES256", async () => {
  await table([["ES256 eigener EC-Schlüssel", es256()]], "alg");
});

test("attack: kid und Schlüsselsuche", async () => {
  await expectReason("kid unbekannt", "unknown_kid", jwt(claims(), { alg: "RS256", kid: "K9" }));
  await expectReason("Suche ohne Schlüssel", "keys_unavailable", jwt(), RAW, stub(() => "keys_unavailable").keys);
  await expectReason("kid fehlt", "unknown_kid", jwt(claims(), { alg: "RS256" }));
});

test("attack: JWK mit fremdem alg oder kty", async () => {
  const ecJwk = { ...ec.publicKey.export({ format: "jwk" }), kid: "K1" } as JsonWebKey;
  await expectReason("JWK alg RS384", "unknown_kid", jwt(), RAW, stub(() => ({ ...JWK, alg: "RS384" })).keys);
  await expectReason("JWK kty EC", "unknown_kid", jwt(), RAW, stub(() => ecJwk).keys);
});

test("attack: Signatur", async () => {
  await table([
    ["Payload geändert", tamper(jwt())], ["Signatur geändert", flipSig(jwt())],
    ["anderer RSA-Schlüssel, gleicher kid", jwt(claims(), undefined, otherRsa.privateKey)],
  ], "signature");
  await expectReason("JWK n leer", "signature", jwt(), RAW, stub(() => ({ ...JWK, n: "" })).keys);
});

test("attack: iss", async () => {
  await table([
    ["iss mit Schrägstrich", jwt(claims({ iss: "https://appleid.apple.com/" }))],
    ["iss http", jwt(claims({ iss: "http://appleid.apple.com" }))],
    ["iss fremd", jwt(claims({ iss: "https://evil.example" }))], ["iss fehlt", jwt(drop("iss"))],
  ], "iss");
});

test("attack: aud", async () => {
  await table([
    ["aud Teilstring", jwt(claims({ aud: "com.henning.loose" }))], ["aud Oberstring", jwt(claims({ aud: `${IDS[0]}.x` }))],
    ["aud Array gemischt", jwt(claims({ aud: [IDS[0], "evil"] }))], ["aud Array erlaubt", jwt(claims({ aud: [IDS[0]] }))],
    ["aud Großschreibung", jwt(claims({ aud: IDS[0].toUpperCase() }))], ["aud fehlt", jwt(drop("aud"))],
    ["aud Zahl", jwt(claims({ aud: 42 }))],
  ], "aud");
});

test("attack: abgelaufen", async () => {
  assert.deepEqual(await verify(jwt(claims({ exp: SEC - 59 }))), { ok: true, sub: SUB, aud: IDS[0] });
  await table([
    ["exp now-60s", jwt(claims({ exp: SEC - 60 }))], ["exp now-1h", jwt(claims({ exp: SEC - 3600 }))],
    ["exp fehlt", jwt(drop("exp"))], ["exp Text", jwt(claims({ exp: String(SEC + 600) }))], ["exp NaN", jwt(claims({ exp: NaN }))],
  ], "expired");
  assert.deepEqual(await direct(jwt(), RAW, NaN), { ok: false, reason: "expired" }, "now NaN");
});

test("attack: iat", async () => {
  assert.deepEqual(await verify(jwt(claims({ iat: SEC + 60 }))), { ok: true, sub: SUB, aud: IDS[0] });
  await table([
    ["iat now+61s", jwt(claims({ iat: SEC + 61 }))], ["iat now+1d", jwt(claims({ iat: SEC + 86400 }))],
    ["iat fehlt", jwt(drop("iat"))], ["iat Text", jwt(claims({ iat: String(SEC) }))],
  ], "iat");
});

test("attack: nonce", async () => {
  assert.deepEqual(await verify(jwt()), { ok: true, sub: SUB, aud: IDS[0] });
  await table([
    ["nonce fehlt", jwt(drop("nonce"))], ["nonce Rohwert", jwt(claims({ nonce: RAW }))],
    ["nonce falscher Hash", jwt(claims({ nonce: hash("anders") }))], ["nonce Zahl", jwt(claims({ nonce: 42 }))],
    ["nonce Array", jwt(claims({ nonce: [hash(RAW)] }))], ["nonce andere Länge", jwt(claims({ nonce: hash(RAW).slice(0, 10) }))],
    ["falscher Rohwert", jwt(), "anderer-rohwert"],
  ], "nonce");
  assert.deepEqual(await direct(jwt(), Object.create(null)), { ok: false, reason: "nonce" }, "rawNonce ohne Prototyp");
  assert.deepEqual(await direct(jwt(claims({ nonce: hash("undefined") })), undefined), { ok: false, reason: "nonce" }, "rawNonce undefined");
});

test("reasons: feste Liste", () => {
  assert.ok(seen.length >= 50, `zu wenige Fälle gesammelt: ${seen.length}`);
  for (const { name, result } of seen) {
    assert.deepEqual(Object.keys(result).sort(), ["ok", "reason"], name);
    assert.ok(REASONS.includes(result.reason as string), `${name}: ${String(result.reason)}`);
  }
  for (const r of REASONS) assert.ok(seen.some((s) => s.result.reason === r), `Grund ${r} kommt nie vor`);
});

test("verify: fehlerformen", () => {
  for (const { name, result } of seen) assert.deepEqual(Object.keys(result), ["ok", "reason"], `${name}: genau ok und reason`);
});

test("silence", async () => {
  const written: string[] = [];
  const saved = { log: console.log, error: console.error, warn: console.warn, info: console.info, debug: console.debug };
  const out = process.stdout.write, err = process.stderr.write;
  const catcher = (...a: unknown[]) => { written.push(a.map(String).join(" ")); return true; };
  Object.assign(console, { log: catcher, error: catcher, warn: catcher, info: catcher, debug: catcher });
  process.stdout.write = catcher as typeof out;
  process.stderr.write = catcher as typeof err;
  const messages: string[] = [];
  try {
    loadAppleConfig(validEnv());
    try { loadAppleConfig(validEnv({ APPLE_PRIVATE_KEY: "GEHEIM-123" })); } catch (e) { messages.push((e as Error).message); }
    await verify(jwt());
    await verify(tamper(jwt()));
    await verify(jwt(claims({ aud: "evil" })));
  } finally {
    Object.assign(console, saved);
    process.stdout.write = out;
    process.stderr.write = err;
  }
  assert.deepEqual(written, []);
  for (const m of messages) for (const secret of ["GEHEIM", SUB, "BEGIN", jwt().slice(0, 20)]) assert.ok(!m.includes(secret), m);
});
