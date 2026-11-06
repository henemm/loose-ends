import { test } from "node:test";
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import http from "node:http";
import { createServer } from "node:net";
import { join } from "node:path";
import pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { start } from "../src/main.ts";
import { ErrorWindow, healthHandler } from "../src/health.ts";
import { putTranscript } from "../src/transcripts.ts";
import { putOrder } from "../src/orders.ts";
import { spawn } from "node:child_process";
import { createHash, generateKeyPairSync, randomBytes, sign } from "node:crypto";
import { connect } from "node:net";
import { createSession, findOrCreate, resolveSession } from "../src/accounts.ts";
import { loadAppleConfig } from "../src/apple.ts";
import { OAuthError, OAuthErrorCode, type AuthInfo } from "@modelcontextprotocol/server";

type Doc = Record<string, any>;
type T = { after: (fn: () => Promise<void>) => void; mock: any };
type Options = Partial<Parameters<typeof start>[0]>;

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/;

// Each service gets its own schema (search_path in the URL) and its own application_name, so runs never meet.
async function service(t: T, options: Options = {}) {
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  const applicationName = `le-test-${schema.slice(2, 14)}`;
  const admin = new pg.Pool({ connectionString: databaseUrl });
  await admin.query(`CREATE SCHEMA ${schema}`);
  const url = new URL(databaseUrl!);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const running = await start({ databaseUrl: url.toString(), port: 0, migrationsDir: migrations, applicationName, ...options });
  t.after(async () => {
    await running.close();
    await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  });
  return { ...running, admin, schema, applicationName, databaseUrl: url.toString() };
}

async function health(url: string): Promise<{ status: number; body: Doc }> {
  const answer = await fetch(`${url}/health`);
  return { status: answer.status, body: await answer.json() };
}

function capturedLines(t: T): string[] {
  const lines: string[] = [];
  for (const name of ["log", "error"]) t.mock.method(console, name, (...args: unknown[]) => { lines.push(args.map(String).join(" ")); });
  return lines;
}

async function freePort(): Promise<number> {
  const probe = createServer();
  await new Promise<void>((done) => probe.listen(0, "127.0.0.1", done));
  const port = (probe.address() as { port: number }).port;
  await new Promise((done) => probe.close(done));
  return port;
}

const connections = async (admin: pg.Pool, name: string) =>
  Number((await admin.query("SELECT count(*) AS n FROM pg_stat_activity WHERE application_name = $1", [name])).rows[0].n);

test("AC-1 (S1): after ready, /health answers 200 with exactly five keys", async (t) => {
  const { url, ready } = await service(t);
  await ready;
  const { status, body } = await health(url);
  assert.equal(status, 200);
  assert.deepEqual(Object.keys(body).sort(), ["db", "errorRate", "migrated", "requests", "status"]);
  assert.equal(body.status, "ok");
  assert.equal(body.db, "up");
  assert.equal(body.migrated, true);
  assert.equal(body.errorRate, 0);
  assert.equal(typeof body.requests, "number");
});

test("AC-2 (S1): without a database /health and /mcp answer 503, ready is refused, close does not throw", async (t) => {
  const port = await freePort();
  const running = await start({
    databaseUrl: `postgres://postgres@127.0.0.1:${port}/postgres`, port: 0, migrationsDir: migrations, retryMs: 50, maxAttempts: 20,
  });
  const refused = assert.rejects(running.ready);
  const { status, body } = await health(running.url);
  assert.equal(status, 503);
  assert.equal(body.migrated, false);
  assert.equal(body.status, "unavailable");
  const mcp = await fetch(`${running.url}/mcp`, { method: "POST", headers: { "content-type": "application/json" }, body: "{}" });
  assert.equal(mcp.status, 503);
  await refused;
  await assert.doesNotReject(running.close());
});

// #621 S1: /mcp sits behind the bearer check; this verifier knows one token for the configured resource, without an account.
const MCP_TOKEN = "test-token-ohne-konto";
const tokenVerifier = {
  verifyAccessToken: async (token: string): Promise<AuthInfo> => {
    if (token !== MCP_TOKEN) throw new OAuthError(OAuthErrorCode.InvalidToken, "unknown token");
    return { token, clientId: "test", scopes: [], expiresAt: Math.floor(Date.now() / 1000) + 3600,
      resource: new URL("https://loose-ends.henemm.com/mcp"), extra: {} };
  },
};
const bearerTransport = (url: string) =>
  new StreamableHTTPClientTransport(new URL(`${url}/mcp`), { requestInit: { headers: { Authorization: `Bearer ${MCP_TOKEN}` } } });

