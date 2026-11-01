import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { migrate } from "../src/migrate.ts";
import { getTranscript, putTranscript } from "../src/transcripts.ts";
import { mcpHandler } from "../src/mcp.ts";
import { freshPool } from "./db.ts";

type Doc = Record<string, any>;
type T = Parameters<typeof freshPool>[0];

const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const [steuer, muell, angebot] = ["…0003", "…0001", "…0002"];

// The transcript example is read from the contract, never copied (first of the three ```json blocks).
function example(): Doc {
  const blocks = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  assert.equal(blocks.length, 3, "der Vertrag muss genau drei ```json-Blöcke enthalten");
  return JSON.parse(blocks[0][1]);
}

const changed = (change: (copy: Doc) => void): Doc => { const copy = example(); change(copy); return copy; };
const byEnd = (doc: Doc, end: string) => doc.tasks.find((task: Doc) => task.id.endsWith(end.slice(1))).id;
const fakeID = (n: number) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;

async function migrated(t: T): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

// A client in the process, no port: every request goes straight to handler.fetch with the account in authInfo.
async function connect(t: T, pool: pg.Pool, account?: string): Promise<Client> {
  const handler = mcpHandler(pool);
  const authInfo = account === undefined ? undefined : { token: "test", clientId: "test", scopes: [], extra: { account } };
  const transport = new StreamableHTTPClientTransport(new URL("http://mcp.test/mcp"), {
    fetch: (url, init) => handler.fetch(new Request(url, init), { authInfo }),
  });
  const client = new Client({ name: "test", version: "1" });
  await client.connect(transport);
  t.after(async () => { await client.close(); await handler.close(); });
  return client;
}

async function call(client: Client, name: string): Promise<{ text: string; isError: boolean }> {
  const result: Doc = await client.callTool({ name, arguments: {} });
  return { text: result.content.map((part: Doc) => part.text).join(""), isError: result.isError === true };
}
const json = async (client: Client, name: string) => JSON.parse((await call(client, name)).text);
const titles = (doc: Doc) => doc.tasks.map((task: Doc) => task.title as string);

test("AC-1: tools/list names exactly get_now and list_tasks", async (t) => {
  const client = await connect(t, await migrated(t), "henning");
  const names = (await client.listTools()).tools.map((tool) => tool.name).sort();
  assert.deepEqual(names, ["get_now", "list_tasks"]);
});

test("AC-2: without an account every tool refuses and reads nothing", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool);
  for (const name of ["get_now", "list_tasks"]) {
    await t.test(name, async () => {
      const { text, isError } = await call(client, name);
      assert.equal(isError, true);
      assert.match(text, /kein Konto/);
      for (const title of titles(example())) assert.ok(!text.includes(title), `${title} darf nicht vorkommen`);
    });
  }
});

test("AC-3/AC-4: another account and an account without transcript get „noch keine Abschrift“", async (t) => {
  for (const [label, stored] of [["AC-3 fremdes Konto", true], ["AC-4 keine Abschrift", false]] as const) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      if (stored) await putTranscript(pool, "henning", example());
      const client = await connect(t, pool, "anna");
      for (const name of ["get_now", "list_tasks"]) {
        const { text, isError } = await call(client, name);
        assert.equal(isError, false, name);
        assert.match(text, /noch keine Abschrift/, name);
        for (const title of titles(example())) assert.ok(!text.includes(title), `${name}: ${title}`);
      }
    });
  }
});

test("AC-5: get_now passes nowCount through and never recounts", async (t) => {
  for (const [label, doc, expected] of [["Vertrag", example(), example().nowCount], ["7 bei drei Zeilen", changed((d) => { d.nowCount = 7; }), 7]] as const) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      await putTranscript(pool, "henning", doc);
      assert.equal((await json(await connect(t, pool, "henning"), "get_now")).nowCount, expected);
    });
  }
});

