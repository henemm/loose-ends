import { test } from "node:test";
import assert from "node:assert/strict";
import { createCipheriv, createHash, generateKeyPairSync, randomBytes, sign } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type pg from "pg";
import { createSession, deleteAccount, endSession, findOrCreate, resolveSession } from "../src/accounts.ts";
import { type AppleConfig, loadAppleConfig } from "../src/apple.ts";
import { decryptToken, encryptToken, storeRefreshToken } from "../src/apple-vault.ts";
import { authRoutes, bearerToken, type AuthDeps } from "../src/auth.ts";
import { start } from "../src/main.ts";
import { migrate } from "../src/migrate.ts";
import { freshPool } from "./db.ts";

type Doc = Record<string, unknown>;
type Answer = () => Response | Promise<Response>;

const NOW = 1_800_000_000_000;
const SEC = NOW / 1000;
const IDS = ["com.henning.looseends", "com.henning.looseends.connector"];
const SUB = "001234.abcdef0123456789.0042";
const RAW = "nonce-roh-0815";
const CODE = "GEHEIM-CODE";
const REFRESH = "GEHEIM-REFRESH";
const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const otherRsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const ec = generateKeyPairSync("ec", { namedCurve: "P-256" });
const JWK = { ...rsa.publicKey.export({ format: "jwk" }), kid: "K1", alg: "RS256", use: "sig" } as JsonWebKey;
const config: AppleConfig = loadAppleConfig({
  APPLE_TEAM_ID: "TEAM123456", APPLE_KEY_ID: "KEY1234567", APPLE_CLIENT_IDS: IDS.join(","),
  APPLE_PRIVATE_KEY: (ec.privateKey.export({ type: "pkcs8", format: "pem" }) as string).replace(/\n/g, "\\n"),
  APPLE_TOKEN_KEY: randomBytes(32).toString("base64"),
});
const migrations = join(import.meta.dirname, "../migrations");

const seg = (x: unknown) => Buffer.from(JSON.stringify(x)).toString("base64url");
function jwt(over: Doc = {}, header: Doc = { alg: "RS256", kid: "K1" }, key = rsa.privateKey, aud = IDS[0]): string {
  const nonce = createHash("sha256").update(RAW).digest("hex");
  const data = `${seg(header)}.${seg({ iss: "https://appleid.apple.com", aud, sub: SUB, iat: SEC, exp: SEC + 600, nonce, ...over })}`;
  return `${data}.${sign("sha256", Buffer.from(data), key).toString("base64url")}`;
}
const appleOk = (sub = SUB, aud = IDS[0]): Answer => () =>
  new Response(JSON.stringify({ refresh_token: REFRESH, id_token: jwt({ sub }, undefined, undefined, aud) }), { status: 200 });
const appleError = (error: string): Answer => () => new Response(JSON.stringify({ error }), { status: 400 });

async function migrated(t: Parameters<typeof freshPool>[0]): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

// Fake Apple: a counting fetch with a replaceable answer; keys and clock are fixed.
function rig(pool: pg.Pool, answer: Answer = appleOk(), over: Partial<AuthDeps> = {}) {
  const r = {
    calls: 0, answer, urls: [] as string[], forms: [] as URLSearchParams[], signals: [] as AbortSignal[],
    fetch: ((url: string, init?: RequestInit) => {
      r.calls++; r.urls.push(String(url)); r.forms.push(new URLSearchParams(String(init?.body ?? "")));
      if (init?.signal) r.signals.push(init.signal);
      return Promise.resolve(r.answer());
    }) as unknown as typeof fetch,
  };
  const deps: AuthDeps = { pool, config, keys: async (kid) => (kid === "K1" ? JWK : "unknown_kid"), fetch: r.fetch, now: () => NOW, ...over };
  return { r, routes: authRoutes(deps) };
}
const post = (body: unknown, headers: Record<string, string> = { "content-type": "application/json" }, method = "POST") =>
  new Request("http://x/auth/apple", { method, headers, body: method === "GET" ? undefined : typeof body === "string" ? body : JSON.stringify(body) });
const login = (over: Doc = {}) => post({ identityToken: jwt(), nonce: RAW, code: CODE, ...over });
const bearer = (token?: string, method = "POST", scheme = "Bearer") =>
  new Request("http://x/auth/logout", { method, headers: token === undefined ? {} : { authorization: `${scheme} ${token}` } });
const count = async (pool: pg.Pool, table: string) => Number((await pool.query(`SELECT count(*) FROM ${table}`)).rows[0].count);
async function assertEmpty(pool: pg.Pool, name: string) {
  for (const table of ["accounts", "sessions", "apple_tokens"]) assert.equal(await count(pool, table), 0, `${name}: ${table}`);
}