test("AC-3 (S1): /mcp answers initialize with serverInfo and refuses get_now without an account", async (t) => {
  const { url, ready } = await service(t, { oauth: { verifier: tokenVerifier } } as Options);
  await ready;
  const bare = await fetch(`${url}/mcp`, { method: "POST", headers: { "content-type": "application/json" }, body: "{}" });
  assert.equal(bare.status, 401, "ohne Token");
  assert.match(bare.headers.get("www-authenticate") ?? "", /^Bearer /);
  const client = new Client({ name: "test", version: "1" });
  await client.connect(bearerTransport(url));
  t.after(async () => { await client.close(); });
  assert.equal(client.getServerVersion()?.name, "loose-ends");
  const result: Doc = await client.callTool({ name: "get_now", arguments: {} });
  assert.equal(result.isError, true);
  assert.match(result.content.map((part: Doc) => part.text).join(""), /kein Konto/);
});

test("AC-4 (S1): an unknown path answers 404 and counts in the next /health", async (t) => {
  const { url, ready } = await service(t);
  await ready;
  const before = (await health(url)).body.requests;
  const missing = await fetch(`${url}/gibt-es-nicht`);
  assert.equal(missing.status, 404);
  assert.equal(await missing.text(), "");
  assert.equal((await health(url)).body.requests, before + 1);
});

test("AC-5 (S1): terminated pool connections leave the process alive and /health recovers within 5 s, without error text", async (t) => {
  const { url, ready, admin, applicationName } = await service(t);
  await ready;
  assert.equal((await health(url)).status, 200);
  const lines = capturedLines(t);
  await admin.query("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name = $1", [applicationName]);
  const deadline = Date.now() + 5000;
  let last = await health(url);
  while (last.status !== 200 && Date.now() < deadline) {
    await new Promise((done) => setTimeout(done, 100));
    last = await health(url);
  }
  assert.equal(last.status, 200);
  assert.equal(last.body.db, "up");
  for (const line of lines) assert.ok(!/terminat|administrator/i.test(line), line);
});

test("AC-6 (S1): close ends server and pool, a second close does not throw, keep-alive does not hold it", async (t) => {
  const { url, ready, close, admin, applicationName } = await service(t);
  await ready;
  const agent = new http.Agent({ keepAlive: true });
  await new Promise<void>((done, fail) => {
    http.get(`${url}/health`, { agent }, (answer) => { answer.resume(); answer.on("end", done); }).on("error", fail);
  });
  const began = Date.now();
  await close();
  assert.ok(Date.now() - began < 2000, `close dauerte ${Date.now() - began} ms`);
  await assert.rejects(fetch(`${url}/health`));
  let open = await connections(admin, applicationName);
  for (let i = 0; open > 0 && i < 20; i++) {
    await new Promise((done) => setTimeout(done, 50));
    open = await connections(admin, applicationName);
  }
  assert.equal(open, 0, "der Pool hält noch Verbindungen");
  await assert.doesNotReject(close());
  agent.destroy();
});

test("AC-7 (S1): ErrorWindow trips only above half of at least 20 answers and forgets after five minutes", () => {
  let clock = 1_000_000;
  const fill = (fives: number, total: number) => {
    const window = new ErrorWindow(() => clock);
    for (let i = 0; i < total; i++) window.record(i < fives ? 500 : 200);
    return window;
  };
  assert.equal(fill(19, 19).tripped(), false);
  const eleven = fill(11, 20);
  assert.equal(eleven.tripped(), true);
  assert.equal(eleven.stats().errorRate, 0.55);
  assert.equal(fill(10, 20).tripped(), false);
  clock += 300_001;
  assert.deepEqual(eleven.stats(), { requests: 0, errors: 0, errorRate: 0 });
  assert.equal(eleven.tripped(), false);
  const plain = new ErrorWindow(() => clock);
  plain.record(404);
  plain.record(200);
  assert.deepEqual(plain.stats(), { requests: 2, errors: 0, errorRate: 0 });
});

test("AC-8 (S1): /health turns 503 on a high error rate and recovers when the window passes", async (t) => {
  let clock = 5_000_000;
  const boom = async (): Promise<Response> => { throw new Error("kaputt"); };
  const { url, ready } = await service(t, { now: () => clock, extraRoutes: { "/boom": boom } });
  await ready;
  for (let i = 0; i < 20; i++) {
    const answer = await fetch(`${url}${i < 11 ? "/boom" : "/gibt-es-nicht"}`);
    await answer.arrayBuffer();
    assert.equal(answer.status, i < 11 ? 500 : 404);
  }
  const tripped = await health(url);
  assert.equal(tripped.status, 503);
  assert.equal(tripped.body.status, "unavailable");
  assert.equal(tripped.body.db, "up");
  assert.equal(tripped.body.migrated, true);
  assert.ok(tripped.body.errorRate > 0.5, String(tripped.body.errorRate));
  assert.equal((await health(url)).body.requests, 20, "/health zählt nicht mit");
  clock += 300_001;
  assert.equal((await health(url)).status, 200);
});

