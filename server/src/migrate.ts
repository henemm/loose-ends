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

// One transaction per migration: its SQL and its row in schema_migrations commit together or not at all.
// A migration never steers its own transaction: no BEGIN or COMMIT inside the file.
async function applyOne(pool: pg.Pool, migration: Migration): Promise<void> {
  const client = await pool.connect();
  // A failed ROLLBACK leaves the connection unusable; handing the error to release makes pg discard it.
  let broken: Error | boolean = false;
  try {
    await client.query("BEGIN");
    await client.query(migration.sql);
    await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [migration.name]);
    await client.query("COMMIT");
  } catch (error) {
    try {
      await client.query("ROLLBACK");
    } catch (rollbackError) {
      broken = rollbackError instanceof Error ? rollbackError : true;
    }
    throw error;
  } finally {
    client.release(broken);
  }
}

// Applies every migration not yet remembered and returns the names applied in this run, in order.
export async function migrate(pool: pg.Pool, dir: string): Promise<string[]> {
  const migrations = await loadMigrations(dir);
  await pool.query(
    "CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())",
  );
  const result = await pool.query<{ name: string }>("SELECT name FROM schema_migrations");
  const done = new Set(result.rows.map((row) => row.name));
  const applied: string[] = [];
  for (const migration of migrations) {
    if (done.has(migration.name)) continue;
    await applyOne(pool, migration);
    applied.push(migration.name);
  }
  return applied;
}
