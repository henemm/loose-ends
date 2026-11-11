import { mock, test } from "node:test";
import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { readFileSync } from "node:fs";
import http from "node:http";
import { connect, createServer } from "node:net";
import { join } from "node:path";
import pg from "pg";
import { start } from "../src/main.ts";
import { appRoutes } from "../src/app-routes.ts";
import { createSession, deleteAccount, endSession, findOrCreate } from "../src/accounts.ts";
import { CLAIM_TIMEOUT_MINUTES, claimOrder, getResult, putOrder } from "../src/orders.ts";
import { getTranscript } from "../src/transcripts.ts";

type Doc = Record<string, any>;
type T = { after: (fn: () => Promise<void>) => void };

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const KIB = 1024;
const LIMIT = 256 * KIB;

// Transcript (1), order (2) and result (3) are read from the contract, never copied.
function blocks(): Doc[] {
  const found = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  assert.equal(found.length, 3, "der Vertrag muss genau drei ```json-Blöcke enthalten");
  return found.map((b) => JSON.parse(b[1]));
}
const transcript = (generatedAt?: string): Doc => ({ ...blocks()[0], ...(generatedAt ? { generatedAt } : {}) });
const contractOrder = (): Doc => blocks()[1];
const contractRejected = (): Doc => blocks()[2];
const uuid = (n: number) => `0b7d5e3c-0000-4000-8000-${String(n).padStart(12, "0")}`;
const capture = (n: number): Doc => ({ version: 1, id: uuid(n), kind: "capture", text: "Milch kaufen" });
const G1 = "a1b2c3d4-0000-4000-8000-0000000000a1";
const G2 = "a1b2c3d4-0000-4000-8000-0000000000a2";

// Every answer ≥ 400 through call(); AC-15 checks them all at the end of the file.
const seen: Array<{ label: string; status: number; body: string; headers: Headers }> = [];
let watching = true;
const errorLines: string[] = [];
mock.method(console, "error", (...args: unknown[]) => { if (watching) errorLines.push(args.map(String).join(" ")); });

// The real route table of start(), without the auth option; a second pool on the same schema to look into the tables.
async function service(t: T, extraRoutes?: Record<string, (r: Request) => Promise<Response>>) {
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  const admin = new pg.Pool({ connectionString: databaseUrl });
  await admin.query(`CREATE SCHEMA ${schema}`);
  const url = new URL(databaseUrl!);
  url.searchParams.set("options", `-c search_path=${schema}`);
  const running = await start({ databaseUrl: url.toString(), port: 0, migrationsDir: migrations, extraRoutes });
  await running.ready;
  const pool = new pg.Pool({ connectionString: url.toString() });
  t.after(async () => {
    await pool.end();
    await running.close();
    await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  });
  const account = await findOrCreate(pool, `sub.${schema}`);
  return { url: running.url, pool, account, token: await createSession(pool, account) };
}

type Call = { method?: string; token?: string | null; auth?: string; device?: string | null; type?: string | null; body?: unknown };
async function call(url: string, path: string, c: Call = {}, label = path) {
  const headers: Record<string, string> = {};
  if (c.auth !== undefined) headers.authorization = c.auth;
  else if (c.token) headers.authorization = `Bearer ${c.token}`;
  if (c.device) headers["x-device"] = c.device;
  if (c.type) headers["content-type"] = c.type;
  else if (c.type === undefined && c.body !== undefined) headers["content-type"] = "application/json";
  const body = c.body === undefined ? undefined : new TextEncoder().encode(typeof c.body === "string" ? c.body : JSON.stringify(c.body));
  const response = await fetch(`${url}${path}`, { method: c.method ?? "POST", headers, body });
  const text = await response.text();
  if (response.status >= 400) seen.push({ label, status: response.status, body: text, headers: response.headers });
  return { status: response.status, text, headers: response.headers };
}