test("auth: rundweg anmelden", async (t) => {
  const pool = await migrated(t);
  for (const aud of IDS) {
    const { routes } = rig(pool, appleOk(`${SUB}.${aud}`, aud), { allowedSubs: new Set(IDS.map((id) => `${SUB}.${id}`)) } as Partial<AuthDeps>);
    const res = await routes["/auth/apple"](login({ identityToken: jwt({ sub: `${SUB}.${aud}` }, undefined, undefined, aud) }));
    assert.equal(res.status, 200);
    assert.equal(res.headers.get("cache-control"), "no-store");
    assert.match(res.headers.get("content-type") ?? "", /^application\/json/);
    const { sessionToken } = (await res.json()) as { sessionToken: string };
    assert.ok(typeof sessionToken === "string" && sessionToken !== "");
    const account = await resolveSession(pool, sessionToken);
    assert.equal(account, (await pool.query("SELECT id FROM accounts WHERE apple_sub = $1", [`${SUB}.${aud}`])).rows[0].id);
    const deletion = await deleteAccount(pool, account!);
    assert.equal(deletion.tokens.length, 1);
    assert.equal(decryptToken(config.tokenKey, account!, deletion.tokens[0].blob), REFRESH);
    assert.equal(deletion.tokens[0].clientId, aud);
  }
});

test("auth: zweite anmeldung ersetzt schluessel nur je client", async (t) => {
  const pool = await migrated(t);
  const signIn = async (aud: string, refresh: string) => {
    const answer = () => new Response(JSON.stringify({ refresh_token: refresh, id_token: jwt({}, undefined, undefined, aud) }), { status: 200 });
    const res = await rig(pool, answer).routes["/auth/apple"](login({ identityToken: jwt({}, undefined, undefined, aud) }));
    return ((await res.json()) as { sessionToken: string }).sessionToken;
  };
  const tokens = async () => (await pool.query("SELECT * FROM apple_tokens ORDER BY client_id")).rows;
  const a = await signIn(IDS[0], "ALT");
  const id = (await resolveSession(pool, a))!;
  const old = (await tokens())[0];
  await signIn(IDS[0], "NEU");
  const replaced = await tokens();
  assert.equal(replaced.length, 1, "dieselbe App-ID ersetzt");
  assert.notDeepEqual(replaced[0].refresh_token_enc, old.refresh_token_enc);
  assert.equal(decryptToken(config.tokenKey, id, replaced[0].refresh_token_enc), "NEU");

  const b = await signIn(IDS[1], "ANDERS");
  assert.equal(await resolveSession(pool, b), id);
  assert.equal(await count(pool, "accounts"), 1);
  const both = await tokens();
  assert.deepEqual(both.map((row: { client_id: string }) => row.client_id), IDS);
  assert.deepEqual(both[0], replaced[0], "die Zeile der ersten App-ID bleibt unberührt");
  assert.equal(decryptToken(config.tokenKey, id, both[1].refresh_token_enc), "ANDERS");
});

// #621 S6a: without a list only the first account gets in; a list admits whoever is on it.
test("auth: fremde sub wird abgewiesen, kein konto, keine sitzung, kein token", async (t) => {
  const pool = await migrated(t);
  const lines: string[] = [];
  const log = (event: string) => void lines.push(event);
  const stranger = `${SUB}.fremd`;
  const as = (sub: string) => login({ identityToken: jwt({ sub }) });

  const first = await rig(pool, appleOk(), { log }).routes["/auth/apple"](as(SUB));
  assert.equal(first.status, 200, "das Erstkonto");
  const res = await rig(pool, appleOk(stranger), { log }).routes["/auth/apple"](as(stranger));
  assert.equal(res.status, 401);
  assert.equal(res.headers.get("cache-control"), "no-store");
  const body = await res.text();
  assert.equal(body, "");
  assert.equal(await count(pool, "accounts"), 1);
  assert.equal((await pool.query("SELECT count(*)::int AS n FROM accounts WHERE apple_sub = $1", [stranger])).rows[0].n, 0);
  assert.equal(await count(pool, "sessions"), 1, "keine Sitzung für die fremde sub");
  assert.equal(await count(pool, "apple_tokens"), 1, "kein Token für die fremde sub");
  assert.deepEqual(lines, ["account refused"]);
  for (const text of [...lines, body, JSON.stringify([...res.headers])]) assert.ok(!text.includes(stranger), "sub in Antwort oder Protokoll");

  const both = { log, allowedSubs: new Set([SUB, stranger]) } as Partial<AuthDeps>;
  const admitted = await rig(pool, appleOk(stranger), both).routes["/auth/apple"](as(stranger));
  assert.equal(admitted.status, 200, "mit Listeneintrag");
  const { sessionToken } = (await admitted.json()) as { sessionToken: string };
  assert.notEqual(await resolveSession(pool, sessionToken), null);
  assert.equal(await count(pool, "accounts"), 2);
  assert.deepEqual(lines, ["account refused"]);
});

