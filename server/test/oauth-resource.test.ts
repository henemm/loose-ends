import { test } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import http from "node:http";
import { createServer } from "node:net";
import { join } from "node:path";
import pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { OAuthError, OAuthErrorCode, type AuthInfo, type OAuthTokenVerifier } from "@modelcontextprotocol/server";
import { start } from "../src/main.ts";
import { createSession, findOrCreate } from "../src/accounts.ts";
import { putTranscript } from "../src/transcripts.ts";

// Schnitt 1 of #621: the service as an OAuth protected resource (RFC 9728, RFC 8707, RFC 6750). No issuer yet.

type Doc = Record<string, any>;
type T = { after: (fn: () => Promise<void>) => void; mock: any };
type Options = Partial<Parameters<typeof start>[0]> & Record<string, unknown>;

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const ROOT = join(import.meta.dirname, "../..");
const ORIGIN = "https://loose-ends.henemm.com";
const RESOURCE = `${ORIGIN}/mcp`;
const META_PATH = "/.well-known/oauth-protected-resource/mcp";
const META = `${ORIGIN}${META_PATH}`;
const DOCUMENT = { resource: RESOURCE, authorization_servers: [ORIGIN], bearer_methods_supported: ["header"] };
const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z/;

// The module under test is loaded at run time, so a missing file fails each test on its own instead of the whole file.
const resourceModule = () => import("../src/oauth-resource.ts" as string) as Promise<Doc>;

// Each service gets its own schema (search_path in the URL) and its own application_name, so runs never meet.
async function service(t: T, options: Options = {}) {
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  const applicationName = `le-oauth-${schema.slice(2, 14)}`;
  const admin = new pg.Pool({ connectionString: databaseUrl });
  await admin.query(`CREATE SCHEMA ${schema}`);
  const url = new URL(databaseUrl!);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const running = await start({ databaseUrl: url.toString(), port: 0, migrationsDir: migrations, applicationName, ...options } as never);
  t.after(async () => {
    await running.close();
    await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  });
  return { ...running, admin, databaseUrl: url.toString() };
}

function dataPool(t: T, url: string): pg.Pool {
  const pool = new pg.Pool({ connectionString: url });
  t.after(async () => { await pool.end(); });
  return pool;
}

async function freePort(): Promise<number> {
  const probe = createServer();
  await new Promise<void>((done) => probe.listen(0, "127.0.0.1", done));
  const port = (probe.address() as { port: number }).port;
  await new Promise((done) => probe.close(done));
  return port;
}

function capturedLines(t: T): string[] {
  const lines: string[] = [];
  for (const name of ["log", "error", "warn", "info", "debug"]) {
    t.mock.method(console, name, (...args: unknown[]) => { lines.push(args.map(String).join(" ")); });
  }
  return lines;
}

const inAnHour = () => Math.floor(Date.now() / 1000) + 3600;
function info(token: string, change: Partial<AuthInfo> = {}): AuthInfo {
  return { token, clientId: "claude-test", scopes: [], expiresAt: inAnHour(), resource: new URL(RESOURCE), extra: {}, ...change };
}

// Maps a token string to its AuthInfo; anything else is an unknown token. Counts every call.
function verifier(table: Record<string, AuthInfo>) {
  const v = { calls: 0, verifyAccessToken: async (token: string): Promise<AuthInfo> => {
    v.calls++;
    const found = table[token];
    if (found === undefined) throw new OAuthError(OAuthErrorCode.InvalidToken, "unknown token");
    return found;
  } };
  return v;
}

type Raw = { status: number; headers: http.IncomingHttpHeaders; body: string };
// node:http, so the Host header can be set (fetch would refuse it).
function raw(url: string, path: string, options: { method?: string; headers?: Record<string, string>; body?: string } = {}): Promise<Raw> {
  return new Promise((done, fail) => {
    const request = http.request(`${url}${path}`, { method: options.method ?? "GET", headers: options.headers }, (answer) => {
      let body = "";
      answer.setEncoding("utf8");
      answer.on("data", (chunk) => { body += chunk; });
      answer.on("end", () => done({ status: answer.statusCode!, headers: answer.headers, body }));
    });
    request.on("error", fail);
    request.end(options.body);
  });
}

const INIT = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize",
  params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "probe", version: "1" } } });
const mcpPost = (url: string, headers: Record<string, string> = {}, host?: string) => raw(url, "/mcp", {
  method: "POST", body: INIT,
  headers: { "content-type": "application/json", accept: "application/json, text/event-stream", ...(host ? { host } : {}), ...headers },
});

