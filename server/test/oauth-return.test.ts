import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, randomBytes, randomUUID, sign } from "node:crypto";
import http from "node:http";
import { join } from "node:path";
import pg from "pg";
import { deleteAccount, findOrCreate } from "../src/accounts.ts";
import { loadAppleConfig } from "../src/apple.ts";
import { createJwks } from "../src/apple-jwks.ts";
import { start } from "../src/main.ts";
import { PgAdapter } from "../src/oauth-adapter.ts";
import { oauthKeysFromEnv, productInteraction } from "../src/oauth-provider.ts";

// Schnitt 4b-2a of #621: Apple's form_post comes back, is checked strictly and ends in a one-time ticket and a 303 to finish.
// Schnitt 4b-2b: finish needs the interaction cookie and the ticket, both bound to the path's uid, and signs the browser in.
// The whole path runs through the real issuer and a throwaway Postgres; only Apple is faked.

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
const interactionModule = () => import("../src/oauth-interaction.ts" as string) as Promise<Doc>;
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

// Each service gets its own schema; ret replaces the return handler (AC-13, AC-18), inter the interaction, both built
// from the pool the test gets back.
type Options = { auth?: Doc; interaction?: any; inter?: (pool: () => pg.Pool) => any; ret?: (pool: () => pg.Pool) => any; now?: () => number };
async function service(t: T, options: Options = {}) {
  const admin = new pg.Pool({ connectionString: databaseUrl });
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  await admin.query(`CREATE SCHEMA ${schema}`);
  const parsed = new URL(databaseUrl!);
  parsed.searchParams.set("options", `-c search_path=${schema}`);
  let pool: pg.Pool | undefined;
  const appleReturn = options.ret?.(() => pool!);
  if (options.inter) options = { ...options, interaction: options.inter(() => pool!) };
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
const secrets = new Set<string>([COOKIE_KEY, WEB, REFRESH, CODE, "apple-sub-1", "apple-sub-2", "appleid.apple.com"]);
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
const EVENT = /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z (oauth return refused|oauth return store failed|oauth interaction refused|oauth interaction store failed|oauth server error|oauth error|pool error|pool end failed|mcp close failed|listening|migrated)$/;
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

// finish (S4b-2b): later cookies replace earlier ones of the same name, as a browser's jar would.
const jar = (...cookies: string[]) =>
  [...new Map(cookies.join("; ").split("; ").filter(Boolean).map((pair) => [pair.split("=")[0], pair])).values()].join("; ");
const valuesOf = (cookie: string) => cookie.split("; ").map((pair) => pair.split("=")[1]);
const finishPath = (answer: Raw) => { const url = new URL(String(answer.headers.location)); return `${url.pathname}${url.search}`; };
type Flow = { at: { uid: string; cookie: string }; ticket: string; path: string };
// Hinweg and Rückweg up to the 303 to finish: the ticket and finish's path with its query.
async function flow(running: Running, apple: Apple, extra?: [string, string][]): Promise<Flow & { at: Awaited<ReturnType<typeof hinweg>> }> {
  const { at, answer } = await through(running, apple, extra);
  return { at, ticket: ticketOf(answer, at), path: finishPath(answer) };
}
const finish = (running: Running, path: string, cookie?: string, method = "GET") =>
  raw(running.url, path, { method, ...(cookie ? { headers: { cookie } } : {}) });
const consumed = async (pool: pg.Pool, ticket: string) => (await ticketRow(pool, ticket)).consumed_at !== null;
const interactionOf = async (pool: pg.Pool, uid: string) =>
  (await pool.query("SELECT payload FROM oauth_records WHERE model = 'Interaction' AND id_hash = $1", [sha(uid)])).rows[0]?.payload;
const resultOf = async (pool: pg.Pool, uid: string) => (await interactionOf(pool, uid))?.result;
const sessionsOf = (pool: pg.Pool, where = "true") => countOf(pool, "oauth_records", `model = 'Session' AND ${where}`);
async function accountOf(pool: pg.Pool, sub = "apple-sub-1"): Promise<string> {
  const id = (await pool.query("SELECT id FROM accounts WHERE apple_sub = $1", [sub])).rows[0].id as string;
  note(id);
  return id;
}
// finish succeeded: 303 to the issuer's resume of exactly this interaction, the resume cookie, no body.
function assertFinished(answer: Raw, uid: string, name: string) {
  assert.equal(answer.status, 303, `${name}: ${answer.status} ${answer.body.slice(0, 160)}`);
  assert.equal(new URL(String(answer.headers.location), ORIGIN).href, `${ORIGIN}/oauth/auth/${uid}`, name);
  assert.match(cookiesOf(answer), /(^|; )_interaction_resume=/, name);
  assert.equal(answer.body, "", name);
  note(...valuesOf(cookiesOf(answer)));
}
// Weiterlaufen: GET of finish's location with the browser's cookies and the resume cookie.
async function resume(running: Running, answer: Raw, cookie: string) {
  const jarred = jar(cookie, cookiesOf(answer));
  const to = new URL(String(answer.headers.location), ORIGIN);
  const next = await raw(running.url, `${to.pathname}${to.search}`, { headers: { cookie: jarred } });
  const all = jar(jarred, cookiesOf(next));
  note(...valuesOf(all));
  return { next, cookie: all };
}
// A refused finish: the fixed 400, the ticket unconsumed, no new session, no result in the interaction.
async function assertRefused(running: Running, answer: Raw, f: Pick<Flow, "at" | "ticket">, name: string, sessions = 0) {
  assertFixed(answer, 400, BAD, name);
  assert.equal(answer.headers["content-type"], "text/plain; charset=utf-8", name);
  assert.equal(await consumed(running.pool, f.ticket), false, `${name}: Ticket verbraucht`);
  assert.equal(await sessionsOf(running.pool), sessions, `${name}: Sitzung`);
  assert.equal(await resultOf(running.pool, f.at.uid), undefined, `${name}: result`);
}
const finishOf = (uid: string, ticket: string) => `/oauth/interaction/${uid}/finish?ticket=${ticket}`;
const anyTicket = () => { const ticket = randomBytes(32).toString("base64url"); note(ticket); return ticket; };

test("finish: erfolg legt sitzung des kontos an und endet bei der zustimmung", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const f = await flow(running, apple);
  const accountId = await accountOf(running.pool);
  const done = await finish(running, f.path, f.at.cookie);
  assertFinished(done, f.at.uid, "finish");
  assert.equal(await consumed(running.pool, f.ticket), true, "Ticket nicht verbraucht");
  const { next, cookie } = await resume(running, done, f.at.cookie);
  assert.equal(next.status, 303, `weiter: ${next.status} ${next.body.slice(0, 160)}`);
  const consent = new URL(String(next.headers.location), ORIGIN).pathname;
  assert.match(consent, /^\/oauth\/interaction\/[^/]+$/);
  const uid = consent.split("/").at(-1)!;
  note(uid);
  assert.notEqual(uid, f.at.uid, "keine neue Interaktion");
  assert.equal((await interactionOf(running.pool, uid))?.prompt?.name, "consent");
  const sessions = (await running.pool.query("SELECT account_id FROM oauth_records WHERE model = 'Session'")).rows;
  assert.deepEqual(sessions.map((row) => row.account_id), [accountId]);
  assertFixed(await raw(running.url, consent, { headers: { cookie } }), 501, "sign-in not available", "zustimmung");
  assert.equal(await countOf(running.pool, "oauth_records", "model IN ('AuthorizationCode', 'AccessToken', 'RefreshToken')"), 0);
});

