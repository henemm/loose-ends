import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import pg from "pg";
import { migrate } from "../src/migrate.ts";
import { checkTranscript, putTranscript } from "../src/transcripts.ts";
import { freshPool } from "./db.ts";

type Doc = Record<string, any>;

const migrations = join(import.meta.dirname, "../migrations");
const contractPath = join(import.meta.dirname, "../../docs/reference/claude-abschrift-vertrag.md");

// The transcript example is read from the contract, never copied (first of the three ```json blocks).
function example(): Doc {
  const blocks = [...readFileSync(contractPath, "utf8").matchAll(/```json\n([\s\S]*?)\n```/g)];
  assert.equal(blocks.length, 3, "der Vertrag muss genau drei ```json-Blöcke enthalten");
  return JSON.parse(blocks[0][1]);
}

function changed(change: (copy: Doc) => void, doc: Doc = example()): Doc {
  const copy = structuredClone(doc);
  change(copy);
  return copy;
}

async function migrated(t: Parameters<typeof freshPool>[0]): Promise<pg.Pool> {
  const pool = await freshPool(t);
  await migrate(pool, migrations);
  return pool;
}

const count = async (pool: pg.Pool) => Number((await pool.query("SELECT count(*) AS n FROM transcripts")).rows[0].n);
const row = async (pool: pg.Pool, account = "henning") =>
  (await pool.query("SELECT doc, generated_at, received_at FROM transcripts WHERE account_id = $1", [account])).rows[0];
const at = (generatedAt: string, nowCount = 3) => changed((d) => { d.generatedAt = generatedAt; d.nowCount = nowCount; });

test("AC-1: the contract example and a lower-case one without optional fields are accepted", () => {
  checkTranscript(example());
  const lower = JSON.parse(JSON.stringify(example()).replace(/[0-9A-F]{8}-[0-9A-F-]{27}/g, (id) => id.toLowerCase()));
  delete lower.now.knaeuel;
  for (const task of lower.tasks) { delete task.dueDate; delete task.project; delete task.nextRank; }
  checkTranscript(lower);
});

// One row per line of the deviation table: each change is refused with its field path, and nothing is written.
const table: Array<[string, Array<[(d: Doc) => void, string]>]> = [
  ["AC-2 (Z1) version", [[(d) => { delete d.version; }, "version"], [(d) => { d.version = "1"; }, "version"], [(d) => { d.version = 2; }, "version"]]],
  ["AC-3 (Z2) generatedAt", [[(d) => { delete d.generatedAt; }, "generatedAt"], [(d) => { d.generatedAt = "2026-03-12T09:00:00"; }, "generatedAt"]]],
  ["AC-4 (Z3) now is no object", [[(d) => { d.now = []; }, "now"], [(d) => { d.now = "x"; }, "now"]]],
  ["AC-5 (Z4) keys of now", [[(d) => { d.now.extra = []; }, "now.extra"], [(d) => { delete d.now.waiting; }, "now.waiting"]]],
  ["AC-6 (Z5) now.knaeuel", [[(d) => { d.now.knaeuel = "abc"; }, "now.knaeuel"], [(d) => { d.now.knaeuel = 5; }, "now.knaeuel"]]],
  ["AC-7 (Z6) lists of now", [
    [(d) => { d.now.today = "x"; }, "now.today"], [(d) => { d.now.today = ["abc"]; }, "now.today[0]"],
    [(d) => { d.now.lined = {}; }, "now.lined"], [(d) => { d.now.lined = [5]; }, "now.lined[0]"],
    [(d) => { d.now.waiting = null; }, "now.waiting"], [(d) => { d.now.waiting = ["nein"]; }, "now.waiting[0]"],
  ]],
  ["AC-8 (Z7) contexts", [[(d) => { d.tasks[1].contexts = "Computer"; }, "tasks[1].contexts"], [(d) => { d.tasks[1].contexts = [1]; }, "tasks[1].contexts"]]],
  ["AC-9 (Z8) title and project", [[(d) => { d.tasks[0].title = 5; }, "tasks[0].title"], [(d) => { d.tasks[1].project = false; }, "tasks[1].project"]]],
  ["AC-10 (Z9) raw text and note anywhere", [
    [(d) => { d.tasks[0].rawText = "Müll"; }, "tasks[0].rawText"], [(d) => { d.tasks[1].note = "privat"; }, "tasks[1].note"],
    [(d) => { d.now.rawText = "Müll"; }, "now.rawText"], [(d) => { d.tasks[1].contexts = [{ note: "privat" }]; }, "tasks[1].contexts[0].note"],
  ]],
  ["AC-11 (Z10) root keys and nowCount", [
    [(d) => { d.revisions = []; }, "revisions"],
    [(d) => { d.nowCount = "3"; }, "nowCount"], [(d) => { d.nowCount = -1; }, "nowCount"], [(d) => { d.nowCount = 1.5; }, "nowCount"],
  ]],
];

