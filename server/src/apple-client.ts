import { sign } from "node:crypto";
import type { AppleConfig } from "./apple.ts";

export type Redeemed = { ok: true; refreshToken: string; sub: string } | { ok: false; reason: string };
type Doc = Record<string, unknown>;

const ISSUER = "https://appleid.apple.com";
const TOKEN_URL = "https://appleid.apple.com/auth/token";
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
  if (!config.clientIds.includes(clientId)) throw new Error("client id is not configured");
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

async function readAnswer(response: Response, clientId: string): Promise<Redeemed> {
  // A body that breaks off while reading (network, timeout) is unavailable; broken JSON is Apple's answer.
  let raw: string;
  try { raw = await response.text(); } catch { return { ok: false, reason: "unavailable" }; }
  let body: Doc | null;
  try { body = asObject(JSON.parse(raw)); } catch { body = null; }
  if (response.status !== 200) {
    const error = body?.error;
    return { ok: false, reason: typeof error === "string" && APPLE_ERRORS.has(error) ? `apple:${error}` : "apple_status" };
  }
  const sub = idTokenSub(body?.id_token, clientId);
  if (!body || !text(body.refresh_token) || !sub) return { ok: false, reason: "malformed_response" };
  return { ok: true, refreshToken: body.refresh_token, sub };
}

// Redeems the app's authorization code. Throws only on own misuse; Apple's answer, network and timeout give a reason.
export async function redeemCode(
  code: string, clientId: string, opts: { config: AppleConfig; fetch: typeof fetch; now: () => number; url?: string },
): Promise<Redeemed> {
  if (typeof code !== "string" || code === "") throw new Error("code must not be empty");
  const body = new URLSearchParams({
    client_id: clientId, client_secret: clientSecret(opts.config, clientId, opts.now()),
    code, grant_type: "authorization_code",
  }).toString();
  let response: Response;
  try {
    response = await opts.fetch(opts.url ?? TOKEN_URL, {
      method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch {
    return { ok: false, reason: "unavailable" };
  }
  return readAnswer(response, clientId);
}