const BIG ="x".repeat(16 * 1024 + 1);
const JSON_H = { "content-type": "application/json" };
const INPUT: [string, () => Request, number][] = [
  ["GET", () => post("", JSON_H, "GET"), 405],
  ["PUT", () => post({}, JSON_H, "PUT"), 405],
  ["DELETE", () => post({}, JSON_H, "DELETE"), 405],
  ["text/plain", () => post({}, { "content-type": "text/plain" }), 415],
  ["ohne Content-Type", () => new Request("http://x/auth/apple", { method: "POST", body: "{}", headers: {} }), 415],
  ["16 KiB + 1", () => post(`{"code":"${BIG.slice(0, 16 * 1024 - 10)}"}`, JSON_H), 413],
  ["16 KiB + 1, Content-Length lügt", () => post(BIG, { ...JSON_H, "content-length": "10" }), 413],
  ["kein JSON", () => post("{kaputt", JSON_H), 400],
  ["Array", () => post("[]", JSON_H), 400],
  ["null", () => post("null", JSON_H), 400],
  ...["identityToken", "nonce", "code"].flatMap((f): [string, () => Request, number][] => [
    [`${f} fehlt`, () => { const b: Doc = { identityToken: jwt(), nonce: RAW, code: CODE }; delete b[f]; return post(b, JSON_H); }, 400],
    [`${f} leer`, () => login({ [f]: "" }), 400],
    [`${f} Zahl`, () => login({ [f]: 7 }), 400],
    [`${f} Objekt`, () => login({ [f]: {} }), 400],
  ]),
];

test("auth: eingabe abgelehnt, nichts angefasst", async (t) => {
  const pool = await migrated(t);
  const { r, routes } = rig(pool);
  for (const [name, request, status] of INPUT) {
    const res = await routes["/auth/apple"](request());
    assert.equal(res.status, status, name);
    assert.equal(await res.text(), "", name);
    if (status === 405) assert.equal(res.headers.get("allow"), "POST", name);
  }
  assert.equal(r.calls, 0);
  await assertEmpty(pool, "eingabe");
});

test("auth: identity-token abgelehnt", async (t) => {
  const pool = await migrated(t);
  const none = `${seg({ alg: "none", kid: "K1" })}.${seg({ sub: SUB })}.`;
  const rows: [string, string, number][] = [
    ["abgelaufen", jwt({ exp: SEC - 3600 }), 401],
    ["falsch signiert", jwt({}, undefined, otherRsa.privateKey), 401],
    ["falsches aud", jwt({}, undefined, undefined, "com.fremd.app"), 401],
    ["falsche Nonce", jwt({ nonce: "00" }), 401],
    ["alg none", none, 401],
    ["kaputt", "a.b", 401],
  ];
  for (const [name, token, status] of rows) {
    const { r, routes } = rig(pool);
    const res = await routes["/auth/apple"](login({ identityToken: token }));
    assert.equal(res.status, status, name);
    assert.equal(await res.text(), "", name);
    assert.equal(r.calls, 0, name);
  }
  const { r, routes } = rig(pool, appleOk(), { keys: async () => "keys_unavailable" });
  assert.equal((await routes["/auth/apple"](login())).status, 503);
  assert.equal(r.calls, 0);
  await assertEmpty(pool, "identity-token");
});

test("auth: einloesen scheitert, nichts abgelegt", async (t) => {
  const pool = await migrated(t);
  const rows: [string, Answer, number][] = [
    ["invalid_grant", appleError("invalid_grant"), 401],
    ["invalid_client", appleError("invalid_client"), 401],
    ["anderer Fehler", () => new Response("{}", { status: 500 }), 401],
    ["kaputter Body", () => new Response("<html>", { status: 200 }), 401],
    ["Netzfehler", () => { throw new Error("netz"); }, 503],
  ];
  for (const [name, answer, status] of rows) {
    const { r, routes } = rig(pool, answer);
    const res = await routes["/auth/apple"](login());
    assert.equal(res.status, status, name);
    assert.equal(await res.text(), "", name);
    assert.equal(r.calls, 1, name);
  }
  await assertEmpty(pool, "einloesen");
});

test("auth: sub weicht ab", async (t) => {
  const pool = await migrated(t);
  const { r, routes } = rig(pool, appleOk("anderes.sub"));
  const res = await routes["/auth/apple"](login());
  assert.equal(res.status, 401);
  assert.equal(r.calls, 1);
  await assertEmpty(pool, "sub");
});

// A pool whose first statement on apple_tokens first runs `before`, e.g. deleting the account or throwing.
function trapped(pool: pg.Pool, before: () => Promise<void>): pg.Pool {
  let armed = true;
  return new Proxy(pool, {
    get(target, prop) {
      if (prop !== "query") {
        const value = Reflect.get(target, prop, target);
        return typeof value === "function" ? value.bind(target) : value;
      }
      return async (...args: unknown[]) => {
        if (armed && String(args[0]).includes("apple_tokens")) { armed = false; await before(); }
        return (target.query as (...a: unknown[]) => Promise<unknown>)(...args);
      };
    },
  });
}