function assertChallenge(answer: Raw, meta = META, name = "") {
  assert.equal(answer.status, 401, `${name}: ${answer.status} ${answer.body}`);
  const challenge = String(answer.headers["www-authenticate"] ?? "");
  assert.match(challenge, /^Bearer /, `${name}: ${challenge}`);
  assert.ok(challenge.includes(`resource_metadata="${meta}"`), `${name}: ${challenge}`);
  return challenge;
}

async function connect(t: T, url: string, token: string) {
  const client = new Client({ name: "test", version: "1" });
  await client.connect(new StreamableHTTPClientTransport(new URL(`${url}/mcp`), { requestInit: { headers: { Authorization: `Bearer ${token}` } } }));
  t.after(async () => { await client.close(); });
  return client;
}
const text = (result: Doc) => result.content.map((part: Doc) => part.text).join("");

// The contract's transcript example (first ```json block); the copy for B carries other ids throughout.
function example(): Doc {
  const blocks = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  return JSON.parse(blocks[0][1]);
}
const otherIds = (doc: Doc): Doc => JSON.parse(JSON.stringify(doc).replaceAll("6F1C2B0A", "9B9B9B9B"));
const ids = (doc: Doc): string[] => doc.tasks.map((task: Doc) => task.id);

test("oauth-resource: metadaten dokument", async (t) => {
  const running = await service(t);
  await running.ready;
  const answer = await raw(running.url, META_PATH);
  assert.equal(answer.status, 200, answer.body);
  assert.match(String(answer.headers["content-type"]), /^application\/json/);
  assert.deepEqual(JSON.parse(answer.body), DOCUMENT);
  assert.equal(answer.headers["access-control-allow-origin"], undefined);
});

test("oauth-resource: metadaten nur get", async (t) => {
  const running = await service(t);
  await running.ready;
  for (const method of ["POST", "PUT", "DELETE", "HEAD"]) {
    const answer = await raw(running.url, META_PATH, { method });
    assert.equal(answer.status, 405, method);
    assert.equal(answer.headers.allow, "GET", method);
    assert.equal(answer.body, "", method);
  }
});

test("oauth-resource: metadaten vor migrate", async (t) => {
  const port = await freePort();
  const running = await start({
    databaseUrl: `postgres://postgres@127.0.0.1:${port}/postgres`, port: 0, migrationsDir: migrations, retryMs: 50, maxAttempts: 20,
  });
  t.after(running.close);
  const refused = assert.rejects(running.ready);
  const meta = await raw(running.url, META_PATH);
  assert.equal(meta.status, 200, "Metadaten brauchen keine Datenbank");
  assert.deepEqual(JSON.parse(meta.body), DOCUMENT);
  const mcp = await mcpPost(running.url);
  assert.equal(mcp.status, 503, "vor migrate 503, nicht 401");
  assert.equal(mcp.body, "");
  await refused;
  const live = await service(t);
  await live.ready;
  assertChallenge(await mcpPost(live.url), META, "nach ready");
});

test("oauth-resource: mcp ohne token 401", async (t) => {
  const running = await service(t);
  await running.ready;
  const answer = await mcpPost(running.url);
  const challenge = assertChallenge(answer);
  assert.ok(challenge.includes('error="invalid_token"'), challenge);
  const body = JSON.parse(answer.body);
  assert.equal(body.error, "invalid_token");
  assert.equal(body.jsonrpc, undefined, "kein MCP-Antwortkörper");
  assert.equal(body.result, undefined, "kein MCP-Antwortkörper");
});

test("oauth-resource: ablehnungstabelle", async (t) => {
  const past = Math.floor(Date.now() / 1000) - 60;
  const v = verifier({
    fremd: info("fremd", { resource: new URL("https://anderer.example/mcp") }),
    ohne_resource: info("ohne_resource", { resource: undefined }),
    ohne_ablauf: info("ohne_ablauf", { expiresAt: undefined }),
    abgelaufen: info("abgelaufen", { expiresAt: past }),
  });
  const running = await service(t, { oauth: { verifier: v } });
  await running.ready;
  const cases: [string, string, RegExp | undefined][] = [
    ["(a) Basic", "Basic eDp4", undefined],
    ["(b) unbekannt", "Bearer unbekannt", undefined],
    ["(c) fremde Ressource", "Bearer fremd", /not issued for this resource/],
    ["(d) ohne Ressource", "Bearer ohne_resource", undefined],
    ["(e) ohne Ablauf", "Bearer ohne_ablauf", /no expiration time/],
    ["(f) abgelaufen", "Bearer abgelaufen", undefined],
  ];
  for (const [name, authorization, description] of cases) {
    const answer = await mcpPost(running.url, { authorization });
    const challenge = assertChallenge(answer, META, name);
    if (description) assert.match(`${challenge} ${answer.body}`, description, name);
  }
});

