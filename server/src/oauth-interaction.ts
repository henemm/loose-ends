import { randomBytes } from "node:crypto";
import type { IncomingMessage, ServerResponse } from "node:http";
import type Provider from "oidc-provider";
import type pg from "pg";
import type { AppleConfig, KeyLookup } from "./apple.ts";
import { appleReturnUrl, authorizeUrl } from "./apple-client.ts";
import { PgAdapter } from "./oauth-adapter.ts";
import { type ConsentDeps, decideConsent, showConsent } from "./oauth-consent.ts";
import type { Interaction } from "./oauth-provider.ts";
import { TICKET_MODEL, type Ticket } from "./oauth-return.ts";

// The issuer's login interaction with Apple in the browser: the way there (#621 S4b-1) and finish (S4b-2b), which closes
// the sign-in with the interaction cookie and the return's one-time ticket, both bound to the uid in the path.
export type AppleInteractionDeps = {
  pool: pg.Pool; config: AppleConfig; publicUrl: string; now: () => Date; fallback: Interaction;
  // Shared JWKS lookup, used by the return in S4b-2.
  keys: KeyLookup; log: (event: string) => void;
  // The consent page (S5); without it prompt consent stays with the fallback.
  consent?: ConsentDeps;
};

const MODEL = "AppleLogin";
const MAX_TTL = 600;
const INTERACTION_PATH = "/oauth/interaction/";
const REFUSED = "oauth interaction refused";
const STORE_FAILED = "oauth interaction store failed";
// The adapter's message for a row that is not consumable (consumed meanwhile, expired, gone).
const NOT_CONSUMABLE = "oauth record not consumable";

type Details = Awaited<ReturnType<Provider["interactionDetails"]>>;

const random = () => randomBytes(32).toString("base64url");