test("auth: createSession zuletzt", async (t) => {
  const pool = await migrated(t);
  const gone = rig(trapped(pool, async () => { await pool.query("DELETE FROM accounts"); })).routes;
  assert.equal((await gone["/auth/apple"](login())).status, 401);
  assert.equal(await count(pool, "sessions"), 0);
  const broken = rig(trapped(pool, async () => { throw new Error("db"); })).routes;
  await assert.rejects(broken["/auth/apple"](login()));
  assert.equal(await count(pool, "sessions"), 0);
});

test("auth: ohne apple-konfiguration", async (t) => {
  const pool = await migrated(t);
  const { r, routes } = rig(pool, appleOk(), { config: undefined });
  for (const request of [login(), post("", JSON_H, "GET"), post("{kaputt", JSON_H)]) {
    assert.equal((await routes["/auth/apple"](request)).status, 503);
  }
  const noKeys = rig(pool, appleOk(), { keys: undefined }).routes;
  assert.equal((await noKeys["/auth/apple"](login())).status, 503);
  const token = await createSession(pool, await findOrCreate(pool, SUB));
  assert.equal((await routes["/auth/logout"](bearer(token))).status, 204);
  assert.equal(r.calls, 0);
});

test("auth: abmelden", async (t) => {
  const pool = await migrated(t);
  const { routes } = rig(pool);
  const mine = await findOrCreate(pool, SUB);
  const [a, b] = [await createSession(pool, mine), await createSession(pool, mine)];
  const other = await createSession(pool, await findOrCreate(pool, "fremd"));
  assert.equal((await routes["/auth/logout"](bearer(a))).status, 204);
  assert.equal(await resolveSession(pool, a), null);
  assert.equal(await resolveSession(pool, b), mine);
  assert.notEqual(await resolveSession(pool, other), null);
  for (const token of [a, "unbekannt"]) {
    const res = await routes["/auth/logout"](bearer(token));
    assert.equal(res.status, 204);
    assert.equal(await res.text(), "");
  }
  assert.equal(await resolveSession(pool, b), mine);
  assert.equal((await routes["/auth/logout"](bearer(b, "POST", "bearer"))).status, 204);
  const refused: [string, Request][] = [
    ["ohne Header", bearer()], ["Basic", bearer(b, "POST", "Basic")], ["leer", bearer("")], ["zwei Token", bearer("a b")],
  ];
  for (const [name, request] of refused) assert.equal((await routes["/auth/logout"](request)).status, 401, name);
  for (const method of ["GET", "DELETE"]) assert.equal((await routes["/auth/logout"](bearer(other, method))).status, 405, method);
  assert.notEqual(await resolveSession(pool, other), null);
});

test("auth: bearerToken", () => {
  const request = (value?: string) => new Request("http://x/", { headers: value === undefined ? {} : { authorization: value } });
  const rows: [string | undefined, string | null][] = [
    ["Bearer abc", "abc"], ["bearer abc", "abc"], ["BEARER abc", "abc"],
    [undefined, null], ["Basic abc", null], ["Bearer", null], ["Bearer ", null], ["Bearer a b", null], ["Bearer  abc", null],
  ];
  for (const [value, expected] of rows) assert.equal(bearerToken(request(value)), expected, String(value));
});

test("auth: stille und einheitliche ablehnung", async (t) => {
  const pool = await migrated(t);
  const written: string[] = [];
  const { log, error, out, err } = { log: console.log, error: console.error, out: process.stdout.write, err: process.stderr.write };
  const grab = ((chunk: unknown) => { written.push(String(chunk)); return true; }) as typeof process.stdout.write;
  const refusals: [Request, Answer][] = [
    [login({ identityToken: jwt({ exp: SEC - 3600 }) }), appleOk()],
    [login({ identityToken: jwt({}, undefined, otherRsa.privateKey) }), appleOk()],
    [login(), appleError("invalid_grant")],
    [login(), appleOk("anderes.sub")],
  ];
  const seen: { status: number; headers: string; body: string }[] = [];
  process.stdout.write = grab; process.stderr.write = grab;
  console.log = console.error = (...a: unknown[]) => void written.push(a.join(" "));
  try {
    for (const [request, answer] of refusals) {
      const res = await rig(pool, answer).routes["/auth/apple"](request);
      seen.push({ status: res.status, headers: JSON.stringify([...res.headers]), body: await res.text() });
    }
    const { routes } = rig(pool);
    await routes["/auth/apple"](login());
    await routes["/auth/logout"](bearer("x"));
  } finally {
    Object.assign(console, { log, error });
    process.stdout.write = out; process.stderr.write = err;
  }
  assert.deepEqual(written, []);
  assert.equal(seen.length, 4);
  for (const s of seen) assert.deepEqual(s, { status: 401, headers: seen[0].headers, body: "" });
});

