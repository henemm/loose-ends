import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";
import { migrate } from "../src/migrate.ts";
import { putTranscript } from "../src/transcripts.ts";
import { mcpHandler } from "../src/mcp.ts";
import { freshPool } from "./db.ts";

// #624 Schnitt 1: the window a host with MCP Apps shows next to get_view. A resource ui://… with the MIME of the extension
// io.modelcontextprotocol/ui and the pointer _meta.ui.resourceUri on get_view; a host without MCP Apps sees the same text.

type Doc = Record<string, any>;
type T = Parameters<typeof freshPool>[0];
const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");
const ID = (n: number) => `6F1C2B0A-0000-4000-8000-${String(n).padStart(12, "0")}`;
const URI = "ui://loose-ends/view.html";
const MIME = "text/html;profile=mcp-app";

// The contract example plus a parked task and the three lists, as in mcp-read.test.ts.
function withViews(): Doc {
  const blocks = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  const doc = JSON.parse(blocks[0][1]);
  doc.tasks.push({ contexts: ["Computer", "Büro"], dueHasTime: false, id: ID(4), isKnaeuel: false, project: "Haus", status: "parked", title: "Keller räumen" });
  doc.views = { due: [ID(1)], next: [ID(2)], open: [ID(1), ID(3), ID(2), ID(4)] };
  return doc;
}

// A client in the process, no port: every request goes straight to handler.fetch with the account in authInfo.
async function connect(t: T, doc?: Doc): Promise<Client> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  if (doc) await putTranscript(pool, "henning", doc);
  const handler = mcpHandler(pool);
  const authInfo = { token: "test", clientId: "test", scopes: [], extra: { account: "henning" } };
  const transport = new StreamableHTTPClientTransport(new URL("http://mcp.test/mcp"), {
    fetch: (url, init) => handler.fetch(new Request(url, init), { authInfo }),
  });
  const client = new Client({ name: "test", version: "1" });
  await client.connect(transport);
  t.after(async () => { await client.close(); await handler.close(); });
  return client;
}

async function html(client: Client): Promise<string> {
  const { contents } = await client.readResource({ uri: URI });
  return (contents[0] as Doc).text;
}

test("AC-1: the service lists exactly one resource, the view with the MCP Apps MIME", async (t) => {
  const client = await connect(t);
  const { resources } = await client.listResources();
  const views = resources.filter((resource) => resource.uri === URI);
  assert.equal(views.length, 1);
  assert.equal(views[0].mimeType, MIME);
  assert.equal(resources.length, 1);
});

test("AC-2: reading the resource gives one whole German HTML document under its uri and MIME", async (t) => {
  const client = await connect(t);
  const { contents } = await client.readResource({ uri: URI });
  assert.equal(contents.length, 1);
  const content = contents[0] as Doc;
  assert.equal(content.uri, URI);
  assert.equal(content.mimeType, MIME);
  assert.equal(typeof content.text, "string");
  assert.match(content.text, /^<!doctype html>/i);
  assert.ok(content.text.includes('lang="de"'));
});

test("AC-3: the HTML carries no script and no outside source, and brings light and dark", async (t) => {
  const text = await html(await connect(t));
  for (const banned of ["<script", "http://", "https://", "@import"]) {
    assert.ok(!text.toLowerCase().includes(banned), `${banned} steht im HTML`);
  }
  assert.ok(text.includes("prefers-color-scheme: dark"));
});

test("AC-4: only get_view points to the view; no other tool carries _meta.ui", async (t) => {
  const client = await connect(t);
  const { tools } = await client.listTools();
  const view = tools.find((tool) => tool.name === "get_view");
  assert.ok(view);
  assert.equal((view._meta as Doc | undefined)?.ui?.resourceUri, URI);
  for (const tool of tools.filter((tool) => tool.name !== "get_view")) {
    assert.equal((tool._meta as Doc | undefined)?.ui, undefined, `${tool.name} trägt _meta.ui`);
  }
});

test("AC-5: get_view answers as before in all four views: one text, no structuredContent", async (t) => {
  const client = await connect(t, withViews());
  const expected: Record<string, { keys: string[]; ids: string[] }> = {
    now: { keys: ["view", "generatedAt", "nowCount", "count", "rows"], ids: [ID(3), ID(1), ID(2)] },
    due: { keys: ["view", "generatedAt", "count", "rows"], ids: [ID(1)] },
    next: { keys: ["view", "generatedAt", "count", "rows"], ids: [ID(2)] },
    open: { keys: ["view", "generatedAt", "count", "rows"], ids: [ID(1), ID(3), ID(2), ID(4)] },
  };
  for (const [view, want] of Object.entries(expected)) {
    const result: Doc = await client.callTool({ name: "get_view", arguments: { view } });
    assert.deepEqual(Object.keys(result).filter((key) => key !== "isError"), ["content"], view);
    assert.equal(result.isError ?? false, false, view);
    assert.equal(result.content.length, 1, view);
    assert.equal(result.content[0].type, "text", view);
    const text: string = result.content[0].text;
    const json = JSON.parse(text);
    assert.equal(text, JSON.stringify(json), view);
    assert.deepEqual(Object.keys(json), want.keys, view);
    assert.equal(json.view, view);
    assert.equal(json.generatedAt, "2026-03-12T09:00:00Z");
    assert.deepEqual(json.rows.map((row: Doc) => row.id), want.ids, view);
    assert.equal(json.count, want.ids.length, view);
  }
});
