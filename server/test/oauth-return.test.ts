import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, randomBytes, randomUUID, sign } from "node:crypto";
import http from "node:http";
import { join } from "node:path";
import pg from "pg";
import { deleteAccount } from "../src/accounts.ts";
import { loadAppleConfig } from "../src/apple.ts";
import { createJwks } from "../src/apple-jwks.ts";
import { start } from "../src/main.ts";
import { PgAdapter } from "../src/oauth-adapter.ts";
import { oauthKeysFromEnv } from "../src/oauth-provider.ts";

// Schnitt 4b-2a of #621: Apple's form_post comes back, is checked strictly and ends in a one-time ticket and a 303 to finish.
// The whole path runs through the real issuer and a throwaway Postgres; only Apple is faked. finish itself is S4b-2b.

type Doc = Record<string, any>;
type T = { after: (fn: () => Promise<void>) => void; mock: any };

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
const migrations = join(import.meta.dirname, "../migrations");
const ORIGIN = "https://loose-ends.test";
const CID = "https://claude.ai/oauth/test-client";
const CB = "https://claude.ai/api/mcp/auth_callback";
const WEB = "com.henning.looseends.web";
const APP = "com.henning.looseends";
const KEYS_URL = "https://appleid.apple.com/auth/keys";
const REVOKE_URL = "https://appleid.apple.com/auth/revoke";
const RETURN = "/oauth/apple/return";
const PROXY = { host: "loose-ends.test", "x-forwarded-proto": "https" };
const FORM = { "content-type": "application/x-www-form-urlencoded" };
const REFRESH = "REFRESH-RUECK-4711";
const CODE = "CODE-RUECK-4711";
const BAD = "bad request";

const returnModule = () => import("../src/oauth-return.ts" as string) as Promise<Doc>;
const COOKIE_KEY = `geheim-cookie-schluessel-${randomBytes(16).toString("hex")}`;
const ES256 = generateKeyPairSync("ec", { namedCurve: "P-256" });
const keys = oauthKeysFromEnv({ OAUTH_COOKIE_KEYS: COOKIE_KEY, OAUTH_SIGNING_JWK: JSON.stringify(ES256.privateKey.export({ format: "jwk" })) })!;
const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const foreign = generateKeyPairSync("rsa", { modulusLength: 2048 });
const JWK = { ...rsa.publicKey.export({ format: "jwk" }), kid: "R1", alg: "RS256", use: "sig" };
const ENV = {
  APPLE_TEAM_ID: "TEAMRUE001", APPLE_KEY_ID: "KEYRUE0001", APPLE_CLIENT_IDS: APP,
  APPLE_PRIVATE_KEY: (generateKeyPairSync("ec", { namedCurve: "P-256" }).privateKey.export({ type: "pkcs8", format: "pem" }) as string).replace(/\n/g, "\\n"),
  APPLE_TOKEN_KEY: randomBytes(32).toString("base64"),
};
const appOnly = loadAppleConfig(ENV);
const withWeb = loadAppleConfig({ ...ENV, APPLE_WEB_CLIENT_ID: WEB });

const cimdFetch = (async (input: string | URL | Request) => {
  const url = String(input instanceof Request ? input.url : input);
  if (url !== CID) return new Response("not found", { status: 404 });
  return Response.json({ client_id: CID, client_name: "Claude", redirect_uris: [CB], token_endpoint_auth_method: "none",
    grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] });
}) as typeof fetch;

const seg = (x: unknown) => Buffer.from(JSON.stringify(x)).toString("base64url");
const shaHex = (value: string) => createHash("sha256").update(value).digest("hex");
const sha = (value: string) => createHash("sha256").update(value).digest();
type Over = { nonce?: string; aud?: string; iss?: string; sub?: string | null; alg?: string; key?: any; exp?: number };

