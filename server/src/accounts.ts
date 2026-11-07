import { createHash, randomBytes } from "node:crypto";
import type pg from "pg";

const hash = (token: string): Buffer => createHash("sha256").update(token).digest();

// One statement: the same apple_sub gives the same account, also when two calls meet.
export async function findOrCreate(pool: pg.Pool, appleSub: string): Promise<string> {
  const result = await pool.query(
    "INSERT INTO accounts (apple_sub) VALUES ($1) ON CONFLICT (apple_sub) DO UPDATE SET apple_sub = EXCLUDED.apple_sub RETURNING id",
    [appleSub],
  );
  return result.rows[0].id;
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
    const found = await client.query(
      "SELECT refresh_token_enc, client_id FROM apple_tokens WHERE account_id = $1 ORDER BY client_id",
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