// Deleting (S3c-1): a member signs in through /auth/apple and carries a transcript and an answered order.
const REVOKE = "https://appleid.apple.com/auth/revoke";
const DATA = ["accounts", "sessions", "apple_tokens", "transcripts", "orders", "order_results"];
const LOG_WORDS = ["apple revoke skipped", "apple revoke failed"];
const revokes = (r: { urls: string[] }) => r.urls.filter((url) => url === REVOKE).length;
const ok200: Answer = () => new Response(null, { status: 200 });
const del = (token?: string, method = "POST", scheme = "Bearer") => bearer(token, method, scheme);

async function member(pool: pg.Pool, n: number, aud = IDS[0]) {
  const sub = `${SUB}.${n}`;
  const res = await rig(pool, appleOk(sub, aud), { allowedSubs: new Set([sub]) } as Partial<AuthDeps>)
    .routes["/auth/apple"](login({ identityToken: jwt({ sub }, undefined, undefined, aud) }));
  const { sessionToken } = (await res.json()) as { sessionToken: string };
  const id = (await resolveSession(pool, sessionToken))!;
  const order = `0b7d5e3c-0000-4000-8000-${String(n).padStart(12, "0")}`;
  const at = "2026-11-05T06:00:00Z";
  await pool.query("INSERT INTO transcripts (account_id, doc, generated_at) VALUES ($1, $2::jsonb, $3)", [id, JSON.stringify({ version: 1, generatedAt: at }), at]);
  await pool.query("INSERT INTO orders (doc, account_id) VALUES ($1::jsonb, $2)", [JSON.stringify({ version: 1, id: order, kind: "capture" }), id]);
  await pool.query("INSERT INTO order_results (doc, reported_by) VALUES ($1::jsonb, 'iphone')", [JSON.stringify({ orderID: order, outcome: "done" })]);
  return { id, token: sessionToken, sub };
}

// Rows per table of one account, in the order of DATA.
async function rows(pool: pg.Pool, id: string): Promise<number[]> {
  const result: number[] = [];
  for (const table of DATA) {
    const sql = table === "accounts" ? "SELECT count(*)::int AS n FROM accounts WHERE id = $1"
      : table === "order_results" ? "SELECT count(*)::int AS n FROM order_results r JOIN orders o ON o.id = r.order_id WHERE o.account_id = $1"
      : `SELECT count(*)::int AS n FROM ${table} WHERE account_id = $1`;
    result.push((await pool.query(sql, [id])).rows[0].n);
  }
  return result;
}
const totals = async (pool: pg.Pool) => Promise.all(DATA.map((table) => count(pool, table)));

// The delete route with fake Apple and the log lines it writes.
function deleter(pool: pg.Pool, answer: Answer = ok200, over: Partial<AuthDeps> = {}) {
  const lines: string[] = [];
  const { r, routes } = rig(pool, answer, { log: (event: string) => void lines.push(event), ...over } as Partial<AuthDeps>);
  return { r, lines, route: routes["/auth/delete"] };
}

// A pool whose first connect (the deletion's transaction) first runs `before`; the client is released if it throws.
function onConnect(pool: pg.Pool, before: () => Promise<void>): pg.Pool {
  let armed = true;
  return new Proxy(pool, {
    get(target, prop) {
      const value = Reflect.get(target, prop, target);
      if (prop !== "connect") return typeof value === "function" ? value.bind(target) : value;
      return async () => {
        const client = await target.connect();
        if (armed) {
          armed = false;
          try { await before(); } catch (error) { client.release(); throw error; }
        }
        return client;
      };
    },
  });
}

// S4c-1: the web sign-in's token beside the app's, stored as the return way will store it (4c-2).
const WEB = "com.henning.looseends.web";
const WEB_REFRESH = "GEHEIM-WEB-REFRESH";
const webConfig: AppleConfig = { ...config, webClientId: WEB };
async function withWeb(pool: pg.Pool, id: string, clientId = WEB): Promise<void> {
  assert.equal(await storeRefreshToken(pool, id, encryptToken(config.tokenKey, id, WEB_REFRESH), clientId), true);
}
// A blob of the agreed format holding the empty string, which encryptToken refuses to build.
function sealedEmpty(id: string): Buffer {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", config.tokenKey, iv, { authTagLength: 16 });
  cipher.setAAD(Buffer.from(id));
  const ct = Buffer.concat([cipher.update("", "utf8"), cipher.final()]);
  return Buffer.concat([Buffer.from([0x01]), iv, cipher.getAuthTag(), ct]);
}

test("auth: rundweg loeschen", async (t) => {
  const pool = await migrated(t);
  const me = await member(pool, 1);
  const res = await deleter(pool).route(del(me.token));
  assert.equal(res.status, 204);
  assert.equal(await res.text(), "");
  assert.deepEqual(await rows(pool, me.id), [0, 0, 0, 0, 0, 0]);
  assert.equal(await resolveSession(pool, me.token), null);
});

