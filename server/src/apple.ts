import { createHash, createPrivateKey, createPublicKey, timingSafeEqual, verify, type KeyObject } from "node:crypto";

export type AppleConfig = { teamId: string; keyId: string; clientIds: string[]; webClientId?: string; privateKey: KeyObject; tokenKey: Buffer };
export type KeyLookup = (kid: string) => Promise<JsonWebKey | "unknown_kid" | "keys_unavailable">;
export type Verdict = { ok: true; sub: string; aud: string } | { ok: false; reason: string };
type Doc = Record<string, unknown>;

const ISSUER = "https://appleid.apple.com";
const LEEWAY_MS = 60_000;

// Every error names only the variable, never its value.
function required(env: NodeJS.ProcessEnv, name: string): string {
  const value = env[name]?.trim();
  if (!value) throw new Error(`${name} is missing or empty`);
  return value;
}

function ecPrivateKey(pem: string): KeyObject {
  let key: KeyObject;
  try {
    key = createPrivateKey(pem.replace(/\\n/g, "\n"));
  } catch {
    throw new Error("APPLE_PRIVATE_KEY is not a readable private key");
  }
  if (key.asymmetricKeyType !== "ec" || key.asymmetricKeyDetails?.namedCurve !== "prime256v1") {
    throw new Error("APPLE_PRIVATE_KEY is not an EC P-256 key");
  }
  return key;
}

export function loadAppleConfig(env: NodeJS.ProcessEnv = process.env): AppleConfig {
  const teamId = required(env, "APPLE_TEAM_ID");
  const keyId = required(env, "APPLE_KEY_ID");
  const clientIds = required(env, "APPLE_CLIENT_IDS").split(",").map((s) => s.trim()).filter((s) => s !== "");
  if (clientIds.length === 0) throw new Error("APPLE_CLIENT_IDS has no entry");
  const privateKey = ecPrivateKey(required(env, "APPLE_PRIVATE_KEY"));
  const raw = required(env, "APPLE_TOKEN_KEY");
  const tokenKey = Buffer.from(raw, "base64");
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(raw) || tokenKey.length !== 32) throw new Error("APPLE_TOKEN_KEY is not 32 bytes of base64");
  return { teamId, keyId, clientIds, webClientId: webClientId(env, clientIds), privateKey, tokenKey };
}

// The web flow's Services ID: optional and kept apart from the app ids, so /auth/apple never accepts a web token.
function webClientId(env: NodeJS.ProcessEnv, clientIds: string[]): string | undefined {
  const value = env.APPLE_WEB_CLIENT_ID?.trim();
  if (!value) return undefined;
  if (value.includes(",")) throw new Error("APPLE_WEB_CLIENT_ID must be a single id");
  if (clientIds.includes(value)) throw new Error("APPLE_WEB_CLIENT_ID must differ from APPLE_CLIENT_IDS");
  return value;
}

function jsonObject(segment: string): Doc | null {
  const value: unknown = JSON.parse(Buffer.from(segment, "base64url").toString("utf8"));
  return value !== null && typeof value === "object" && !Array.isArray(value) ? (value as Doc) : null;
}

// Three base64url segments, header and payload JSON objects; anything else is null.
function parse(token: unknown): { header: Doc; payload: Doc; data: string; signature: Buffer } | null {
  if (typeof token !== "string") return null;
  const parts = token.split(".");
  if (parts.length !== 3 || parts.some((p) => !/^[A-Za-z0-9_-]*$/.test(p))) return null;
  const header = jsonObject(parts[0]);
  const payload = jsonObject(parts[1]);
  if (!header || !payload) return null;
  return { header, payload, data: `${parts[0]}.${parts[1]}`, signature: Buffer.from(parts[2], "base64url") };
}

function claimsReason(p: Doc, rawNonce: string, audiences: string[], now: number): string | null {
  if (p.iss !== ISSUER) return "iss";
  if (typeof p.aud !== "string" || !audiences.includes(p.aud)) return "aud";
  if (typeof now !== "number" || !Number.isFinite(now)) return "expired";
  if (typeof p.exp !== "number" || !Number.isFinite(p.exp) || p.exp * 1000 <= now - LEEWAY_MS) return "expired";
  if (typeof p.iat !== "number" || !Number.isFinite(p.iat) || p.iat * 1000 > now + LEEWAY_MS) return "iat";
  if (typeof rawNonce !== "string" || rawNonce === "") return "nonce";
  const expected = Buffer.from(createHash("sha256").update(rawNonce).digest("hex"));
  const claim = Buffer.from(typeof p.nonce === "string" ? p.nonce : "");
  if (claim.length !== expected.length || !timingSafeEqual(claim, expected)) return "nonce";
  if (typeof p.sub !== "string" || p.sub === "") return "malformed";
  return null;
}

function signatureValid(jwk: JsonWebKey, data: string, signature: Buffer): boolean {
  try {
    return verify("sha256", Buffer.from(data), createPublicKey({ key: jwk, format: "jwk" }), signature);
  } catch {
    return false;
  }
}

// Order: malformed, alg (before any key lookup), kid, signature, then the claims. Never throws on input.
// audiences defaults to the app ids; the web flow passes [webClientId].
export async function verifyIdentityToken(
  token: string, rawNonce: string, opts: { config: AppleConfig; keys: KeyLookup; now: number; audiences?: string[] },
): Promise<Verdict> {
  const fail = (reason: string): Verdict => ({ ok: false, reason });
  let parsed;
  try { parsed = parse(token); } catch { parsed = null; }
  if (!parsed) return fail("malformed");
  if (parsed.header.alg !== "RS256") return fail("alg");
  const kid = parsed.header.kid;
  if (typeof kid !== "string") return fail("unknown_kid");
  let jwk;
  try { jwk = await opts.keys(kid); } catch { return fail("keys_unavailable"); }
  if (jwk === "unknown_kid" || jwk === "keys_unavailable") return fail(jwk);
  if (!jwk || typeof jwk !== "object" || jwk.kty !== "RSA" || (jwk.alg !== undefined && jwk.alg !== "RS256")) return fail("unknown_kid");
  if (!signatureValid(jwk, parsed.data, parsed.signature)) return fail("signature");
  const reason = claimsReason(parsed.payload, rawNonce, opts.audiences ?? opts.config.clientIds, opts.now);
  // aud is the checked client id the token was issued for; the revocation needs exactly this one.
  return reason ? fail(reason) : { ok: true, sub: parsed.payload.sub as string, aud: parsed.payload.aud as string };
}