// Fake Apple: keys, token endpoint (replaceable), revoke; counts every call. The token's nonce is the current attempt's.
function fakeApple() {
  const a = {
    nonce: "", sub: "apple-sub-1", forms: [] as URLSearchParams[], keyCalls: 0, revokes: 0, keysDown: false,
    token: undefined as undefined | ((form: URLSearchParams) => Response | Promise<Response>),
    id(over: Over = {}): string {
      const now = Math.floor(Date.now() / 1000);
      const claims: Doc = { iss: over.iss ?? "https://appleid.apple.com", aud: over.aud ?? WEB, iat: now, exp: over.exp ?? now + 600, nonce: over.nonce ?? shaHex(a.nonce) };
      if (over.sub !== null) claims.sub = over.sub ?? a.sub;
      const data = `${seg({ alg: over.alg ?? "RS256", kid: "R1" })}.${seg(claims)}`;
      return `${data}.${sign("sha256", Buffer.from(data), over.key ?? rsa.privateKey).toString("base64url")}`;
    },
    fetch: (async (input: string | URL, init?: RequestInit) => {
      const url = String(input);
      if (url === KEYS_URL) { a.keyCalls++; return a.keysDown ? new Response("down", { status: 500 }) : Response.json({ keys: [JWK] }); }
      if (url === REVOKE_URL) { a.revokes++; return new Response("", { status: 200 }); }
      const form = new URLSearchParams(String(init?.body));
      a.forms.push(form);
      return a.token ? a.token(form) : Response.json({ refresh_token: REFRESH, id_token: a.id({ aud: form.get("client_id") ?? WEB }) });
    }) as unknown as typeof globalThis.fetch,
  };
  return a;
}
type Apple = ReturnType<typeof fakeApple>;

const clock = () => { const c = { offset: 0, now: () => Date.now() + c.offset }; return c; };

