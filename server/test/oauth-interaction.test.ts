import { after, before, test } from "node:test";
import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, randomBytes, randomUUID, sign } from "node:crypto";
import http from "node:http";
import { join } from "node:path";
import pg from "pg";
import { findOrCreate } from "../src/accounts.ts";
import { loadAppleConfig } from "../src/apple.ts";
import { start } from "../src/main.ts";
import { PgAdapter } from "../src/oauth-adapter.ts";
import { oauthKeysFromEnv, productInteraction } from "../src/oauth-provider.ts";

// Schnitt 4b-1 of #621: the issuer's login interaction sends the browser to Apple, end to end against a throwaway Postgres.
// oidc-provider's interactionDetails reads the uid from the cookie only and never compares it with the path, so
// "another interaction's cookie" and "unknown uid" (AC-7) need the module's own check: details.uid must equal the path's uid.

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
const PROXY = { host: "loose-ends.test", "x-forwarded-proto": "https" };

// The module under test is loaded at run time, so a missing file fails each test on its own instead of the whole file.
const interactionModule = () => import("../src/oauth-interaction.ts" as string) as Promise<Doc>;

const COOKIE_KEY = `geheim-cookie-schluessel-${randomBytes(16).toString("hex")}`;
const ES256 = generateKeyPairSync("ec", { namedCurve: "P-256" });
const keys = oauthKeysFromEnv({ OAUTH_COOKIE_KEYS: COOKIE_KEY, OAUTH_SIGNING_JWK: JSON.stringify(ES256.privateKey.export({ format: "jwk" })) })!;
const rsa = generateKeyPairSync("rsa", { modulusLength: 2048 });
const JWK = { ...rsa.publicKey.export({ format: "jwk" }), kid: "H1", alg: "RS256", use: "sig" };
const ENV = {
  APPLE_TEAM_ID: "TEAMHIN001", APPLE_KEY_ID: "KEYHIN0001", APPLE_CLIENT_IDS: APP,
  APPLE_PRIVATE_KEY: (generateKeyPairSync("ec", { namedCurve: "P-256" }).privateKey.export({ type: "pkcs8", format: "pem" }) as string).replace(/\n/g, "\\n"),
  APPLE_TOKEN_KEY: randomBytes(32).toString("base64"),
};
const appOnly = loadAppleConfig(ENV);
const withWeb = loadAppleConfig({ ...ENV, APPLE_WEB_CLIENT_ID: WEB });

// Claude's client document and fake Apple behind counting fetches; Apple's authorize page is never fetched.
const cimdFetch = (async (input: string | URL | Request) => {
  const url = String(input instanceof Request ? input.url : input);
  if (url !== CID) return new Response("not found", { status: 404 });
  return Response.json({ client_id: CID, client_name: "Claude", redirect_uris: [CB], token_endpoint_auth_method: "none",
    grant_types: ["authorization_code", "refresh_token"], response_types: ["code"] });
}) as typeof fetch;
function fakeApple() {
  const urls: string[] = [];
  const fetch = (async (input: string | URL) => {
    urls.push(String(input));
    if (String(input) === KEYS_URL) return Response.json({ keys: [JWK] });
    return Response.json({ refresh_token: "REFRESH-HIN-4711", id_token: idToken() });
  }) as unknown as typeof globalThis.fetch;
  return { urls, fetch, keyCalls: () => urls.filter((url) => url === KEYS_URL).length };
}
const seg = (x: unknown) => Buffer.from(JSON.stringify(x)).toString("base64url");
function idToken(): string {
  const now = Math.floor(Date.now() / 1000);
  const nonce = createHash("sha256").update("nonce-hin-4711").digest("hex");
  const data = `${seg({ alg: "RS256", kid: "H1" })}.${seg({ iss: "https://appleid.apple.com", aud: APP, sub: "001234.hin.0815", iat: now, exp: now + 600, nonce })}`;
  return `${data}.${sign("sha256", Buffer.from(data), rsa.privateKey).toString("base64url")}`;
}

// A clock the test can move; the library's own clock keeps real time.
const clock = () => { const c = { offset: 0, now: () => Date.now() + c.offset }; return c; };