test("oauth-resource: verifizierer wirft 500", async (t) => {
  const lines = capturedLines(t);
  const SECRET = "geheimnis-im-fehler-4711";
  const TOKEN = "token-das-nie-ins-log-darf-4711";
  const throwing = { verifyAccessToken: async (): Promise<AuthInfo> => { throw new Error(SECRET); } };
  const running = await service(t, { oauth: { verifier: throwing } });
  await running.ready;
  const answer = await mcpPost(running.url, { authorization: `Bearer ${TOKEN}` });
  assert.equal(answer.status, 500);
  assert.equal(JSON.parse(answer.body).error, "server_error");
  const health = await (await fetch(`${running.url}/health`)).json();
  assert.ok(health.errorRate > 0, `500 nicht im Fehlerfenster: ${JSON.stringify(health)}`);
  await running.close();
  for (const line of lines) {
    assert.ok(!line.includes(TOKEN), `Token im Log: ${line}`);
    assert.ok(!line.includes(SECRET), `Ausnahmetext im Log: ${line}`);
    assert.match(line, ISO);
  }
});

test("oauth-resource: app-sitzung abgelehnt", async (t) => {
  const running = await service(t, { oauth: {} });
  await running.ready;
  const pool = dataPool(t, running.databaseUrl);
  const account = await findOrCreate(pool, "001234.app-sitzung.0815");
  const session = await createSession(pool, account);
  for (const token of [session, "irgendwas", randomUUID()]) assertChallenge(await mcpPost(running.url, { authorization: `Bearer ${token}` }), META, token);
  const bare = await service(t);
  await bare.ready;
  assertChallenge(await mcpPost(bare.url, { authorization: `Bearer ${session}` }), META, "ohne oauth-Option");
});

test("oauth-resource: konto durchgereicht", async (t) => {
  const v = verifier({});
  const running = await service(t, { oauth: { verifier: v } });
  await running.ready;
  const pool = dataPool(t, running.databaseUrl);
  const a = await findOrCreate(pool, "001234.konto-a.0815");
  const empty = await findOrCreate(pool, "001234.konto-leer.0815");
  const doc = example();
  await putTranscript(pool, a, doc);
  // Accounts exist only after migrate, so the table is filled in once the service runs.
  v.verifyAccessToken = verifier({
    "tok-a": info("tok-a", { extra: { account: a } }), "tok-leer": info("tok-leer", { extra: { account: empty } }),
  }).verifyAccessToken;
  const result: Doc = await (await connect(t, running.url, "tok-a")).callTool({ name: "get_now", arguments: {} });
  assert.notEqual(result.isError, true, text(result));
  const now = JSON.parse(text(result));
  assert.equal(now.nowCount, doc.nowCount);
  const expected = [...(doc.now.knaeuel ? [doc.now.knaeuel] : []), ...doc.now.today, ...doc.now.lined, ...doc.now.waiting];
  assert.deepEqual(now.rows.map((row: Doc) => row.id), expected);
  const none: Doc = await (await connect(t, running.url, "tok-leer")).callTool({ name: "get_now", arguments: {} });
  assert.notEqual(none.isError, true);
  assert.match(text(none), /noch keine Abschrift/);
});

test("oauth-resource: konten getrennt", async (t) => {
  const v = verifier({});
  const running = await service(t, { oauth: { verifier: v } });
  await running.ready;
  const pool = dataPool(t, running.databaseUrl);
  const a = await findOrCreate(pool, "001234.getrennt-a.0815");
  const b = await findOrCreate(pool, "001234.getrennt-b.0815");
  const docA = example();
  const docB = otherIds(example());
  await putTranscript(pool, a, docA);
  await putTranscript(pool, b, docB);
  const table = verifier({ "tok-a": info("tok-a", { extra: { account: a } }), "tok-b": info("tok-b", { extra: { account: b } }) });
  v.verifyAccessToken = table.verifyAccessToken;
  const read = async (token: string) => text(await (await connect(t, running.url, token)).callTool({ name: "get_now", arguments: {} }));
  const forA = await read("tok-a");
  const forB = await read("tok-b");
  for (const id of ids(docB)) assert.ok(!forA.includes(id), `A sieht ${id} aus B`);
  for (const id of ids(docA)) assert.ok(!forB.includes(id), `B sieht ${id} aus A`);
  assert.ok(ids(docA).some((id) => forA.includes(id)), "A sieht die eigene Abschrift nicht");
  assert.ok(ids(docB).some((id) => forB.includes(id)), "B sieht die eigene Abschrift nicht");
});