// Each service gets its own schema; ret replaces the return handler (AC-13, AC-18), built from the pool the test gets back.
async function service(t: T, options: { auth?: Doc; interaction?: any; ret?: (pool: () => pg.Pool) => any; now?: () => number } = {}) {
  const admin = new pg.Pool({ connectionString: databaseUrl });
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  await admin.query(`CREATE SCHEMA ${schema}`);
  const parsed = new URL(databaseUrl!);
  parsed.searchParams.set("options", `-c search_path=${schema}`);
  let pool: pg.Pool | undefined;
  const appleReturn = options.ret?.(() => pool!);
  const running = await start({ databaseUrl: parsed.toString(), port: 0, migrationsDir: migrations, now: options.now,
    applicationName: `le-rue-${randomUUID().slice(0, 8)}`, auth: options.auth as never,
    oauth: { publicUrl: ORIGIN, keys, fetch: cimdFetch, ...(options.interaction ? { interaction: options.interaction } : {}), ...(appleReturn ? { appleReturn } : {}) } as never });
  pool = new pg.Pool({ connectionString: parsed.toString() });
  t.after(async () => { await running.close(); await pool!.end(); await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  await running.ready;
  return { ...running, pool };
}
type Running = Awaited<ReturnType<typeof service>>;
const withApple = (t: T, apple: Apple, more: Doc = {}) => service(t, { auth: { config: withWeb, fetch: apple.fetch }, ...more });

type Raw = { status: number; headers: http.IncomingHttpHeaders; body: string };
function raw(url: string, path: string, options: { method?: string; headers?: Record<string, string>; body?: string; chunks?: string[] } = {}): Promise<Raw> {
  return new Promise((done, fail) => {
    const request = http.request(`${url}${path}`, { method: options.method ?? "GET", headers: { ...PROXY, ...options.headers } }, (answer) => {
      let body = "";
      answer.setEncoding("utf8");
      answer.on("data", (chunk) => { body += chunk; });
      answer.on("end", () => done({ status: answer.statusCode!, headers: answer.headers, body }));
    });
    request.on("error", fail);
    for (const chunk of options.chunks ?? []) request.write(chunk);
    request.end(options.body);
  });
}
const cookiesOf = (answer: Raw) => [answer.headers["set-cookie"] ?? []].flat().map((line) => line.split(";")[0]).join("; ");
const form = (pairs: [string, string][]) => new URLSearchParams(pairs).toString();
const post = (url: string, body: string, headers: Record<string, string> = FORM) => raw(url, RETURN, { method: "POST", body, headers });
const countOf = async (pool: pg.Pool, table: string, where = "true") => Number((await pool.query(`SELECT count(*) FROM ${table} WHERE ${where}`)).rows[0].count);

// Values of the whole file: only fixed event names may reach the output, never one of these (AC-17).
const secrets = new Set<string>([COOKIE_KEY, WEB, REFRESH, CODE]);
const lines: string[] = [];
const restore: (() => void)[] = [];
before(() => {
  for (const stream of [process.stdout, process.stderr]) {
    const write = stream.write.bind(stream);
    (stream as Doc).write = (chunk: unknown, ...rest: any[]) => {
      if (typeof chunk === "string") lines.push(...chunk.split("\n").filter(Boolean));
      return write(chunk as never, ...rest);
    };
    restore.push(() => { (stream as Doc).write = write; });
  }
});
const EVENT = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z (oauth return refused|oauth return store failed|oauth interaction refused|oauth interaction store failed|oauth server error|oauth error|pool error|pool end failed|mcp close failed)$/;
function assertQuiet() {
  for (const line of lines) {
    assert.match(line, EVENT, `kein festes Ereignis: ${line.slice(0, 160)}`);
    for (const secret of secrets) assert.ok(!line.includes(secret), `Wert im Log: ${line.slice(0, 160)}`);
  }
}
after(() => { for (const undo of restore.reverse()) undo(); });
const note = (...values: (string | null | undefined)[]) => { for (const value of values) if (value) secrets.add(value); };

// /oauth/auth with PKCE up to the issuer's interaction, then the Hinweg to Apple: state, the raw nonce, uid and cookie.
async function hinweg(running: Running, apple: Apple) {
  const challenge = createHash("sha256").update(randomBytes(32).toString("base64url")).digest("base64url");
  const query = new URLSearchParams({ client_id: CID, redirect_uri: CB, response_type: "code", scope: "tasks offline_access",
    state: "s1", resource: `${ORIGIN}/mcp`, code_challenge: challenge, code_challenge_method: "S256" });
  const auth = await raw(running.url, `/oauth/auth?${query}`);
  const path = new URL(String(auth.headers.location), ORIGIN).pathname;
  assert.ok(path.startsWith("/oauth/interaction/"), `keine Interaktion: ${auth.status} ${auth.body.slice(0, 160)}`);
  const cookie = cookiesOf(auth);
  const to = await raw(running.url, path, { headers: { cookie } });
  assert.equal(to.status, 303, `Hinweg: ${to.status} ${to.body.slice(0, 160)}`);
  const state = new URL(String(to.headers.location)).searchParams.get("state")!;
  const uid = path.split("/").at(-1)!;
  const row = (await running.pool.query("SELECT payload FROM oauth_records WHERE model = 'AppleLogin' AND uid = $1", [uid])).rows[0];
  apple.nonce = row.payload.nonce;
  note(state, uid, row.payload.nonce, ...cookie.split("; ").map((pair) => pair.split("=")[1]));
  return { uid, state, cookie, nonce: row.payload.nonce as string };
}
// One full Hinweg and Rückweg; the answer and where it started.
async function through(running: Running, apple: Apple, extra: [string, string][] = [["code", CODE]]) {
  const at = await hinweg(running, apple);
  const answer = await post(running.url, form([["state", at.state], ...extra]));
  return { at, answer };
}
// 303 to finish with a ticket; returns the ticket.
function ticketOf(answer: Raw, at: { uid: string }, name = "ticket"): string {
  assert.equal(answer.status, 303, `${name}: ${answer.status} ${answer.body.slice(0, 160)}`);
  const url = new URL(String(answer.headers.location));
  assert.equal(url.origin, ORIGIN, name);
  assert.equal(url.pathname, `/oauth/interaction/${at.uid}/finish`, name);
  assert.deepEqual([...url.searchParams.keys()], ["ticket"], name);
  const ticket = url.searchParams.get("ticket")!;
  assert.match(ticket, /^[A-Za-z0-9_-]{43,}$/, name);
  assert.equal(answer.headers["cache-control"], "no-store", name);
  assert.equal(answer.headers["referrer-policy"], "no-referrer", name);
  assert.equal(answer.body, "", name);
  note(ticket);
  return ticket;
}
async function ticketRow(pool: pg.Pool, ticket: string): Promise<Doc> {
  const row = (await pool.query("SELECT * FROM oauth_records WHERE model = 'AppleTicket' AND id_hash = $1", [sha(ticket)])).rows[0];
  assert.ok(row, "Ticket nicht abgelegt");
  return row;
}
function assertFixed(answer: Raw, status: number, body: string, name: string) {
  assert.equal(answer.status, status, `${name}: ${answer.status} ${answer.body.slice(0, 160)}`);
  assert.equal(answer.body, body, name);
  assert.equal(answer.headers["cache-control"], "no-store", name);
  assert.equal(answer.headers.location, undefined, `${name}: Weiterleitung`);
}
const nothingMade = async (pool: pg.Pool, apple: Apple, name: string) => {
  assert.equal(await countOf(pool, "oauth_records", "model = 'AppleTicket'"), 0, `${name}: Ticket`);
  assert.equal(await countOf(pool, "accounts"), 0, `${name}: Konto`);
  assert.equal(apple.forms.length, 0, `${name}: Aufruf an Apple`);
};

test("rueckweg: erfolg ergibt 303 auf finish mit ticket und legt konto an", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const { at, answer } = await through(running, apple);
  ticketOf(answer, at, "erfolg");
  const accounts = (await running.pool.query("SELECT apple_sub FROM accounts")).rows;
  assert.deepEqual(accounts.map((r) => r.apple_sub), ["apple-sub-1"]);
  assert.equal(apple.forms.length, 1);
  const [sent] = apple.forms;
  assert.equal(sent.get("client_id"), WEB);
  assert.equal(sent.get("redirect_uri"), `${ORIGIN}${RETURN}`);
  assert.equal(sent.get("grant_type"), "authorization_code");
  assert.equal(sent.get("code"), CODE);
});

test("rueckweg: ticket gehasht, gebunden, 60 sekunden, einmalig", async (t) => {
  const c = clock();
  const apple = fakeApple();
  const running = await withApple(t, apple, { now: c.now });
  const first = await through(running, apple);
  const ticket = ticketOf(first.answer, first.at);
  const row = await ticketRow(running.pool, ticket);
  const accountId = (await running.pool.query("SELECT id FROM accounts")).rows[0].id;
  assert.equal(row.uid, first.at.uid);
  assert.equal(row.account_id, accountId);
  assert.deepEqual(Object.keys(row.payload).sort(), ["accountId", "uid"]);
  assert.deepEqual(row.payload, { uid: first.at.uid, accountId });
  assert.ok(row.expires_at.getTime() <= c.now() + 60_000 && row.expires_at.getTime() > c.now(), "Ablauf nicht innerhalb 60 s");
  assert.ok(!JSON.stringify(row).includes(ticket), "Ticket im Klartext");
  const adapter = new PgAdapter(running.pool, "AppleTicket", () => new Date(c.now()));
  assert.deepEqual({ ...(await adapter.find(ticket)), jti: undefined }, { uid: first.at.uid, accountId, jti: undefined });
  await adapter.consume(ticket);
  await assert.rejects(adapter.consume(ticket), "zweites consume gelang");
  c.offset = 61_000;
  assert.equal(await adapter.find(ticket), undefined, "nach Ablauf sichtbar");
  c.offset = 0;
  const second = await through(running, apple);
  assert.notEqual(ticketOf(second.answer, second.at), ticket);
});

test("rueckweg: replay desselben state wird abgelehnt", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const { at, answer } = await through(running, apple);
  ticketOf(answer, at);
  assertFixed(await post(running.url, form([["state", at.state], ["code", CODE]])), 400, BAD, "replay");
  assert.equal(await countOf(running.pool, "oauth_records", "model = 'AppleTicket'"), 1);
  assert.equal(await countOf(running.pool, "accounts"), 1);
  assert.equal(apple.forms.length, 1);
});