test("AC-9 (S1): a database that never answers gives 503 with db down within a second, no exception", async () => {
  const pool = { query: () => new Promise(() => {}) } as unknown as pg.Pool;
  const handler = healthHandler({ pool, isMigrated: () => true, window: new ErrorWindow(Date.now), timeoutMs: 50 });
  const began = Date.now();
  const answer = await handler();
  assert.ok(Date.now() - began < 1000, `${Date.now() - began} ms`);
  assert.equal(answer.status, 503);
  assert.equal((await answer.json()).db, "down");
});

test("AC-10 (S1): no title, order id, database error text or URL in any answer or log line; every log line starts ISO", async (t) => {
  const lines = capturedLines(t);
  const blocks = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)].map((b) => JSON.parse(b[1]));
  const transcript: Doc = blocks[0];
  const order: Doc = blocks[1];
  const titles: string[] = transcript.tasks.map((task: Doc) => task.title);
  const leak = async (): Promise<Response> => { throw new Error(`${titles[0]} ${order.id}`); };
  const running = await service(t, { extraRoutes: { "/leak": leak } });
  await running.ready;
  const data = new pg.Pool({ connectionString: running.databaseUrl });
  t.after(async () => { await data.end(); });
  await putTranscript(data, "henning", transcript);
  await putOrder(data, "henning", order);
  const bodies: string[] = [];
  for (const path of ["/health", "/gibt-es-nicht", "/leak"]) bodies.push(await (await fetch(`${running.url}${path}`)).text());
  await running.admin.query("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name = $1", [running.applicationName]);
  await new Promise((done) => setTimeout(done, 200));
  bodies.push(await (await fetch(`${running.url}/health`)).text());
  await running.close();
  const forbidden = [...titles, order.id, running.databaseUrl, databaseUrl!, "terminating connection"];
  for (const text of [...bodies, ...lines]) for (const word of forbidden) assert.ok(!text.includes(word), `${word} in ${text}`);
  assert.ok(lines.length > 0, "keine Logzeile aufgefangen");
  for (const line of lines) assert.match(line, ISO);
});

// Schnitt 3c-2: the auth routes mounted by start(); Apple is a self-made key pair behind a counting fetch, no network.
const KEYS_URL = "https://appleid.apple.com/auth/keys";
const TOKEN_URL = "https://appleid.apple.com/auth/token";
const A_IDS = ["com.henning.looseends", "com.henning.looseends.connector"];
const A_SUB = "001234.feedface0123456789.0815";
const A_NONCE = "nonce-einhaengen-4711";
const A_CODE = "CODE-EINHAENGEN-4711";
const A_REFRESH = "REFRESH-EINHAENGEN-4711";
const MIB = 1024 * 1024;
const aRsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const aEc = generateKeyPairSync("ec", { namedCurve: "P-256" });
const A_JWK = { ...aRsa.publicKey.export({ format: "jwk" }), kid: "E1", alg: "RS256", use: "sig" };
const A_ENV: Record<string, string> = {
  APPLE_TEAM_ID: "TEAMEINH01", APPLE_KEY_ID: "KEYEINH001", APPLE_CLIENT_IDS: A_IDS.join(","),
  APPLE_PRIVATE_KEY: (aEc.privateKey.export({ type: "pkcs8", format: "pem" }) as string).replace(/\n/g, "\\n"),
  APPLE_TOKEN_KEY: randomBytes(32).toString("base64"),
};
const aConfig = loadAppleConfig(A_ENV);
// Every value of the environment, and the key body alone, must never reach a log line or a message.
const A_VALUES = [...Object.values(A_ENV), ...A_IDS, A_ENV.APPLE_PRIVATE_KEY.split("\\n")[1]];

const aSeg = (x: unknown) => Buffer.from(JSON.stringify(x)).toString("base64url");
function idToken(sub = A_SUB): string {
  const now = Math.floor(Date.now() / 1000);
  const nonce = createHash("sha256").update(A_NONCE).digest("hex");
  const data = `${aSeg({ alg: "RS256", kid: "E1" })}.${aSeg({ iss: "https://appleid.apple.com", aud: A_IDS[0], sub, iat: now, exp: now + 600, nonce })}`;
  return `${data}.${sign("sha256", Buffer.from(data), aRsa.privateKey).toString("base64url")}`;
}