// Each service gets its own schema (search_path in the URL).
async function service(t: T, options: { auth?: Doc; interaction?: (pool: () => pg.Pool) => any; now?: () => number } = {}) {
  const admin = new pg.Pool({ connectionString: databaseUrl });
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  await admin.query(`CREATE SCHEMA ${schema}`);
  const parsed = new URL(databaseUrl!);
  parsed.searchParams.set("options", `-c search_path=${schema}`);
  let pool: pg.Pool | undefined;
  const interaction = options.interaction?.(() => pool!);
  const running = await start({ databaseUrl: parsed.toString(), port: 0, migrationsDir: migrations, now: options.now,
    applicationName: `le-hin-${randomUUID().slice(0, 8)}`, auth: options.auth as never,
    oauth: { publicUrl: ORIGIN, keys, fetch: cimdFetch, ...(interaction ? { interaction } : {}) } });
  pool = new pg.Pool({ connectionString: parsed.toString() });
  t.after(async () => { await running.close(); await pool!.end(); await admin.query(`DROP SCHEMA ${schema} CASCADE`); await admin.end(); });
  await running.ready;
  return { ...running, pool };
}

type Raw = { status: number; headers: http.IncomingHttpHeaders; body: string };
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
const cookiesOf = (answer: Raw) => [answer.headers["set-cookie"] ?? []].flat().map((line) => line.split(";")[0]).join("; ");
// Later cookies replace earlier ones of the same name, as a browser's jar would.
const jar = (...cookies: string[]) =>
  [...new Map(cookies.join("; ").split("; ").filter(Boolean).map((pair) => [pair.split("=")[0], pair])).values()].join("; ");

// /oauth/auth with PKCE until the issuer's redirect to its interaction: the uid, its path and the cookies it set.
async function begin(url: string) {
  const challenge = createHash("sha256").update(randomBytes(32).toString("base64url")).digest("base64url");
  const query = new URLSearchParams({ client_id: CID, redirect_uri: CB, response_type: "code", scope: "tasks offline_access",
    state: "s1", resource: `${ORIGIN}/mcp`, code_challenge: challenge, code_challenge_method: "S256" });
  const answer = await raw(url, `/oauth/auth?${query}`);
  const location = new URL(String(answer.headers.location), ORIGIN);
  assert.ok(location.pathname.startsWith("/oauth/interaction/"), `keine Interaktion: ${answer.status} ${answer.body.slice(0, 160)}`);
  return { uid: location.pathname.split("/").at(-1)!, path: location.pathname, cookie: cookiesOf(answer) };
}
const visit = (url: string, at: { path: string; cookie: string }, cookie = at.cookie) =>
  raw(url, at.path, cookie ? { headers: { cookie } } : {});

async function appleRows(pool: pg.Pool): Promise<Doc[]> {
  return (await pool.query("SELECT * FROM oauth_records WHERE model = 'AppleLogin'")).rows;
}
const sha = (value: string) => createHash("sha256").update(value).digest();
const shaHex = (value: string) => createHash("sha256").update(value).digest("hex");
const appleParams = (answer: Raw) => new URL(String(answer.headers.location)).searchParams;
function assertFixed(answer: Raw, status: number, body: string, name: string) {
  assert.equal(answer.status, status, `${name}: ${answer.status} ${answer.body.slice(0, 160)}`);
  assert.equal(answer.body, body, name);
  assert.equal(answer.headers["cache-control"], "no-store", name);
  assert.equal(answer.headers.location, undefined, `${name}: Weiterleitung`);
}

// Only in tests: finishes login with an account, hands every later prompt to appleInteraction (AC-5, AC-8, AC-10).
function loginThenApple(build: (pool: pg.Pool) => Promise<any>) {
  return (pool: () => pg.Pool) => async (provider: any, req: http.IncomingMessage, res: http.ServerResponse) => {
    const details = await provider.interactionDetails(req, res).catch(() => undefined);
    if (details?.prompt.name === "login") {
      const accountId = await findOrCreate(pool(), `001234.${randomUUID()}.0815`);
      return void await provider.interactionFinished(req, res, { login: { accountId } }, { mergeWithLastSubmission: false });
    }
    return (await build(pool()))(provider, req, res);
  };
}
const appleWith = (over: Doc = {}) => async (pool: pg.Pool) => (await interactionModule()).appleInteraction({
  pool, config: withWeb, publicUrl: ORIGIN, now: () => new Date(), fallback: productInteraction, keys: async () => "unknown_kid", log: () => {}, ...over,
});
// From /oauth/auth through the helper's login to the consent interaction; the answer there and where it was.
async function toConsent(url: string) {
  const first = await begin(url);
  const finished = await visit(url, first);
  const resumed = await raw(url, new URL(String(finished.headers.location), ORIGIN).pathname, { headers: { cookie: jar(first.cookie, cookiesOf(finished)) } });
  const at = { path: new URL(String(resumed.headers.location), ORIGIN).pathname, cookie: jar(first.cookie, cookiesOf(finished), cookiesOf(resumed)) };
  assert.ok(at.path.startsWith("/oauth/interaction/"), `keine zweite Interaktion: ${resumed.status} ${resumed.body.slice(0, 160)}`);
  return { at, answer: await visit(url, at) };
}