async function snapshot(pool: pg.Pool) {
  const rows = async (sql: string) => (await pool.query(sql)).rows;
  return {
    transcripts: await rows("SELECT * FROM transcripts ORDER BY account_id"),
    orders: await rows("SELECT * FROM orders ORDER BY id"),
    results: await rows("SELECT * FROM order_results ORDER BY order_id"),
  };
}
const claimedBy = async (pool: pg.Pool, id: string) =>
  (await pool.query("SELECT claimed_by, claimed_at FROM orders WHERE id = $1", [id.toLowerCase()])).rows[0];
const age = (pool: pg.Pool, id: string, minutes: number) =>
  pool.query(`UPDATE orders SET claimed_at = now() - make_interval(mins => $2) WHERE id = $1`, [id.toLowerCase(), minutes]);
const resultCount = async (pool: pg.Pool) => Number((await pool.query("SELECT count(*) AS n FROM order_results")).rows[0].n);
// A JSON object of exactly `size` bytes; with only a filler key the form check refuses it (400), never the size check.
const padded = (size: number) => { const head = '{"pad":"'; return `${head}${"x".repeat(size - head.length - 2)}"}`; };

test("app: abschrift ablegen und ersetzen", async (t) => {
  const s = await service(t);
  const first = await call(s.url, "/app/transcript", { token: s.token, body: transcript() });
  assert.equal(first.status, 204);
  assert.equal(first.text, "");
  assert.equal(first.headers.get("cache-control"), "no-store");
  assert.deepEqual(await getTranscript(s.pool, s.account), transcript());
  const newer = transcript("2026-03-12T10:00:00Z");
  assert.equal((await call(s.url, "/app/transcript", { token: s.token, body: newer })).status, 204);
  assert.deepEqual(await getTranscript(s.pool, s.account), newer);
});

test("app: aeltere abschrift 204 ohne wirkung", async (t) => {
  const s = await service(t);
  assert.equal((await call(s.url, "/app/transcript", { token: s.token, body: transcript() })).status, 204);
  const before = await snapshot(s.pool);
  for (const generatedAt of ["2026-03-12T09:00:00Z", "2026-03-12T08:59:00Z"]) {
    const doc = { ...transcript(generatedAt), nowCount: 7 };
    assert.equal((await call(s.url, "/app/transcript", { token: s.token, body: doc })).status, 204, generatedAt);
  }
  assert.deepEqual((await snapshot(s.pool)).transcripts, before.transcripts);
});

test("app: ungueltige abschrift 400 ohne details", async (t) => {
  const s = await service(t);
  const cases: Array<[string, unknown]> = [
    ["feld fehlt", (() => { const d = transcript(); delete d.nowCount; return d; })()],
    ["version 2", { ...transcript(), version: 2 }],
    ["rawText", (() => { const d = transcript(); d.tasks[0].rawText = "Müll"; return d; })()],
    ["note", (() => { const d = transcript(); d.tasks[1].note = "privat"; return d; })()],
    ["array", []], ["text", "x"], ["null", null], ["kaputt", "{"],
  ];
  for (const [name, body] of cases) {
    const raw = name === "kaputt" ? "{" : JSON.stringify(body);
    const answer = await call(s.url, "/app/transcript", { token: s.token, body: raw }, `AC-3 ${name}`);
    assert.equal(answer.status, 400, name);
    assert.equal(answer.text, "", name);
    assert.equal(await getTranscript(s.pool, s.account), undefined, name);
  }
});

test("app: auftrag abholen genau einmal", async (t) => {
  const s = await service(t);
  const doc = contractOrder();
  await putOrder(s.pool, s.account, doc);
  const got = await call(s.url, "/app/orders/claim", { token: s.token, device: G1.toUpperCase() });
  assert.equal(got.status, 200);
  assert.match(got.headers.get("content-type") ?? "", /^application\/json/);
  assert.equal(got.headers.get("cache-control"), "no-store");
  assert.deepEqual(JSON.parse(got.text), doc);
  assert.equal((await claimedBy(s.pool, doc.id)).claimed_by, G1);
  for (const device of [G1, G2]) {
    const again = await call(s.url, "/app/orders/claim", { token: s.token, device });
    assert.equal(again.status, 204, device);
    assert.equal(again.text, "");
  }
});