// One fixed answer without values: no uid, no cookie, no error text.
function badRequest(res: ServerResponse): void {
  res.writeHead(400, { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" }).end("bad request");
}

function refuse(deps: AppleInteractionDeps, res: ServerResponse): void {
  deps.log(REFUSED);
  badRequest(res);
}

// The path behind /oauth/interaction/: "<uid>" is the way there (and the consent page), "<uid>/finish" the closing,
// "<uid>/confirm" and "<uid>/abort" the consent's answers, anything else null.
type Step = "start" | "finish" | "confirm" | "abort";
function pathParts(url: string | undefined): { uid: string; step: Step } | null {
  const path = URL.parse(url ?? "/", "http://localhost")?.pathname ?? "";
  if (!path.startsWith(INTERACTION_PATH)) return { uid: "", step: "start" };
  const [uid, ...rest] = path.slice(INTERACTION_PATH.length).split("/");
  if (rest.length === 0) return { uid, step: "start" };
  const step = rest[0];
  return rest.length === 1 && (step === "finish" || step === "confirm" || step === "abort") ? { uid, step } : null;
}

// The cookie's interaction, only if it is the one in the path; interactionDetails reads the cookie and never compares.
async function detailsFor(provider: Provider, req: IncomingMessage, res: ServerResponse, uid: string): Promise<Details | null> {
  try {
    const details = await provider.interactionDetails(req, res);
    return details.uid === uid ? details : null;
  } catch {
    return null;
  }
}

// The route: no web client id → the fallback on every path; an unknown rest after the uid → the fixed 400.
export function appleInteraction(deps: AppleInteractionDeps): Interaction {
  return async (provider, req, res) => {
    if (!deps.config.webClientId) return deps.fallback(provider, req, res);
    const parts = pathParts(req.url);
    if (parts === null) return refuse(deps, res);
    if (parts.step === "finish") return finishLogin(deps, parts.uid, provider, req, res);
    if (parts.step === "confirm" || parts.step === "abort") return answerConsent(deps, parts.uid, parts.step, provider, req, res);
    return startLogin(deps, parts.uid, provider, req, res);
  };
}

// Prompt login: a random state and raw nonce, stored under the state's hash for at most the interaction's remaining
// time, then 303 to Apple. Any other prompt: the fallback. Never a redirect without stored state.
async function startLogin(deps: AppleInteractionDeps, uid: string, provider: Provider, req: IncomingMessage, res: ServerResponse): Promise<void> {
  const { pool, config, publicUrl, now, fallback, log } = deps;
  const details = await detailsFor(provider, req, res, uid);
  if (details === null) return refuse(deps, res);
  if (details.prompt.name === "consent" && deps.consent !== undefined) return showConsent(deps.consent, provider, details, req, res);
  if (details.prompt.name !== "login") return fallback(provider, req, res);
  const ttl = Math.min(MAX_TTL, Math.floor(details.exp - now().getTime() / 1000));
  if (!(ttl > 0)) return refuse(deps, res);
  const state = random();
  const nonce = random();
  try {
    await new PgAdapter(pool, MODEL, now).upsert(state, { uid: details.uid, nonce }, ttl);
  } catch {
    log(STORE_FAILED);
    return badRequest(res);
  }
  const location = authorizeUrl(config, { redirectUri: appleReturnUrl(publicUrl), state, nonce });
  res.writeHead(303, { location, "cache-control": "no-store", "referrer-policy": "no-referrer" }).end();
}

// The consent's two answers: only for the cookie's interaction, in prompt consent, and only when the page is mounted.
async function answerConsent(
  deps: AppleInteractionDeps, uid: string, answer: "confirm" | "abort", provider: Provider, req: IncomingMessage, res: ServerResponse,
): Promise<void> {
  if (deps.consent === undefined) return deps.fallback(provider, req, res);
  const details = await detailsFor(provider, req, res, uid);
  if (details === null || details.prompt.name !== "consent") return refuse(deps, res);
  return decideConsent(deps.consent, provider, details, answer, req, res);
}

// Exactly one non-empty ticket in the query; every other parameter is never read.
function ticketQuery(url: string | undefined): string | null {
  const values = URL.parse(url ?? "/", "http://localhost")?.searchParams.getAll("ticket") ?? [];
  return values.length === 1 && values[0] !== "" ? values[0] : null;
}

// Exactly one of the two forms the return writes; jti comes from the adapter, consumed is refused before.
function ticketForm(found: Record<string, unknown>): Ticket | null {
  const { jti: _jti, ...payload } = found;
  const keys = Object.keys(payload).sort().join(",");
  const filled = (value: unknown) => typeof value === "string" && value !== "";
  if (!filled(payload.uid)) return null;
  if (keys === "accountId,uid" && filled(payload.accountId)) return payload as Ticket;
  const known = payload.error === "access_denied" || payload.error === "temporarily_unavailable";
  return keys === "error,uid" && known ? payload as Ticket : null;
}

// Found, well formed and for this interaction, only then consumed: a wrong ticket burns nothing.
// "refused" for anything not redeemable; a database error throws.
async function redeemTicket(deps: AppleInteractionDeps, ticket: string, uid: string): Promise<Ticket | "refused"> {
  const adapter = new PgAdapter(deps.pool, TICKET_MODEL, deps.now);
  const found = await adapter.find(ticket);
  if (!found || found.consumed !== undefined) return "refused";
  const form = ticketForm(found);
  if (form === null || form.uid !== uid) return "refused";
  try {
    await adapter.consume(ticket);
  } catch (error) {
    if (error instanceof Error && error.message === NOT_CONSUMABLE) return "refused";
    throw error;
  }
  return form;
}

// GET only; the cookie's interaction must be the path's and in prompt login, then the ticket once, then the result.
// The browser session is not remembered: it ends with the browser, Claude's access holds its own token.
async function finishLogin(deps: AppleInteractionDeps, uid: string, provider: Provider, req: IncomingMessage, res: ServerResponse): Promise<void> {
  if (req.method !== "GET") {
    deps.log(REFUSED);
    return void res.writeHead(405, { allow: "GET", "cache-control": "no-store" }).end();
  }
  const details = await detailsFor(provider, req, res, uid);
  if (details === null || details.prompt.name !== "login") return refuse(deps, res);
  const ticket = ticketQuery(req.url);
  if (ticket === null) return refuse(deps, res);
  let redeemed: Ticket | "refused";
  try {
    redeemed = await redeemTicket(deps, ticket, details.uid);
  } catch {
    deps.log(STORE_FAILED);
    return badRequest(res);
  }
  if (redeemed === "refused") return refuse(deps, res);
  const result = "accountId" in redeemed ? { login: { accountId: redeemed.accountId, remember: false } } : { error: redeemed.error };
  try {
    await provider.interactionFinished(req, res, result, { mergeWithLastSubmission: false });
  } catch {
    deps.log(STORE_FAILED);
    if (!res.headersSent) badRequest(res);
  }
}
