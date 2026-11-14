import type pg from "pg";
import { type Check, fail, shape } from "./transcripts.ts";

export type DeviceDoc = { token: string; environment: "sandbox" | "production" };

// At most this many devices per account; the oldest give way to a new one.
export const MAX_DEVICES = 10;

// Apple fixes no length, so only hex, an even length and a wide span; the message never names the value.
const hex = /^[0-9a-f]+$/i;
const token: Check = (v, p) => {
  if (typeof v !== "string" || !hex.test(v) || v.length % 2 !== 0 || v.length < 64 || v.length > 200) fail(p, "kein Gerätetoken");
};
const environment: Check = (v, p) => {
  if (v !== "sandbox" && v !== "production") fail(p, "unbekannte Umgebung");
};

export function checkDevice(doc: unknown): asserts doc is DeviceDoc {
  shape(doc, "", { token, environment });
}

// One transaction: a token that moved leaves its old owner, the device's row is written, and past MAX_DEVICES the
// oldest rows of the account go (updated_at, then device, ascending), never the one just written.
export async function putDevice(pool: pg.Pool, account: string, device: string, doc: DeviceDoc): Promise<void> {
  const value = doc.token.toLowerCase();
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("DELETE FROM device_tokens WHERE token = $1 AND (account_id, device) <> ($2, $3)", [value, account, device]);
    await client.query(
      `INSERT INTO device_tokens (account_id, device, token, environment, updated_at) VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (account_id, device) DO UPDATE SET token = EXCLUDED.token, environment = EXCLUDED.environment, updated_at = now()`,
      [account, device, value, doc.environment],
    );
    // Keep the written row and the MAX_DEVICES - 1 newest others; everything older goes.
    await client.query(
      `DELETE FROM device_tokens WHERE account_id = $1 AND device IN (
         SELECT device FROM device_tokens WHERE account_id = $1 AND device <> $2
         ORDER BY updated_at DESC, device DESC OFFSET $3)`,
      [account, device, MAX_DEVICES - 1],
    );
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

// Every device row of the account, by device ascending; database errors reach the caller.
export async function listTokens(pool: pg.Pool, account: string): Promise<DeviceDoc[]> {
  const { rows } = await pool.query("SELECT token, environment FROM device_tokens WHERE account_id = $1 ORDER BY device", [account]);
  return rows.map((r) => ({ token: r.token as string, environment: r.environment as DeviceDoc["environment"] }));
}

// Drops only the row holding this token in this environment, so a row re-registered meanwhile stays.
export async function dropToken(pool: pg.Pool, token: string, environment: DeviceDoc["environment"]): Promise<boolean> {
  const result = await pool.query("DELETE FROM device_tokens WHERE token = $1 AND environment = $2", [token.toLowerCase(), environment]);
  return (result.rowCount ?? 0) > 0;
}