test("app: abholen in reihenfolge und nur eigenes konto", async (t) => {
  const s = await service(t);
  const other = await findOrCreate(s.pool, "sub.fremd");
  for (const n of [1, 2, 3]) await putOrder(s.pool, s.account, capture(n));
  await putOrder(s.pool, other, capture(4));
  for (const n of [1, 2, 3]) {
    const got = await call(s.url, "/app/orders/claim", { token: s.token, device: G1 });
    assert.equal(got.status, 200, `Auftrag ${n}`);
    assert.equal(JSON.parse(got.text).id, uuid(n));
  }
  assert.equal((await call(s.url, "/app/orders/claim", { token: s.token, device: G1 })).status, 204);
  assert.equal((await claimedBy(s.pool, uuid(4))).claimed_by, null);
});

test("app: abholen ohne auftrag 204", async (t) => {
  const s = await service(t);
  const answer = await call(s.url, "/app/orders/claim", { token: s.token, device: G1 });
  assert.equal(answer.status, 204);
  assert.equal(answer.text, "");
  assert.equal(answer.headers.get("cache-control"), "no-store");
});

test("app: ergebnis melden und wiederholen", async (t) => {
  const s = await service(t);
  const done = { orderID: uuid(1), outcome: "done" };
  for (const [order, result] of [[capture(1), done], [contractOrder(), contractRejected()]] as const) {
    await putOrder(s.pool, s.account, order);
    assert.equal((await call(s.url, "/app/orders/claim", { token: s.token, device: G1 })).status, 200);
    assert.equal((await call(s.url, "/app/orders/result", { token: s.token, device: G1, body: result })).status, 204);
    assert.deepEqual(await getResult(s.pool, s.account, order.id), { state: "result", result });
    const before = await snapshot(s.pool);
    assert.equal((await call(s.url, "/app/orders/result", { token: s.token, device: G1, body: result })).status, 204, "duplicate");
    assert.deepEqual((await snapshot(s.pool)).results, before.results);
  }
});

test("app: ergebnis abgelehnt 409", async (t) => {
  const s = await service(t);
  const other = await findOrCreate(s.pool, "sub.fremd");
  await putOrder(s.pool, s.account, capture(2));
  await putOrder(s.pool, s.account, capture(3));
  await claimOrder(s.pool, s.account, G2);
  await claimOrder(s.pool, s.account, G2);
  await putOrder(s.pool, s.account, capture(1));
  await putOrder(s.pool, other, capture(4));
  await claimOrder(s.pool, other, G1);
  const cases: Array<[string, string]> = [["unbekannt", uuid(99)], ["nie vergeben", uuid(1)], ["anderes geraet", uuid(2)], ["anderes konto", uuid(4)]];
  for (const [name, orderID] of cases) {
    const answer = await call(s.url, "/app/orders/result", { token: s.token, device: G1, body: { orderID, outcome: "done" } }, `AC-7 ${name}`);
    assert.equal(answer.status, 409, name);
    assert.equal(answer.text, "", name);
  }
  assert.equal(await resultCount(s.pool), 0);
});

test("app: ungueltiges ergebnis 400", async (t) => {
  const s = await service(t);
  await putOrder(s.pool, s.account, capture(1));
  await claimOrder(s.pool, s.account, G1);
  const cases: Array<[string, string]> = [
    ["ohne orderID", JSON.stringify({ outcome: "done" })],
    ["rejected ohne reason", JSON.stringify({ orderID: uuid(1), outcome: "rejected" })],
    ["unbekanntes outcome", JSON.stringify({ orderID: uuid(1), outcome: "ok" })],
    ["reason bei done", JSON.stringify({ orderID: uuid(1), outcome: "done", reason: "stale" })],
    ["kaputt", "{"],
  ];
  for (const [name, body] of cases) {
    const answer = await call(s.url, "/app/orders/result", { token: s.token, device: G1, body }, `AC-8 ${name}`);
    assert.equal(answer.status, 400, name);
    assert.equal(answer.text, "", name);
  }
  assert.equal(await resultCount(s.pool), 0);
});

