import { test } from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtemp, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type pg from "pg";
import { migrate } from "../src/migrate.ts";
// AC-5: db.ts fails the run without DATABASE_URL, it is never skipped.
import { freshPool } from "./db.ts";

// Files are written in the given order, which is deliberately not the number order.
async function migrationDir(files: Array<[string, string]>): Promise<string> {
  const dir = await mkdtemp(join(tmpdir(), "le-migrations-"));
  for (const [name, sql] of files) {
    await writeFile(join(dir, name), sql);
  }
  return dir;
}

async function tableExists(pool: pg.Pool, name: string): Promise<boolean> {
  const result = await pool.query("SELECT to_regclass($1) AS oid", [name]);
  return result.rows[0].oid !== null;
}

async function remembered(pool: pg.Pool): Promise<string[]> {
  const result = await pool.query("SELECT name FROM schema_migrations ORDER BY name");
  return result.rows.map((row: { name: string }) => row.name);
}

const three: Array<[string, string]> = [
  ["003_uses_second.sql", "INSERT INTO second (id) VALUES (1);"],
  ["001_first.sql", "CREATE TABLE first (id int);"],
  ["002_second.sql", "CREATE TABLE second (id int);"],
];

test("AC-1: applies migrations in number order and returns their names in that order", async (t) => {
  const pool = await freshPool(t);
  const dir = await migrationDir(three);

  const applied = await migrate(pool, dir);

  assert.deepEqual(applied, ["001_first.sql", "002_second.sql", "003_uses_second.sql"]);
  const rows = await pool.query("SELECT id FROM second");
  assert.equal(rows.rowCount, 1);
});

test("AC-2: a second run applies nothing, a new file alone is applied", async (t) => {
  const pool = await freshPool(t);
  const dir = await migrationDir(three);
  await migrate(pool, dir);

  assert.deepEqual(await migrate(pool, dir), []);
  assert.deepEqual(await remembered(pool), ["001_first.sql", "002_second.sql", "003_uses_second.sql"]);
  assert.equal((await pool.query("SELECT id FROM second")).rowCount, 1);

  await writeFile(join(dir, "004_third.sql"), "CREATE TABLE third (id int);");
  assert.deepEqual(await migrate(pool, dir), ["004_third.sql"]);
  assert.equal((await remembered(pool)).length, 4);
});

test("AC-3: a broken migration rolls back completely and rethrows the Postgres error", async (t) => {
  const pool = await freshPool(t);
  const dir = await migrationDir([
    ["001_first.sql", "CREATE TABLE first (id int);"],
    ["002_broken.sql", "CREATE TABLE kept_out (id int);\nSELECT * FROM no_such_table;"],
  ]);

  await assert.rejects(migrate(pool, dir), (error: unknown) => {
    assert.ok(error instanceof Error);
    assert.equal((error as Error & { code?: string }).code, "42P01");
    assert.match(error.message, /no_such_table/);
    return true;
  });

  assert.equal(await tableExists(pool, "kept_out"), false);
  assert.equal(await tableExists(pool, "first"), true);
  assert.deepEqual(await remembered(pool), ["001_first.sql"]);
});

test("AC-4: a gap in the numbers is refused before anything is applied", async (t) => {
  const pool = await freshPool(t);
  const dir = await migrationDir([
    ["001_first.sql", "CREATE TABLE first (id int);"],
    ["003_third.sql", "CREATE TABLE third (id int);"],
  ]);

  await assert.rejects(migrate(pool, dir), /Lücke.*002/);

  assert.equal(await tableExists(pool, "first"), false);
  assert.equal(await tableExists(pool, "schema_migrations"), false);
});

test("AC-4: a duplicate number is refused before anything is applied", async (t) => {
  const pool = await freshPool(t);
  const dir = await migrationDir([
    ["001_first.sql", "CREATE TABLE first (id int);"],
    ["002_a.sql", "CREATE TABLE a (id int);"],
    ["002_b.sql", "CREATE TABLE b (id int);"],
  ]);

  await assert.rejects(migrate(pool, dir), /doppelt.*002/);

  assert.equal(await tableExists(pool, "first"), false);
  assert.equal(await tableExists(pool, "schema_migrations"), false);
});

test("AC-4: a misnamed .sql file is refused before anything is applied, README.md is ignored", async (t) => {
  const pool = await freshPool(t);
  const dir = await migrationDir([
    ["001_first.sql", "CREATE TABLE first (id int);"],
    ["01_x.sql", "CREATE TABLE x (id int);"],
    ["README.md", "not a migration"],
  ]);

  await assert.rejects(migrate(pool, dir), /falsch benannt.*01_x\.sql/);

  assert.equal(await tableExists(pool, "first"), false);
  assert.equal(await tableExists(pool, "schema_migrations"), false);
});

test("AC-4: a README.md beside the migrations does not disturb the run", async (t) => {
  const pool = await freshPool(t);
  const dir = await migrationDir([...three, ["README.md", "not a migration"]]);

  assert.deepEqual(await migrate(pool, dir), ["001_first.sql", "002_second.sql", "003_uses_second.sql"]);
});

test("AC-4: number 000 is refused as invalid, not as a duplicate", async (t) => {
  const pool = await freshPool(t);
  const dir = await migrationDir([
    ["000_a.sql", "CREATE TABLE a (id int);"],
    ["001_first.sql", "CREATE TABLE first (id int);"],
  ]);

  await assert.rejects(migrate(pool, dir), /000.*ungültig/);

  assert.equal(await tableExists(pool, "schema_migrations"), false);
});

test("AC-5: without DATABASE_URL the test run fails and names the variable", () => {
  const env = { ...process.env };
  delete env.DATABASE_URL;
  // Inherited from node --test, it would make the child report to us and exit 0.
  delete env.NODE_TEST_CONTEXT;
  const child = spawnSync(process.execPath, ["--test", import.meta.filename], { env, encoding: "utf8" });

  assert.notEqual(child.status, 0);
  assert.match(child.stdout + child.stderr, /DATABASE_URL/);
});