test("rueckweg: unbekanntes fremdes oder abgelaufenes state wird abgelehnt", async (t) => {
  const c = clock();
  const apple = fakeApple();
  const running = await withApple(t, apple, { now: c.now });
  const done = await through(running, apple);
  const ticket = ticketOf(done.answer, done.at);
  const accounts = await countOf(running.pool, "accounts");
  const calls = apple.forms.length;
  for (const [name, state] of [["unbekannt", randomBytes(32).toString("base64url")], ["ticket als state", ticket]] as const) {
    assertFixed(await post(running.url, form([["state", state], ["code", CODE]])), 400, BAD, name);
  }
  const old = await hinweg(running, apple);
  c.offset = 601_000;
  assertFixed(await post(running.url, form([["state", old.state], ["code", CODE]])), 400, BAD, "abgelaufen");
  assert.equal(await countOf(running.pool, "oauth_records", "model = 'AppleTicket'"), 1, "weiteres Ticket");
  assert.equal(await countOf(running.pool, "accounts"), accounts);
  assert.equal(apple.forms.length, calls, "Aufruf an Apple");
});

test("rueckweg: uebergroesse wird beim lesen gezaehlt abgelehnt", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const at = await hinweg(running, apple);
  const big = (size: number) => `x=${"a".repeat(size - 2)}`;
  const over = [["mit Länge", await raw(running.url, RETURN, { method: "POST", headers: FORM, body: big(16 * 1024 + 1) })],
    ["ohne Länge", await raw(running.url, RETURN, { method: "POST", headers: FORM, chunks: [big(10_000)], body: big(6385) })]] as const;
  for (const [name, answer] of over) {
    assert.equal(answer.status, 413, name);
    assert.equal(answer.body, "", name);
    assert.equal(answer.headers.connection, "close", name);
    assert.equal(answer.headers["cache-control"], "no-store", name);
  }
  assertFixed(await post(running.url, big(16 * 1024)), 400, BAD, "genau 16 KiB");
  assert.equal(apple.forms.length, 0);
  ticketOf(await post(running.url, form([["state", at.state], ["code", CODE]])), at, "state unverbraucht");
});

