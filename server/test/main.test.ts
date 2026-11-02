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

test("AC-3 (S1): /mcp answers initialize with serverInfo and refuses get_now without an account", async (t) => {
  const { url, ready } = await service(t);
  await ready;
  const client = new Client({ name: "test", version: "1" });
  await client.connect(new StreamableHTTPClientTransport(new URL(`${url}/mcp`)));
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