// Over the whole file (AC-9): only fixed event names reach the output, never a value seen in a test.
const secrets = new Set<string>([COOKIE_KEY, WEB]);
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
after(() => {
  for (const undo of restore.reverse()) undo();
  for (const line of lines) {
    assert.match(line, /^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z [a-z][a-z ,]*(\(\d+\/\d+\))?$/, `kein festes Ereignis: ${line.slice(0, 160)}`);
    for (const secret of secrets) assert.ok(!line.includes(secret), `Wert im Log: ${line.slice(0, 160)}`);
  }
});
function remember(answer: Raw, at?: { uid?: string; cookie?: string }) {
  for (const value of [at?.uid, ...(at?.cookie ?? "").split("; ").map((pair) => pair.split("=")[1])]) if (value) secrets.add(value);
  if (answer.headers.location) { const p = appleParams(answer); for (const k of ["state", "nonce"]) if (p.get(k)) secrets.add(p.get(k)!); secrets.add(String(answer.headers.location)); }
}

test("hinweg: login leitet mit allen parametern zu apple", async (t) => {
  const running = await service(t, { auth: { config: withWeb } });
  const at = await begin(running.url);
  const answer = await visit(running.url, at);
  remember(answer, at);
  assert.equal(answer.status, 303, `${answer.status} ${answer.body.slice(0, 160)}`);
  assert.ok(String(answer.headers.location).startsWith("https://appleid.apple.com/auth/authorize?"), String(answer.headers.location));
  const params = appleParams(answer);
  assert.deepEqual([...params.keys()].sort(), ["client_id", "nonce", "redirect_uri", "response_mode", "response_type", "state"]);
  assert.equal(params.get("client_id"), WEB);
  assert.equal(params.get("redirect_uri"), `${ORIGIN}/oauth/apple/return`);
  assert.equal(params.get("response_type"), "code");
  assert.equal(params.get("response_mode"), "form_post");
  assert.match(params.get("state")!, /^[A-Za-z0-9_-]{43,}$/);
  assert.match(params.get("nonce")!, /^[0-9a-f]{64}$/);
  assert.equal(answer.headers["cache-control"], "no-store");
  assert.equal(answer.headers["referrer-policy"], "no-referrer");
  assert.equal(answer.body, "");
});

test("hinweg: zustand gehasht, mit ablauf, einmal einlösbar", async (t) => {
  const c = clock();
  const running = await service(t, { auth: { config: withWeb }, now: c.now });
  const at = await begin(running.url);
  const answer = await visit(running.url, at);
  remember(answer, at);
  assert.equal(answer.status, 303, `${answer.status} ${answer.body.slice(0, 160)}`);
  const state = appleParams(answer).get("state")!;
  const [row, ...more] = await appleRows(running.pool);
  assert.ok(row && more.length === 0, "genau eine AppleLogin-Zeile");
  assert.deepEqual(row.id_hash, sha(state));
  assert.deepEqual(Object.keys(row.payload).sort(), ["nonce", "uid"]);
  assert.equal(row.payload.uid, at.uid);
  assert.equal(shaHex(row.payload.nonce), appleParams(answer).get("nonce"), "rohe Nonce passt nicht zum Hash an Apple");
  for (const value of Object.values(row)) assert.ok(!JSON.stringify(value ?? null).includes(state), "state im Klartext");
  const interaction = (await running.pool.query("SELECT expires_at FROM oauth_records WHERE model = 'Interaction'")).rows[0];
  assert.ok(row.expires_at.getTime() <= c.now() + 600_000 && row.expires_at.getTime() <= interaction.expires_at.getTime() + 1000, "Ablauf zu spät");
  const adapter = new PgAdapter(running.pool, "AppleLogin", () => new Date(c.now()));
  assert.equal((await adapter.find(state))?.uid, at.uid);
  await adapter.consume(state);
  await assert.rejects(adapter.consume(state), "zweites consume gelang");
  c.offset = 601_000;
  assert.equal(await adapter.find(state), undefined, "nach Ablauf sichtbar");
});