test("auth: loeschen widerruft einmal", async (t) => {
  const pool = await migrated(t);
  const me = await member(pool, 1, IDS[1]);
  const seen = { accounts: -1, answered: false };
  const d = deleter(pool, async () => {
    seen.accounts = await count(pool, "accounts");
    seen.answered = true;
    return new Response(null, { status: 200 });
  });
  assert.equal((await d.route(del(me.token))).status, 204);
  assert.equal(seen.answered, true, "der Widerruf ist vor der Antwort fertig");
  assert.equal(seen.accounts, 0, "beim Widerruf ist das Konto schon weg");
  assert.deepEqual(d.r.urls, [REVOKE]);
  assert.equal(d.r.forms[0].get("token"), REFRESH);
  assert.equal(d.r.forms[0].get("client_id"), IDS[1]);
  assert.equal(d.r.forms[0].get("token_type_hint"), "refresh_token");
  assert.deepEqual(d.lines, []);
});

test("auth: loeschen beruehrt kein anderes konto", async (t) => {
  const pool = await migrated(t);
  const [me, other] = [await member(pool, 1), await member(pool, 2)];
  const second = await createSession(pool, me.id);
  assert.equal((await deleter(pool).route(del(me.token))).status, 204);
  assert.equal(await resolveSession(pool, second), null);
  assert.deepEqual(await rows(pool, other.id), [1, 1, 1, 1, 1, 1]);
  assert.equal(await resolveSession(pool, other.token), other.id);
});

test("auth: loeschen abgelehnt, nichts angefasst", async (t) => {
  const pool = await migrated(t);
  const me = await member(pool, 1);
  const ended = await createSession(pool, me.id);
  await endSession(pool, ended);
  const refused: [string, () => Request, number][] = [
    ...["GET", "PUT", "DELETE"].map((m): [string, () => Request, number] => [m, () => del(me.token, m), 405]),
    ["ohne Header", () => del(), 401], ["Basic", () => del(me.token, "POST", "Basic"), 401], ["leer", () => del(""), 401],
    ["zwei Token", () => del(`${me.token} ${me.token}`), 401], ["unbekannt", () => del("unbekannt"), 401],
    ["beendet", () => del(ended), 401], ["erfunden", () => del(randomBytes(32).toString("base64url")), 401],
  ];
  const before = await totals(pool);
  for (const [name, request, code] of refused) {
    const d = deleter(pool);
    const res = await d.route(request());
    assert.equal(res.status, code, name);
    assert.equal(await res.text(), "", name);
    if (code === 405) assert.equal(res.headers.get("allow"), "POST", name);
    assert.equal(d.r.calls, 0, name);
    assert.deepEqual(d.lines, [], name);
    assert.deepEqual(await totals(pool), before, name);
  }
});

test("auth: loeschen rennen", async (t) => {
  const pool = await migrated(t);
  const me = await member(pool, 1);
  const d = deleter(onConnect(pool, async () => { await pool.query("DELETE FROM accounts WHERE id = $1", [me.id]); }));
  const res = await d.route(del(me.token));
  assert.equal(res.status, 401);
  assert.equal(await res.text(), "");
  assert.equal(revokes(d.r), 0);
  assert.deepEqual(d.lines, []);
});

test("auth: zwei loeschungen gleichzeitig", async (t) => {
  const pool = await migrated(t);
  const me = await member(pool, 1);
  const d = deleter(pool);
  const answers = await Promise.all([d.route(del(me.token)), d.route(del(me.token))]);
  assert.deepEqual(answers.map((a) => a.status).sort(), [204, 401]);
  assert.equal(await count(pool, "accounts"), 0);
  assert.equal(revokes(d.r), 1);
});

test("auth: loeschen widerruft app und web token je mit eigener client_id", async (t) => {
  const pool = await migrated(t);
  const me = await member(pool, 1);
  await withWeb(pool, me.id);
  const seen: number[] = [];
  const d = deleter(pool, async () => {
    seen.push(await count(pool, "accounts"));
    return new Response(null, { status: 200 });
  }, { config: webConfig });
  const res = await d.route(del(me.token));
  assert.equal(res.status, 204);
  assert.equal(await res.text(), "");
  assert.deepEqual(await rows(pool, me.id), [0, 0, 0, 0, 0, 0]);
  assert.deepEqual(d.r.urls, [REVOKE, REVOKE]);
  assert.deepEqual(seen, [0, 0], "beim Widerruf ist das Konto schon weg");
  // Sorted by client_id: the app id before the web id, each with its own token.
  assert.deepEqual(d.r.forms.map((f) => [f.get("client_id"), f.get("token")]), [[IDS[0], REFRESH], [WEB, WEB_REFRESH]]);
  for (const form of d.r.forms) assert.equal(form.get("token_type_hint"), "refresh_token");
  assert.deepEqual(d.lines, []);
});

