import { createHash, sign } from "node:crypto";
import type { AppleConfig } from "./apple.ts";

export type Redeemed = { ok: true; refreshToken: string; sub: string; idToken: string } | { ok: false; reason: string };
export type Revoked = { ok: true } | { ok: false; reason: string };
type Doc = Record<string, unknown>;

const ISSUER = "https://appleid.apple.com";
const AUTHORIZE_URL = "https://appleid.apple.com/auth/authorize";
const TOKEN_URL = "https://appleid.apple.com/auth/token";
const REVOKE_URL = "https://appleid.apple.com/auth/revoke";
const SECRET_LIFETIME_S = 300;
const TIMEOUT_MS = 5000;
const APPLE_ERRORS = new Set([
  "invalid_request", "invalid_client", "invalid_grant", "unauthorized_client", "unsupported_grant_type", "invalid_scope",
]);

const segment = (value: Doc) => Buffer.from(JSON.stringify(value)).toString("base64url");

function asObject(value: unknown): Doc | null {
  return value !== null && typeof value === "object" && !Array.isArray(value) ? (value as Doc) : null;
}

const text = (value: unknown): value is string => typeof value === "string" && value !== "";

// ES256 JWT for Apple's token endpoint, new per call, valid 5 minutes. Throws on own misuse; messages carry no secret.
export function clientSecret(config: AppleConfig, clientId: string, now: number): string {
  if (!config.clientIds.includes(clientId) && (!config.webClientId || clientId !== config.webClientId)) {
    throw new Error("client id is not configured");
  }
  if (typeof now !== "number" || !Number.isFinite(now)) throw new Error("now must be a finite number");
  const iat = Math.floor(now / 1000);
  const data = `${segment({ alg: "ES256", kid: config.keyId })}.${segment({
    iss: config.teamId, iat, exp: iat + SECRET_LIFETIME_S, aud: ISSUER, sub: clientId,
  })}`;
  const signature = sign("sha256", Buffer.from(data), { key: config.privateKey, dsaEncoding: "ieee-p1363" });
  return `${data}.${signature.toString("base64url")}`;
}

// The id_token comes over TLS straight from Apple, so it is only read (OIDC Core 3.1.3.7 (6)), not verified.
function idTokenSub(token: unknown, clientId: string): string | null {
  if (typeof token !== "string") return null;
  const parts = token.split(".");
  if (parts.length !== 3 || !/^[A-Za-z0-9_-]+$/.test(parts[1])) return null;
  let payload: Doc | null;
  try { payload = asObject(JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"))); } catch { return null; }
  if (!payload || payload.iss !== ISSUER || payload.aud !== clientId || !text(payload.sub)) return null;
  return payload.sub;
}

// Apple's error name when it is one of the known ones, never its text.
function appleReason(body: Doc | null): string {
  const error = body?.error;
  return typeof error === "string" && APPLE_ERRORS.has(error) ? `apple:${error}` : "apple_status";
}

// The body as JSON object, null when it is none; undefined when reading breaks off (network, timeout).
async function readBody(response: Response): Promise<Doc | null | undefined> {
  let raw: string;
  try { raw = await response.text(); } catch { return undefined; }
  try { return asObject(JSON.parse(raw)); } catch { return null; }
}

// One form POST to Apple with the 5 s limit; null on network failure, timeout or any throw from fetch.
async function postForm(doFetch: typeof fetch, url: string, form: Record<string, string>): Promise<Response | null> {
  try {
    return await doFetch(url, {
      method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(form).toString(), signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch {
    return null;
  }
}

async function readAnswer(response: Response, clientId: string): Promise<Redeemed> {
  // A body that breaks off while reading is unavailable; broken JSON is Apple's answer.
  const body = await readBody(response);
  if (body === undefined) return { ok: false, reason: "unavailable" };
  if (response.status !== 200) return { ok: false, reason: appleReason(body) };
  const sub = idTokenSub(body?.id_token, clientId);
  if (!body || !text(body.refresh_token) || !sub || !text(body.id_token)) return { ok: false, reason: "malformed_response" };
  // The web flow verifies the id_token itself (nonce), so it is handed on.
  return { ok: true, refreshToken: body.refresh_token, sub, idToken: body.id_token };
}

// Redeems an authorization code. Throws only on own misuse; Apple's answer, network and timeout give a reason.
// redirectUri only when the authorization sent one (web flow); without it the app's form stays as it was.
export async function redeemCode(
  code: string, clientId: string,
  opts: { config: AppleConfig; fetch: typeof fetch; now: () => number; url?: string; redirectUri?: string },
): Promise<Redeemed> {
  if (typeof code !== "string" || code === "") throw new Error("code must not be empty");
  if (opts.redirectUri !== undefined && (typeof opts.redirectUri !== "string" || opts.redirectUri === "")) {
    throw new Error("redirectUri must not be empty");
  }
  const form: Record<string, string> = {
    client_id: clientId, client_secret: clientSecret(opts.config, clientId, opts.now()),
    code, grant_type: "authorization_code",
  };
  if (opts.redirectUri !== undefined) form.redirect_uri = opts.redirectUri;
  const response = await postForm(opts.fetch, opts.url ?? TOKEN_URL, form);
  return response ? readAnswer(response, clientId) : { ok: false, reason: "unavailable" };
}

// Hands the refresh token back to Apple. ok only means Apple did not refuse: it may answer 200 for an invalid token.
// Throws only on own misuse; Apple's answer, network and timeout give a reason.
export async function revokeToken(
  refreshToken: string, clientId: string, opts: { config: AppleConfig; fetch: typeof fetch; now: () => number; url?: string },
): Promise<Revoked> {
  if (typeof refreshToken !== "string" || refreshToken === "") throw new Error("refresh token must not be empty");
  const response = await postForm(opts.fetch, opts.url ?? REVOKE_URL, {
    client_id: clientId, client_secret: clientSecret(opts.config, clientId, opts.now()),
    token: refreshToken, token_type_hint: "refresh_token",
  });
  if (!response) return { ok: false, reason: "unavailable" };
  if (response.status === 200) return { ok: true };
  const body = await readBody(response);
  return { ok: false, reason: body === undefined ? "unavailable" : appleReason(body) };
}

// Where the web flow sends the browser. form_post keeps the code out of every URL; no scope, apple_sub is enough.
// nonce is the raw value; Apple gets its SHA-256 hex, the form verifyIdentityToken expects.
export function authorizeUrl(config: AppleConfig, input: { redirectUri: string; state: string; nonce: string }): string {
  if (!text(config.webClientId)) throw new Error("webClientId is not configured");
  for (const field of ["redirectUri", "state", "nonce"] as const) {
    if (!text(input[field])) throw new Error(`${field} must not be empty`);
  }
  const params = new URLSearchParams({
    client_id: config.webClientId, redirect_uri: input.redirectUri, response_type: "code", response_mode: "form_post",
    state: input.state, nonce: createHash("sha256").update(input.nonce).digest("hex"),
  });
  return `${AUTHORIZE_URL}?${params.toString()}`;
}

// The return address registered with Apple, built only from the public URL's origin, never the Host header.
export function appleReturnUrl(publicUrl: string): string {
  let origin: string;
  try { origin = new URL(publicUrl).origin; } catch { throw new Error("public url is not a valid URL"); }
  return `${origin}/oauth/apple/return`;
}
