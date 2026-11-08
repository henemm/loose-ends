import http, { type IncomingMessage, type ServerResponse } from "node:http";
import type { EventEmitter } from "node:events";
import type { AddressInfo } from "node:net";
import { join } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { setTimeout as sleep } from "node:timers/promises";
import type { ReadableStream as NodeReadableStream } from "node:stream/web";
import pg from "pg";
import { allowedSubsFromEnv } from "./accounts.ts";
import { type AppleConfig, type KeyLookup, loadAppleConfig } from "./apple.ts";
import { createJwks } from "./apple-jwks.ts";
import { authRoutes } from "./auth.ts";
import { ErrorWindow, healthHandler } from "./health.ts";
import { mcpHandler } from "./mcp.ts";
import { appleInteraction } from "./oauth-interaction.ts";
import { appleReturn, type ReturnHandler } from "./oauth-return.ts";
import { migrate } from "./migrate.ts";
import type { OAuthTokenVerifier } from "@modelcontextprotocol/server";
import { bearerGate, DEFAULT_PUBLIC_URL, METADATA_PATH, metadataRoute, publicUrlFromEnv, rejectAll } from "./oauth-resource.ts";
import {
  createProvider, type Interaction, type OAuthKeys, oauthKeysFromEnv, productInteraction, providerVerifier,
} from "./oauth-provider.ts";

export type Route = (request: Request) => Promise<Response>;
export type StartOptions = {
  databaseUrl: string; port: number; host?: string; migrationsDir: string; retryMs?: number; maxAttempts?: number;
  now?: () => number; applicationName?: string; extraRoutes?: Record<string, Route>;
  auth?: { config?: AppleConfig; fetch?: typeof fetch; allowedSubs?: ReadonlySet<string> };
  oauth?: { publicUrl?: string; verifier?: OAuthTokenVerifier; keys?: OAuthKeys; fetch?: typeof fetch; interaction?: Interaction;
    appleReturn?: ReturnHandler;
  };
};
export type Running = { url: string; ready: Promise<void>; close: () => Promise<void> };

// One line per event, ISO time first; never task text, ids, database error text or connection data.
const log = (event: string) => console.log(`${new Date().toISOString()} ${event}`);
// Never throws: console.error can fail on a closed stderr (EPIPE), and a log line must not end the process.
const logError = (event: string) => {
  try { console.error(`${new Date().toISOString()} ${event}`); } catch {}
};
const BODY_LIMIT = 1024 * 1024;
const APPLE_VARS = ["APPLE_TEAM_ID", "APPLE_KEY_ID", "APPLE_CLIENT_IDS", "APPLE_PRIVATE_KEY", "APPLE_TOKEN_KEY", "APPLE_WEB_CLIENT_ID"];

// None of them set (blank counts as unset) → undefined; otherwise the full config, or a throw naming the variable.
export function appleConfigFromEnv(env: NodeJS.ProcessEnv): AppleConfig | undefined {
  if (APPLE_VARS.every((name) => !env[name]?.trim())) return undefined;
  return loadAppleConfig(env);
}

// The error listener keeps an idle client's failure (database restart, network cut) from ending the process.
export function createPool(databaseUrl: string, applicationName = "loose-ends"): pg.Pool {
  const pool = new pg.Pool({ connectionString: databaseUrl, application_name: applicationName });
  pool.on("error", () => logError("pool error"));
  return pool;
}

// Retries while the database is not reachable yet; gives up after maxAttempts or when stopped.
async function migrateWithRetry(pool: pg.Pool, dir: string, retryMs: number, maxAttempts: number, signal: AbortSignal) {
  for (let attempt = 1; ; attempt++) {
    try {
      await migrate(pool, dir);
      return;
    } catch {
      if (attempt >= maxAttempts || signal.aborted) throw new Error("migrate gave up");
      logError(`migrate failed, retrying (${attempt}/${maxAttempts})`);
      await sleep(retryMs, undefined, { signal });
    }
  }
}