test("app: sitzung und geraet, jede ablehnung", async (t) => {
  const s = await service(t);
  await putOrder(s.pool, s.account, capture(1));
  await putOrder(s.pool, s.account, capture(2));
  await claimOrder(s.pool, s.account, G1);
  const expired = await createSession(s.pool, s.account);
  await s.pool.query("UPDATE sessions SET last_used_at = now() - interval '91 days' WHERE token_hash = $1", [createHash("sha256").update(expired).digest()]);
  const ended = await createSession(s.pool, s.account);
  await endSession(s.pool, ended);
  const gone = await findOrCreate(s.pool, "sub.geloescht");
  const goneToken = await createSession(s.pool, gone);
  await deleteAccount(s.pool, gone);
  const bodies: Record<string, unknown> = { "/app/transcript": transcript(), "/app/orders/claim": undefined, "/app/orders/result": { orderID: uuid(1), outcome: "done" } };
  const before = await snapshot(s.pool);
  const auths: Array<[string, Call]> = [
    ["ohne kopf", { token: null }], ["basic", { auth: "Basic abc" }], ["bearer leer", { auth: "Bearer " }],
    ["zwei token", { auth: "Bearer a b" }], ["unbekannt", { token: "unbekannt" }], ["abgelaufen", { token: expired }],
    ["beendet", { token: ended }], ["geloescht", { token: goneToken }],
  ];
  for (const [path, body] of Object.entries(bodies)) {
    for (const [name, c] of auths) {
      const answer = await call(s.url, path, { ...c, device: G1, body }, `AC-9 ${path} ${name}`);
      assert.equal(answer.status, 401, `${path} ${name}`);
      assert.equal(answer.text, "", `${path} ${name}`);
      assert.equal(answer.headers.get("cache-control"), "no-store", `${path} ${name}`);
    }
    if (path === "/app/transcript") continue;
    assert.equal((await call(s.url, path, { token: "unbekannt", device: null, body })).status, 401, `${path} 401 vor Gerät`);
    for (const device of [null, "gerät", G1.replaceAll("-", ""), G1.slice(0, 35)]) {
      const answer = await call(s.url, path, { token: s.token, device, body }, `AC-9 ${path} geraet ${device}`);
      assert.equal(answer.status, 400, `${path} Gerät ${device}`);
    }
  }
  assert.deepEqual(await snapshot(s.pool), before);
});

// POST over node:http, the body streamed in parts without Content-Length (chunked).
function chunked(url: string, path: string, token: string, parts: Buffer[]): Promise<number | "aborted"> {
  return new Promise((done) => {
    const headers = { authorization: `Bearer ${token}`, "content-type": "application/json", "x-device": G1 };
    const request = http.request(`${url}${path}`, { method: "POST", headers }, (answer) => { answer.resume(); answer.on("end", () => done(answer.statusCode!)); });
    request.on("error", () => done("aborted"));
    for (const part of parts) request.write(part);
    request.end();
  });
}

// Raw HTTP/1.1 whose Content-Length claims less than is sent; resolves with everything the service answered.
function lying(url: string, path: string, token: string, claimed: number, size: number): Promise<string> {
  return new Promise((done) => {
    const socket = connect(Number(new URL(url).port), "127.0.0.1");
    let text = "";
    socket.on("data", (chunk) => { text += chunk; });
    socket.on("close", () => done(text));
    socket.on("error", () => {});
    socket.write(`POST ${path} HTTP/1.1\r\nHost: x\r\nAuthorization: Bearer ${token}\r\nX-Device: ${G1}\r\nContent-Type: application/json\r\nContent-Length: ${claimed}\r\n\r\n`);
    socket.end(padded(size));
  });
}

