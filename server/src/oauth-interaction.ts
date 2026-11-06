import { randomBytes } from "node:crypto";
import type { ServerResponse } from "node:http";
import type pg from "pg";
import type { AppleConfig, KeyLookup } from "./apple.ts";
import { appleReturnUrl, authorizeUrl } from "./apple-client.ts";
import { PgAdapter } from "./oauth-adapter.ts";
import type { Interaction } from "./oauth-provider.ts";

// The issuer's login interaction with Apple in the browser (#621 S4b-1): the way there only; the return is S4b-2.
export type AppleInteractionDeps = {
  pool: pg.Pool; config: AppleConfig; publicUrl: string; now: () => Date; fallback: Interaction;
  // Shared JWKS lookup, used by the return in S4b-2.
  keys: KeyLookup; log: (event: string) => void;
};

const MODEL = "AppleLogin";
const MAX_TTL = 600;
const INTERACTION_PATH = "/oauth/interaction/";

const random = () => randomBytes(32).toString("base64url");

// One fixed answer without values: no uid, no cookie, no error text.
function badRequest(res: ServerResponse): void {
  res.writeHead(400, { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" }).end("bad request");
}

// The uid in the path; interactionDetails reads the cookie only and never compares it with the path.
function pathUid(url: string | undefined): string | undefined {
  const path = URL.parse(url ?? "/", "http://localhost")?.pathname ?? "";
  return path.startsWith(INTERACTION_PATH) ? path.slice(INTERACTION_PATH.length) : undefined;
}

// Prompt login: a random state and raw nonce, stored under the state's hash for at most the interaction's remaining
// time, then 303 to Apple. Any other prompt or no web client id: the fallback. Never a redirect without stored state.
export function appleInteraction(deps: AppleInteractionDeps): Interaction {
  const { pool, config, publicUrl, now, fallback, log } = deps;
  return async (provider, req, res) => {
    if (!config.webClientId) return fallback(provider, req, res);
    let details: Awaited<ReturnType<typeof provider.interactionDetails>>;
    try {
      details = await provider.interactionDetails(req, res);
    } catch {
      log("oauth interaction refused");
      return badRequest(res);
    }
    if (details.uid !== pathUid(req.url)) {
      log("oauth interaction refused");
      return badRequest(res);
    }
    if (details.prompt.name !== "login") return fallback(provider, req, res);
    const ttl = Math.min(MAX_TTL, Math.floor(details.exp - now().getTime() / 1000));
    if (!(ttl > 0)) {
      log("oauth interaction refused");
      return badRequest(res);
    }
    const state = random();
    const nonce = random();
    try {
      await new PgAdapter(pool, MODEL, now).upsert(state, { uid: details.uid, nonce }, ttl);
    } catch {
      log("oauth interaction store failed");
      return badRequest(res);
    }
    const location = authorizeUrl(config, { redirectUri: appleReturnUrl(publicUrl), state, nonce });
    res.writeHead(303, { location, "cache-control": "no-store", "referrer-policy": "no-referrer" }).end();
  };
}