// Unknown path 404, an exception 500, both without a body; every answer but /health counts in the window.
async function dispatch(routes: Record<string, Route>, window: ErrorWindow, request: Request): Promise<Response> {
  const path = new URL(request.url).pathname;
  const route = Object.hasOwn(routes, path) ? routes[path] : undefined;
  let response: Response;
  try {
    response = route === undefined ? new Response(null, { status: 404 }) : await route(request);
  } catch {
    response = new Response(null, { status: 500 });
  }
  if (path !== "/health") window.record(response.status);
  return response;
}

// Counted while reading (Content-Length may lie or be absent); past the limit the rest is drained, never kept, and the
// answer is null. Draining to the end lets the 413 arrive: closing on unread data would reset the connection first.
function buffered(req: IncomingMessage): Promise<Buffer | null> {
  return new Promise((done, fail) => {
    let chunks: Buffer[] | null = [];
    let size = 0;
    req.on("data", (chunk: Buffer) => {
      size += chunk.length;
      if (size > BODY_LIMIT) chunks = null;
      else chunks?.push(chunk);
    });
    req.once("end", () => done(chunks === null ? null : Buffer.concat(chunks)));
    req.once("error", fail);
  });
}

// node:http in, Request and Response through the route, node:http out; the body is streamed, so SSE answers pass.
async function bridge(req: IncomingMessage, res: ServerResponse, handle: Route): Promise<void> {
  try {
    const headers = new Headers();
    for (let i = 0; i < req.rawHeaders.length; i += 2) headers.append(req.rawHeaders[i], req.rawHeaders[i + 1]);
    const method = req.method ?? "GET";
    const raw = method === "GET" || method === "HEAD" ? undefined : await buffered(req);
    if (raw === null) return void res.writeHead(413, { connection: "close" }).end();
    const body = raw === undefined ? undefined : new Uint8Array(raw);
    const response = await handle(new Request(`http://${req.headers.host ?? "localhost"}${req.url ?? "/"}`, { method, headers, body }));
    res.writeHead(response.status, [...response.headers].flat());
    if (response.body === null) res.end();
    else await pipeline(Readable.fromWeb(response.body as NodeReadableStream), res);
  } catch {
    if (!res.headersSent) res.writeHead(500).end();
    else res.destroy();
  }
}

// 503 without a body until migrate is done: the route needs the database.
function gated(isReady: () => boolean, route: Route): Route {
  return async (request) => (isReady() ? route(request) : new Response(null, { status: 503 }));
}

// One lazy JWKS instance per start, only with a config; shared by the auth routes and the issuer's interaction.
function appleKeys(options: StartOptions): KeyLookup | undefined {
  if (options.auth?.config === undefined) return undefined;
  return createJwks({ fetch: options.auth.fetch ?? globalThis.fetch, now: options.now ?? Date.now }).keys;
}

// The auth routes, each gated.
function mountAuth(options: StartOptions, pool: pg.Pool, isReady: () => boolean, keys: KeyLookup | undefined): Record<string, Route> {
  if (options.auth === undefined) return {};
  const { config } = options.auth;
  const fetch = options.auth.fetch ?? globalThis.fetch;
  const now = options.now ?? Date.now;
  const routes = authRoutes({ pool, config, keys, fetch, now, log: logError, allowedSubs: options.auth.allowedSubs });
  return Object.fromEntries(Object.entries(routes).map(([path, route]) => [path, gated(isReady, route)]));
}

const DISCOVERY = new Set(["/.well-known/oauth-authorization-server", "/.well-known/openid-configuration"]);
type NodeHandler = (req: IncomingMessage, res: ServerResponse) => void;
const unavailable: NodeHandler = (_req, res) => void res.writeHead(503).end();