test("finish: fehler-tickets enden als oauth-fehler beim client ohne beschreibung", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const cases: [string, () => void, [string, string][]][] = [
    ["access_denied", () => { apple.token = undefined; }, [["error", "user_cancelled_authorize"]]],
    ["temporarily_unavailable", () => { apple.token = () => Promise.reject(new Error("netz-4711")) as never; }, [["code", CODE]]],
  ];
  for (const [error, arrange, extra] of cases) {
    arrange();
    const f = await flow(running, apple, extra);
    const done = await finish(running, f.path, f.at.cookie);
    assertFinished(done, f.at.uid, error);
    assert.equal(await consumed(running.pool, f.ticket), true, `${error}: Ticket`);
    const { next } = await resume(running, done, f.at.cookie);
    assert.equal(next.status, 303, `${error}: ${next.status} ${next.body.slice(0, 160)}`);
    const to = new URL(String(next.headers.location));
    assert.equal(`${to.origin}${to.pathname}`, CB, error);
    assert.equal(to.searchParams.get("error"), error);
    assert.equal(to.searchParams.get("state"), "s1", error);
    for (const key of ["error_description", "code"]) assert.equal(to.searchParams.has(key), false, `${error}: ${key}`);
  }
  assert.equal(await sessionsOf(running.pool, "account_id IS NOT NULL"), 0);
  assert.equal(await countOf(running.pool, "oauth_records", "model = 'AuthorizationCode'"), 0);
});

