import { randomUUID } from "node:crypto";
import pg from "pg";

// Without a database the run fails, it is never skipped.
const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) {
  throw new Error("DATABASE_URL fehlt: die Tests laufen nur gegen echtes Postgres");
}

// Each test gets its own schema, so runs never see each other's tables.
export async function freshPool(t: { after: (fn: () => Promise<void>) => void }): Promise<pg.Pool> {
  const schema = `t_${randomUUID().replaceAll("-", "")}`;
  const admin = new pg.Pool({ connectionString: databaseUrl });
  await admin.query(`CREATE SCHEMA ${schema}`);
  const pool = new pg.Pool({ connectionString: databaseUrl, options: `-c search_path=${schema}` });
  t.after(async () => {
    await pool.end();
    await admin.query(`DROP SCHEMA ${schema} CASCADE`);
    await admin.end();
  });
  return pool;
}
