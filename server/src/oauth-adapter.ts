import { createHash } from "node:crypto";
import type pg from "pg";

type Payload = Record<string, unknown>;

const CLEANUP_EVERY_MS = 10 * 60 * 1000;
// Last cleanup per pool (module state, no timer); the first upsert only starts the count.
const lastCleanup = new WeakMap<pg.Pool, number>();

const hash = (id: string): Buffer => createHash("sha256").update(id).digest();
const NOT_EXPIRED = "(expires_at IS NULL OR expires_at > $3)";

// Payload as oidc-provider expects it back; consumed in seconds while the row is consumed.
function restore(payload: Payload, consumedAt: Date | null): Payload {
  return consumedAt ? { ...payload, consumed: Math.floor(consumedAt.getTime() / 1000) } : payload;
}

// The oidc-provider adapter on one table: ids only as SHA-256, jti never stored, time from the handed-in clock.
export class PgAdapter {
  private readonly pool: pg.Pool;
  private readonly name: string;
  private readonly now: () => Date;

  constructor(pool: pg.Pool, name: string, now: () => Date = () => new Date()) {
    this.pool = pool;
    this.name = name;
    this.now = now;
  }

  // Insert or replace; consumed_at survives a replace. ReplayDetection replaces only an expired row, else throws.
  async upsert(id: string, payload: Payload, expiresIn?: number): Promise<void> {
    const now = this.now();
    await this.cleanup(now);
    const { jti: _jti, consumed: _consumed, ...stored } = payload;
    const expiresAt = expiresIn === undefined ? null : new Date(now.getTime() + expiresIn * 1000);
    const replayOnly = this.name === "ReplayDetection" ? "WHERE oauth_records.expires_at <= $8" : "";
    const result = await this.pool.query(
      `INSERT INTO oauth_records (model, id_hash, payload, grant_id, uid, account_id, expires_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (model, id_hash) DO UPDATE SET payload = EXCLUDED.payload, grant_id = EXCLUDED.grant_id,
         uid = EXCLUDED.uid, account_id = EXCLUDED.account_id, expires_at = EXCLUDED.expires_at
       ${replayOnly} RETURNING 1`,
      [this.name, hash(id), stored, payload.grantId ?? null, payload.uid ?? null, payload.accountId ?? null, expiresAt,
        ...(replayOnly ? [now] : [])],
    );
    if (result.rowCount !== 1) throw new Error("oauth record already present");
  }

  async find(id: string): Promise<Payload | undefined> {
    const result = await this.pool.query(
      `SELECT payload, consumed_at FROM oauth_records WHERE model = $1 AND id_hash = $2 AND ${NOT_EXPIRED}`,
      [this.name, hash(id), this.now()],
    );
    const found = result.rows[0];
    return found ? { ...restore(found.payload, found.consumed_at), jti: id } : undefined;
  }

  // Without jti: the row holds only the hash of the id.
  async findByUid(uid: string): Promise<Payload | undefined> {
    const result = await this.pool.query(
      `SELECT payload, consumed_at FROM oauth_records WHERE model = $1 AND uid = $2 AND ${NOT_EXPIRED} LIMIT 1`,
      [this.name, uid, this.now()],
    );
    const found = result.rows[0];
    return found ? restore(found.payload, found.consumed_at) : undefined;
  }

  async findByUserCode(_userCode: string): Promise<never> {
    throw new Error("findByUserCode not supported");
  }

  // One statement: only an unconsumed, unexpired row is marked; anything else throws.
  async consume(id: string): Promise<void> {
    const result = await this.pool.query(
      `UPDATE oauth_records SET consumed_at = $3 WHERE model = $1 AND id_hash = $2 AND consumed_at IS NULL AND ${NOT_EXPIRED}
       RETURNING 1`,
      [this.name, hash(id), this.now()],
    );
    if (result.rowCount !== 1) throw new Error("oauth record not consumable");
  }

  async destroy(id: string): Promise<void> {
    await this.pool.query("DELETE FROM oauth_records WHERE model = $1 AND id_hash = $2", [this.name, hash(id)]);
  }

  // Every model, not only this one.
  async revokeByGrantId(grantId: string): Promise<void> {
    await this.pool.query("DELETE FROM oauth_records WHERE grant_id = $1", [grantId]);
  }

  // At most every 10 minutes per pool. A failed cleanup is ignored on purpose: expired rows are invisible to
  // find anyway, and the write must not fail for it; nothing is logged, so no value can leak.
  private async cleanup(now: Date): Promise<void> {
    const last = lastCleanup.get(this.pool);
    if (last === undefined || now.getTime() - last < CLEANUP_EVERY_MS) {
      if (last === undefined) lastCleanup.set(this.pool, now.getTime());
      return;
    }
    lastCleanup.set(this.pool, now.getTime());
    await this.pool.query("DELETE FROM oauth_records WHERE expires_at < $1", [now]).catch(() => undefined);
  }
}