test("finish: ohne cookie und mit fremdem cookie 400 und ticket bleibt", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const a = await flow(running, apple);
  const b = await flow(running, apple);
  const invented = a.at.cookie.split("; ").map((pair) => `${pair.split("=")[0]}=${anyTicket()}`).join("; ");
  for (const [name, cookie] of [["ohne cookie", undefined], ["cookie von b", b.at.cookie], ["erfundenes cookie", invented]] as const) {
    await assertRefused(running, await finish(running, a.path, cookie), a, name);
  }
  assert.equal(await resultOf(running.pool, b.at.uid), undefined, "result bei b");
  assert.equal(await consumed(running.pool, b.ticket), false, "Ticket von b verbraucht");
  assertFinished(await finish(running, a.path, a.at.cookie), a.at.uid, "richtiges cookie");
});

test("finish: ticket einer anderen interaktion 400 und ticket bleibt", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const a = await flow(running, apple);
  apple.sub = "apple-sub-2";
  const b = await flow(running, apple);
  await assertRefused(running, await finish(running, finishOf(a.at.uid, b.ticket), a.at.cookie), b, "ticket von b");
  assert.equal(await resultOf(running.pool, a.at.uid), undefined, "result bei a");
  await assertRefused(running, await finish(running, b.path, a.at.cookie), b, "pfad von b, cookie von a");
  for (const f of [a, b]) assert.equal(await consumed(running.pool, f.ticket), false, "Ticket verbraucht");
  assertFinished(await finish(running, a.path, a.at.cookie), a.at.uid, "a");
  assertFinished(await finish(running, b.path, b.at.cookie), b.at.uid, "b");
});

test("finish: replay abgelaufen unbekannt und fremdes modell 400", async (t) => {
  const c = clock();
  const apple = fakeApple();
  const running = await withApple(t, apple, { now: c.now });
  const once = await flow(running, apple);
  const done = await finish(running, once.path, once.at.cookie);
  assertFinished(done, once.at.uid, "erster abruf");
  assertFixed(await finish(running, once.path, once.at.cookie), 400, BAD, "zweiter abruf");
  await resume(running, done, once.at.cookie);
  assert.equal(await sessionsOf(running.pool), 1, "nicht genau eine Sitzung");
  const late = await flow(running, apple);
  c.offset = 61_000;
  await assertRefused(running, await finish(running, late.path, late.at.cookie), late, "abgelaufen", 1);
  c.offset = 0;
  const fresh = await flow(running, apple);
  await assertRefused(running, await finish(running, finishOf(fresh.at.uid, anyTicket()), fresh.at.cookie), fresh, "unbekannt", 1);
  const other = await hinweg(running, apple);
  assertFixed(await finish(running, finishOf(other.uid, other.state), other.cookie), 400, BAD, "state als ticket");
  const login = (await running.pool.query("SELECT consumed_at FROM oauth_records WHERE model = 'AppleLogin' AND id_hash = $1", [sha(other.state)])).rows[0];
  assert.equal(login.consumed_at, null, "AppleLogin verbraucht");
  assert.equal(await resultOf(running.pool, other.uid), undefined, "result nach state als ticket");
  assert.equal(await sessionsOf(running.pool), 1, "weitere Sitzung");
});

test("finish: ticket genau einmal und nicht leer", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const f = await flow(running, apple);
  const base = `/oauth/interaction/${f.at.uid}/finish`;
  const cases: [string, string][] = [
    ["ohne ticket", base], ["leeres ticket", `${base}?ticket=`], ["zwei gleiche", `${base}?ticket=${f.ticket}&ticket=${f.ticket}`],
    ["gueltig und erfunden", `${base}?ticket=${f.ticket}&ticket=${anyTicket()}`],
  ];
  for (const [name, path] of cases) await assertRefused(running, await finish(running, path, f.at.cookie), f, name);
  assertFinished(await finish(running, `${base}?x=1&ticket=${f.ticket}&state=s1`, f.at.cookie), f.at.uid, "weitere parameter");
});