test("app: methode inhaltstyp und groesse", async (t) => {
  const s = await service(t);
  const paths = ["/app/transcript", "/app/orders/claim", "/app/orders/result"];
  for (const path of paths) {
    for (const method of ["GET", "PUT", "DELETE"]) {
      const answer = await call(s.url, path, { method, token: s.token, device: G1, body: method === "GET" ? undefined : "{}" }, `AC-10 ${method} ${path}`);
      assert.equal(answer.status, 405, `${method} ${path}`);
      assert.equal(answer.headers.get("allow"), "POST", `${method} ${path}`);
    }
  }
  for (const path of ["/app/transcript", "/app/orders/result"]) {
    for (const type of ["text/plain", null]) {
      const answer = await call(s.url, path, { token: s.token, device: G1, type, body: "{}" }, `AC-10 ${path} ${type}`);
      assert.equal(answer.status, 415, `${path} ${type}`);
    }
    assert.equal((await call(s.url, path, { token: s.token, device: G1, body: padded(LIMIT) }, `AC-10 ${path} genau`)).status, 400, `${path} genau 256 KiB`);
    for (const size of [LIMIT + 1, 900 * KIB]) {
      const answer = await call(s.url, path, { token: s.token, device: G1, body: padded(size) }, `AC-10 ${path} ${size}`);
      assert.equal(answer.status, 413, `${path} ${size}`);
      assert.equal(answer.text, "");
    }
    const streamed = await chunked(s.url, path, s.token, Array.from({ length: 5 }, () => Buffer.from(padded(64 * KIB))));
    assert.ok(streamed === "aborted" || streamed === 413, `${path} chunked: ${streamed}`);
    const raw = await lying(s.url, path, s.token, 100, 300 * KIB);
    assert.ok(!raw.startsWith("HTTP/1.1 2"), `${path} lügende Länge angenommen`);
    for (const c of [{ type: "text/plain", body: "{}" }, { body: padded(300 * KIB) }]) {
      assert.equal((await call(s.url, path, { token: null, device: G1, ...c }, `AC-10 ${path} ohne token`)).status, 401, `${path} ohne Token`);
    }
  }
  assert.equal((await call(s.url, "/app/transcript", { token: s.token, type: "application/json; charset=utf-8", body: transcript() })).status, 204);
  await s.pool.query("DELETE FROM transcripts");
  assert.deepEqual(await snapshot(s.pool), { transcripts: [], orders: [], results: [] });
});

test("app: rueckholen nach zehn minuten", async (t) => {
  assert.equal(CLAIM_TIMEOUT_MINUTES, 10);
  const s = await service(t);
  await putOrder(s.pool, s.account, capture(1));
  await claimOrder(s.pool, s.account, G1);
  await age(s.pool, uuid(1), 11);
  const before = (await s.pool.query("SELECT now() AS at")).rows[0].at;
  const got = await call(s.url, "/app/orders/claim", { token: s.token, device: G2 });
  assert.equal(got.status, 200);
  assert.equal(JSON.parse(got.text).id, uuid(1));
  const row = await claimedBy(s.pool, uuid(1));
  assert.equal(row.claimed_by, G2);
  assert.ok(row.claimed_at >= before, "claimed_at frisch");
  const result = { orderID: uuid(1), outcome: "done" };
  assert.equal((await call(s.url, "/app/orders/result", { token: s.token, device: G1, body: result })).status, 409);
  assert.equal(await resultCount(s.pool), 0);
  assert.equal((await call(s.url, "/app/orders/result", { token: s.token, device: G2, body: result })).status, 204);
});