test("rueckweg: falsche methode und falscher inhaltstyp", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const at = await hinweg(running, apple);
  const body = form([["state", at.state], ["code", CODE]]);
  for (const method of ["GET", "PUT", "DELETE"]) {
    const answer = await raw(running.url, RETURN, { method });
    assert.equal(answer.status, 405, method);
    assert.equal(answer.headers.allow, "POST", method);
    assert.equal(answer.body, "", method);
  }
  for (const [name, headers] of [["json", { "content-type": "application/json" }], ["text", { "content-type": "text/plain" }], ["ohne", {}]] as const) {
    const answer = await post(running.url, body, headers);
    assert.equal(answer.status, 415, name);
    assert.equal(answer.body, "", name);
  }
  assert.equal(apple.forms.length, 0);
  ticketOf(await post(running.url, body, { "content-type": "application/x-www-form-urlencoded; charset=utf-8" }), at, "charset");
});

test("rueckweg: fehlende und doppelte felder ergeben 400", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const at = await hinweg(running, apple);
  const s: [string, string] = ["state", at.state];
  const c: [string, string] = ["code", CODE];
  const cases: [string, [string, string][]][] = [
    ["ohne state", [c]], ["zwei state", [s, s, c]], ["leerer state", [["state", ""], c]], ["zwei code", [s, c, c]],
    ["zwei error", [s, ["error", "a"], ["error", "b"]]], ["code und error", [s, c, ["error", "a"]]], ["weder noch", [s]], ["leer", []],
  ];
  for (const [name, pairs] of cases) assertFixed(await post(running.url, form(pairs)), 400, BAD, name);
  await nothingMade(running.pool, apple, "felder");
  ticketOf(await post(running.url, form([s, c])), at, "state unverbraucht");
});

