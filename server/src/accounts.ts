import { createHash, randomBytes } from "node:crypto";
import type pg from "pg";

const hash = (token: string): Buffer => createHash("sha256").update(token).digest();

// Test helper; the product goes through admit.
// One statement: the same apple_sub gives the same account, also when two calls meet.
export async function findOrCreate(pool: pg.Pool, appleSub: string): Promise<string> {
  const result = await pool.query(
    "INSERT INTO accounts (apple_sub) VALUES ($1) ON CONFLICT (apple_sub) DO UPDATE SET apple_sub = EXCLUDED.apple_sub RETURNING id",
    [appleSub],
  );
  return result.rows[0].id;
}

// Advisory lock for the first account (#621 S6a); distinct from MIGRATE_LOCK_ID.
export const ACCOUNT_LOCK_ID = 7_960_613_002;

// The door (#621 S6a): with a list only its subs get in, existing accounts too; without one only the first account is
// created, after that only existing subs get in. null = refused, nothing written.
export async function admit(pool: pg.Pool, appleSub: string, allowed?: ReadonlySet<string>): Promise<string | null> {
  if (allowed === undefined) return admitFirst(pool, appleSub);
  if (!allowed.has(appleSub)) return null;
  const result = await pool.query(
    "INSERT INTO accounts (apple_sub) VALUES ($1) ON CONFLICT (apple_sub) DO UPDATE SET apple_sub = EXCLUDED.apple_sub RETURNING id",
    [appleSub],
  );
  return result.rows[0].id;
}

// One transaction under ACCOUNT_LOCK_ID: an existing sub gets its account, a new one only while accounts is empty.
async function admitFirst(pool: pg.Pool, appleSub: string): Promise<string | null> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("SELECT pg_advisory_xact_lock($1)", [ACCOUNT_LOCK_ID]);
    const found = await client.query("SELECT id FROM accounts WHERE apple_sub = $1", [appleSub]);
    if (found.rowCount === 1) {
      await client.query("COMMIT");
      return found.rows[0].id;
    }
    const counted = await client.query("SELECT count(*)::int AS n FROM accounts");
    if (counted.rows[0].n !== 0) {
      await client.query("ROLLBACK");
      return null;
    }
    const created = await client.query("INSERT INTO accounts (apple_sub) VALUES ($1) RETURNING id", [appleSub]);
    await client.query("COMMIT");
    return created.rows[0].id;
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// ALLOWED_APPLE_SUBS: missing or blank → undefined (no list); else comma-separated, trimmed, no empty entry.
// The error names only the variable, never its value.
export function allowedSubsFromEnv(env: NodeJS.ProcessEnv): ReadonlySet<string> | undefined {
  const raw = env.ALLOWED_APPLE_SUBS;
  if (raw === undefined || raw.trim() === "") return undefined;
  const subs = raw.split(",").map((entry) => entry.trim());
  if (subs.some((entry) => entry === "")) throw new Error("ALLOWED_APPLE_SUBS");
  return new Set(subs);
}

// 32 random bytes as base64url; only their SHA-256 is stored, the token leaves only as the return value.
export async function createSession(pool: pg.Pool, accountId: string): Promise<string> {
  const token = randomBytes(32).toString("base64url");
  await pool.query("INSERT INTO sessions (token_hash, account_id) VALUES ($1, $2)", [hash(token), accountId]);
  return token;
}

// One statement: the account of a valid session, last_used_at refreshed. Anything else is null, never an error.
export async function resolveSession(pool: pg.Pool, token: string): Promise<string | null> {
  if (typeof token !== "string" || token === "") return null;
  const result = await pool.query(
    "UPDATE sessions SET last_used_at = now() WHERE token_hash = $1 RETURNING account_id",
    [hash(token)],
  );
  return result.rows[0]?.account_id ?? null;
}

// Ends exactly this one session; false if there was none.
export async function endSession(pool: pg.Pool, token: string): Promise<boolean> {
  if (typeof token !== "string" || token === "") return false;
  const result = await pool.query("DELETE FROM sessions WHERE token_hash = $1", [hash(token)]);
  return result.rowCount === 1;
}

export type Deletion = { deleted: boolean; tokens: { blob: Buffer; clientId: string }[] };

// One transaction: lock the account first (a concurrent deletion waits and then finds nothing), read its Apple tokens
// ordered by client id, remove results, orders, transcript and the account; sessions and the Apple tokens follow by
// their foreign keys. An unknown account changes nothing.
export async function deleteAccount(pool: pg.Pool, accountId: string): Promise<Deletion> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const locked = await client.query("SELECT id FROM accounts WHERE id = $1 FOR UPDATE", [accountId]);
    if (locked.rowCount !== 1) {
      await client.query("ROLLBACK");
      return { deleted: false, tokens: [] };
    }
    // FOR UPDATE on the token rows too: an upsert that only changes a value takes no lock on accounts, and without it a fresh
    // token could commit between this read and the cascade and stay unrevoked.
    const found = await client.query(
      "SELECT refresh_token_enc, client_id FROM apple_tokens WHERE account_id = $1 ORDER BY client_id FOR UPDATE",
      [accountId],
    );
    await client.query("DELETE FROM order_results WHERE order_id IN (SELECT id FROM orders WHERE account_id = $1)", [accountId]);
    await client.query("DELETE FROM orders WHERE account_id = $1", [accountId]);
    await client.query("DELETE FROM transcripts WHERE account_id = $1", [accountId]);
    // OAuth rows known only by one of the account's grants (Interaction); rows with account_id follow by cascade.
    await client.query(
      "DELETE FROM oauth_records WHERE grant_id IN (SELECT grant_id FROM oauth_records WHERE account_id = $1 AND grant_id IS NOT NULL)",
      [accountId],
    );
    await client.query("DELETE FROM accounts WHERE id = $1", [accountId]);
    await client.query("COMMIT");
    return { deleted: true, tokens: found.rows.map((row) => ({ blob: row.refresh_token_enc, clientId: row.client_id })) };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