test("finish: ticket in falscher form wird abgelehnt und nicht verbraucht", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const at = await hinweg(running, apple);
  const accountId = await findOrCreate(running.pool, "apple-sub-1");
  note(accountId);
  assert.equal((await returnModule()).TICKET_MODEL, "AppleTicket", "eine Quelle für das Modell des Tickets");
  const adapter = new PgAdapter(running.pool, "AppleTicket");
  const cases: [string, Doc][] = [
    ["ohne uid", { accountId }], ["weder konto noch fehler", { uid: at.uid }],
    ["konto und fehler", { uid: at.uid, accountId, error: "access_denied" }], ["anderer fehler", { uid: at.uid, error: "server_error" }],
    ["konto als zahl", { uid: at.uid, accountId: 42 }], ["leere strings", { uid: "", accountId: "" }],
  ];
  for (const [name, payload] of cases) {
    const ticket = anyTicket();
    // The adapter writes account_id from the payload; a number or an empty string has no account row, so straight in.
    if (typeof payload.accountId === "number" || payload.accountId === "") {
      await running.pool.query("INSERT INTO oauth_records (model, id_hash, payload, uid, expires_at) VALUES ('AppleTicket', $1, $2, $3, now() + interval '60 seconds')",
        [sha(ticket), payload, payload.uid]);
    } else await adapter.upsert(ticket, payload, 60);
    await assertRefused(running, await finish(running, finishOf(at.uid, ticket), at.cookie), { at, ticket }, name);
  }
});

test("finish: anderer pfadrest falsche methode und anderer prompt 400", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const f = await flow(running, apple);
  for (const rest of ["/finishx", "/finish/x", "/x", "/", "/finish/"]) {
    await assertRefused(running, await finish(running, `/oauth/interaction/${f.at.uid}${rest}?ticket=${f.ticket}`, f.at.cookie), f, rest);
  }
  for (const method of ["POST", "PUT", "DELETE"]) {
    const answer = await finish(running, f.path, f.at.cookie, method);
    assert.equal(answer.status, 405, `${method}: ${answer.status}`);
    assert.equal(answer.headers.allow, "GET", method);
    assert.equal(answer.headers["cache-control"], "no-store", method);
    assert.equal(answer.body, "", method);
    assert.equal(await consumed(running.pool, f.ticket), false, `${method}: Ticket verbraucht`);
  }
  const done = await finish(running, f.path, f.at.cookie);
  assertFinished(done, f.at.uid, "finish");
  const { next, cookie } = await resume(running, done, f.at.cookie);
  const consent = new URL(String(next.headers.location), ORIGIN).pathname;
  const uid = consent.split("/").at(-1)!;
  note(uid);
  const ticket = anyTicket();
  await new PgAdapter(running.pool, "AppleTicket").upsert(ticket, { uid, accountId: await accountOf(running.pool) }, 60);
  assertFixed(await finish(running, finishOf(uid, ticket), cookie), 400, BAD, "prompt consent");
  assert.equal(await consumed(running.pool, ticket), false, "consent: Ticket verbraucht");
  await hinweg(running, apple);
});

test("finish: geloeschtes konto raeumt das ticket ab und ergibt 400", async (t) => {
  const apple = fakeApple();
  const running = await withApple(t, apple);
  const f = await flow(running, apple);
  const accountId = await accountOf(running.pool);
  await deleteAccount(running.pool, accountId);
  assert.equal(await countOf(running.pool, "oauth_records", "model = 'AppleTicket'"), 0, "Ticket nicht abgeräumt");
  assertFixed(await finish(running, f.path, f.at.cookie), 400, BAD, "konto gelöscht");
  assert.equal(await sessionsOf(running.pool), 0, "Sitzung");
  assert.equal(await countOf(running.pool, "oauth_records", `account_id = '${accountId}'`), 0, "Eintrag mit Konto");
  assert.equal(await resultOf(running.pool, f.at.uid), undefined, "result");
});