// The issuer's paths: everything under /oauth/ and the two discovery documents.
function isIssuerPath(url: string | undefined): boolean {
  const path = URL.parse(url ?? "/", "http://localhost")?.pathname ?? "/";
  return path.startsWith("/oauth/") || DISCOVERY.has(path);
}

// A handed-in interaction wins (tests); with an Apple web client id the login goes to Apple; else the fixed 501.
function interactionFor(options: StartOptions, pool: pg.Pool, now: () => Date, keys: KeyLookup | undefined): Interaction {
  const { publicUrl = DEFAULT_PUBLIC_URL, interaction } = options.oauth ?? {};
  const config = options.auth?.config;
  if (interaction !== undefined) return interaction;
  if (config?.webClientId === undefined || keys === undefined) return productInteraction;
  return appleInteraction({ pool, config, publicUrl, now, fallback: productInteraction, keys, log: logError, consent: { publicUrl, log: logError } });
}

// Apple's way back, under exactly the conditions of appleInteraction; a handed-in one wins (tests).
function returnFor(options: StartOptions, pool: pg.Pool, now: () => Date, keys: KeyLookup | undefined): ReturnHandler | undefined {
  const { publicUrl = DEFAULT_PUBLIC_URL, interaction, appleReturn: handedIn } = options.oauth ?? {};
  const config = options.auth?.config;
  if (handedIn !== undefined) return handedIn;
  if (interaction !== undefined || config?.webClientId === undefined || keys === undefined) return undefined;
  const fetch = options.auth?.fetch ?? globalThis.fetch;
  return appleReturn({ pool, config, publicUrl, now, fetch, keys, log: logError, allowedSubs: options.auth?.allowedSubs });
}

// The issuer gets the raw request (it reads the body itself); 503 without a body before migrate or without keys.
// Its answers count in the error window, except the product interaction's deliberate 501. Library errors are logged
// as fixed event names only: an error object can carry values (the FK detail names the account).
function mountIssuer(options: StartOptions, pool: pg.Pool, isReady: () => boolean, window: ErrorWindow, jwks: KeyLookup | undefined) {
  const { publicUrl = DEFAULT_PUBLIC_URL, keys, fetch = globalThis.fetch } = options.oauth ?? {};
  if (keys === undefined) return { handle: unavailable, provider: undefined };
  const clock = options.now ?? Date.now;
  const now = () => new Date(clock());
  const interaction = interactionFor(options, pool, now, jwks);
  const returnHandler = returnFor(options, pool, now, jwks);
  const provider = createProvider({ publicUrl, pool, now, fetch, keys, interaction, appleReturn: returnHandler });
  provider.on("server_error", () => logError("oauth server error"));
  // Koa's own "error" event (missing from the provider's types); a listener replaces Koa's default console output.
  (provider as unknown as EventEmitter).on("error", () => logError("oauth error"));
  const callback = provider.callback();
  const handle: NodeHandler = (req, res) => {
    if (!isReady()) return unavailable(req, res);
    res.once("finish", () => { if (res.statusCode !== 501) window.record(res.statusCode); });
    void callback(req, res);
  };
  return { handle, provider };
}