test("AC-2 to AC-11: the deviation table is refused with the field path, nothing is stored", async (t) => {
  const pool = await migrated(t);
  for (const [name, cases] of table) {
    await t.test(name, async () => {
      for (const [change, path] of cases) {
        const doc = changed(change);
        assert.throws(() => checkTranscript(doc), (e: Error) => e.message.startsWith(`Abschrift ungültig: ${path}: `), `${name} → ${path}`);
        await assert.rejects(putTranscript(pool, "henning", doc), (e: Error) => e.message.startsWith(`Abschrift ungültig: ${path}: `));
        assert.equal(await count(pool), 0, `${name} → ${path}`);
      }
    });
  }
});

test("AC-6: without now.knaeuel the transcript is accepted", () => {
  checkTranscript(changed((d) => { delete d.now.knaeuel; }));
});

test("AC-12/13/14: the first is stored, a newer replaces it, an older or equally old one leaves it", async (t) => {
  const pool = await migrated(t);
  const first = example();

  assert.equal(await putTranscript(pool, "henning", first), "stored");
  const stored = await row(pool);
  assert.deepEqual(stored.doc, first);
  assert.equal(stored.generated_at.toISOString(), new Date(first.generatedAt).toISOString());

  const newer = at("2026-03-12T10:00:00Z", 4);
  assert.equal(await putTranscript(pool, "henning", newer), "stored");
  const replaced = await row(pool);
  assert.deepEqual(replaced.doc, newer);
  assert.equal(await count(pool), 1);
  assert.ok(replaced.received_at >= stored.received_at);

  for (const doc of [at("2026-03-12T09:30:00Z", 5), at("2026-03-12T11:00:00+01:00", 6)]) {
    assert.equal(await putTranscript(pool, "henning", doc), "older", doc.generatedAt);
    assert.deepEqual(await row(pool), replaced, doc.generatedAt);
  }
});

test("AC-15: two concurrent uploads over two connections always leave the newer one", async (t) => {
  const pool = await migrated(t);
  const searchPath = (await pool.query("SHOW search_path")).rows[0].search_path;
  const second = new pg.Pool({ connectionString: process.env.DATABASE_URL, options: `-c search_path=${searchPath}` });
  t.after(() => second.end());
  const older = at("2026-03-12T09:00:00Z", 1);
  const newer = at("2026-03-12T09:00:01Z", 2);

  for (let round = 0; round < 10; round++) {
    const account = `konto-${round}`;
    const [a, b] = round % 2 === 0 ? [older, newer] : [newer, older];
    const results = await Promise.all([putTranscript(pool, account, a), putTranscript(second, account, b)]);
    assert.ok(results.includes("stored"), `${round}: ${results}`);
    assert.deepEqual((await row(pool, account)).doc, newer, `Runde ${round}`);
  }
});

test("AC-16: two accounts keep their transcripts apart", async (t) => {
  const pool = await migrated(t);
  await putTranscript(pool, "henning", example());
  const before = await row(pool, "henning");

  assert.equal(await putTranscript(pool, "anna", at("2026-03-12T12:00:00Z", 9)), "stored");
  assert.deepEqual(await row(pool, "henning"), before);
  assert.equal(await count(pool), 2);
});

test("AC-17: the service does not recount, a mismatching nowCount and unknown now ids are stored", async (t) => {
  const pool = await migrated(t);
  const doc = changed((d) => { d.nowCount = 7; d.now.today = ["11111111-2222-4333-8444-555555555555"]; });
  assert.equal(await putTranscript(pool, "henning", doc), "stored");
});