test("AC-6: get_now orders knaeuel, today, lined, waiting and keeps the order inside a group", async (t) => {
  const doc = example();
  const many = changed((d) => {
    d.now = { today: [fakeID(2), fakeID(1)], lined: [fakeID(4), fakeID(3)], waiting: [fakeID(6), fakeID(5)] };
  });
  const cases: Array<[string, Doc, Array<[string, string]>]> = [
    ["Vertrag", doc, [[byEnd(doc, steuer), "knaeuel"], [byEnd(doc, muell), "today"], [byEnd(doc, angebot), "lined"]]],
    ["ohne Knäuel, mehrere je Gruppe", many, [[fakeID(2), "today"], [fakeID(1), "today"], [fakeID(4), "lined"],
      [fakeID(3), "lined"], [fakeID(6), "waiting"], [fakeID(5), "waiting"]]],
  ];
  for (const [label, input, expected] of cases) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      await putTranscript(pool, "henning", input);
      const rows = (await json(await connect(t, pool, "henning"), "get_now")).rows;
      assert.deepEqual(rows.map((row: Doc) => [row.id, row.group]), expected);
    });
  }
});

test("AC-7: each row of get_now carries the task's fields; an id without task stays id and group", async (t) => {
  const doc = changed((d) => { d.now.waiting = [fakeID(9)]; });
  const pool = await migrated(t);
  await putTranscript(pool, "henning", doc);
  const out = await json(await connect(t, pool, "henning"), "get_now");
  assert.equal(out.generatedAt, doc.generatedAt);
  const row = (id: string) => out.rows.find((r: Doc) => r.id === id);
  const take = (task: Doc, group: string) => {
    const { id, title, dueDate, dueHasTime, status, isKnaeuel } = task;
    return { id, title, ...(dueDate === undefined ? {} : { dueDate }), dueHasTime, status, isKnaeuel, group };
  };
  const task = (end: string) => doc.tasks.find((x: Doc) => x.id === byEnd(doc, end));
  assert.deepEqual(row(byEnd(doc, muell)), take(task(muell), "today"));
  assert.equal(row(byEnd(doc, muell)).dueDate, "2026-03-12T17:00:00Z");
  assert.equal(row(byEnd(doc, muell)).dueHasTime, true);
  assert.equal(row(byEnd(doc, muell)).status, "active");
  assert.deepEqual(row(byEnd(doc, steuer)), take(task(steuer), "knaeuel"));
  assert.equal(row(byEnd(doc, steuer)).isKnaeuel, true);
  assert.deepEqual(row(byEnd(doc, angebot)), take(task(angebot), "lined"));
  assert.deepEqual(row(fakeID(9)), { id: fakeID(9), group: "waiting" });
});

test("AC-8: list_tasks returns every task as delivered, with generatedAt", async (t) => {
  for (const [label, doc] of [["Vertrag", example()], ["vertauscht", changed((d) => { d.tasks.reverse(); })]] as const) {
    await t.test(label, async (t) => {
      const pool = await migrated(t);
      await putTranscript(pool, "henning", doc);
      const out = await json(await connect(t, pool, "henning"), "list_tasks");
      assert.deepEqual(out, { generatedAt: doc.generatedAt, tasks: doc.tasks });
    });
  }
});

test("AC-9: no raw text or note in any answer, nothing on console or stdout", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool, "henning");
  const log = t.mock.method(console, "log");
  const write = t.mock.method(process.stdout, "write");
  const texts = [(await call(client, "get_now")).text, (await call(client, "list_tasks")).text];
  const [logs, writes] = [log.mock.callCount(), write.mock.callCount()];
  t.mock.restoreAll();
  assert.equal(logs, 0, "console.log");
  assert.equal(writes, 0, "process.stdout.write");
  for (const text of texts) assert.ok(!/"rawText"|"note"/.test(text), text);
});

test("AC-10: a newer upload is read on the next call, nothing is cached", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const client = await connect(t, pool, "henning");
  assert.equal((await json(client, "list_tasks")).generatedAt, example().generatedAt);
  const newer = changed((d) => { d.generatedAt = "2026-03-13T09:00:00+01:00"; d.nowCount = 5; });
  assert.equal(await putTranscript(pool, "henning", newer), "stored");
  assert.equal((await json(client, "list_tasks")).generatedAt, newer.generatedAt);
  assert.equal((await json(client, "get_now")).nowCount, 5);
});

test("AC-13: getTranscript returns the stored document or undefined", async (t) => {
  const pool = await migrated(t);
  assert.equal(await getTranscript(pool, "henning"), undefined);
  await putTranscript(pool, "henning", example());
  assert.deepEqual(await getTranscript(pool, "henning"), example());
  assert.equal(await getTranscript(pool, "anna"), undefined);
});