test("auth: ein widerruf scheitert, der andere laeuft, 204 und genau ein failed", async (t) => {
  const pool = await migrated(t);
  const failures: [string, Answer][] = [["invalid_grant", appleError("invalid_grant")], ["Netz weg", () => { throw new Error("netz"); }]];
  let n = 0;
  for (const [name, failure] of failures) {
    for (const failing of [1, 2]) {
      const me = await member(pool, ++n);
      await withWeb(pool, me.id);
      const d = deleter(pool, ok200, { config: webConfig });
      d.r.answer = () => (d.r.calls === failing ? failure() : ok200());
      const res = await d.route(del(me.token));
      const label = `${name}, Zeile ${failing}`;
      assert.equal(res.status, 204, label);
      assert.equal(revokes(d.r), 2, label);
      assert.deepEqual(d.r.forms.map((f) => f.get("client_id")), [IDS[0], WEB], label);
      assert.deepEqual(await rows(pool, me.id), [0, 0, 0, 0, 0, 0], label);
      assert.deepEqual(d.lines, ["apple revoke failed"], label);
    }
  }
});

test("auth: web token ohne webClientId wird uebersprungen ohne netz", async (t) => {
  const pool = await migrated(t);
  const me = await member(pool, 1);
  await withWeb(pool, me.id);
  const d = deleter(pool, ok200, { config });
  const res = await d.route(del(me.token));
  assert.equal(res.status, 204);
  assert.equal(revokes(d.r), 1);
  assert.equal(d.r.forms[0].get("client_id"), IDS[0]);
  assert.equal(d.r.forms[0].get("token"), REFRESH);
  assert.deepEqual(d.lines, ["apple revoke skipped"]);
  assert.deepEqual(await rows(pool, me.id), [0, 0, 0, 0, 0, 0]);
});

test("auth: zwei loeschungen gleichzeitig mit zwei tokens, widerrufe nur einmal", async (t) => {
  const pool = await migrated(t);
  const me = await member(pool, 1);
  await withWeb(pool, me.id);
  const second = await createSession(pool, me.id);
  const d = deleter(pool, ok200, { config: webConfig });
  const answers = await Promise.all([d.route(del(me.token)), d.route(del(second))]);
  assert.deepEqual(answers.map((a) => a.status).sort(), [204, 401]);
  assert.equal(await count(pool, "accounts"), 0);
  assert.equal(await count(pool, "apple_tokens"), 0);
  assert.equal(revokes(d.r), 2);
  assert.deepEqual(d.r.forms.map((f) => f.get("client_id")), [IDS[0], WEB]);
});

test("auth: widerruf scheitert, konto weg", async (t) => {
  const pool = await migrated(t);
  const failures: [string, (r: { signals: AbortSignal[] }) => Answer][] = [
    ["Netz weg", () => () => { throw new Error("netz"); }],
    ["invalid_grant", () => appleError("invalid_grant")],
    ["Zeitüberschreitung", (r) => () => new Promise<Response>((_, reject) => {
      const signal = r.signals.at(-1)!;
      signal.addEventListener("abort", () => reject(signal.reason));
    })],
  ];
  for (const [i, [name, answer]] of failures.entries()) {
    const me = await member(pool, i + 1);
    const d = deleter(pool);
    d.r.answer = answer(d.r);
    const res = await d.route(del(me.token));
    assert.equal(res.status, 204, name);
    assert.deepEqual(await rows(pool, me.id), [0, 0, 0, 0, 0, 0], name);
    assert.equal(revokes(d.r), 1, name);
    assert.deepEqual(d.lines, ["apple revoke failed"], name);
  }
});

test("auth: widerruf entfaellt je zeile, keine zeile genau ein skipped", async (t) => {
  const pool = await migrated(t);
  const onlyRow = (id: string, blob: Buffer) => pool.query(
    "UPDATE apple_tokens SET refresh_token_enc = $2 WHERE account_id = $1", [id, blob],
  );
  // Name, deps, preparation, expected revokes; the log is one "skipped" in every case.
  const cases: [string, Partial<AuthDeps>, (id: string) => Promise<unknown>, number][] = [
    ["client_id nicht mehr konfiguriert", { config: { ...config, clientIds: ["com.example.other"] } }, async () => {}, 0],
    ["anderer tokenKey", { config: { ...config, tokenKey: randomBytes(32) } }, async () => {}, 0],
    ["App-Zeile und unbekannte Zeile", {}, (id) => withWeb(pool, id, "com.example.unknown"), 1],
    ["leerer Klartext", {}, (id) => onlyRow(id, sealedEmpty(id)), 0],
    ["keine apple_tokens-Zeile", {}, (id) => pool.query("DELETE FROM apple_tokens WHERE account_id = $1", [id]), 0],
    ["ohne config und keys", { config: undefined, keys: undefined }, async () => {}, 0],
  ];
  for (const [i, [name, over, prepare, expected]] of cases.entries()) {
    const me = await member(pool, i + 1);
    await prepare(me.id);
    const d = deleter(pool, ok200, over);
    const res = await d.route(del(me.token));
    assert.equal(res.status, 204, name);
    assert.deepEqual(await rows(pool, me.id), [0, 0, 0, 0, 0, 0], name);
    assert.equal(d.r.calls, expected, name);
    if (expected === 1) assert.equal(d.r.forms[0].get("client_id"), IDS[0], name);
    assert.deepEqual(d.lines, ["apple revoke skipped"], name);
  }
});