let storeFailures = 0;
test("finish: speicherfehler 400 store failed ohne werte", async (t) => {
  const apple = fakeApple();
  const logged: string[] = [];
  let mode = "";
  let leak = "";
  // The pool finish reads through: reading or redeeming the ticket fails with values in the text, or the interaction
  // vanishes right after the redemption, so the library throws.
  const swap = (real: pg.Pool) => ({ query: async (sql: string, params?: any[]) => {
    if (params?.[0] !== "AppleTicket") return real.query(sql, params);
    if (mode === "read" && /^\s*SELECT/.test(sql)) throw new Error(`lesen kaputt ${leak}`);
    if (mode === "consume" && /^\s*UPDATE/.test(sql)) throw new Error(`einloesen kaputt ${leak}`);
    const result = await real.query(sql, params);
    if (mode === "gone" && /^\s*UPDATE/.test(sql)) await real.query("DELETE FROM oauth_records WHERE model = 'Interaction'");
    return result;
  } });
  const jwks = createJwks({ fetch: apple.fetch, now: Date.now }).keys;
  const base = { config: withWeb, publicUrl: ORIGIN, now: () => new Date(), keys: jwks };
  const log = (event: string) => { logged.push(event); if (event === "oauth interaction store failed") storeFailures++; };
  const running = await service(t, { auth: { config: withWeb, fetch: apple.fetch },
    inter: (pool) => async (provider: any, req: any, res: any) =>
      (await interactionModule()).appleInteraction({ ...base, pool: swap(pool()), fallback: productInteraction, log })(provider, req, res),
    ret: (pool) => async (req: any, res: any) => (await returnModule()).appleReturn({ ...base, pool: pool(), fetch: apple.fetch, log: () => {} })(req, res) });
  for (const name of ["read", "consume", "gone"]) {
    const f = await flow(running, apple);
    leak = `${await accountOf(running.pool)} ${f.ticket}`;
    logged.length = 0;
    mode = name;
    const answer = await finish(running, f.path, f.at.cookie);
    mode = "";
    assertFixed(answer, 400, BAD, name);
    for (const value of leak.split(" ")) assert.ok(!answer.body.includes(value) && !JSON.stringify(answer.headers).includes(value), `${name}: Wert`);
    assert.deepEqual(logged, ["oauth interaction store failed"], name);
    if (name !== "gone") assert.equal(await consumed(running.pool, f.ticket), false, `${name}: Ticket verbraucht`);
    assert.equal(await sessionsOf(running.pool), 0, `${name}: Sitzung`);
  }
});

test("finish: fehlerfenster zaehlt weder 400 noch 303", async (t) => {
  const c = clock();
  const apple = fakeApple();
  const running = await withApple(t, apple, { now: c.now });
  const ats = [];
  for (let i = 0; i < 5; i++) ats.push(await hinweg(running, apple));
  // Only what follows counts: the preparation drops out of the 5-minute window.
  c.offset = 301_000;
  for (const at of ats) {
    const answer = await post(running.url, form([["state", at.state], ["code", CODE]]));
    ticketOf(answer, at);
    assertFinished(await finish(running, finishPath(answer), at.cookie), at.uid, "erfolg");
  }
  const refused = finishOf(ats[0].uid, "x");
  for (let i = 0; i < 20; i++) assert.equal((await finish(running, refused)).status, 400, `400 ${i}`);
  for (let i = 0; i < 5; i++) assert.equal((await finish(running, refused, undefined, "POST")).status, 405, `405 ${i}`);
  assert.equal((await raw(running.url, "/health")).status, 200, "400, 405 oder 303 im Fehlerfenster gezählt");

  const failing = await service(t, { auth: { config: withWeb, fetch: apple.fetch }, interaction: async () => { throw new Error("kaputt-4711"); } });
  for (let i = 0; i < 25; i++) assert.equal((await finish(failing, finishOf("x", "y"))).status, 500, `500 ${i}`);
  assert.equal((await raw(failing.url, "/health")).status, 503, "5xx nicht gezählt");
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

test("finish: protokoll nur feste ereignisse ohne werte", () => {
  assert.ok(lines.some((line) => line.endsWith("oauth interaction refused")), "kein abgelehnter Abschluss protokolliert");
  assert.ok(storeFailures > 0, "kein Speicherfehler protokolliert");
  assertQuiet();
});
