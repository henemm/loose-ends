import { createPrivateKey } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import { type AuthInfo, OAuthError, OAuthErrorCode, type OAuthTokenVerifier } from "@modelcontextprotocol/server";
import Provider, { type Configuration, errors, type JWK, type KoaContextWithOIDC } from "oidc-provider";
import type pg from "pg";
import { PgAdapter } from "./oauth-adapter.ts";
import { resourceFor } from "./oauth-resource.ts";

// The OAuth issuer for /mcp (#621 S3): oidc-provider with Client ID Metadata Documents, opaque tokens, PKCE S256.
export type OAuthKeys = { cookieKeys: string[]; signingJwk: JsonWebKey };
export type Interaction = (provider: Provider, req: IncomingMessage, res: ServerResponse) => Promise<void>;
export type ProviderOptions = {
  publicUrl: string; pool: pg.Pool; now: () => Date; fetch: typeof fetch; keys: OAuthKeys; interaction?: Interaction;
};

const SCOPE = "tasks";
const INTERACTION_PATH = "/oauth/interaction/";
const DAY = 24 * 3600;
const TTL = { AuthorizationCode: 60, Interaction: 600, AccessToken: 3600, RefreshToken: 30 * DAY, Grant: 30 * DAY, Session: 14 * DAY };
const ROUTES = {
  authorization: "/oauth/auth", backchannel_authentication: "/oauth/backchannel", code_verification: "/oauth/device",
  challenge: "/oauth/challenge", device_authorization: "/oauth/device/auth", end_session: "/oauth/session/end",
  introspection: "/oauth/token/introspection", jwks: "/oauth/jwks", pushed_authorization_request: "/oauth/request",
  registration: "/oauth/reg", revocation: "/oauth/token/revocation", token: "/oauth/token", userinfo: "/oauth/me",
  credential: "/oauth/credential",
};
const COOKIE_VAR = "OAUTH_COOKIE_KEYS";
const JWK_VAR = "OAUTH_SIGNING_JWK";