test("oauth-resource: mcp vor migrate 503", async (t) => {
  const port = await freePort();
  const v = verifier({ gut: info("gut") });
  const running = await start({
    databaseUrl: `postgres://postgres@127.0.0.1:${port}/postgres`, port: 0, migrationsDir: migrations, retryMs: 50, maxAttempts: 20,
    oauth: { verifier: v },
  } as never);
  t.after(running.close);
  const refused = assert.rejects(running.ready);
  for (const headers of [{ authorization: "Bearer gut" }, {}] as Record<string, string>[]) {
    const answer = await mcpPost(running.url, headers);
    assert.equal(answer.status, 503, JSON.stringify(headers));
    assert.equal(answer.body, "");
  }
  assert.equal(v.calls, 0, "Verifizierer vor migrate aufgerufen");
  await refused;
  const w = verifier({});
  const live = await service(t, { oauth: { verifier: w } });
  await live.ready;
  assertChallenge(await mcpPost(live.url, { authorization: "Bearer gut" }), META, "nach ready");
  assert.equal(w.calls, 1, "nach ready prüft der Verifizierer");
});

test("oauth-resource: ressource folgt public url", async (t) => {
  const local = "http://127.0.0.1";
  const localMeta = `${local}${META_PATH}`;
  const v = verifier({
    eigen: info("eigen", { resource: new URL(`${local}/mcp`), extra: {} }),
    boese: info("boese", { resource: new URL("http://evil.example/mcp") }),
  });
  const running = await service(t, { oauth: { publicUrl: local, verifier: v } });
  await running.ready;
  for (const host of [undefined, "evil.example"]) {
    const meta = await raw(running.url, META_PATH, host ? { headers: { host } } : {});
    assert.equal(meta.status, 200, String(host));
    assert.deepEqual(JSON.parse(meta.body), { resource: `${local}/mcp`, authorization_servers: [local], bearer_methods_supported: ["header"] });
    assertChallenge(await mcpPost(running.url, {}, host), localMeta, `ohne Token, Host ${host}`);
    assertChallenge(await mcpPost(running.url, { authorization: "Bearer boese" }, host), localMeta, `fremde Audience, Host ${host}`);
  }
  const accepted = await mcpPost(running.url, { authorization: "Bearer eigen" }, "evil.example");
  assert.notEqual(accepted.status, 401, "das Token der konfigurierten Ressource gilt");
});

test("oauth-resource: public url aus env", async () => {
  const { publicUrlFromEnv } = await resourceModule();
  assert.equal(typeof publicUrlFromEnv, "function", "publicUrlFromEnv fehlt");
  const ok: [string, Record<string, string | undefined>, string][] = [
    ["leer", { PUBLIC_URL: "" }, ORIGIN],
    ["fehlend", {}, ORIGIN],
    ["nur Leerzeichen", { PUBLIC_URL: "   " }, ORIGIN],
    ["Standard", { PUBLIC_URL: ORIGIN }, ORIGIN],
    ["Schrägstrich", { PUBLIC_URL: "https://example.org/" }, "https://example.org"],
    ["localhost mit Port", { PUBLIC_URL: "http://localhost:8080" }, "http://localhost:8080"],
    ["127.0.0.1", { PUBLIC_URL: "http://127.0.0.1" }, "http://127.0.0.1"],
  ];
  for (const [name, env, expected] of ok) assert.equal(publicUrlFromEnv(env), expected, name);
  const bad = ["http://example.org", "https://example.org/pfad", "https://example.org/?a=1", "https://example.org/#x",
    "https://nutzer:pw@example.org", "kein-url"];
  for (const value of bad) {
    assert.throws(() => publicUrlFromEnv({ PUBLIC_URL: value }), (error: Error) => {
      assert.equal(error.message, "PUBLIC_URL invalid", value);
      assert.ok(!error.message.includes(value), value);
      return true;
    }, value);
  }
});

