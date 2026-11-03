import { readdir, readFile } from "node:fs/promises";
import { join } from "node:path";
import type pg from "pg";

export type Migration = { number: number; name: string; sql: string };

const fileName = /^\d{3}_.+\.sql$/;

function label(number: number): string {
  return String(number).padStart(3, "0");
}

// Reads NNN_name.sql in number order; a misnamed .sql file, number 000, a gap or a duplicate number is
// refused here, before any database work. Files not ending in .sql (README.md) are ignored.
export async function loadMigrations(dir: string): Promise<Migration[]> {
  const names = (await readdir(dir)).filter((name) => name.toLowerCase().endsWith(".sql"));
  for (const name of names) {
    if (!fileName.test(name)) {
      throw new Error(`Migrationsdatei falsch benannt: ${name} (erwartet NNN_name.sql)`);
    }
  }
  const migrations: Migration[] = [];
  for (const name of names) {
    migrations.push({ number: Number(name.slice(0, 3)), name, sql: await readFile(join(dir, name), "utf8") });
  }
  migrations.sort((a, b) => a.number - b.number || a.name.localeCompare(b.name));
  migrations.forEach((migration, index) => {
    const expected = index + 1;
    if (migration.number < 1) {
      throw new Error(`Migrationsnummer ${label(migration.number)} ungültig, die Folge beginnt bei 001 (${migration.name})`);
    }
    if (migration.number < expected) {
      throw new Error(`Migrationsnummer doppelt: ${label(migration.number)} (${migration.name})`);
    }
    if (migration.number > expected) {
      throw new Error(`Lücke in den Migrationen: ${label(expected)} fehlt vor ${migration.name}`);
    }
  });
  return migrations;
}

// The migrate run lock: one session advisory lock for the whole service, so two processes starting at once
// never apply the same migration twice; a second run waits here and then finds everything done.
export const MIGRATE_LOCK_ID = 7_960_613_001;

// Set when a ROLLBACK or the unlock failed: the connection is unusable and release(error) makes pg discard it.
type Run = { broken: Error | boolean };

function asBroken(error: unknown): Error | boolean {
  return error instanceof Error ? error : true;
}

// One transaction per migration: its SQL and its row in schema_migrations commit together or not at all.
// A migration never steers its own transaction: no BEGIN or COMMIT inside the file.
async function applyOne(client: pg.PoolClient, migration: Migration, run: Run): Promise<void> {
  try {
    await client.query("BEGIN");
    await client.query(migration.sql);
    await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [migration.name]);
    await client.query("COMMIT");
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch (rollbackError) {
      run.broken = asBroken(rollbackError);
    }
    throw error;
  }
}

// Reads the state only after the lock, so a run that waited sees everything the first one applied.
async function applyPending(client: pg.PoolClient, migrations: Migration[], run: Run): Promise<string[]> {
  await client.query(
    "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())",
  );
  const result = await client.query<{ name: string }>("SELECT name FROM schema_migrations");
  const done = new Set(result.rows.map((row) => row.name));
  const applied: string[] = [];
  for (const migration of migrations) {
    if (done.has(migration.name)) continue;
    await applyOne(client, migration, run);
    applied.push(migration.name);
  }
  return applied;
}

// Applies every migration not yet remembered and returns the names applied in this run, in order.
// One client holds the lock for the whole run; a failed unlock never hides the original error. A discarded
// connection ends its session, and with it Postgres releases the lock.
export async function migrate(pool: pg.Pool, dir: string): Promise<string[]> {
  const migrations = await loadMigrations(dir);
  const client = await pool.connect();
  const run: Run = { broken: false };
  try {
    await client.query("SELECT pg_advisory_lock($1)", [MIGRATE_LOCK_ID]);
    try {
      return await applyPending(client, migrations, run);
    } finally {
      if (run.broken === false) {
        await client.query("SELECT pg_advisory_unlock($1)", [MIGRATE_LOCK_ID]).catch((unlockError: unknown) => {
          run.broken = asBroken(unlockError);
        });
      }
    }
  } finally {
    client.release(run.broken);
  }
}
