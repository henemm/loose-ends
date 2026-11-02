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

export type Deletion = { deleted: boolean; appleToken: Buffer | null };

// One transaction: lock the account, read its Apple token, remove results, orders, transcript and the account;
// sessions and the Apple token follow by their foreign keys. An unknown account changes nothing.
export async function deleteAccount(pool: pg.Pool, accountId: string): Promise<Deletion> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const found = await client.query(
      `SELECT t.refresh_token_enc FROM accounts a LEFT JOIN apple_tokens t ON t.account_id = a.id
       WHERE a.id = $1 FOR UPDATE OF a`,
      [accountId],
    );
    if (found.rowCount !== 1) {
      await client.query("ROLLBACK");
      return { deleted: false, appleToken: null };
    }
    await client.query("DELETE FROM order_results WHERE order_id IN (SELECT id FROM orders WHERE account_id = $1)", [accountId]);
    await client.query("DELETE FROM orders WHERE account_id = $1", [accountId]);
    await client.query("DELETE FROM transcripts WHERE account_id = $1", [accountId]);
    await client.query("DELETE FROM accounts WHERE id = $1", [accountId]);
    await client.query("COMMIT");
    return { deleted: true, appleToken: found.rows[0].refresh_token_enc };
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}