test("app: rueckholen grenzen", async (t) => {
  await t.test("9 minuten: bleibt", async (t) => {
    const s = await service(t);
    await putOrder(s.pool, s.account, capture(1));
    await claimOrder(s.pool, s.account, G1);
    await age(s.pool, uuid(1), 9);
    assert.equal((await call(s.url, "/app/orders/claim", { token: s.token, device: G2 })).status, 204);
    assert.equal((await claimedBy(s.pool, uuid(1))).claimed_by, G1);
  });
  await t.test("mit ergebnis: nie zurueck", async (t) => {
    const s = await service(t);
    await putOrder(s.pool, s.account, capture(1));
    await claimOrder(s.pool, s.account, G1);
    await call(s.url, "/app/orders/result", { token: s.token, device: G1, body: { orderID: uuid(1), outcome: "done" } });
    await age(s.pool, uuid(1), 11);
    const before = await snapshot(s.pool);
    assert.equal((await call(s.url, "/app/orders/claim", { token: s.token, device: G2 })).status, 204);
    assert.deepEqual(await snapshot(s.pool), before);
  });
  await t.test("aelterer zuerst, jeder genau einmal", async (t) => {
    const s = await service(t);
    await putOrder(s.pool, s.account, capture(1));
    await putOrder(s.pool, s.account, capture(2));
    await s.pool.query("UPDATE orders SET created_at = now() - interval '1 hour' WHERE id = $1", [uuid(1)]);
    await claimOrder(s.pool, s.account, G1);
    await age(s.pool, uuid(1), 11);
    const ids = [];
    for (let i = 0; i < 2; i++) ids.push(JSON.parse((await call(s.url, "/app/orders/claim", { token: s.token, device: G2 })).text).id);
    assert.deepEqual(ids, [uuid(1), uuid(2)]);
    assert.equal((await call(s.url, "/app/orders/claim", { token: s.token, device: G2 })).status, 204);
  });
  await t.test("anderes konto: nie", async (t) => {
    const s = await service(t);
    const other = await findOrCreate(s.pool, "sub.fremd");
    await putOrder(s.pool, other, capture(1));
    await claimOrder(s.pool, other, G1);
    await age(s.pool, uuid(1), 11);
    assert.equal((await call(s.url, "/app/orders/claim", { token: s.token, device: G2 })).status, 204);
    assert.equal((await claimedBy(s.pool, uuid(1))).claimed_by, G1);
  });
});

test("app: rueckholen gleichzeitig genau einer", async (t) => {
  const s = await service(t);
  const g0 = "a1b2c3d4-0000-4000-8000-0000000000a0";
  for (let n = 1; n <= 20; n++) {
    await putOrder(s.pool, s.account, capture(n));
    await claimOrder(s.pool, s.account, g0);
    await age(s.pool, uuid(n), 11);
    const answers = await Promise.all([G1, G2].map((device) => call(s.url, "/app/orders/claim", { token: s.token, device })));
    const statuses = answers.map((a) => a.status).sort();
    assert.deepEqual(statuses, [200, 204], `Runde ${n}`);
    const winner = answers[0].status === 200 ? G1 : G2;
    assert.equal((await claimedBy(s.pool, uuid(n))).claimed_by, winner, `Runde ${n}`);
  }
});

async function freePort(): Promise<number> {
  const probe = createServer();
  await new Promise<void>((done) => probe.listen(0, "127.0.0.1", done));
  const port = (probe.address() as { port: number }).port;
  await new Promise((done) => probe.close(done));
  return port;
}

