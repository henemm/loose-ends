import { randomBytes } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import type pg from "pg";
import { findOrCreate } from "./accounts.ts";
import { type AppleConfig, type KeyLookup, verifyIdentityToken } from "./apple.ts";
import { appleReturnUrl, redeemCode } from "./apple-client.ts";
import { PgAdapter } from "./oauth-adapter.ts";

// The way back from Apple (#621 S4b-2a): Apple's form_post is checked and ends in a one-time ticket and a 303 to
// finish. finish itself, which needs the interaction cookie and the ticket, is S4b-2b; until then nobody signs in.
export type ReturnHandler = (req: IncomingMessage, res: ServerResponse) => Promise<void>;
export type AppleReturnDeps = {
  pool: pg.Pool; config: AppleConfig; publicUrl: string; now: () => Date; fetch: typeof fetch; keys: KeyLookup;
  log: (event: string) => void;
};
type Ticket = { uid: string; accountId: string } | { uid: string; error: "access_denied" | "temporarily_unavailable" };
type Fields = { state: string; code?: string; error?: string };

const LIMIT = 16 * 1024;
const TICKET_TTL = 60;
const FORM = "application/x-www-form-urlencoded";
const REFUSED = "oauth return refused";
const STORE_FAILED = "oauth return store failed";

function empty(res: ServerResponse, status: number, headers: Record<string, string> = {}): void {
  res.writeHead(status, { "cache-control": "no-store", ...headers }).end();
}

// One fixed answer without values.
function badRequest(res: ServerResponse): void {
  res.writeHead(400, { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" }).end("bad request");
}

// Counted while reading (Content-Length may lie or be absent); past the limit the rest is not kept, the answer is null.
function readLimited(req: IncomingMessage): Promise<string | null> {
  return new Promise((done, fail) => {
    const chunks: Buffer[] = [];
    let size = 0;
    const onData = (chunk: Buffer) => {
      size += chunk.length;
      if (size <= LIMIT) return void chunks.push(chunk);
      req.off("data", onData);
      req.resume();
      done(null);
    };
    req.on("data", onData);
    req.once("end", () => done(Buffer.concat(chunks).toString("utf8")));
    req.once("error", fail);
  });
}

// state exactly once, exactly one of code and error, each at most once; every other field (user too) is never read.
function parseFields(raw: string): Fields | null {
  const params = new URLSearchParams(raw);
  const one = (name: string) => {
    const values = params.getAll(name);
    return values.length === 1 && values[0] !== "" ? values[0] : values.length === 0 ? undefined : null;
  };
  const state = one("state");
  const code = one("code");
  const error = one("error");
  if (typeof state !== "string" || code === null || error === null) return null;
  if ((code === undefined) === (error === undefined)) return null;
  return { state, code, error };
}

// The state's row once: unknown, expired, foreign or consumed → null; a database error throws.
async function redeemState(deps: AppleReturnDeps, state: string): Promise<{ uid: string; nonce: string } | null> {
  const adapter = new PgAdapter(deps.pool, "AppleLogin", deps.now);
  const found = await adapter.find(state);
  if (!found || typeof found.uid !== "string" || typeof found.nonce !== "string" || found.consumed !== undefined) return null;
  try {
    await adapter.consume(state);
  } catch {
    return null;
  }
  return { uid: found.uid, nonce: found.nonce };
}

// Apple's error, a refused redemption or token → access_denied; Apple unreachable → temporarily_unavailable.
async function outcome(deps: AppleReturnDeps, fields: Fields, uid: string, nonce: string): Promise<Ticket> {
  const { config, fetch, publicUrl } = deps;
  const webClientId = config.webClientId;
  if (fields.code === undefined || webClientId === undefined) return { uid, error: "access_denied" };
  const now = () => deps.now().getTime();
  const redeemed = await redeemCode(fields.code, webClientId, { config, fetch, now, redirectUri: appleReturnUrl(publicUrl) });
  if (!redeemed.ok) return { uid, error: redeemed.reason === "unavailable" ? "temporarily_unavailable" : "access_denied" };
  // The web refresh token is dropped: neither stored nor revoked until its own storage (migration 005, before S6).
  const verdict = await verifyIdentityToken(redeemed.idToken, nonce, { config, keys: deps.keys, now: now(), audiences: [webClientId] });
  if (!verdict.ok) return { uid, error: verdict.reason === "keys_unavailable" ? "temporarily_unavailable" : "access_denied" };
  return { uid, accountId: await findOrCreate(deps.pool, verdict.sub) };
}

// From the state on: the result as a ticket, then the 303; any failure a fixed 400, never a redirect without ticket.
async function finishReturn(deps: AppleReturnDeps, fields: Fields, res: ServerResponse): Promise<void> {
  let at: { uid: string; nonce: string } | null;
  try {
    at = await redeemState(deps, fields.state);
  } catch {
    deps.log(STORE_FAILED);
    return badRequest(res);
  }
  if (at === null) {
    deps.log(REFUSED);
    return badRequest(res);
  }
  const ticket = randomBytes(32).toString("base64url");
  try {
    const payload = await outcome(deps, fields, at.uid, at.nonce);
    await new PgAdapter(deps.pool, "AppleTicket", deps.now).upsert(ticket, payload, TICKET_TTL);
  } catch {
    deps.log(STORE_FAILED);
    return badRequest(res);
  }
  const location = `${new URL(deps.publicUrl).origin}/oauth/interaction/${encodeURIComponent(at.uid)}/finish?ticket=${ticket}`;
  empty(res, 303, { location, "referrer-policy": "no-referrer" });
}

// POST only, form only, at most 16 KiB counted while reading, then the fields; the state is untouched before that.
export function appleReturn(deps: AppleReturnDeps): ReturnHandler {
  return async (req, res) => {
    if (req.method !== "POST") return empty(res, 405, { allow: "POST" });
    const type = (req.headers["content-type"] ?? "").split(";")[0].trim().toLowerCase();
    if (type !== FORM) return empty(res, 415);
    let raw: string | null;
    try {
      raw = await readLimited(req);
    } catch {
      deps.log(REFUSED);
      return badRequest(res);
    }
    if (raw === null) return empty(res, 413, { connection: "close" });
    const fields = parseFields(raw);
    if (fields === null) {
      deps.log(REFUSED);
      return badRequest(res);
    }
    await finishReturn(deps, fields, res);
  };
}