// Fake Apple: keys, token and revoke; counts every call by URL.
function fakeApple(revoke: "ok" | "throws" = "ok") {
  const urls: string[] = [];
  const fetch = (async (input: string | URL) => {
    const url = String(input);
    urls.push(url);
    if (url === KEYS_URL) return Response.json({ keys: [A_JWK] });
    if (url === TOKEN_URL) return Response.json({ refresh_token: A_REFRESH, id_token: idToken() });
    if (revoke === "throws") throw new Error("netz-weg-4711");
    return new Response(null, { status: 200 });
  }) as unknown as typeof globalThis.fetch;
  return { urls, fetch, keyCalls: () => urls.filter((url) => url === KEYS_URL).length };
}

const signIn = (url: string) => fetch(`${url}/auth/apple`, {
  method: "POST", headers: { "content-type": "application/json" },
  body: JSON.stringify({ identityToken: idToken(), nonce: A_NONCE, code: A_CODE }),
});
const withBearer = (url: string, path: string, token: string) =>
  fetch(`${url}${path}`, { method: "POST", headers: { authorization: `Bearer ${token}` } });

// A data pool on the service's own schema, ended after the test.
function dataPool(t: T, databaseUrl: string): pg.Pool {
  const pool = new pg.Pool({ connectionString: databaseUrl });
  t.after(async () => { await pool.end(); });
  return pool;
}
async function member(pool: pg.Pool, sub = A_SUB) {
  const id = await findOrCreate(pool, sub);
  return { id, token: await createSession(pool, id) };
}

// A counting route that reads the whole body; maxSeen is the largest body it ever got.
function counter() {
  const c = { calls: 0, maxSeen: 0, route: async (request: Request) => {
    c.calls++;
    c.maxSeen = Math.max(c.maxSeen, (await request.arrayBuffer()).byteLength);
    return new Response(null, { status: 204 });
  } };
  return c;
}

type Sent = { status: number; connection: string | undefined; body: string } | { aborted: true };
// POST over node:http with a keep-alive agent (so "connection: close" comes from the service); an error after the answer is ignored.
function send(url: string, path: string, parts: Buffer[], headers: Record<string, string> = {}): Promise<Sent> {
  const agent = new http.Agent({ keepAlive: true });
  return new Promise<Sent>((done) => {
    const request = http.request(`${url}${path}`, { method: "POST", headers, agent }, (answer) => {
      let body = "";
      answer.setEncoding("utf8");
      answer.on("data", (chunk) => { body += chunk; });
      const finish = () => done({ status: answer.statusCode!, connection: answer.headers.connection, body });
      answer.on("end", finish);
      answer.on("error", finish);
    });
    request.on("error", () => done({ aborted: true }));
    for (const part of parts) request.write(part);
    request.end();
  }).finally(() => agent.destroy());
}
const sized = (url: string, path: string, size: number) =>
  send(url, path, [Buffer.alloc(size, 0x61)], { "content-type": "application/json", "content-length": String(size) });

test("einhaengen: auth vor migrate 503", async (t) => {
  const port = await freePort();
  const apple = fakeApple();
  const running = await start({
    databaseUrl: `postgres://postgres@127.0.0.1:${port}/postgres`, port: 0, migrationsDir: migrations, retryMs: 50, maxAttempts: 40,
    auth: { config: aConfig, fetch: apple.fetch },
  });
  t.after(running.close);
  const refused = assert.rejects(running.ready);
  const answers = [await signIn(running.url), await withBearer(running.url, "/auth/logout", "x"), await withBearer(running.url, "/auth/delete", "x"),
    await fetch(`${running.url}/mcp`, { method: "POST", headers: { "content-type": "application/json" }, body: "{}" })];
  for (const answer of answers) {
    assert.equal(answer.status, 503, answer.url);
    assert.equal(await answer.text(), "", answer.url);
  }
  assert.equal(apple.urls.length, 0);
  await refused;
  await running.close();
  const live = await service(t, { auth: { config: aConfig, fetch: apple.fetch } });
  await live.ready;
  assert.equal((await fetch(`${live.url}/auth/logout`, { method: "POST" })).status, 401, "nach ready läuft logout");
});

