import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, randomBytes, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import http from "node:http";
import { createServer } from "node:net";
import { join } from "node:path";
import pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { start } from "../src/main.ts";
import { createSession, deleteAccount, findOrCreate } from "../src/accounts.ts";
import { PgAdapter } from "../src/oauth-adapter.ts";
import { putTranscript } from "../src/transcripts.ts";

// Schnitt 3 of #621: the OAuth issuer (oidc-provider with CIMD) in front of /mcp, end to end against a throwaway Postgres.

type Doc = Record<string, any>;
type T = { after: (fn: () => Promise<void>) => void; mock: any };
type Options = Partial<Parameters<typeof start>[0]> & Record<string, unknown>;

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const ORIGIN = "https://loose-ends.test";
const RESOURCE = `${ORIGIN}/mcp`;
const META_PATH = "/.well-known/oauth-protected-resource/mcp";
const CID = "https://claude.ai/oauth/test-client";
const CB = "https://claude.ai/api/mcp/auth_callback";
const PROXY = { host: "loose-ends.test", "x-forwarded-proto": "https" };

// The module under test is loaded at run time, so a missing file fails each test on its own instead of the whole file.
const providerModule = () => import("../src/oauth-provider.ts" as string) as Promise<Doc>;

const COOKIE_KEY = `geheim-cookie-schluessel-${randomBytes(16).toString("hex")}`;
const jwkOf = (key: { export: (o: { format: "jwk" }) => object }) => JSON.stringify(key.export({ format: "jwk" }));
const ES256 = generateKeyPairSync("ec", { namedCurve: "P-256" });
const KEY_ENV = { OAUTH_COOKIE_KEYS: COOKIE_KEY, OAUTH_SIGNING_JWK: jwkOf(ES256.privateKey) };
const keys = async () => (await providerModule()).oauthKeysFromEnv(KEY_ENV);

// Claude's client document for each URL; every fetched URL is counted.
function cimd(extra: Record<string, Doc> = {}) {
  const docs: Record<string, Doc> = {
    [CID]: { client_id: CID, client_name: "Claude", redirect_uris: [CB], token_endpoint_auth_method: "none",
      grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] },
    ...extra,
  };
  const urls: string[] = [];
  const fetch = async (input: string | URL | Request) => {
    const url = String(input instanceof Request ? input.url : input);
    urls.push(url);
    const doc = docs[url];
    if (doc === undefined) return new Response("not found", { status: 404 });
    return new Response(JSON.stringify(doc), { status: 200, headers: { "content-type": "application/json", "cache-control": "max-age=300" } });
  };
  return { fetch, urls };
}

// login → account via findOrCreate → consent with a grant for every missing scope. Only tests hand this in.
function testInteraction(pool: () => pg.Pool, sub: string, hooks: { afterGrant?: (account: string) => Promise<void> } = {}) {
  const state = { account: undefined as string | undefined, stopped: false };
  const handle = async (provider: any, req: http.IncomingMessage, res: http.ServerResponse) => {
    if (state.stopped) return void res.writeHead(403).end();
    const details = await provider.interactionDetails(req, res);
    if (details.prompt.name === "login") {
      state.account = await findOrCreate(pool(), sub);
      return void await provider.interactionFinished(req, res, { login: { accountId: state.account } }, { mergeWithLastSubmission: false });
    }
    const grant = new provider.Grant({ clientId: details.params.client_id, accountId: details.session.accountId });
    if (details.prompt.details.missingOIDCScope) grant.addOIDCScope(details.prompt.details.missingOIDCScope.join(" "));
    for (const [resource, scopes] of Object.entries(details.prompt.details.missingResourceScopes ?? {})) {
      grant.addResourceScope(resource, (scopes as string[]).join(" "));
    }
    const grantId = await grant.save();
    if (hooks.afterGrant) { await hooks.afterGrant(details.session.accountId); state.stopped = true; }
    await provider.interactionFinished(req, res, { consent: { grantId } }, { mergeWithLastSubmission: true });
  };
  return { handle, state };
}

// Each service gets its own schema (search_path in the URL), unless it joins an existing one.
async function service(t: T, options: Options = {}, joinUrl?: string) {
  const admin = new pg.Pool({ connectionString: databaseUrl });
  let url = joinUrl;
  let schema: string | undefined;
  if (url === undefined) {
    schema = `t_${randomUUID().replaceAll("-", "")}`;
    await admin.query(`CREATE SCHEMA ${schema}`);
    const parsed = new URL(databaseUrl!);
    parsed.searchParams.set("options", `-c search_path=${schema}`);
    url = parsed.toString();
  }
  const running = await start({ databaseUrl: url, port: 0, migrationsDir: migrations, applicationName: `le-op-${randomUUID().slice(0, 8)}`,
    ...options } as never);
  const pool = new pg.Pool({ connectionString: url });
  t.after(async () => {
    await running.close();
    await pool.end();
    if (schema) await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  });
  return { ...running, pool, databaseUrl: url };
}