test("auth: log ohne geheimnisse", async (t) => {
  const pool = await migrated(t);
  const secrets: string[] = [REFRESH, WEB_REFRESH, CODE, "invalid_grant", "netz", WEB, ...IDS];
  const lines: string[] = [];
  // The last three runs carry an app and a web token, each row writes its own line.
  const runs: [Answer, Partial<AuthDeps>, boolean][] = [
    [appleError("invalid_grant"), {}, false], [() => { throw new Error("netz"); }, {}, false], [ok200, { config: undefined }, false],
    [appleError("invalid_grant"), { config: webConfig }, true], [() => { throw new Error("netz"); }, { config: webConfig }, true],
    [ok200, { config: undefined }, true],
  ];
  for (const [i, [answer, over, web]] of runs.entries()) {
    for (const [j, log] of [undefined, (event: string) => void lines.push(event)].entries()) {
      const me = await member(pool, 10 * i + j + 1);
      if (web) await withWeb(pool, me.id);
      secrets.push(me.id, me.token, me.sub);
      const res = await rig(pool, answer, { ...over, log } as Partial<AuthDeps>).routes["/auth/delete"](del(me.token));
      assert.equal(res.status, 204);
    }
  }
  const [skipped, failed] = LOG_WORDS;
  assert.deepEqual(lines, [failed, failed, skipped, failed, failed, failed, failed, skipped, skipped]);
  for (const line of lines) {
    assert.ok(LOG_WORDS.includes(line), line);
    for (const secret of secrets) assert.ok(!line.includes(secret), `Logzeile enthält ${secret}`);
  }
});

test("auth: stille und einheitliche ablehnung loeschen", async (t) => {
  const pool = await migrated(t);
  const written: string[] = [];
  const { log, error, out, err } = { log: console.log, error: console.error, out: process.stdout.write, err: process.stderr.write };
  const grab = ((chunk: unknown) => { written.push(String(chunk)); return true; }) as typeof process.stdout.write;
  const [a, b, c] = [await member(pool, 1), await member(pool, 2), await member(pool, 3)];
  const seen: { status: number; headers: string; body: string }[] = [];
  process.stdout.write = grab; process.stderr.write = grab;
  console.log = console.error = (...x: unknown[]) => void written.push(x.join(" "));
  try {
    for (const request of [del(), del(a.token, "POST", "Basic"), del("unbekannt"), del("a b")]) {
      const res = await deleter(pool).route(request);
      seen.push({ status: res.status, headers: JSON.stringify([...res.headers]), body: await res.text() });
    }
    await deleter(pool).route(del(a.token));
    await deleter(pool, appleError("invalid_grant")).route(del(b.token));
    await deleter(pool, ok200, { config: undefined }).route(del(c.token));
  } finally {
    Object.assign(console, { log, error });
    process.stdout.write = out; process.stderr.write = err;
  }
  assert.deepEqual(written, []);
  assert.equal(seen.length, 4);
  for (const s of seen) assert.deepEqual(s, { status: 401, headers: seen[0].headers, body: "" });
  assert.doesNotMatch(readFileSync(join(import.meta.dirname, "../src/auth.ts"), "utf8"), /console|process\.(stdout|stderr)/);
});

test("auth: loeschen datenbankfehler", async (t) => {
  const pool = await migrated(t);
  const me = await member(pool, 1);
  const d = deleter(onConnect(pool, async () => { throw new Error("db"); }));
  const schema = (await pool.query("SELECT current_schema() AS s")).rows[0].s as string;
  const url = new URL(process.env.DATABASE_URL!);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const running = await start({ databaseUrl: url.toString(), port: 0, migrationsDir: migrations, extraRoutes: { "/auth/delete": d.route } });
  try {
    await running.ready;
    const res = await fetch(`${running.url}/auth/delete`, { method: "POST", headers: { authorization: `Bearer ${me.token}` } });
    assert.equal(res.status, 500);
    assert.equal(await res.text(), "");
  } finally {
    await running.close();
  }
  assert.deepEqual(d.lines, []);
  assert.equal(revokes(d.r), 0);
  assert.equal(await resolveSession(pool, me.token), me.id);
});