test("hinweg: ttl folgt der restlaufzeit", async (t) => {
  const c = clock();
  const running = await service(t, { auth: { config: withWeb }, now: c.now });
  const late = await begin(running.url);
  c.offset = 540_000;
  const answer = await visit(running.url, late);
  remember(answer, late);
  assert.equal(answer.status, 303, `${answer.status} ${answer.body.slice(0, 160)}`);
  const interaction = (await running.pool.query("SELECT expires_at FROM oauth_records WHERE model = 'Interaction'")).rows[0];
  const [row] = await appleRows(running.pool);
  assert.ok(Math.abs(row.expires_at.getTime() - interaction.expires_at.getTime()) <= 1000, "Ablauf ≠ Ablauf der Interaktion");
  await running.pool.query("DELETE FROM oauth_records WHERE model = 'AppleLogin'");
  c.offset = 0;
  const expired = await begin(running.url);
  c.offset = 601_000;
  assertFixed(await visit(running.url, expired), 400, "bad request", "abgelaufen");
  assert.equal((await appleRows(running.pool)).length, 0, "Zeile trotz Ablauf");
});

test("hinweg: state und nonce je versuch verschieden", async (t) => {
  const running = await service(t, { auth: { config: withWeb } });
  const answers = [];
  for (let i = 0; i < 2; i++) { const at = await begin(running.url); const a = await visit(running.url, at); remember(a, at); answers.push(a); }
  for (const a of answers) assert.equal(a.status, 303, `${a.status} ${a.body.slice(0, 160)}`);
  for (const key of ["state", "nonce"]) assert.notEqual(appleParams(answers[0]).get(key), appleParams(answers[1]).get(key), key);
  assert.equal((await appleRows(running.pool)).length, 2);
});

test("hinweg: consent bleibt feste 501", async (t) => {
  const running = await service(t, { auth: { config: withWeb }, interaction: loginThenApple(appleWith()) });
  const { at, answer } = await toConsent(running.url);
  remember(answer, at);
  assertFixed(answer, 501, "sign-in not available", "consent");
  assert.equal((await appleRows(running.pool)).length, 0);
});

test("hinweg: ohne apple-konfiguration oder web-id feste 501", async (t) => {
  for (const [name, auth] of [["ohne auth", undefined], ["ohne web-id", { config: appOnly }]] as const) {
    const running = await service(t, { auth });
    const at = await begin(running.url);
    const answer = await visit(running.url, at);
    remember(answer, at);
    assertFixed(answer, 501, "sign-in not available", name);
    assert.equal((await appleRows(running.pool)).length, 0, name);
  }
});

test("hinweg: ohne passendes cookie feste 400", async (t) => {
  const running = await service(t, { auth: { config: withWeb } });
  const a = await begin(running.url);
  const b = await begin(running.url);
  const cases: [string, Raw][] = [
    ["ohne cookie", await visit(running.url, a, "")],
    ["fremdes cookie", await visit(running.url, a, b.cookie)],
    ["unbekannte uid", await visit(running.url, { path: `/oauth/interaction/${randomUUID()}`, cookie: a.cookie })],
  ];
  for (const [name, answer] of cases) {
    remember(answer, a); remember(answer, b);
    assertFixed(answer, 400, "bad request", name);
    for (const value of [a.uid, b.uid, ...a.cookie.split("; ").map((p) => p.split("=")[1])]) assert.ok(!answer.body.includes(value), name);
  }
  assert.equal((await appleRows(running.pool)).length, 0);
});

test("hinweg: ablagefehler ergibt 400 ohne weiterleitung", async (t) => {
  const logged: string[] = [];
  const broken = { query: async () => { throw new Error("schreiben-geht-nicht-4711"); } };
  const running = await service(t, { auth: { config: withWeb },
    interaction: () => async (provider: any, req: any, res: any) => (await appleWith({ pool: broken, log: (e: string) => logged.push(e) })(broken as never))(provider, req, res) });
  const at = await begin(running.url);
  const answer = await visit(running.url, at);
  remember(answer, at);
  assertFixed(answer, 400, "bad request", "ablagefehler");
  assert.deepEqual(logged, ["oauth interaction store failed"]);
});