// A keyed service with Claude's document and, unless switched off, the test interaction for `sub`.
async function issuer(t: T, options: { sub?: string; interaction?: boolean; now?: () => number; cimd?: ReturnType<typeof cimd>;
  afterGrant?: (account: string) => Promise<void> } = {}) {
  const docs = options.cimd ?? cimd();
  let pool: pg.Pool | undefined;
  const flow = testInteraction(() => pool!, options.sub ?? `001234.${randomUUID()}.0815`, { afterGrant: options.afterGrant });
  const running = await service(t, {
    now: options.now,
    oauth: { publicUrl: ORIGIN, keys: await keys(), fetch: docs.fetch, ...(options.interaction === false ? {} : { interaction: flow.handle }) },
  });
  pool = running.pool;
  await running.ready;
  return { ...running, flow, docs };
}

type Raw = { status: number; headers: http.IncomingHttpHeaders; body: string };
// node:http, so Host and x-forwarded-proto can be set (fetch would refuse Host).
function raw(url: string, path: string, options: { method?: string; headers?: Record<string, string>; body?: string } = {}): Promise<Raw> {
  return new Promise((done, fail) => {
    const request = http.request(`${url}${path}`, { method: options.method ?? "GET", headers: { ...PROXY, ...options.headers } }, (answer) => {
      let body = "";
      answer.setEncoding("utf8");
      answer.on("data", (chunk) => { body += chunk; });
      answer.on("end", () => done({ status: answer.statusCode!, headers: answer.headers, body }));
    });
    request.on("error", fail);
    request.end(options.body);
  });
}

function pkce() {
  const verifier = randomBytes(32).toString("base64url");
  return { verifier, challenge: createHash("sha256").update(verifier).digest("base64url") };
}
const authQuery = (params: Record<string, string | undefined>) => {
  const all: Record<string, string | undefined> = { client_id: CID, redirect_uri: CB, response_type: "code", scope: "tasks offline_access",
    state: "s1", resource: RESOURCE, code_challenge_method: "S256", ...params };
  return `/oauth/auth?${new URLSearchParams(Object.entries(all).filter(([, v]) => v !== undefined) as [string, string][])}`;
};

type Trail = { steps: Raw[]; callback?: URL; last: Raw };
// Follows redirects by hand with a cookie jar until the client's callback, a page without Location, or ten steps.
async function drive(url: string, path: string, jar = new Map<string, string>(), method = "GET", body?: string): Promise<Trail> {
  const steps: Raw[] = [];
  for (let i = 0; i < 10; i++) {
    const cookie = [...jar].map(([k, v]) => `${k}=${v}`).join("; ");
    const headers: Record<string, string> = cookie ? { cookie } : {};
    if (body !== undefined) headers["content-type"] = "application/x-www-form-urlencoded";
    const answer = await raw(url, path, { method, headers, body });
    steps.push(answer);
    for (const line of [answer.headers["set-cookie"] ?? []].flat()) {
      const [pair] = line.split(";");
      const at = pair.indexOf("=");
      jar.set(pair.slice(0, at), pair.slice(at + 1));
    }
    const location = answer.headers.location;
    if (location === undefined) return { steps, last: answer };
    const next = new URL(location, ORIGIN);
    if (next.href.startsWith(CB)) return { steps, callback: next, last: answer };
    if (next.origin !== ORIGIN) return { steps, callback: next, last: answer };
    path = `${next.pathname}${next.search}`;
    method = "GET";
    body = undefined;
  }
  return { steps, last: steps.at(-1)! };
}

const form = (fields: Record<string, string>) => new URLSearchParams(fields).toString();
async function tokenCall(url: string, fields: Record<string, string>): Promise<{ status: number; body: Doc }> {
  const answer = await raw(url, "/oauth/token", { method: "POST", body: form(fields), headers: { "content-type": "application/x-www-form-urlencoded" } });
  return { status: answer.status, body: answer.body ? JSON.parse(answer.body) : {} };
}

// The full way: authorize with PKCE, the test interaction, the code at /oauth/token.
async function signIn(url: string, params: Record<string, string | undefined> = {}, tokenExtra: Record<string, string> = { resource: RESOURCE }) {
  const { verifier, challenge } = pkce();
  const trail = await drive(url, authQuery({ code_challenge: challenge, ...params }));
  const code = trail.callback?.searchParams.get("code");
  assert.ok(code, `kein Code: ${trail.steps.map((s) => `${s.status} ${s.headers.location ?? s.body.slice(0, 120)}`).join(" | ")}`);
  const token = await tokenCall(url, { grant_type: "authorization_code", code, redirect_uri: CB, client_id: CID, code_verifier: verifier, ...tokenExtra });
  return { code, verifier, token, trail };
}