// The real process: main.ts as a child, without the runner's context, any APPLE_* or PUBLIC_URL of this shell.
const MAIN = join(import.meta.dirname, "../src/main.ts");
function child(env: Record<string, string>) {
  const base = Object.fromEntries(Object.entries(process.env)
    .filter(([k]) => !k.startsWith("APPLE_") && k !== "NODE_TEST_CONTEXT" && k !== "PUBLIC_URL"));
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

test("oauth-resource: prozess bricht bei falscher public url ab", async (t) => {
  const dbHits: number[] = [];
  const fakeDb = createServer((socket) => { dbHits.push(1); socket.destroy(); });
  await new Promise<void>((done) => fakeDb.listen(0, "127.0.0.1", done));
  t.after(() => new Promise<void>((done) => fakeDb.close(() => done())));
  const dbUrl = `postgres://postgres@127.0.0.1:${(fakeDb.address() as { port: number }).port}/postgres`;
  const wrong = child({ DATABASE_URL: dbUrl, PORT: String(await freePort()), PUBLIC_URL: "http://example.org" });
  assert.equal(await within(wrong.exited, 5000, () => wrong.proc.kill("SIGKILL")), 1, wrong.output());
  assert.doesNotMatch(wrong.output(), /listening/);
  assert.equal(dbHits.length, 0, "Pool geöffnet");
  assert.match(wrong.output(), /public url invalid/);
  assert.ok(!wrong.output().includes("example.org"), wrong.output());
  const admin = new pg.Pool({ connectionString: databaseUrl });
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  await admin.query(`CREATE SCHEMA ${schema}`);
  t.after(async () => { await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  const url = new URL(databaseUrl!);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const port = await freePort();
  const run = child({ DATABASE_URL: url.toString(), PORT: String(port) });
  let meta: Raw | undefined;
  for (let i = 0; i < 100 && meta?.status !== 200; i++) {
    await new Promise((done) => setTimeout(done, 100));
    meta = await raw(`http://127.0.0.1:${port}`, META_PATH).catch(() => undefined);
  }
  run.proc.kill("SIGTERM");
  assert.equal(meta?.status, 200, `ohne PUBLIC_URL kein Dokument: ${run.output()}`);
  assert.deepEqual(JSON.parse(meta!.body), DOCUMENT);
  assert.equal(await within(run.exited, 5000, () => run.proc.kill("SIGKILL")), 0);
});

test("oauth-resource: nicht ueberschreibbar", async (t) => {
  const fake = async () => new Response("gefaelscht", { status: 418 });
  const running = await service(t, { auth: {}, extraRoutes: { [META_PATH]: fake, "/mcp": fake } });
  await running.ready;
  const meta = await raw(running.url, META_PATH);
  assert.equal(meta.status, 200);
  assert.deepEqual(JSON.parse(meta.body), DOCUMENT);
  assertChallenge(await mcpPost(running.url), META, "/mcp");
  // Since #621 S3 the issuer owns this path; without keys it answers 503 (AC-13), never the extra route.
  assert.equal((await raw(running.url, "/.well-known/oauth-authorization-server")).status, 503, "Aussteller ohne Schlüssel");
});

// Rough length check: the file split at each top-level declaration, no part over 50 lines.
function longestTopLevel(source: string): number {
  const parts = source.split(/\n(?=(?:export )?(?:async )?(?:function|const|type|class) )/);
  return Math.max(...parts.map((part) => part.trimEnd().split("\n").length));
}

// The file boundary of S1 is checked once at validation, not here: a diff against origin/main fails in a shallow CI
// checkout and on main itself after the merge.
test("oauth-resource: grenze und doku", () => {
  const resource = readFileSync(join(ROOT, "server/src/oauth-resource.ts"), "utf8");
  assert.ok(longestTopLevel(resource) <= 50, `Funktion über 50 Zeilen: ${longestTopLevel(resource)}`);
  assert.doesNotMatch(resource, /console\./, "kein console.* in oauth-resource.ts");
  const line = readFileSync(join(ROOT, "CLAUDE.md"), "utf8").split("\n").find((l) => l.includes("`src/oauth-resource.ts`")) ?? "";
  for (const word of ["publicUrlFromEnv", "401", "/.well-known/oauth-protected-resource/mcp"]) {
    assert.ok(line.includes(word), `CLAUDE.md-Zeile zu oauth-resource.ts ohne ${word}`);
  }
});