// Listens first, so /health can answer 503 while migrate still waits for the database; ready settles with migrate.
export async function start(options: StartOptions): Promise<Running> {
  const { databaseUrl, port, host = "127.0.0.1", migrationsDir, retryMs = 2000, maxAttempts = 60 } = options;
  const pool = createPool(databaseUrl, options.applicationName);
  const window = new ErrorWindow(options.now ?? Date.now);
  const mcp = mcpHandler(pool);
  let migrated = false;
  const isReady = () => migrated;
  const { publicUrl = DEFAULT_PUBLIC_URL } = options.oauth ?? {};
  const jwks = appleKeys(options);
  const issuer = mountIssuer(options, pool, isReady, window, jwks);
  const verifier = options.oauth?.verifier ?? (issuer.provider ? providerVerifier(issuer.provider, publicUrl) : rejectAll);
  const gate = bearerGate(publicUrl, verifier);
  // Metadata, /health and /mcp last: neither auth nor extraRoutes can replace them. Metadata needs no database.
  const routes: Record<string, Route> = {
    ...mountAuth(options, pool, isReady, jwks),
    ...options.extraRoutes,
    [METADATA_PATH]: metadataRoute(publicUrl),
    "/health": healthHandler({ pool, isMigrated: isReady, window }),
    "/mcp": gated(isReady, async (request) => {
      const checked = await gate(request);
      return checked instanceof Response ? checked : mcp.fetch(request, { authInfo: checked });
    }),
  };
  const server = http.createServer((req, res) => isIssuerPath(req.url)
    ? issuer.handle(req, res)
    : void bridge(req, res, (request) => dispatch(routes, window, request)));
  try {
    await new Promise<void>((done, fail) => { server.once("error", fail); server.listen(port, host, done); });
  } catch (error) {
    await pool.end();
    throw error;
  }
  log("listening");
  const stop = new AbortController();
  const ready = migrateWithRetry(pool, migrationsDir, retryMs, maxAttempts, stop.signal)
    .then(() => { migrated = true; log("migrated"); });
  ready.catch(() => {});
  let closing: Promise<void> | undefined;
  const close = () => (closing ??= shutdown(server, pool, mcp.close, stop));
  return { url: `http://${host}:${(server.address() as AddressInfo).port}`, ready, close };
}

// Server first (open keep-alive connections are cut), then the pool and the MCP handler; never throws.
async function shutdown(server: http.Server, pool: pg.Pool, closeMcp: () => Promise<void>, stop: AbortController) {
  stop.abort();
  const closed = new Promise<void>((done) => server.close(() => done()));
  server.closeAllConnections();
  await closed;
  await pool.end().catch(() => logError("pool end failed"));
  await closeMcp().catch(() => logError("mcp close failed"));
}

// The door's list; an invalid value stops the process before pool and port, never naming the value.
function allowedSubsOrExit(): ReadonlySet<string> | undefined {
  try {
    return allowedSubsFromEnv(process.env);
  } catch {
    logError("allowed subs invalid: ALLOWED_APPLE_SUBS");
    process.exit(1);
  }
}

// The process: settings from the environment, one shutdown on SIGTERM or SIGINT, exit 1 when migrate gives up.
async function main(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL;
  if (databaseUrl === undefined || databaseUrl === "") {
    logError("DATABASE_URL missing");
    process.exit(1);
  }
  let config: AppleConfig | undefined;
  try {
    config = appleConfigFromEnv(process.env);
  } catch (error) {
    logError(`apple config invalid: ${(error as Error).message}`);
    process.exit(1);
  }
  const allowedSubs = allowedSubsOrExit();
  let keys: OAuthKeys | undefined;
  try {
    keys = oauthKeysFromEnv(process.env);
  } catch (error) {
    logError(`oauth config invalid: ${(error as Error).message}`);
    process.exit(1);
  }
  let publicUrl: string;
  try {
    publicUrl = publicUrlFromEnv(process.env);
  } catch {
    logError("public url invalid");
    process.exit(1);
  }
  const running = await start({
    databaseUrl, port: Number(process.env.PORT ?? 8080), host: process.env.HOST ?? "127.0.0.1",
    migrationsDir: join(import.meta.dirname, "../migrations"), auth: { config, allowedSubs }, oauth: { publicUrl, keys },
  });
  let stopping = false;
  const stop = async (code: number) => {
    if (stopping) return;
    stopping = true;
    log("shutting down");
    await running.close();
    log("stopped");
    process.exit(code);
  };
  process.on("SIGTERM", () => void stop(0));
  process.on("SIGINT", () => void stop(0));
  running.ready.catch(() => { logError("migrate gave up"); void stop(1); });
}

if (import.meta.main) await main();