test("hinweg: protokoll ohne werte", async (t) => {
  const logged: string[] = [];
  const running = await service(t, { auth: { config: withWeb },
    interaction: (pool) => async (provider: any, req: any, res: any) => (await appleWith({ log: (e: string) => logged.push(e) })(pool()))(provider, req, res) });
  const at = await begin(running.url);
  const ok = await visit(running.url, at);
  const refused = await visit(running.url, at, "");
  remember(ok, at);
  assert.equal(ok.status, 303, `${ok.status} ${ok.body.slice(0, 160)}`);
  assert.equal(refused.status, 400);
  assert.deepEqual(logged, ["oauth interaction refused"]);
  for (const answer of [ok, refused]) for (const value of [at.uid, ...at.cookie.split("; ").map((p) => p.split("=")[1])]) {
    assert.ok(!answer.body.includes(value), "Wert im Körper");
  }
});

test("hinweg: fehlerfenster unberuehrt", async (t) => {
  const c = clock();
  let helper = true;
  const apple = appleWith();
  const running = await service(t, { auth: { config: withWeb }, now: c.now,
    interaction: (pool) => async (provider: any, req: any, res: any) => (helper ? loginThenApple(apple)(pool) : await apple(pool()))(provider, req, res) });
  const { at } = await toConsent(running.url);
  for (let i = 0; i < 25; i++) assert.equal((await visit(running.url, at)).status, 501, `consent ${i}`);
  helper = false;
  for (let i = 0; i < 12; i++) {
    const next = await begin(running.url);
    const answer = await visit(running.url, next);
    remember(answer, next);
    assert.equal(answer.status, 303, `hinweg ${i}: ${answer.status}`);
    assert.equal((await visit(running.url, next, "")).status, 400, `400 ${i}`);
  }
  assert.equal((await raw(running.url, "/health")).status, 200, "501 oder 400 im Fehlerfenster gezählt");
});

test("einhaengen: gesetzte interaktion hat vorrang", async (t) => {
  let called = 0;
  const running = await service(t, { auth: { config: withWeb },
    interaction: () => async (_p: any, _req: any, res: any) => { called++; res.writeHead(418, { "cache-control": "no-store" }).end(); } });
  const at = await begin(running.url);
  assert.equal((await visit(running.url, at)).status, 418);
  assert.equal(called, 1);
  assert.equal((await appleRows(running.pool)).length, 0);
  assert.equal(typeof (await interactionModule()).appleInteraction, "function", "appleInteraction fehlt");
});

test("hinweg: rueckweg noch nicht behandelt", async (t) => {
  const running = await service(t, { auth: { config: withWeb } });
  const before = Number((await running.pool.query("SELECT count(*) FROM oauth_records")).rows[0].count);
  for (const body of ["", "state=abc&code=def"]) {
    const answer = await raw(running.url, "/oauth/apple/return", { method: "POST", body, headers: { "content-type": "application/x-www-form-urlencoded" } });
    assert.equal(answer.status, 404, `${JSON.stringify(body)}: ${answer.status}`);
    for (const value of ["abc", "def"]) assert.ok(!answer.body.includes(value), "Wert im Körper");
  }
  assert.equal(Number((await running.pool.query("SELECT count(*) FROM oauth_records")).rows[0].count), before);
  assert.equal(Number((await running.pool.query("SELECT count(*) FROM accounts")).rows[0].count), 0);
  const at = await begin(running.url);
  assert.equal((await visit(running.url, at)).status, 303, "hinweg fehlt");
});

test("einhaengen: eine jwks-instanz je start", async (t) => {
  const apple = fakeApple();
  const running = await service(t, { auth: { config: withWeb, fetch: apple.fetch } });
  const at = await begin(running.url);
  const answer = await visit(running.url, at);
  remember(answer, at);
  assert.equal(answer.status, 303, `${answer.status} ${answer.body.slice(0, 160)}`);
  assert.equal(apple.urls.length, 0, "der Hinweg ruft Apple");
  for (let i = 0; i < 2; i++) {
    const signIn = await fetch(`${running.url}/auth/apple`, { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ identityToken: idToken(), nonce: "nonce-hin-4711", code: "CODE-HIN-4711" }) });
    assert.equal(signIn.status, 200, `Anmeldung ${i + 1}`);
  }
  assert.equal(apple.keyCalls(), 1, "mehr als eine JWKS-Instanz");
});
