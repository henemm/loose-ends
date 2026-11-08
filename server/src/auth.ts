import type pg from "pg";
import { admit, createSession, type Deletion, deleteAccount, endSession, resolveSession } from "./accounts.ts";
import { type AppleConfig, type KeyLookup, verifyIdentityToken } from "./apple.ts";
import { redeemCode, revokeToken } from "./apple-client.ts";
import { decryptToken, encryptToken, storeRefreshToken } from "./apple-vault.ts";
import type { Route } from "./main.ts";

// log gets only the fixed events "account refused", "apple revoke skipped" and "apple revoke failed"; silent without it.
// allowedSubs: the door's list (admit); without it only the first account is created.
export type AuthDeps = {
  pool: pg.Pool; config?: AppleConfig; keys?: KeyLookup; fetch: typeof fetch; now: () => number; log?: (event: string) => void;
  allowedSubs?: ReadonlySet<string>;
};
type Login = { identityToken: string; nonce: string; code: string };

const BODY_LIMIT = 16 * 1024;

// Every refusal is a bare status: the answer never tells which check failed.
const status = (code: number) => new Response(null, { status: code });
const notAllowed = () => new Response(null, { status: 405, headers: { allow: "POST" } });

// The value behind "Bearer " (scheme in any case), null for a missing header, another scheme, empty or more than one token.
export function bearerToken(request: Request): string | null {
  const match = /^bearer ([^\s]+)$/i.exec(request.headers.get("authorization") ?? "");
  return match ? match[1] : null;
}

function isJson(request: Request): boolean {
  const type = request.headers.get("content-type") ?? "";
  return type.split(";")[0].trim().toLowerCase() === "application/json";
}

// The body as text, counted while reading (Content-Length may lie); null once it passes the limit.
async function readLimited(request: Request): Promise<string | null> {
  if (request.body === null) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > BODY_LIMIT) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  return Buffer.concat(chunks).toString("utf8");
}

// A JSON object with three non-empty strings, otherwise null.
function parseLogin(raw: string): Login | null {
  let value: unknown;
  try { value = JSON.parse(raw); } catch { return null; }
  if (value === null || typeof value !== "object" || Array.isArray(value)) return null;
  const doc = value as Record<string, unknown>;
  const text = (key: string) => typeof doc[key] === "string" && doc[key] !== "";
  if (!text("identityToken") || !text("nonce") || !text("code")) return null;
  return { identityToken: doc.identityToken as string, nonce: doc.nonce as string, code: doc.code as string };
}

// Order: identity token, code (always redeemed once the token holds), same sub, the door, store the key, createSession last.
async function signIn(deps: AuthDeps, config: AppleConfig, keys: KeyLookup, login: Login): Promise<Response> {
  const verdict = await verifyIdentityToken(login.identityToken, login.nonce, { config, keys, now: deps.now() });
  if (!verdict.ok) return status(verdict.reason === "keys_unavailable" ? 503 : 401);
  const redeemed = await redeemCode(login.code, verdict.aud, { config, fetch: deps.fetch, now: deps.now });
  if (!redeemed.ok) return status(redeemed.reason === "unavailable" ? 503 : 401);
  if (redeemed.sub !== verdict.sub) return status(401);
  const accountId = await admit(deps.pool, verdict.sub, deps.allowedSubs);
  if (accountId === null) {
    deps.log?.("account refused");
    return status(401);
  }
  const blob = encryptToken(config.tokenKey, accountId, redeemed.refreshToken);
  // false: the account was deleted meanwhile; no session for it.
  if (!(await storeRefreshToken(deps.pool, accountId, blob, verdict.aud))) return status(401);
  const sessionToken = await createSession(deps.pool, accountId);
  return Response.json({ sessionToken }, { headers: { "cache-control": "no-store" } });
}

// Checks run in the order of the spec; the first violation answers.
async function apple(deps: AuthDeps, request: Request): Promise<Response> {
  const { config, keys } = deps;
  if (config === undefined || keys === undefined) return status(503);
  if (request.method !== "POST") return notAllowed();
  if (!isJson(request)) return status(415);
  const raw = await readLimited(request);
  if (raw === null) return status(413);
  const login = parseLogin(raw);
  if (login === null) return status(400);
  return signIn(deps, config, keys, login);
}

// Ends exactly this one session; 204 also for an unknown one, so the answer never tells whether a token was valid.
async function logout(deps: AuthDeps, request: Request): Promise<Response> {
  if (request.method !== "POST") return notAllowed();
  const token = bearerToken(request);
  if (token === null) return status(401);
  await endSession(deps.pool, token);
  return status(204);
}

// One row, revoked with the client id it was issued for; never throws (network errors are caught in revokeToken).
async function revokeOne(deps: AuthDeps, accountId: string, token: Deletion["tokens"][number]): Promise<void> {
  const { config } = deps;
  // An unconfigured client id would make clientSecret throw after the commit.
  const known = config !== undefined
    && (config.clientIds.includes(token.clientId) || (config.webClientId !== undefined && token.clientId === config.webClientId));
  const plain = known ? decryptToken(config.tokenKey, accountId, token.blob) : null;
  if (!known || plain === null || plain === "") {
    deps.log?.("apple revoke skipped");
    return;
  }
  const revoked = await revokeToken(plain, token.clientId, { config, fetch: deps.fetch, now: deps.now });
  if (!revoked.ok) deps.log?.("apple revoke failed");
}

// Best effort once the account is gone, one row after the other: Apple's answer never changes the response.
async function revokeAfterDelete(deps: AuthDeps, accountId: string, deletion: Deletion): Promise<void> {
  if (deletion.tokens.length === 0) {
    deps.log?.("apple revoke skipped");
    return;
  }
  for (const token of deletion.tokens) await revokeOne(deps, accountId, token);
}

// Session, then delete, then revoke at Apple; needs no Apple config, deleting never waits on Apple's setup.
async function deleteAccountRoute(deps: AuthDeps, request: Request): Promise<Response> {
  if (request.method !== "POST") return notAllowed();
  const token = bearerToken(request);
  if (token === null) return status(401);
  const accountId = await resolveSession(deps.pool, token);
  if (accountId === null) return status(401);
  const deletion = await deleteAccount(deps.pool, accountId);
  // false: a concurrent deletion won; no second revoke.
  if (!deletion.deleted) return status(401);
  await revokeAfterDelete(deps, accountId, deletion);
  return status(204);
}

// Exceptions are not caught here: dispatch in main.ts turns them into 500 without a body.
export function authRoutes(deps: AuthDeps): Record<string, Route> {
  return {
    "/auth/apple": (request) => apple(deps, request),
    "/auth/logout": (request) => logout(deps, request),
    "/auth/delete": (request) => deleteAccountRoute(deps, request),
  };
}
