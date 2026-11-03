import type { KeyLookup } from "./apple.ts";

const APPLE_KEYS_URL = "https://appleid.apple.com/auth/keys";
const TTL = 3_600_000;
const LOCK = 60_000;
const TIMEOUT = 5000;

type Options = { fetch: typeof fetch; now: () => number; url?: string };

// Valid entries only: an object (not an array, not null) with a non-empty string kid; the first duplicate wins.
function toMap(doc: unknown): Map<string, JsonWebKey> | undefined {
  const list = (doc as { keys?: unknown } | null)?.keys;
  if (!Array.isArray(list)) return undefined;
  const map = new Map<string, JsonWebKey>();
  for (const entry of list) {
    if (entry === null || typeof entry !== "object" || Array.isArray(entry)) continue;
    const kid = (entry as { kid?: unknown }).kid;
    if (typeof kid === "string" && kid !== "" && !map.has(kid)) map.set(kid, entry as JsonWebKey);
  }
  return map.size > 0 ? map : undefined;
}

// One fetch with parsing; any failure yields undefined and never throws.
async function download(opts: Options, url: string): Promise<Map<string, JsonWebKey> | undefined> {
  try {
    const res = await opts.fetch(url, { signal: AbortSignal.timeout(TIMEOUT) });
    if (res.status !== 200) return undefined;
    return toMap(await res.json());
  } catch {
    return undefined;
  }
}

// Apple's public keys, cached for an hour; a reload at most once in 60 s, shared by concurrent callers, fail-closed.
export function createJwks(opts: Options): { keys: KeyLookup } {
  const url = opts.url ?? APPLE_KEYS_URL;
  let cache = new Map<string, JsonWebKey>();
  let loadedAt = -Infinity;
  let lastTry = -Infinity;
  let running: Promise<void> | undefined;

  const refresh = (t: number): Promise<void> | undefined => {
    if (running) return running;
    if (t - lastTry < LOCK) return undefined;
    lastTry = t;
    running = download(opts, url)
      .then((map) => { if (map) { cache = map; loadedAt = t; } })
      .finally(() => { running = undefined; });
    return running;
  };

  const keys: KeyLookup = async (kid) => {
    const t = opts.now();
    const fresh = () => t - loadedAt < TTL;
    if (fresh() && cache.has(kid)) return cache.get(kid)!;
    await refresh(t);
    if (!fresh()) return "keys_unavailable";
    return cache.get(kid) ?? "unknown_kid";
  };
  return { keys };
}
