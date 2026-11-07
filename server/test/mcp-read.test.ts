import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type pg from "pg";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { migrate } from "../src/migrate.ts";
import { checkTranscript, putTranscript } from "../src/transcripts.ts";
import { mcpHandler } from "../src/mcp.ts";
import { freshPool } from "./db.ts";

// #621 Schnitt 5: the read tools Claude uses to see the app's lists. The lists are the app's own (ids in the transcript);
// the service only looks them up, filters and counts.

type Doc = Record<string, any>;
type T = Parameters<typeof freshPool>[0];
const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const ID = (n: number) => `6F1C2B0A-0000-4000-8000-${String(n).padStart(12, "0")}`;

function base(): Doc {
  const blocks = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  return JSON.parse(blocks[0][1]);
}
// The contract example plus a parked task and the three lists as the app would write them.
function withViews(): Doc {
  const doc = base();
  doc.tasks.push({ contexts: ["Computer", "Büro"], dueHasTime: false, id: ID(4), isKnaeuel: false, project: "Haus", status: "parked", title: "Keller räumen" });
  doc.views = { due: [ID(1)], next: [ID(2)], open: [ID(1), ID(3), ID(2), ID(4)] };
  return doc;
}

async function setup(t: T, doc: Doc | undefined, account = "henning") {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  if (doc) await putTranscript(pool, "henning", doc);
  const handler = mcpHandler(pool);
  const authInfo = account === "" ? undefined : { token: "t", clientId: "c", scopes: [], extra: { account } };
  const transport = new StreamableHTTPClientTransport(new URL("http://mcp.test/mcp"), {
    fetch: (url, init) => handler.fetch(new Request(url, init), { authInfo }),
  });
  const client = new Client({ name: "test", version: "1" });
  await client.connect(transport);
  t.after(async () => { await client.close(); await handler.close(); });
  return { pool, client };
}
async function call(client: Client, name: string, args: Doc = {}) {
  const result: Doc = await client.callTool({ name, arguments: args });
  const text = result.content.map((part: Doc) => part.text).join("");
  return { text, isError: result.isError === true, json: () => JSON.parse(text) as Doc };
}

test("views: the transcript takes the optional key, only in its form, and the privacy line stays", async (t) => {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  assert.doesNotThrow(() => checkTranscript(withViews()));
  assert.doesNotThrow(() => checkTranscript(base()));
  for (const [name, change] of Object.entries({
    "unknown list": (d: Doc) => { d.views.later = []; },
    "missing list": (d: Doc) => { delete d.views.next; },
    "no uuid": (d: Doc) => { d.views.due = ["x"]; },
    "not an object": (d: Doc) => { d.views = []; },
  })) {
    const doc = withViews();
    change(doc);
    assert.throws(() => checkTranscript(doc), /Abschrift ungültig/, name);
  }
  assert.equal(await putTranscript(pool, "henning", withViews()), "stored");
  // The database is the second wall: a key beside the views is refused there too.
  const bad = withViews();
  bad.views.rawText = [];
  await assert.rejects(pool.query("UPDATE transcripts SET doc = $1::jsonb", [JSON.stringify(bad)]), /transcripts_view_keys/);
  const top = withViews();
  top.note = "x";
  await assert.rejects(pool.query("UPDATE transcripts SET doc = $1::jsonb", [JSON.stringify(top)]), /check/i);
});

test("get_view: the four views come in the app's order, now with its number", async (t) => {
  const { client } = await setup(t, withViews());
  const ids = (doc: Doc) => doc.rows.map((row: Doc) => row.id);
  const now = (await call(client, "get_view", { view: "now" })).json();
  assert.equal(now.nowCount, 3);
  assert.deepEqual(ids(now), [ID(3), ID(1), ID(2)]);
  const due = (await call(client, "get_view", { view: "due" })).json();
  assert.deepEqual(ids(due), [ID(1)]);
  assert.equal(due.count, 1);
  assert.equal(due.rows[0].title, "Müll rausbringen");
  assert.equal(due.generatedAt, "2026-03-12T09:00:00Z");
  assert.deepEqual(ids((await call(client, "get_view", { view: "next" })).json()), [ID(2)]);
  const open = (await call(client, "get_view", { view: "open" })).json();
  assert.deepEqual(ids(open), [ID(1), ID(3), ID(2), ID(4)]);
  assert.equal(open.rows.at(-1).status, "parked");
});