test("einhaengen: ohne config logout und delete laufen", async (t) => {
  const apple = fakeApple();
  const running = await service(t, { auth: { fetch: apple.fetch } });
  await running.ready;
  const pool = dataPool(t, running.databaseUrl);
  const refused = await signIn(running.url);
  assert.equal(refused.status, 503);
  assert.equal(await refused.text(), "");
  const leaving = await member(pool, `${A_SUB}.a`);
  assert.equal((await withBearer(running.url, "/auth/logout", leaving.token)).status, 204);
  assert.equal(await resolveSession(pool, leaving.token), null);
  const gone = await member(pool, `${A_SUB}.b`);
  assert.equal((await withBearer(running.url, "/auth/delete", gone.token)).status, 204);
  assert.equal((await pool.query("SELECT count(*)::int AS n FROM accounts WHERE id = $1", [gone.id])).rows[0].n, 0);
  assert.equal(apple.urls.length, 0, "ohne config kein Apple-Aufruf, auch kein JWKS");
});

test("einhaengen: anmelden und abmelden mit config", async (t) => {
  const apple = fakeApple();
  const running = await service(t, { auth: { config: aConfig, fetch: apple.fetch } });
  await running.ready;
  const pool = dataPool(t, running.databaseUrl);
  const answer = await signIn(running.url);
  assert.equal(answer.status, 200);
  const { sessionToken } = (await answer.json()) as { sessionToken: string };
  assert.ok(typeof sessionToken === "string" && sessionToken !== "");
  assert.notEqual(await resolveSession(pool, sessionToken), null);
  assert.equal((await withBearer(running.url, "/auth/logout", sessionToken)).status, 204);
  assert.equal(await resolveSession(pool, sessionToken), null);
});

test("einhaengen: jwks lazy und einmal", async (t) => {
  const apple = fakeApple();
  const running = await service(t, { auth: { config: aConfig, fetch: apple.fetch } });
  await running.ready;
  await health(running.url);
  assert.equal(apple.keyCalls(), 0, "kein Vorladen");
  for (let i = 0; i < 2; i++) assert.equal((await signIn(running.url)).status, 200, `Anmeldung ${i + 1}`);
  assert.equal(apple.keyCalls(), 1, "eine Instanz, Cache");
  const bare = fakeApple();
  const without = await service(t, { auth: { fetch: bare.fetch } });
  await without.ready;
  assert.equal((await signIn(without.url)).status, 503);
  assert.equal(bare.keyCalls(), 0, "ohne config nie");
});

test("einhaengen: weiche apple env", async () => {
  const { appleConfigFromEnv } = await import("../src/main.ts");
  assert.equal(typeof appleConfigFromEnv, "function", "appleConfigFromEnv fehlt");
  const blank = Object.fromEntries(Object.keys(A_ENV).map((name) => [name, "  "]));
  const cases: [string, Record<string, string>, RegExp | "none" | "config"][] = [
    ["keine", {}, "none"],
    ["nur Leerzeichen", blank, "none"],
    ["alle gültig", A_ENV, "config"],
    ...Object.keys(A_ENV).map((name): [string, Record<string, string>, RegExp] => {
      const env = { ...A_ENV };
      delete env[name];
      return [`${name} fehlt`, env, new RegExp(name)];
    }),
    ["Schlüssel unlesbar", { ...A_ENV, APPLE_PRIVATE_KEY: "kein-schluessel-4711" }, /APPLE_PRIVATE_KEY/],
    ["Token-Schlüssel 16 Byte", { ...A_ENV, APPLE_TOKEN_KEY: randomBytes(16).toString("base64") }, /APPLE_TOKEN_KEY/],
  ];
  for (const [name, env, expected] of cases) {
    if (expected === "none") { assert.equal(appleConfigFromEnv(env), undefined, name); continue; }
    if (expected === "config") { assert.equal(appleConfigFromEnv(env)?.teamId, A_ENV.APPLE_TEAM_ID, name); continue; }
    assert.throws(() => appleConfigFromEnv(env), (error: Error) => {
      assert.match(error.message, expected, name);
      for (const value of [...A_VALUES, ...Object.values(env)]) assert.ok(!error.message.includes(value), `${name}: Wert in der Meldung`);
      return true;
    }, name);
  }
});