test("app: einhaengen vor migrate und ohne auth", async (t) => {
  const paths = ["/app/transcript", "/app/orders/claim", "/app/orders/result"];
  assert.deepEqual(Object.keys(appRoutes({ pool: new pg.Pool() })).sort(), [...paths].sort());
  watching = false;
  const down = await start({ databaseUrl: `postgres://postgres@127.0.0.1:${await freePort()}/postgres`, port: 0, migrationsDir: migrations, retryMs: 50, maxAttempts: 20 });
  const refused = assert.rejects(down.ready);
  for (const path of paths) {
    const answer = await fetch(`${down.url}${path}`, { method: "POST", headers: { authorization: "Bearer x", "x-device": G1, "content-type": "application/json" }, body: "{}" });
    assert.equal(answer.status, 503, path);
    assert.equal(await answer.text(), "", path);
  }
  await refused;
  await down.close();
  watching = true;

  const fixed = async () => new Response(null, { status: 418 });
  const s = await service(t, { "/health": fixed, "/mcp": fixed, "/app/transcript": fixed });
  assert.equal((await fetch(`${s.url}/app/transcript`, { method: "POST" })).status, 418, "extraRoutes überschreibt die App-Route");
  assert.notEqual((await fetch(`${s.url}/mcp`, { method: "POST" })).status, 418);
  for (let i = 0; i < 25; i++) assert.equal((await call(s.url, "/app/orders/claim", { token: s.token, device: G1 })).status, 204);
  const health = await fetch(`${s.url}/health`);
  assert.equal(health.status, 200);
  assert.equal((await health.json()).errorRate, 0);
  const big = await new Promise<{ status: number; connection?: string }>((done) => {
    const request = http.request(`${s.url}/app/orders/claim`, { method: "POST", headers: { authorization: `Bearer ${s.token}`, "x-device": G1 }, agent: new http.Agent({ keepAlive: true }) },
      (answer) => { answer.resume(); answer.on("end", () => done({ status: answer.statusCode!, connection: answer.headers.connection })); });
    request.on("error", () => done({ status: 0 }));
    request.end(Buffer.alloc(1024 * 1024 + 1, 0x61));
  });
  assert.deepEqual(big, { status: 413, connection: "close" });
  assert.equal(await resultCount(s.pool), 0);
});

test("app: ablehnungen ohne koerper und ohne log", () => {
  const transport = new Set(["date", "connection", "keep-alive", "content-length", "transfer-encoding"]);
  for (const label of ["AC-3", "AC-7", "AC-8", "AC-9", "AC-10"]) assert.ok(seen.some((s) => s.label.startsWith(label)), `keine Ablehnung aus ${label} gesehen`);
  for (const { label, status, body, headers } of seen) {
    assert.equal(body, "", `${label} ${status}: Körper`);
    assert.equal(headers.get("cache-control"), "no-store", `${label} ${status}`);
    const names = [...headers.keys()].filter((name) => !transport.has(name) && name !== "cache-control");
    assert.deepEqual(names, status === 405 ? ["allow"] : [], `${label} ${status}: Köpfe ${names}`);
    assert.ok(["0", null].includes(headers.get("content-length")), `${label} ${status}: Länge`);
  }
  assert.deepEqual(errorLines, [], "console.error während des Laufs");
});

test("app: vertrag und doku", () => {
  const contract = readFileSync(contractPath, "utf8");
  const section = contract.split(/^## /m).find((part) => part.startsWith("Wege der App") || /^[^\n]*Wege der App/.test(part));
  assert.ok(section, "Abschnitt „Wege der App“ fehlt");
  for (const word of ["/app/transcript", "/app/orders/claim", "/app/orders/result", "X-Device", "Authorization: Bearer", "10 Minuten", "Rückholen", "mindestens einmal"]) {
    assert.ok(section.includes(word), `Vertrag ohne ${word}`);
  }
  assert.equal([...contract.matchAll(/```json\n/g)].length, 3, "genau drei ```json-Blöcke");
  const claude = readFileSync(join(import.meta.dirname, "../../CLAUDE.md"), "utf8");
  const line = claude.split("\n").find((l) => l.includes("src/app-routes.ts"));
  assert.ok(line, "CLAUDE.md nennt src/app-routes.ts nicht");
  for (const word of ["X-Device", "256 KiB", "gated", "claimOrder"]) assert.ok(line.includes(word), `CLAUDE.md-Zeile ohne ${word}`);
});