test("rueckweg: feld user wird ignoriert", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const users = [JSON.stringify({ name: { firstName: "Maxine", lastName: "Mustermensch" }, email: "maxine@mustermensch.example" }), "MUELL-4711", ""];
  for (const [i, user] of users.entries()) {
    const { at, answer } = await through(running, apple, [["code", CODE], ["user", user], ...(i === 2 ? [["user", "zwei"]] as [string, string][] : [])]);
    ticketOf(answer, at, `user ${i}`);
  }
  assert.equal(await countOf(running.pool, "accounts"), 1);
  const dump = JSON.stringify((await running.pool.query("SELECT row_to_json(r) AS j FROM (SELECT * FROM oauth_records) r")).rows)
    + JSON.stringify((await running.pool.query("SELECT row_to_json(r) AS j FROM (SELECT * FROM accounts) r")).rows);
  for (const value of ["Maxine", "Mustermensch", "maxine@", "MUELL-4711"]) { assert.ok(!dump.includes(value), value); note(value); }
});

test("rueckweg: apple-fehler ergibt ticket access_denied", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  for (const error of ["user_cancelled_authorize", "beliebiger_text_4711"]) {
    const { at, answer } = await through(running, apple, [["error", error]]);
    note(error);
    const row = await ticketRow(running.pool, ticketOf(answer, at, error));
    assert.deepEqual(row.payload, { uid: at.uid, error: "access_denied" });
    assert.equal(row.account_id, null);
    assert.ok(!JSON.stringify(row).includes(error), "Apple-Text in der Ablage");
  }
  assert.equal(apple.forms.length, 0);
  assert.equal(await countOf(running.pool, "accounts"), 0);
});

// Ticket content and the answer's shape without the per-attempt location.
async function denied(running: Running, answer: Raw, at: { uid: string }, error: string, name: string) {
  const row = await ticketRow(running.pool, ticketOf(answer, at, name));
  assert.deepEqual(row.payload, { uid: at.uid, error }, name);
  assert.equal(row.account_id, null, name);
  return `${answer.status} ${Object.keys(answer.headers).filter((k) => !["location", "date"].includes(k)).sort()} ${answer.headers["cache-control"]}`;
}

test("rueckweg: abgelehnte einloesung ergibt access_denied", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const cases: [string, (f: URLSearchParams) => Response][] = [
    ["invalid_grant", () => Response.json({ error: "invalid_grant" }, { status: 400 })],
    ["invalid_client", () => Response.json({ error: "invalid_client" }, { status: 400 })],
    ["500", () => new Response("kaputt", { status: 500 })],
    ["ohne refresh_token", () => Response.json({ id_token: apple.id() })],
    ["aud app", () => Response.json({ refresh_token: REFRESH, id_token: apple.id({ aud: APP }) })],
  ];
  const shapes = new Set<string>();
  for (const [name, token] of cases) {
    apple.token = token;
    const { at, answer } = await through(running, apple);
    shapes.add(await denied(running, answer, at, "access_denied", name));
  }
  assert.equal(shapes.size, 1, `unterscheidbar: ${[...shapes].join(" | ")}`);
  assert.equal(await countOf(running.pool, "accounts"), 0);
});

test("rueckweg: ungueltiges identity-token ergibt access_denied", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const now = Math.floor(Date.now() / 1000);
  const cases: [string, () => string][] = [
    ["falsche nonce", () => apple.id({ nonce: shaHex("nonce-eines-anderen-versuchs") })],
    ["fremde aud", () => apple.id({ aud: "com.fremd.app" })],
    ["fremder schluessel", () => apple.id({ key: foreign.privateKey })],
    ["abgelaufen", () => apple.id({ exp: now - 120 })],
    ["anderer algorithmus", () => apple.id({ alg: "HS256" })],
    ["ohne sub", () => apple.id({ sub: null })],
    ["anderer aussteller", () => apple.id({ iss: "https://evil.example" })],
  ];
  for (const [name, id] of cases) {
    apple.token = () => Response.json({ refresh_token: REFRESH, id_token: id() });
    const { at, answer } = await through(running, apple);
    await denied(running, answer, at, "access_denied", name);
  }
  assert.equal(await countOf(running.pool, "accounts"), 0);
  assert.equal(await countOf(running.pool, "apple_tokens"), 0);
});