// The real process: main.ts as a child, without the test runner's context and without any APPLE_* of this shell.
const MAIN = join(import.meta.dirname, "../src/main.ts");
function child(env: Record<string, string>) {
  const base = Object.fromEntries(Object.entries(process.env)
    .filter(([k]) => !k.startsWith("APPLE_") && !k.startsWith("OAUTH_") && k !== "NODE_TEST_CONTEXT"));
  const proc = spawn(process.execPath, [MAIN], { env: { ...base, HOST: "127.0.0.1", ...env }, stdio: ["ignore", "pipe", "pipe"] });
  let output = "";
  proc.stdout.on("data", (chunk) => { output += chunk; });
  proc.stderr.on("data", (chunk) => { output += chunk; });
  const exited = new Promise<number | null>((done) => proc.on("exit", (code) => done(code)));
  return { proc, exited, output: () => output };
}
async function within<V>(promise: Promise<V>, ms: number, onLate: () => void): Promise<V | "late"> {
  let timer: NodeJS.Timeout | undefined;
  const late = new Promise<"late">((done) => { timer = setTimeout(() => { onLate(); done("late"); }, ms); });
  try { return await Promise.race([promise, late]); } finally { clearTimeout(timer); }
}

test("einhaengen: prozess bricht bei falscher config ab", async (t) => {
  const dbHits: number[] = [];
  const fakeDb = createServer((socket) => { dbHits.push(1); socket.destroy(); });
  await new Promise<void>((done) => fakeDb.listen(0, "127.0.0.1", done));
  t.after(() => new Promise<void>((done) => fakeDb.close(() => done())));
  const dbUrl = `postgres://postgres@127.0.0.1:${(fakeDb.address() as { port: number }).port}/postgres`;
  const partial = { ...A_ENV };
  delete partial.APPLE_TOKEN_KEY;
  const cases: [string, Record<string, string>, RegExp][] = [
    ["APPLE_TOKEN_KEY fehlt", partial, /apple config invalid: .*APPLE_TOKEN_KEY/],
    ["Schlüssel unlesbar", { ...A_ENV, APPLE_PRIVATE_KEY: "kein-schluessel-4711" }, /apple config invalid: .*APPLE_PRIVATE_KEY/],
    ["Token-Schlüssel 16 Byte", { ...A_ENV, APPLE_TOKEN_KEY: randomBytes(16).toString("base64") }, /apple config invalid: .*APPLE_TOKEN_KEY/],
  ];
  for (const [name, env, line] of cases) {
    dbHits.length = 0;
    const run = child({ ...env, DATABASE_URL: dbUrl, PORT: String(await freePort()) });
    const code = await within(run.exited, 5000, () => run.proc.kill("SIGKILL"));
    assert.equal(code, 1, `${name}: Exit-Code`);
    assert.doesNotMatch(run.output(), /listening/, `${name}: hat gelauscht`);
    assert.equal(dbHits.length, 0, `${name}: Pool geöffnet`);
    assert.match(run.output(), line, name);
    for (const value of [...A_VALUES, ...Object.values(env)]) assert.ok(!run.output().includes(value), `${name}: Wert in der Ausgabe`);
  }
  const admin = new pg.Pool({ connectionString: databaseUrl });
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  await admin.query(`CREATE SCHEMA ${schema}`);
  t.after(async () => { await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  const url = new URL(databaseUrl!);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const port = await freePort();
  const run = child({ DATABASE_URL: url.toString(), PORT: String(port) });
  let status = 0;
  for (let i = 0; i < 100 && status !== 200; i++) {
    await new Promise((done) => setTimeout(done, 100));
    status = await fetch(`http://127.0.0.1:${port}/health`).then((answer) => answer.status, () => 0);
  }
  run.proc.kill("SIGTERM");
  assert.equal(status, 200, `ohne APPLE_* kein /health 200: ${run.output()}`);
  assert.equal(await within(run.exited, 5000, () => run.proc.kill("SIGKILL")), 0);
});

// #621 S3, AC-14: invalid issuer keys stop the process before pool and listen, naming only the variable.
test("main: ungueltige oauth schluessel brechen start ab", async (t) => {
  const dbHits: number[] = [];
  const fakeDb = createServer((socket) => { dbHits.push(1); socket.destroy(); });
  await new Promise<void>((done) => fakeDb.listen(0, "127.0.0.1", done));
  t.after(() => new Promise<void>((done) => fakeDb.close(() => done())));
  const dbUrl = `postgres://postgres@127.0.0.1:${(fakeDb.address() as { port: number }).port}/postgres`;
  const cookie = `geheim-cookie-schluessel-${randomBytes(16).toString("hex")}`;
  const jwk = JSON.stringify(generateKeyPairSync("ec", { namedCurve: "P-256" }).privateKey.export({ format: "jwk" }));
  const cases: [string, Record<string, string>, string][] = [
    ["Cookie zu kurz", { OAUTH_COOKIE_KEYS: "zu-kurz", OAUTH_SIGNING_JWK: jwk }, "OAUTH_COOKIE_KEYS"],
    ["nur JWK", { OAUTH_SIGNING_JWK: jwk }, "OAUTH_COOKIE_KEYS"],
    ["JWK ungültig", { OAUTH_COOKIE_KEYS: cookie, OAUTH_SIGNING_JWK: "geheim-kein-jwk-4711" }, "OAUTH_SIGNING_JWK"],
  ];
  for (const [name, env, variable] of cases) {
    dbHits.length = 0;
    const run = child({ ...env, DATABASE_URL: dbUrl, PORT: String(await freePort()) });
    const code = await within(run.exited, 5000, () => run.proc.kill("SIGKILL"));
    assert.equal(code, 1, `${name}: Exit-Code`);
    assert.doesNotMatch(run.output(), /listening/, `${name}: hat gelauscht`);
    assert.equal(dbHits.length, 0, `${name}: Pool geöffnet`);
    assert.ok(run.output().includes(`oauth config invalid: ${variable}`), `${name}: ${run.output()}`);
    for (const value of [cookie, "zu-kurz", "geheim-kein-jwk-4711", JSON.parse(jwk).d]) {
      assert.ok(!run.output().includes(value), `${name}: Wert in der Ausgabe`);
    }
  }
});

test("einhaengen: body ueber 1 mib 413", async (t) => {
  const probe = counter();
  const running = await service(t, { auth: {}, extraRoutes: { "/zaehler": probe.route } });
  await running.ready;
  for (const size of [MIB + 1, 2 * MIB]) {
    for (const path of ["/auth/apple", "/auth/logout", "/auth/delete", "/mcp", "/zaehler"]) {
      const sent = await sized(running.url, path, size);
      assert.ok(!("aborted" in sent), `${path} ${size}: Verbindung abgebrochen statt 413`);
      assert.equal(sent.status, 413, `${path} ${size}`);
      assert.equal(sent.body, "", `${path} ${size}`);
      assert.equal(sent.connection, "close", `${path} ${size}`);
    }
  }
  assert.equal(probe.calls, 0, "Route trotz zu großem Body aufgerufen");
  const exact = await sized(running.url, "/zaehler", MIB);
  assert.ok(!("aborted" in exact) && exact.status === 204, "genau 1 MiB geht durch");
  assert.equal(probe.maxSeen, MIB);
  // /auth/apple keeps its own 16 KiB limit, so exactly 1 MiB is shown on the other three: their route answers, not the bridge.
  for (const [path, expected] of [["/auth/logout", 401], ["/auth/delete", 401]] as const) {
    const sent = await sized(running.url, path, MIB);
    assert.ok(!("aborted" in sent) && sent.status === expected, `${path} genau 1 MiB`);
  }
  const mcp = await sized(running.url, "/mcp", MIB);
  assert.ok(!("aborted" in mcp) && mcp.status !== 413, "/mcp genau 1 MiB");
});

// Raw HTTP/1.1 with a Content-Length that claims less than is sent; resolves with all bytes the service answered.
function rawPost(url: string, path: string, claimed: number, size: number): Promise<string> {
  return new Promise((done) => {
    const socket = connect(Number(new URL(url).port), "127.0.0.1");
    let text = "";
    socket.on("data", (chunk) => { text += chunk; });
    socket.on("close", () => done(text));
    socket.on("error", () => {});
    socket.write(`POST ${path} HTTP/1.1\r\nHost: x\r\nContent-Type: application/json\r\nContent-Length: ${claimed}\r\n\r\n`);
    socket.end(Buffer.alloc(size, 0x61));
  });
}

test("einhaengen: luegende content-length", async (t) => {
  const probe = counter();
  const running = await service(t, { auth: {}, extraRoutes: { "/zaehler": probe.route } });
  await running.ready;
  const chunk = Buffer.alloc(64 * 1024, 0x61);
  const chunked = await send(running.url, "/zaehler", Array.from({ length: 20 }, () => chunk), { "content-type": "application/json" });
  assert.ok("aborted" in chunked || (chunked.status === 413 && chunked.connection === "close"), "chunked über 1 MiB");
  assert.equal(probe.calls, 0, "chunked: Route aufgerufen");
  // A Content-Length below the body: the parser hands the route only the claimed bytes, the rest is never buffered as body.
  await rawPost(running.url, "/zaehler", 100, 2 * MIB);
  assert.ok(probe.maxSeen <= MIB, `Route bekam ${probe.maxSeen} Bytes`);
  const after = await health(running.url);
  assert.equal(after.status, 200);
});

test("einhaengen: 413 kippt health nicht", async (t) => {
  const boom = async (): Promise<Response> => { throw new Error("kaputt"); };
  const running = await service(t, { auth: {}, extraRoutes: { "/boom": boom } });
  await running.ready;
  const before = (await health(running.url)).body.requests;
  for (let i = 0; i < 25; i++) {
    const sent = await sized(running.url, "/boom", MIB + 1);
    assert.ok(!("aborted" in sent) && sent.status === 413, `Anfrage ${i + 1}`);
  }
  const still = await health(running.url);
  assert.equal(still.status, 200);
  assert.equal(still.body.requests, before, "413 läuft am Fehlerfenster vorbei");
  for (let i = 0; i < 25; i++) await (await fetch(`${running.url}/boom`)).arrayBuffer();
  assert.equal((await health(running.url)).status, 503, "Gegenprobe: 25 × 500 kippen /health");
});

test("einhaengen: health und mcp nicht ueberschreibbar", async (t) => {
  const fake = async () => new Response("gefaelscht", { status: 418 });
  const running = await service(t, { auth: {}, extraRoutes: { "/health": fake, "/mcp": fake }, oauth: { verifier: tokenVerifier } } as Options);
  await running.ready;
  const { status, body } = await health(running.url);
  assert.equal(status, 200);
  assert.deepEqual(Object.keys(body).sort(), ["db", "errorRate", "migrated", "requests", "status"]);
  const bare = await fetch(`${running.url}/mcp`, { method: "POST", headers: { "content-type": "application/json" }, body: "{}" });
  assert.equal(bare.status, 401, "/mcp ohne Token 401 statt 418");
  const client = new Client({ name: "test", version: "1" });
  await client.connect(bearerTransport(running.url));
  t.after(async () => { await client.close(); });
  assert.equal(client.getServerVersion()?.name, "loose-ends");
  assert.equal((await fetch(`${running.url}/auth/logout`, { method: "POST" })).status, 401, "auth daneben eingehängt");
});

test("einhaengen: log wirft nie", async (t) => {
  const apple = fakeApple("throws");
  const running = await service(t, { auth: { config: aConfig, fetch: apple.fetch } });
  await running.ready;
  const answer = await signIn(running.url);
  assert.equal(answer.status, 200);
  const { sessionToken } = (await answer.json()) as { sessionToken: string };
  t.mock.method(console, "error", () => { throw new Error("EPIPE"); });
  await running.admin.query("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE application_name = $1", [running.applicationName]);
  await new Promise((done) => setTimeout(done, 300));
  const deleted = await withBearer(running.url, "/auth/delete", sessionToken);
  assert.equal(deleted.status, 204, "Löschen trotz werfendem Log");
  assert.ok(apple.urls.some((url) => url.endsWith("/auth/revoke")), "Widerruf versucht");
});

test("einhaengen: log ohne geheimnisse", async (t) => {
  const lines = capturedLines(t);
  const apple = fakeApple("throws");
  const running = await service(t, { auth: { config: aConfig, fetch: apple.fetch } });
  await running.ready;
  const pool = dataPool(t, running.databaseUrl);
  const answer = await signIn(running.url);
  assert.equal(answer.status, 200);
  const { sessionToken } = (await answer.json()) as { sessionToken: string };
  const account = (await resolveSession(pool, sessionToken))!;
  assert.equal((await withBearer(running.url, "/auth/delete", sessionToken)).status, 204);
  await running.close();
  assert.ok(lines.some((line) => line.endsWith(" apple revoke failed")), "Log der Auth-Routen nicht angeschlossen");
  const secrets = [sessionToken, account, A_SUB, A_CODE, A_REFRESH, A_NONCE, "netz-weg-4711", ...A_VALUES];
  for (const line of lines) {
    assert.match(line, ISO);
    for (const secret of secrets) assert.ok(!line.includes(secret), `Logzeile enthält ${secret}`);
  }
});

test("einhaengen: grenze und doku", () => {
  const doc = readFileSync(join(import.meta.dirname, "../../CLAUDE.md"), "utf8").split("\n");
  const authLine = doc.find((line) => line.includes("`src/auth.ts` (#615 S3b)")) ?? "";
  const deleteLine = doc.find((line) => line.includes("`POST /auth/delete` (#615 S3c-1)")) ?? "";
  assert.doesNotMatch(authLine, /nothing calls them yet/);
  assert.doesNotMatch(deleteLine, /nothing calls the route yet/);
  const mainLines = doc.filter((line) => line.includes("`src/main.ts`")).join("\n");
  for (const word of ["auth", "APPLE_", "1 MiB", "413", "logError"]) assert.ok(mainLines.includes(word), `CLAUDE.md main.ts-Zeile ohne ${word}`);
});
