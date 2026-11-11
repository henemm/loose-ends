import type pg from "pg";
import { resolveSession } from "./accounts.ts";
import { bearerToken } from "./auth.ts";
import type { Route } from "./main.ts";
import { checkResult, claimOrder, putResult } from "./orders.ts";
import { checkTranscript, putTranscript } from "./transcripts.ts";

export type AppDeps = { pool: pg.Pool };

const BODY_LIMIT = 256 * 1024;
const deviceForm = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// Every answer carries no-store; a refusal has no body and never tells which check failed.
const status = (code: number) => new Response(null, { status: code, headers: { "cache-control": "no-store" } });
const notAllowed = () => new Response(null, { status: 405, headers: { allow: "POST", "cache-control": "no-store" } });

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

// The device id from X-Device in lower case, null unless it is a UUID.
function device(request: Request): string | null {
  const value = request.headers.get("x-device") ?? "";
  return deviceForm.test(value) ? value.toLowerCase() : null;
}

type Checked = { account: string; device: string };
type Steps = { device: boolean };

// Method, then session, then device: the first violation is the answer, else the account (and device).
async function admitted(deps: AppDeps, request: Request, steps: Steps): Promise<Checked | Response> {
  if (request.method !== "POST") return notAllowed();
  const token = bearerToken(request);
  if (token === null) return status(401);
  const account = await resolveSession(deps.pool, token);
  if (account === null) return status(401);
  if (!steps.device) return { account, device: "" };
  const id = device(request);
  return id === null ? status(400) : { account, device: id };
}

// Content type, size, then JSON and form; the check's message never leaves the service.
async function jsonBody(request: Request, check: (doc: unknown) => void): Promise<{ doc: unknown } | Response> {
  if (!isJson(request)) return status(415);
  const raw = await readLimited(request);
  if (raw === null) return status(413);
  try {
    const doc: unknown = JSON.parse(raw);
    check(doc);
    return { doc };
  } catch {
    return status(400);
  }
}

// An older transcript is no error: the service already holds a newer one, a retry would change nothing.
async function transcript(deps: AppDeps, request: Request): Promise<Response> {
  const checked = await admitted(deps, request, { device: false });
  if (checked instanceof Response) return checked;
  const body = await jsonBody(request, checkTranscript);
  if (body instanceof Response) return body;
  await putTranscript(deps.pool, checked.account, body.doc);
  return status(204);
}

// The next free (or reclaimed) order of the account for this device; 204 when none is open. A body is ignored.
async function claim(deps: AppDeps, request: Request): Promise<Response> {
  const checked = await admitted(deps, request, { device: true });
  if (checked instanceof Response) return checked;
  const order = await claimOrder(deps.pool, checked.account, checked.device);
  if (order === undefined) return status(204);
  return Response.json(order, { headers: { "cache-control": "no-store" } });
}

// stored and duplicate are the same for the app; refused (not this device's order) is 409.
async function result(deps: AppDeps, request: Request): Promise<Response> {
  const checked = await admitted(deps, request, { device: true });
  if (checked instanceof Response) return checked;
  const body = await jsonBody(request, checkResult);
  if (body instanceof Response) return body;
  const outcome = await putResult(deps.pool, checked.account, checked.device, body.doc);
  return status(outcome === "refused" ? 409 : 204);
}

// Exceptions are not caught here: dispatch in main.ts turns them into 500 without a body.
export function appRoutes(deps: AppDeps): Record<string, Route> {
  return {
    "/app/transcript": (request) => transcript(deps, request),
    "/app/orders/claim": (request) => claim(deps, request),
    "/app/orders/result": (request) => result(deps, request),
  };
}