test("rueckweg: apple nicht erreichbar ergibt temporarily_unavailable", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const cases: [string, () => void][] = [
    ["netzfehler", () => { apple.token = () => Promise.reject(new Error("netz-4711")) as never; }],
    ["zeitueberschreitung", () => { apple.token = () => Promise.reject(new DOMException("zeit", "TimeoutError")) as never; }],
    ["schluesselsatz", () => { apple.token = undefined; apple.keysDown = true; }],
  ];
  for (const [name, arrange] of cases) {
    arrange();
    const { at, answer } = await through(running, apple);
    await denied(running, answer, at, "temporarily_unavailable", name);
  }
  assert.equal(await countOf(running.pool, "accounts"), 0);
});

test("rueckweg: geloeschtes konto ergibt 400 und raeumt tickets mit ab", async (t) => {
  const apple = fakeApple();
  const logged: string[] = [];
  let deleteFirst = true;
  // The pool the handler writes through: the ticket's INSERT first deletes its account, so the foreign key fails.
  const swap = (real: pg.Pool) => ({ query: async (sql: string, params?: any[]) => {
    if (deleteFirst && params?.[0] === "AppleTicket" && /INSERT/.test(sql)) await deleteAccount(real, params[5]);
    return real.query(sql, params);
  } });
  const running = await withApple(t, apple, { ret: (pool: () => pg.Pool) => async (req: any, res: any) => (await returnModule()).appleReturn({
    pool: swap(pool()), config: withWeb, publicUrl: ORIGIN, now: () => new Date(), fetch: apple.fetch,
    keys: createJwks({ fetch: apple.fetch, now: Date.now }).keys, log: (event: string) => logged.push(event) })(req, res) });
  const { at, answer } = await through(running, apple);
  assertFixed(answer, 400, BAD, "konto gelöscht");
  assert.equal(await countOf(running.pool, "oauth_records", "model = 'AppleTicket'"), 0);
  assert.deepEqual(logged, ["oauth return store failed"]);
  assert.ok(!answer.body.includes(at.uid));
  deleteFirst = false;
  const ok = await through(running, apple);
  const ticket = ticketOf(ok.answer, ok.at);
  const accountId = (await running.pool.query("SELECT id FROM accounts")).rows[0].id;
  await ticketRow(running.pool, ticket);
  await deleteAccount(running.pool, accountId);
  assert.equal(await countOf(running.pool, "oauth_records", "model = 'AppleTicket'"), 0, "Ticket blieb nach deleteAccount");
});

test("rueckweg: web-token wird nicht gespeichert und nicht widerrufen", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const { at, answer } = await through(running, apple);
  ticketOf(answer, at);
  assert.equal(await countOf(running.pool, "apple_tokens"), 0);
  assert.equal(apple.revokes, 0);
  const dump = JSON.stringify((await running.pool.query("SELECT row_to_json(r) AS j FROM (SELECT * FROM oauth_records) r")).rows);
  assert.ok(!dump.includes(REFRESH) && !answer.body.includes(REFRESH) && !JSON.stringify(answer.headers).includes(REFRESH));
});

