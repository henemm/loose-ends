import { createCipheriv, createDecipheriv, randomBytes } from "node:crypto";
import type pg from "pg";

const VERSION = 0x01;
const KEY_LENGTH = 32;
const IV_LENGTH = 12;
const TAG_LENGTH = 16;
const HEADER = 1 + IV_LENGTH + TAG_LENGTH;

// Blob [0x01 | iv 12 | tag 16 | ciphertext], AES-256-GCM, the account as AAD. Throws on own misuse; messages carry no secret.
export function encryptToken(key: Buffer, accountId: string, token: string): Buffer {
  if (!Buffer.isBuffer(key) || key.length !== KEY_LENGTH) throw new Error("token key must be 32 bytes");
  if (typeof token !== "string" || token === "") throw new Error("token must not be empty");
  if (typeof accountId !== "string" || accountId === "") throw new Error("account id must not be empty");
  const iv = randomBytes(IV_LENGTH);
  const cipher = createCipheriv("aes-256-gcm", key, iv, { authTagLength: TAG_LENGTH });
  cipher.setAAD(Buffer.from(accountId));
  const ct = Buffer.concat([cipher.update(token, "utf8"), cipher.final()]);
  return Buffer.concat([Buffer.from([VERSION]), iv, cipher.getAuthTag(), ct]);
}

// The plain token, or null for anything else: no Buffer, wrong key length, short blob, other version, tampering,
// wrong key or wrong account. Never throws.
export function decryptToken(key: Buffer, accountId: string, blob: unknown): string | null {
  if (!Buffer.isBuffer(blob) || !Buffer.isBuffer(key) || key.length !== KEY_LENGTH) return null;
  if (typeof accountId !== "string" || blob.length < HEADER || blob[0] !== VERSION) return null;
  try {
    const decipher = createDecipheriv("aes-256-gcm", key, blob.subarray(1, 1 + IV_LENGTH), { authTagLength: TAG_LENGTH });
    decipher.setAAD(Buffer.from(accountId));
    decipher.setAuthTag(blob.subarray(1 + IV_LENGTH, HEADER));
    return Buffer.concat([decipher.update(blob.subarray(HEADER)), decipher.final()]).toString("utf8");
  } catch {
    return null;
  }
}

// One token per account: a new one replaces the old and moves created_at. An unknown account (23503) gives false.
export async function storeRefreshToken(pool: pg.Pool, accountId: string, blob: Buffer): Promise<boolean> {
  try {
    await pool.query(
      `INSERT INTO apple_tokens (account_id, refresh_token_enc) VALUES ($1, $2)
       ON CONFLICT (account_id) DO UPDATE SET refresh_token_enc = EXCLUDED.refresh_token_enc, created_at = now()`,
      [accountId, blob],
    );
    return true;
  } catch (error) {
    if ((error as { code?: unknown } | null)?.code === "23503") return false;
    throw error;
  }
}
