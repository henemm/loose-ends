import type pg from "pg";

export type WindowStats = { requests: number; errors: number; errorRate: number };

// Counts the answers of the last windowMs (5 minutes) and how many of them were 5xx; the clock is injected.
export class ErrorWindow {
  private readonly now: () => number;
  private readonly windowMs: number;
  private entries: Array<{ at: number; failed: boolean }> = [];

  constructor(now: () => number, windowMs = 300_000) {
    this.now = now;
    this.windowMs = windowMs;
  }

  record(status: number): void {
    this.entries.push({ at: this.now(), failed: status >= 500 });
  }

  // Drops what is older than the window first; the rate is rounded to three decimals, 0 without requests.
  stats(): WindowStats {
    const oldest = this.now() - this.windowMs;
    this.entries = this.entries.filter((entry) => entry.at >= oldest);
    const requests = this.entries.length;
    const errors = this.entries.filter((entry) => entry.failed).length;
    const errorRate = requests === 0 ? 0 : Math.round((errors / requests) * 1000) / 1000;
    return { requests, errors, errorRate };
  }

  // At least 20 answers, so that a single 500 never trips it, and more than half of them 5xx.
  tripped(): boolean {
    const { requests, errorRate } = this.stats();
    return requests >= 20 && errorRate > 0.5;
  }
}

export type HealthOptions = { pool: pg.Pool; isMigrated: () => boolean; window: ErrorWindow; timeoutMs?: number };

// SELECT 1 within timeoutMs; an error or the timeout is "down", never an exception. The query itself is not cancelled.
async function probe(pool: pg.Pool, timeoutMs: number): Promise<"up" | "down"> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<"down">((done) => { timer = setTimeout(() => done("down"), timeoutMs); });
  try {
    return await Promise.race([pool.query("SELECT 1").then(() => "up" as const), timeout]);
  } catch {
    return "down";
  } finally {
    clearTimeout(timer);
  }
}

// 200 only when migrated, the database answers and the error window has not tripped; the body holds numbers and words only.
export function healthHandler({ pool, isMigrated, window, timeoutMs = 2000 }: HealthOptions): () => Promise<Response> {
  return async () => {
    const db = await probe(pool, timeoutMs);
    const migrated = isMigrated();
    const { requests, errorRate } = window.stats();
    const ok = migrated && db === "up" && !window.tripped();
    return Response.json(
      { status: ok ? "ok" : "unavailable", db, migrated, errorRate, requests },
      { status: ok ? 200 : 503 },
    );
  };
}