const sha = (value: string) => createHash("sha256").update(value).digest();
async function rows(pool: pg.Pool, model?: string): Promise<Doc[]> {
  const result = model === undefined
    ? await pool.query("SELECT model, grant_id, account_id, consumed_at, payload FROM oauth_records")
    : await pool.query("SELECT model, grant_id, account_id, consumed_at, payload FROM oauth_records WHERE model = $1", [model]);
  return result.rows;
}

const INIT = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "initialize",
  params: { protocolVersion: "2025-11-25", capabilities: {}, clientInfo: { name: "probe", version: "1" } } });
const mcpPost = (url: string, token: string) => raw(url, "/mcp", {
  method: "POST", body: INIT,
  headers: { "content-type": "application/json", accept: "application/json, text/event-stream", authorization: `Bearer ${token}` },
});
function assertChallenge(answer: Raw, name = "") {
  assert.equal(answer.status, 401, `${name}: ${answer.status} ${answer.body}`);
  const challenge = String(answer.headers["www-authenticate"] ?? "");
  assert.ok(challenge.includes(`resource_metadata="${ORIGIN}${META_PATH}"`), `${name}: ${challenge}`);
}

async function getNow(t: T, url: string, token: string): Promise<string> {
  const client = new Client({ name: "test", version: "1" });
  await client.connect(new StreamableHTTPClientTransport(new URL(`${url}/mcp`), { requestInit: { headers: { Authorization: `Bearer ${token}` } } }));
  t.after(async () => { await client.close(); });
  const result: Doc = await client.callTool({ name: "get_now", arguments: {} });
  assert.notEqual(result.isError, true, JSON.stringify(result));
  return result.content.map((part: Doc) => part.text).join("");
}

function example(): Doc {
  const blocks = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  return JSON.parse(blocks[0][1]);
}
const otherIds = (doc: Doc): Doc => JSON.parse(JSON.stringify(doc).replaceAll("6F1C2B0A", "9B9B9B9B"));
const ids = (doc: Doc): string[] => doc.tasks.map((task: Doc) => task.id);