// A fixed answer without values, the interaction never ends with an account. Since S4b-1 the fallback without an Apple
// web client id and for every prompt but login (consent until S5).
export const productInteraction: Interaction = async (_provider, _req, res) => {
  res.writeHead(501, { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" }).end("sign-in not available");
};

// Only https documents on claude.ai are fetched; everything else is refused before any request.
async function allowFetch(_ctx: KoaContextWithOIDC, clientId: string): Promise<boolean> {
  const url = URL.parse(clientId);
  return url?.protocol === "https:" && url.hostname === "claude.ai";
}

// One fixed page with the error code only: no description, no value from the request or the database.
async function renderError(ctx: KoaContextWithOIDC, out: { error: string }): Promise<void> {
  ctx.type = "html";
  ctx.body = `<!DOCTYPE html><title>error</title><p>${out.error.replace(/[^a-z_]/g, "")}</p>`;
}

// Exactly one resource: <publicUrl>/mcp with the scope "tasks", opaque tokens; any other indicator is invalid_target.
function resourceIndicators(publicUrl: string) {
  const resource = resourceFor(publicUrl).href;
  return {
    enabled: true,
    defaultResource: async () => resource,
    getResourceServerInfo: async (_ctx: KoaContextWithOIDC, indicator: string) => {
      if (indicator !== resource) throw new errors.InvalidTarget();
      return { scope: SCOPE, audience: resource, accessTokenFormat: "opaque" as const, accessTokenTTL: TTL.AccessToken };
    },
  };
}

// The account model: an account exists while its row in accounts exists.
function findAccount(pool: pg.Pool) {
  return async (_ctx: KoaContextWithOIDC, sub: string) => {
    const found = await pool.query("SELECT 1 FROM accounts WHERE id = $1", [sub]);
    return found.rowCount === 1 ? { accountId: sub, claims: async () => ({ sub }) } : undefined;
  };
}

function configuration({ publicUrl, pool, now, fetch, keys }: ProviderOptions): Configuration {
  return {
    adapter: (name: string) => new PgAdapter(pool, name, now),
    fetch,
    routes: ROUTES,
    ttl: TTL,
    cookies: { keys: keys.cookieKeys },
    jwks: { keys: [keys.signingJwk as JWK] },
    clientAuthMethods: ["none"],
    // The default RS256 has no key here; a client would be refused as invalid metadata.
    clientDefaults: { id_token_signed_response_alg: "ES256" },
    pkce: { required: () => true },
    rotateRefreshToken: true,
    issueRefreshToken: async (_ctx, client) => client.grantTypeAllowed("refresh_token") && client.clientAuthMethod === "none",
    interactions: { url: async (_ctx, interaction) => `${INTERACTION_PATH}${interaction.uid}` },
    findAccount: findAccount(pool),
    renderError,
    features: {
      devInteractions: { enabled: false },
      clientIdMetadataDocument: { enabled: true, ack: "draft-02", allowFetch },
      resourceIndicators: resourceIndicators(publicUrl),
    },
  };
}

// The issuer is the public URL's origin (= authorization_servers[0]); TLS ends at nginx, so x-forwarded-proto counts.
export function createProvider(options: ProviderOptions): Provider {
  const provider = new Provider(new URL(options.publicUrl).origin, configuration(options));
  provider.proxy = true;
  const handle = options.interaction ?? productInteraction;
  // The interaction writes to the raw response; a throw goes to Koa (status text only, "error" event, no value).
  provider.use(async (ctx, next) => {
    if (!ctx.path.startsWith(INTERACTION_PATH)) return next();
    ctx.respond = false;
    await handle(provider, ctx.req, ctx.res);
  });
  return provider;
}

// A token counts only if the store knows it, it is unexpired, issued for <publicUrl>/mcp and carries an account.
export function providerVerifier(provider: Provider, publicUrl: string): OAuthTokenVerifier {
  const resource = resourceFor(publicUrl);
  return {
    verifyAccessToken: async (token: string): Promise<AuthInfo> => {
      const found = await provider.AccessToken.find(token);
      const { accountId: account, clientId } = found ?? {};
      if (found === undefined || found.isExpired || found.aud !== resource.href || !account || !clientId) {
        throw new OAuthError(OAuthErrorCode.InvalidToken, "invalid token");
      }
      return { token, clientId, scopes: [...found.scopes], expiresAt: found.exp, resource, extra: { account } };
    },
  };
}

// A private ES256 key (P-256 with d) that node:crypto accepts; anything else throws naming only the variable.
function signingJwk(value: string): JsonWebKey {
  let jwk: JsonWebKey;
  try {
    jwk = JSON.parse(value);
    if (jwk === null || typeof jwk !== "object" || jwk.kty !== "EC" || jwk.crv !== "P-256" || typeof jwk.d !== "string") throw new Error();
    createPrivateKey({ key: jwk, format: "jwk" });
  } catch {
    throw new Error(JWK_VAR);
  }
  return jwk;
}

// Neither set (blank counts as unset) → undefined; one missing or a value invalid → a throw naming only the variable.
export function oauthKeysFromEnv(env: NodeJS.ProcessEnv | Record<string, string | undefined>): OAuthKeys | undefined {
  const cookies = env[COOKIE_VAR]?.trim();
  const jwk = env[JWK_VAR]?.trim();
  if (!cookies && !jwk) return undefined;
  if (!cookies) throw new Error(COOKIE_VAR);
  if (!jwk) throw new Error(JWK_VAR);
  const cookieKeys = cookies.split(",").map((key) => key.trim());
  if (cookieKeys.some((key) => key.length < 32)) throw new Error(COOKIE_VAR);
  return { cookieKeys, signingJwk: signingJwk(jwk) };
}