test("rueckweg: ohne rueckweg und bei fremden pfaden 404 des ausstellers", async (t) => {
  const apple = fakeApple();
  const setups: [string, Doc][] = [
    ["ohne auth", {}], ["ohne web-id", { auth: { config: appOnly, fetch: apple.fetch } }],
    ["gesetzte interaktion", { auth: { config: withWeb, fetch: apple.fetch }, interaction: async (_p: any, _q: any, res: any) => void res.writeHead(418).end() }],
  ];
  for (const [name, options] of setups) {
    const running = await service(t, options);
    const before = await countOf(running.pool, "oauth_records");
    for (const body of ["", form([["state", "abc-4711"], ["code", CODE]])]) {
      const answer = await post(running.url, body);
      assert.equal(answer.status, 404, `${name}: ${answer.status}`);
      for (const value of ["abc-4711", CODE]) assert.ok(!answer.body.includes(value), name);
    }
    assert.equal(await countOf(running.pool, "oauth_records"), before, name);
    assert.equal(await countOf(running.pool, "accounts"), 0, name);
  }
  assert.equal(apple.forms.length, 0);
  const running = await withApple(t, apple);
  for (const path of [`${RETURN}/x`, `${RETURN}x`, "/oauth/apple"]) {
    for (const method of ["GET", "POST"]) {
      const answer = await raw(running.url, path, { method, headers: FORM, body: method === "POST" ? form([["state", "abc-4711"], ["code", CODE]]) : undefined });
      assert.equal(answer.status, 404, `${method} ${path}: ${answer.status}`);
    }
  }
  assert.equal(apple.forms.length, 0);
});

test("rueckweg: finish ist noch nicht behandelt und verbraucht nichts", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const { at, answer } = await through(running, apple);
  const ticket = ticketOf(answer, at);
  const before = await countOf(running.pool, "oauth_records");
  const location = new URL(String(answer.headers.location));
  const path = `${location.pathname}${location.search}`;
  assertFixed(await raw(running.url, path), 400, BAD, "ohne cookie");
  assertFixed(await raw(running.url, path, { headers: { cookie: at.cookie } }), 400, BAD, "mit cookie");
  assert.equal(await countOf(running.pool, "oauth_records"), before, "finish hat etwas angelegt");
  assert.equal(await countOf(running.pool, "oauth_records", "model IN ('Session', 'AuthorizationCode', 'Grant')"), 0);
  assert.equal((await ticketRow(running.pool, ticket)).consumed_at, null, "Ticket verbraucht");
});

test("rueckweg: fehlerfenster zaehlt 5xx und nicht die 303", async (t) => {
  const c = clock();
  const apple = fakeApple();
  apple.token = () => Promise.reject(new Error("netz-4711")) as never;
  const running = await withApple(t, apple, { now: c.now });
  const ats = [];
  for (let i = 0; i < 20; i++) ats.push(await hinweg(running, apple));
  c.offset = 301_000;
  for (const at of ats) ticketOf(await post(running.url, form([["state", at.state], ["code", CODE]])), at, "ausfall");
  for (let i = 0; i < 5; i++) assert.equal((await post(running.url, form([["state", randomBytes(32).toString("base64url")], ["code", CODE]]))).status, 400);
  assert.equal((await raw(running.url, "/health")).status, 200, "303 oder 4xx im Fehlerfenster gezählt");

  const failing = await service(t, { auth: { config: withWeb, fetch: apple.fetch }, ret: () => async () => { throw new Error("kaputt-4711"); } });
  for (let i = 0; i < 25; i++) assert.equal((await post(failing.url, form([["state", "x"], ["code", CODE]]))).status, 500, `500 ${i}`);
  assert.equal((await raw(failing.url, "/health")).status, 503, "5xx nicht gezählt");
});

test("rueckweg: eine jwks-instanz je start fuer rueckweg und app-weg", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const first = await through(running, apple);
  ticketOf(first.answer, first.at);
  assert.equal(apple.keyCalls, 1, "Rückweg lädt den Schlüsselsatz nicht genau einmal");
  const signIn = await fetch(`${running.url}/auth/apple`, { method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ identityToken: apple.id({ aud: APP, nonce: shaHex("nonce-app-4711") }), nonce: "nonce-app-4711", code: "CODE-APP-4711" }) });
  assert.equal(signIn.status, 200, "App-Weg");
  const second = await through(running, apple);
  ticketOf(second.answer, second.at);
  assert.equal(apple.keyCalls, 1, "mehr als eine JWKS-Instanz");
});

test("rueckweg: protokoll nur feste ereignisse ohne werte", () => {
  assert.ok(lines.some((line) => line.endsWith("oauth return refused")), "kein abgelehnter Rückweg protokolliert");
  assertQuiet();
});