function capturedLines(t: T): string[] {
  const lines: string[] = [];
  for (const name of ["log", "error", "warn", "info", "debug"]) {
    t.mock.method(console, name, (...args: unknown[]) => { lines.push(args.map((a) => (typeof a === "string" ? a : JSON.stringify(a) ?? String(a))).join(" ")); });
  }
  return lines;
}
function assertClean(lines: string[], secrets: (string | undefined)[], name: string) {
  for (const line of lines) {
    for (const secret of secrets) if (secret) assert.ok(!line.includes(secret), `${name}: Wert im Log: ${line.slice(0, 160)}`);
    assert.doesNotMatch(line, /23503|violates|detail|Key \(/i, `${name}: Postgres-Fehler im Log: ${line.slice(0, 160)}`);
  }
}

async function freePort(): Promise<number> {
  const probe = createServer();
  await new Promise<void>((done) => probe.listen(0, "127.0.0.1", done));
  const port = (probe.address() as { port: number }).port;
  await new Promise((done) => probe.close(done));
  return port;
}

test("oauth-provider: metadaten unter beiden pfaden", async (t) => {
  const running = await issuer(t);
  const resource = JSON.parse((await raw(running.url, META_PATH)).body);
  for (const path of ["/.well-known/oauth-authorization-server", "/.well-known/openid-configuration"]) {
    const answer = await raw(running.url, path);
    assert.equal(answer.status, 200, `${path}: ${answer.body.slice(0, 200)}`);
    assert.match(String(answer.headers["content-type"]), /json/, path);
    const meta = JSON.parse(answer.body);
    assert.equal(meta.issuer, ORIGIN, path);
    assert.equal(meta.issuer, resource.authorization_servers[0], `${path}: issuer ≠ authorization_servers[0]`);
    assert.deepEqual(meta.code_challenge_methods_supported, ["S256"], path);
    assert.equal(meta.client_id_metadata_document_supported, true, path);
    assert.deepEqual(meta.token_endpoint_auth_methods_supported, ["none"], path);
    assert.ok(meta.authorization_endpoint.startsWith(`${ORIGIN}/oauth/`), `${path}: ${meta.authorization_endpoint}`);
    assert.ok(meta.token_endpoint.startsWith(`${ORIGIN}/oauth/`), `${path}: ${meta.token_endpoint}`);
  }
});

test("oauth-provider: voller durchlauf bis get_now", async (t) => {
  const lines = capturedLines(t);
  const running = await issuer(t);
  const other = await findOrCreate(running.pool, "001234.anderes-konto.0815");
  const doc = example();
  const otherDoc = otherIds(example());
  await putTranscript(running.pool, other, otherDoc);
  const { code, verifier, token } = await signIn(running.url);
  assert.equal(token.status, 200, JSON.stringify(token.body));
  assert.ok(token.body.access_token, "kein access_token");
  assert.ok(token.body.refresh_token, "kein refresh_token");
  assert.equal(token.body.token_type, "Bearer");
  assert.equal(token.body.scope, "tasks");
  const account = running.flow.state.account!;
  assert.ok(account, "Test-Interaction hat kein Konto angelegt");
  await putTranscript(running.pool, account, doc);
  const now = await getNow(t, running.url, token.body.access_token);
  assert.ok(ids(doc).some((id) => now.includes(id)), "eigene Abschrift fehlt");
  for (const id of ids(otherDoc)) assert.ok(!now.includes(id), `fremdes Konto sichtbar: ${id}`);
  const all = await rows(running.pool);
  for (const model of ["Grant", "AccessToken", "RefreshToken", "Session"]) {
    assert.ok(all.some((row) => row.model === model && row.account_id === account), `${model}-Zeile mit Konto fehlt`);
  }
  const codes = all.filter((row) => row.model === "AuthorizationCode");
  assert.equal(codes.length, 1, "genau ein Code");
  assert.ok(codes[0].consumed_at, "consumed_at des Codes nicht gesetzt");
  assertClean(lines, [token.body.access_token, token.body.refresh_token, code, verifier, account, COOKIE_KEY], "durchlauf");
});

test("oauth-provider: code nur einmal", async (t) => {
  const running = await issuer(t);
  const { code, verifier, token } = await signIn(running.url);
  assert.equal(token.status, 200, JSON.stringify(token.body));
  const before = (await rows(running.pool, "AccessToken")).length;
  const grantId = (await rows(running.pool, "AccessToken"))[0].grant_id;
  assert.ok(grantId, "AccessToken ohne grant_id");
  const again = await tokenCall(running.url, { grant_type: "authorization_code", code, redirect_uri: CB, client_id: CID, code_verifier: verifier, resource: RESOURCE });
  assert.equal(again.status, 400, JSON.stringify(again.body));
  assert.equal(again.body.error, "invalid_grant");
  assert.ok((await rows(running.pool, "AccessToken")).length <= before, "zweiter Code hat ein Token erzeugt");
  assertChallenge(await mcpPost(running.url, token.body.access_token), "erstes Token nach Wiederholung");
  const refresh = await tokenCall(running.url, { grant_type: "refresh_token", refresh_token: token.body.refresh_token, client_id: CID });
  assert.equal(refresh.status, 400, JSON.stringify(refresh.body));
  assert.equal(refresh.body.error, "invalid_grant");
  const left = (await rows(running.pool)).filter((row) => ["AccessToken", "RefreshToken"].includes(row.model) && row.grant_id === grantId);
  assert.equal(left.length, 0, "Token-Zeilen der widerrufenen Erlaubnis übrig");
});

test("oauth-provider: ohne pkce abgelehnt", async (t) => {
  const running = await issuer(t);
  const { challenge } = pkce();
  const cases: [string, Record<string, string | undefined>][] = [
    ["ohne code_challenge", { code_challenge: undefined, code_challenge_method: undefined }],
    ["plain", { code_challenge: challenge, code_challenge_method: "plain" }],
  ];
  for (const [name, params] of cases) {
    const trail = await drive(running.url, authQuery(params));
    assert.ok(trail.callback?.href.startsWith(CB), `${name}: kein Rücksprung: ${trail.last.status} ${trail.last.body.slice(0, 160)}`);
    assert.equal(trail.callback!.searchParams.get("error"), "invalid_request", name);
    assert.equal(trail.callback!.searchParams.get("code"), null, name);
  }
  const all = await rows(running.pool);
  assert.ok(!all.some((row) => row.model === "AuthorizationCode"), "Code entstanden");
  assert.ok(!all.some((row) => row.account_id !== null), "Zeile mit Konto entstanden");
  assert.equal(running.flow.state.account, undefined, "Interaction wurde erreicht");
});

test("oauth-provider: cimd und resource streng", async (t) => {
  const MISMATCH = "https://claude.ai/oauth/falsche-id";
  const SECRET = "https://claude.ai/oauth/mit-secret";
  const docs = cimd({
    [MISMATCH]: { client_id: CID, redirect_uris: [CB], token_endpoint_auth_method: "none" },
    [SECRET]: { client_id: SECRET, redirect_uris: [CB], token_endpoint_auth_method: "client_secret_basic" },
  });
  const running = await issuer(t, { cimd: docs });
  const { challenge } = pkce();
  const refused: [string, Record<string, string>][] = [
    ["fremder Host", { client_id: "https://evil.example/client" }],
    ["kein https", { client_id: "http://claude.ai/oauth/test-client" }],
    ["client_id ≠ URL", { client_id: MISMATCH }],
    ["client_secret_basic", { client_id: SECRET }],
    ["fremder Rücksprung", { redirect_uri: "https://evil.example/cb" }],
  ];
  for (const [name, params] of refused) {
    const trail = await drive(running.url, authQuery({ code_challenge: challenge, ...params }));
    assert.equal(trail.callback, undefined, `${name}: Rücksprung nach ${trail.callback?.href}`);
    assert.ok(trail.last.status >= 400 && trail.last.status < 500, `${name}: ${trail.last.status}`);
  }
  const evil = await drive(running.url, authQuery({ code_challenge: challenge, client_id: "https://evil.example/client" }));
  assert.match(evil.last.body, /invalid_client/, "fremder Host: kein invalid_client");
  assert.ok(!docs.urls.some((url) => url.includes("evil.example")), `fetch für fremden Host: ${docs.urls.join(", ")}`);
  for (const resource of [`${ORIGIN}/andere`, "https://evil.example/mcp"]) {
    const trail = await drive(running.url, authQuery({ code_challenge: challenge, resource }));
    assert.ok(trail.callback?.href.startsWith(CB), `${resource}: kein Rücksprung: ${trail.last.status} ${trail.last.body.slice(0, 160)}`);
    assert.equal(trail.callback!.searchParams.get("error"), "invalid_target", resource);
    assert.equal(trail.callback!.searchParams.get("code"), null, resource);
  }
  const { token } = await signIn(running.url, { resource: undefined }, {});
  assert.equal(token.status, 200, JSON.stringify(token.body));
  const access = (await rows(running.pool, "AccessToken")).at(-1)!;
  assert.equal(access.payload.aud, RESOURCE, "Standardressource gilt nicht");
});

test("oauth-provider: vor bridge und im fehlerfenster", async (t) => {
  const running = await issuer(t);
  const { token } = await signIn(running.url);
  assert.equal(token.status, 200, `Körper kam nicht ungelesen an: ${JSON.stringify(token.body)}`);
  const big = form({ grant_type: "authorization_code", code: "x", client_id: CID, padding: "a".repeat(100 * 1024) });
  const large = await raw(running.url, "/oauth/token", { method: "POST", body: big, headers: { "content-type": "application/x-www-form-urlencoded" } });
  assert.ok(large.status >= 400 && large.status < 500, `über 56 KiB: ${large.status}`);
  assert.ok(large.body.length > 0 && JSON.parse(large.body).error, `über 56 KiB nicht von der Bibliothek beantwortet: ${large.status} ${large.body}`);
  assert.notEqual(large.headers.connection, "close", "die Brücke hat geantwortet");
  assert.equal((await raw(running.url, "/health")).status, 200, "vor der Fehlerserie");
  await running.pool.query("ALTER TABLE oauth_records RENAME TO oauth_records_weg");
  for (let i = 0; i < 20; i++) {
    const broken = await tokenCall(running.url, { grant_type: "authorization_code", code: `code-${i}`, redirect_uri: CB, client_id: CID, code_verifier: "v".repeat(43) });
    assert.ok(broken.status >= 500, `erzwungener server_error ${i}: ${broken.status}`);
  }
  for (let i = 0; i < 5; i++) await raw(running.url, "/health");
  assert.equal((await raw(running.url, "/health")).status, 503, "Fehlerfenster zählt Aussteller-Antworten nicht");
  await running.pool.query("ALTER TABLE oauth_records_weg RENAME TO oauth_records");
});

test("oauth-provider: refresh rotiert, altes invalid_grant", async (t) => {
  const running = await issuer(t);
  const { token } = await signIn(running.url);
  assert.equal(token.status, 200, JSON.stringify(token.body));
  const fresh = await tokenCall(running.url, { grant_type: "refresh_token", refresh_token: token.body.refresh_token, client_id: CID, resource: RESOURCE });
  assert.equal(fresh.status, 200, JSON.stringify(fresh.body));
  assert.ok(fresh.body.access_token && fresh.body.access_token !== token.body.access_token, "kein neues access_token");
  assert.ok(fresh.body.refresh_token && fresh.body.refresh_token !== token.body.refresh_token, "kein neues refresh_token");
  await putTranscript(running.pool, running.flow.state.account!, example());
  await getNow(t, running.url, fresh.body.access_token);
  const old = await tokenCall(running.url, { grant_type: "refresh_token", refresh_token: token.body.refresh_token, client_id: CID });
  assert.equal(old.status, 400, JSON.stringify(old.body));
  assert.equal(old.body.error, "invalid_grant");
});

test("oauth-provider: verifizierer streng", async (t) => {
  const clock = { offset: 0 };
  const running = await issuer(t, { now: () => Date.now() + clock.offset });
  const issue = async () => {
    const { token } = await signIn(running.url);
    assert.equal(token.status, 200, JSON.stringify(token.body));
    return token.body.access_token as string;
  };
  const edit = (token: string, change: string) =>
    running.pool.query(`UPDATE oauth_records SET ${change} WHERE model = 'AccessToken' AND id_hash = $1`, [sha(token)]);
  const valid = await issue();
  assert.equal((await mcpPost(running.url, valid)).status, 200, "gültiges Token abgelehnt");
  assertChallenge(await mcpPost(running.url, randomBytes(32).toString("base64url")), "unbekannt");
  const expired = await issue();
  clock.offset = 2 * 3600 * 1000;
  assertChallenge(await mcpPost(running.url, expired), "abgelaufen");
  clock.offset = 0;
  const foreign = await issue();
  await edit(foreign, `payload = jsonb_set(payload, '{aud}', '"https://evil.example/mcp"')`);
  assertChallenge(await mcpPost(running.url, foreign), "fremde aud");
  const anonymous = await issue();
  await edit(anonymous, "payload = payload - 'accountId', account_id = NULL");
  assertChallenge(await mcpPost(running.url, anonymous), "ohne accountId");
  const revoked = await issue();
  const grant = (await running.pool.query("SELECT grant_id FROM oauth_records WHERE model = 'AccessToken' AND id_hash = $1", [sha(revoked)])).rows[0].grant_id;
  await new PgAdapter(running.pool, "AccessToken").revokeByGrantId(grant);
  assertChallenge(await mcpPost(running.url, revoked), "widerrufen");
  const gone = await issue();
  await deleteAccount(running.pool, running.flow.state.account!);
  assertChallenge(await mcpPost(running.url, gone), "Konto gelöscht");
});

test("oauth-provider: app-sitzung an mcp weiter 401", async (t) => {
  const running = await issuer(t);
  const account = await findOrCreate(running.pool, "001234.app-sitzung.0815");
  const session = await createSession(running.pool, account);
  assertChallenge(await mcpPost(running.url, session), "Sitzungstoken");
  const stored = (await running.pool.query("SELECT token_hash FROM sessions WHERE account_id = $1", [account])).rows[0].token_hash as Buffer;
  for (const value of [stored.toString("hex"), stored.toString("base64url")]) assertChallenge(await mcpPost(running.url, value), "Hash der Sitzung");
});

test("oauth-provider: produkt-interaction meldet niemanden an", async (t) => {
  const running = await issuer(t, { interaction: false });
  const { challenge } = pkce();
  const jar = new Map<string, string>();
  const trail = await drive(running.url, authQuery({ code_challenge: challenge }), jar);
  const landed = trail.steps.at(-1)!;
  const interactionStep = trail.steps.map((s) => s.headers.location).find((l) => l?.includes("/oauth/interaction/"));
  assert.ok(interactionStep, `keine Weiterleitung zur Interaction: ${trail.steps.map((s) => s.status).join(",")}`);
  const uid = new URL(interactionStep!, ORIGIN).pathname.split("/").at(-1)!;
  assert.equal(landed.status, 501, `GET: ${landed.status} ${landed.body.slice(0, 160)}`);
  const path = new URL(interactionStep!, ORIGIN).pathname;
  for (const [method, body] of [["POST", form({ login: "henning", password: "geheim" })], ["POST", form({ prompt: "consent" })]] as const) {
    const answer = (await drive(running.url, path, jar, method, body)).steps[0];
    assert.equal(answer.status, 501, `${method}: ${answer.status}`);
  }
  for (const page of [landed.body]) {
    assert.ok(!page.includes(uid) && !page.includes(CID) && !page.includes(challenge), `Text mit Werten: ${page.slice(0, 160)}`);
  }
  const all = await rows(running.pool);
  for (const model of ["Grant", "AuthorizationCode", "AccessToken", "RefreshToken"]) {
    assert.ok(!all.some((row) => row.model === model), `${model} entstanden`);
  }
  assert.ok(all.every((row) => row.account_id === null), "Zeile mit Konto");
  const made = await tokenCall(running.url, { grant_type: "authorization_code", code: randomBytes(32).toString("base64url"), redirect_uri: CB,
    client_id: CID, code_verifier: "v".repeat(43) });
  assert.equal(made.body.error, "invalid_grant", JSON.stringify(made.body));
});

// Spec AC-11 names provider.configuration(); oidc-provider 9.13.3 has no public accessor for it, so the switch is
// proven by its effects: no devInteractions warning, the interaction URL stays ours, and no library form anywhere.
test("oauth-provider: dev interactions aus", async (t) => {
  const lines = capturedLines(t);
  const running = await issuer(t, { interaction: false });
  const { challenge } = pkce();
  const first = await raw(running.url, authQuery({ code_challenge: challenge }));
  assert.ok(String(first.headers.location).includes("/oauth/interaction/"), `Interaction-URL nicht unsere: ${first.status} ${first.headers.location}`);
  for (const [method, path] of [["GET", "/oauth/interaction/anything"], ["POST", "/oauth/interaction/anything/login"],
    ["POST", "/oauth/interaction/anything/confirm"], ["GET", "/interaction/anything"]] as const) {
    const answer = await raw(running.url, path, { method, body: method === "POST" ? form({ login: "a", password: "b" }) : undefined,
      headers: method === "POST" ? { "content-type": "application/x-www-form-urlencoded" } : {} });
    assert.notEqual(answer.status, 200, `${method} ${path}`);
    assert.doesNotMatch(answer.body, /<form/i, `${method} ${path}: Formular`);
  }
  assert.ok(!lines.some((line) => /devInteractions/.test(line)), `devInteractions an: ${lines.join(" | ")}`);
});

test("oauth-provider: schluessel aus der umgebung", async () => {
  const { oauthKeysFromEnv } = await providerModule();
  const second = `zweiter-cookie-schluessel-${randomBytes(16).toString("hex")}`;
  const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const p384 = generateKeyPairSync("ec", { namedCurve: "P-384" });
  const publicJwk = jwkOf(ES256.publicKey);
  assert.equal(oauthKeysFromEnv({}), undefined, "(a) keine Variable");
  assert.equal(oauthKeysFromEnv({ OAUTH_COOKIE_KEYS: " ", OAUTH_SIGNING_JWK: "" }), undefined, "(a) leer zählt als ungesetzt");
  const one = oauthKeysFromEnv(KEY_ENV);
  assert.equal(typeof one, "object", "(b) beide gültig");
  assert.deepEqual(one.cookieKeys, [COOKIE_KEY], "(b) cookieKeys");
  assert.equal(one.signingJwk.d, JSON.parse(KEY_ENV.OAUTH_SIGNING_JWK).d, "(b) privater Schlüssel");
  assert.deepEqual(oauthKeysFromEnv({ ...KEY_ENV, OAUTH_COOKIE_KEYS: `${COOKIE_KEY},${second}` }).cookieKeys, [COOKIE_KEY, second], "(b) Liste");
  const cases: [string, Record<string, string>, string][] = [
    ["(c) nur Cookie", { OAUTH_COOKIE_KEYS: COOKIE_KEY }, "OAUTH_SIGNING_JWK"],
    ["(c) nur JWK", { OAUTH_SIGNING_JWK: KEY_ENV.OAUTH_SIGNING_JWK }, "OAUTH_COOKIE_KEYS"],
    ["(d) Cookie zu kurz", { ...KEY_ENV, OAUTH_COOKIE_KEYS: "geheim-cookie-kurz-4711" }, "OAUTH_COOKIE_KEYS"],
    ["(d) zweiter Cookie zu kurz", { ...KEY_ENV, OAUTH_COOKIE_KEYS: `${COOKIE_KEY},geheim-kurz-0815` }, "OAUTH_COOKIE_KEYS"],
    ["(d) kein JSON", { ...KEY_ENV, OAUTH_SIGNING_JWK: "geheim-kein-json-4711" }, "OAUTH_SIGNING_JWK"],
    ["(d) öffentlich", { ...KEY_ENV, OAUTH_SIGNING_JWK: publicJwk }, "OAUTH_SIGNING_JWK"],
    ["(d) RSA", { ...KEY_ENV, OAUTH_SIGNING_JWK: jwkOf(rsa.privateKey) }, "OAUTH_SIGNING_JWK"],
    ["(d) P-384", { ...KEY_ENV, OAUTH_SIGNING_JWK: jwkOf(p384.privateKey) }, "OAUTH_SIGNING_JWK"],
  ];
  for (const [name, env, variable] of cases) {
    assert.throws(() => oauthKeysFromEnv(env), (error: Error) => {
      assert.ok(error.message.includes(variable), `${name}: ${error.message}`);
      for (const value of Object.values(env)) {
        for (const part of [value, ...value.split(","), ...Object.values(JSON.parse(value.startsWith("{") ? value : "{}")).map(String)]) {
          if (part.length >= 8) assert.ok(!error.message.includes(part), `${name}: Wert in der Meldung`);
        }
      }
      return true;
    }, name);
  }
});

test("oauth-provider: ohne schluessel 503 und mcp bleibt zu", async (t) => {
  const keyed = await issuer(t);
  const { token } = await signIn(keyed.url);
  assert.equal(token.status, 200, JSON.stringify(token.body));
  const bare = await service(t, { oauth: { publicUrl: ORIGIN } }, keyed.databaseUrl);
  await bare.ready;
  const { challenge } = pkce();
  const answers = [await raw(bare.url, "/.well-known/oauth-authorization-server"), await raw(bare.url, "/.well-known/openid-configuration"),
    await raw(bare.url, authQuery({ code_challenge: challenge })),
    await raw(bare.url, "/oauth/token", { method: "POST", body: form({ grant_type: "authorization_code", code: "x" }),
      headers: { "content-type": "application/x-www-form-urlencoded" } })];
  for (const answer of answers) {
    assert.equal(answer.status, 503, `${answer.status} ${answer.body.slice(0, 120)}`);
    assert.equal(answer.body, "");
  }
  assertChallenge(await mcpPost(bare.url, token.body.access_token), "gültiges Token ohne Schlüssel");
  assertChallenge(await mcpPost(bare.url, "beliebig"), "beliebig");
  const meta = await raw(bare.url, META_PATH);
  assert.equal(meta.status, 200);
  assert.deepEqual(JSON.parse(meta.body).authorization_servers, [ORIGIN]);
  assert.equal((await raw(bare.url, "/health")).status, 200);
});

test("oauth-provider: 503 vor migrate", async (t) => {
  const port = await freePort();
  const running = await start({
    databaseUrl: `postgres://postgres@127.0.0.1:${port}/postgres`, port: 0, migrationsDir: migrations, retryMs: 50, maxAttempts: 40,
    oauth: { publicUrl: ORIGIN, keys: await keys(), fetch: cimd().fetch },
  } as never);
  t.after(running.close);
  const refused = assert.rejects(running.ready);
  for (const answer of [await raw(running.url, "/.well-known/oauth-authorization-server"), await raw(running.url, "/.well-known/openid-configuration"),
    await raw(running.url, "/oauth/token", { method: "POST", body: form({ grant_type: "authorization_code", code: "x" }),
      headers: { "content-type": "application/x-www-form-urlencoded" } })]) {
    assert.equal(answer.status, 503, `${answer.status} ${answer.body.slice(0, 120)}`);
    assert.equal(answer.body, "");
  }
  const meta = await raw(running.url, META_PATH);
  assert.equal(meta.status, 200, "Metadaten der Ressource brauchen keine Datenbank");
  assert.equal((await raw(running.url, "/health")).status, 503);
  await refused;
  await running.close();
  const live = await issuer(t);
  assert.equal((await raw(live.url, "/.well-known/oauth-authorization-server")).status, 200, "nach migrate fachlich");
  assert.equal((await signIn(live.url)).token.status, 200, "nach migrate Durchlauf");
});

test("oauth-provider: nichts im log, auch nicht beim fk fehler", async (t) => {
  const lines = capturedLines(t);
  let deleted: string | undefined;
  let pool: pg.Pool | undefined;
  const running = await issuer(t, { afterGrant: async (account) => { deleted = account; await deleteAccount(pool!, account); } });
  pool = running.pool;
  const { verifier, challenge } = pkce();
  const trail = await drive(running.url, authQuery({ code_challenge: challenge }));
  assert.ok(deleted, "Konto wurde nicht zwischen Anmeldung und Grant gelöscht");
  assert.equal(trail.callback?.searchParams.get("code") ?? null, null, `Code trotz gelöschtem Konto: ${trail.callback?.href}`);
  const all = await rows(running.pool);
  for (const model of ["AuthorizationCode", "AccessToken", "RefreshToken"]) assert.ok(!all.some((row) => row.model === model), `${model} entstanden`);
  const pages = trail.steps.map((s) => s.body).join("\n");
  assert.ok(!pages.includes(deleted!), "Konto-ID in einer Antwort");
  assert.doesNotMatch(pages, /23503|violates|Key \(/, "Postgres-Fehler in einer Antwort");
  assertClean(lines, [deleted, verifier, challenge, COOKIE_KEY, JSON.parse(KEY_ENV.OAUTH_SIGNING_JWK).d], "fk fehler");
});

test("oauth-provider: abhaengigkeit exakt gepinnt", () => {
  const manifest = JSON.parse(readFileSync(join(import.meta.dirname, "../package.json"), "utf8"));
  assert.equal(manifest.dependencies?.["oidc-provider"], "9.13.3");
  assert.equal(manifest.devDependencies?.["@types/oidc-provider"], "9.13.1");
  assert.equal(manifest.dependencies?.["@types/oidc-provider"], undefined, "Typen nur als Dev-Abhängigkeit");
});