test("get_view: an unknown view is refused by the schema; an old transcript without views says so and 'now' still works", async (t) => {
  const { client } = await setup(t, base());
  assert.equal((await call(client, "get_view", { view: "everything" })).isError, true);
  const due = await call(client, "get_view", { view: "due" });
  assert.equal(due.isError, true);
  assert.match(due.text, /aktualisieren/);
  assert.equal((await call(client, "get_view", { view: "now" })).json().count, 3);
});

test("search_tasks: all words, case and accents ignored, nothing that does not match", async (t) => {
  const { client } = await setup(t, withViews());
  const titles = async (query: string) => (await call(client, "search_tasks", { query })).json().tasks.map((task: Doc) => task.title);
  assert.deepEqual(await titles("MULL"), ["Müll rausbringen"]);
  assert.deepEqual(await titles("angebot schreiben"), ["Angebot schreiben"]);
  assert.deepEqual(await titles("angebot müll"), []);
  // "ä" reads as "a": the accent does not hide "räumen" from a search for "raumen" or "a".
  assert.deepEqual(await titles("raumen"), ["Keller räumen"]);
  const empty = await call(client, "search_tasks", { query: "   " });
  assert.equal(empty.isError, true);
});

test("get_task: the task with its entry and the lists it stands in; another id says so", async (t) => {
  const { client } = await setup(t, withViews());
  const task = (await call(client, "get_task", { taskID: ID(2).toLowerCase() })).json();
  assert.equal(task.task.title, "Angebot schreiben");
  assert.deepEqual(task.views, { now: true, due: false, next: true, open: true });
  const parked = (await call(client, "get_task", { taskID: ID(4) })).json();
  assert.deepEqual(parked.views, { now: false, due: false, next: false, open: true });
  const unknown = await call(client, "get_task", { taskID: ID(99) });
  assert.equal(unknown.isError, true);
  assert.match(unknown.text, /nicht in der Abschrift/);
});

test("list_projects and list_contexts: names with the number of open tasks, sorted", async (t) => {
  const { client } = await setup(t, withViews());
  assert.deepEqual((await call(client, "list_projects")).json().projects, [{ name: "Haus", open: 2 }]);
  assert.deepEqual((await call(client, "list_contexts")).json().contexts, [{ name: "Büro", open: 1 }, { name: "Computer", open: 2 }]);
});

test("the new read tools refuse without an account, show another account nothing and say so without a transcript", async (t) => {
  const none = await setup(t, withViews(), "");
  for (const [name, args] of [["get_view", { view: "now" }], ["search_tasks", { query: "müll" }], ["get_task", { taskID: ID(1) }], ["list_projects", {}], ["list_contexts", {}]] as const) {
    const answer = await call(none.client, name, args);
    assert.equal(answer.isError, true, name);
    assert.match(answer.text, /kein Konto/, name);
    assert.ok(!answer.text.includes("Müll"), name);
  }
  const other = await setup(t, withViews(), "someone-else");
  for (const [name, args] of [["get_view", { view: "now" }], ["search_tasks", { query: "müll" }], ["get_task", { taskID: ID(1) }], ["list_projects", {}], ["list_contexts", {}]] as const) {
    const answer = await call(other.client, name, args);
    assert.equal(answer.text, "noch keine Abschrift", name);
  }
});

test("the read tools are marked read only", async (t) => {
  const { client } = await setup(t, undefined);
  const tools = (await client.listTools()).tools;
  for (const name of ["get_view", "search_tasks", "get_task", "list_projects", "list_contexts"]) {
    assert.equal(tools.find((tool) => tool.name === name)?.annotations?.readOnlyHint, true, name);
  }
});
