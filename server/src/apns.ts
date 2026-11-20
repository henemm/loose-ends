import { createPrivateKey, sign, type KeyObject } from "node:crypto";
import http2, { type IncomingHttpHeaders } from "node:http2";
import type pg from "pg";
import { dropToken, listTokens, type DeviceDoc } from "./devices.ts";

export type ApnsConfig = { teamId: string; keyId: string; privateKey: KeyObject; topic: string };
export type ApnsRequest = { origin: string; token: string; jwt: string; topic: string; body: string };
export type ApnsResponse = { status: number; reason?: string; apnsId?: string; uniqueId?: string };
type Origins = Record<DeviceDoc["environment"], string>;

const NAMES = ["APNS_TEAM_ID", "APNS_KEY_ID", "APNS_PRIVATE_KEY", "APNS_TOPIC"] as const;
const ORIGINS: Origins = { sandbox: "https://api.sandbox.push.apple.com", production: "https://api.push.apple.com" };
const BODY = JSON.stringify({ aps: { "content-available": 1 }, looseends: { v: 1 } });
const MIN = 60_000;
const RENEW_AFTER = 50 * MIN;
const MIN_AGE = 20 * MIN;
// At most one wake-up per device in this window (#960 S2); iOS throttles silent pushes sent more often.
const MIN_GAP = 15 * MIN;
// Apple's reasons that mean the token is no good for this app; everything else keeps the row.
const DROP = new Set(["410 Unregistered", "400 BadDeviceToken", "400 DeviceTokenNotForTopic"]);
const UUID = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;

// None set → undefined (no wake-up); some or an unreadable key → an error naming only the variable.
export function apnsConfigFromEnv(env: NodeJS.ProcessEnv = process.env): ApnsConfig | undefined {
  const [teamId, keyId, pem, topic] = NAMES.map((name) => env[name]?.trim() ?? "");
  if (!teamId && !keyId && !pem && !topic) return undefined;
  NAMES.forEach((name, i) => { if (![teamId, keyId, pem, topic][i]) throw new Error(`${name} is missing or empty`); });
  let privateKey: KeyObject;
  try {
    privateKey = createPrivateKey(pem.replace(/\\n/g, "\n"));
  } catch {
    throw new Error("APNS_PRIVATE_KEY is not a readable private key");
  }
  if (privateKey.asymmetricKeyType !== "ec" || privateKey.asymmetricKeyDetails?.namedCurve !== "prime256v1") {
    throw new Error("APNS_PRIVATE_KEY is not an EC P-256 key");
  }
  return { teamId, keyId, privateKey, topic };
}

const segment = (value: object) => Buffer.from(JSON.stringify(value)).toString("base64url");

function providerJwt(config: ApnsConfig, now: number): string {
  if (!Number.isFinite(now)) throw new Error("clock is not a number");
  const data = `${segment({ alg: "ES256", kid: config.keyId })}.${segment({ iss: config.teamId, iat: Math.floor(now / 1000) })}`;
  return `${data}.${sign("sha256", Buffer.from(data), { key: config.privateKey, dsaEncoding: "ieee-p1363" }).toString("base64url")}`;
}

// One session per call, closed in finally; a session error, a closed stream or the time limit rejects.
export async function sendHttp2(request: ApnsRequest, opts: { timeoutMs?: number } = {}): Promise<ApnsResponse> {
  const session = http2.connect(request.origin);
  let timer: NodeJS.Timeout | undefined;
  try {
    return await new Promise<ApnsResponse>((resolve, reject) => {
      timer = setTimeout(() => reject(new Error("apns timeout")), opts.timeoutMs ?? 5000);
      session.on("error", reject);
      const stream = session.request({
        ":method": "POST", ":path": `/3/device/${request.token}`, authorization: `bearer ${request.jwt}`,
        "apns-topic": request.topic, "apns-push-type": "background", "apns-priority": "5", "content-type": "application/json",
      });
      const chunks: Buffer[] = [];
      let status = 0;
      let ids: ReturnType<typeof apnsIds> = {};
      stream.on("response", (headers) => { status = Number(headers[":status"]); ids = apnsIds(headers); });
      stream.on("data", (chunk: Buffer) => chunks.push(chunk));
      // Without a response header (status 0) the stream ended unanswered, which the close handler rejects.
      stream.on("end", () => { if (status) resolve({ status, ...ids, ...reasonOf(Buffer.concat(chunks).toString("utf8")) }); });
      stream.on("error", reject);
      stream.on("close", () => reject(new Error("apns stream closed")));
      stream.end(request.body);
    });
  } finally {
    clearTimeout(timer);
    session.destroy();
  }
}

// Apple's ids only as one canonical UUID string each; anything else is left out and never logged.
export function apnsIds(headers: IncomingHttpHeaders): { apnsId?: string; uniqueId?: string } {
  const valid = (value: unknown) => (typeof value === "string" && UUID.test(value) ? value : undefined);
  const [apnsId, uniqueId] = [valid(headers["apns-id"]), valid(headers["apns-unique-id"])];
  return { ...(apnsId ? { apnsId } : {}), ...(uniqueId ? { uniqueId } : {}) };
}

// " STATUS ENV[ id=…][ unique=…]", the end of every outcome line; the ids are checked again before they are written.
function describe(response: ApnsResponse, env: DeviceDoc["environment"]): string {
  const ids = apnsIds({ "apns-id": response.apnsId, "apns-unique-id": response.uniqueId });
  return ` ${response.status} ${env}${ids.apnsId ? ` id=${ids.apnsId}` : ""}${ids.uniqueId ? ` unique=${ids.uniqueId}` : ""}`;
}

function reasonOf(body: string): { reason?: string } {
  try {
    const reason: unknown = JSON.parse(body)?.reason;
    return typeof reason === "string" ? { reason } : {};
  } catch {
    return {};
  }
}

type WakerOptions = {
  config: ApnsConfig; pool: pg.Pool; send?: (request: ApnsRequest) => Promise<ApnsResponse>;
  now?: () => number; log?: (event: string) => void; origins?: Origins;
  minGapMs?: number; schedule?: (run: () => Promise<void>, delayMs: number) => void;
};

// unref, so a planned later wake never keeps the process from ending.
const laterTimer = (run: () => Promise<void>, delayMs: number) => { setTimeout(run, delayMs).unref(); };

// wake(account) sends a silent push to every device of the account and drops dead tokens; it never throws.
// Per device (key ENV:token) at most one push per minGapMs; a wake inside the window plans exactly one later wake.
export function createWaker(opts: WakerOptions): { wake(account: string): Promise<void> } {
  const { config, pool, send = sendHttp2, now = Date.now, origins = ORIGINS, minGapMs = MIN_GAP, schedule = laterTimer } = opts;
  const log = (event: string) => { try { opts.log?.(event); } catch { /* a broken log never stops a wake */ } };
  let cached: { jwt: string; issuedAt: number } | undefined;
  const paced = new Map<string, { last: number; later: boolean }>();
  const keyOf = (device: DeviceDoc) => `${device.environment}:${device.token}`;

  // Renew at 50 minutes; after ExpiredProviderToken renew only if at least 20 minutes old (undefined = no retry).
  function providerToken(at: number, rejected?: string): string | undefined {
    if (cached && rejected && cached.jwt !== rejected) return cached.jwt;
    if (cached && rejected && at - cached.issuedAt < MIN_AGE) return undefined;
    if (cached && !rejected && at - cached.issuedAt < RENEW_AFTER) return cached.jwt;
    cached = { jwt: providerJwt(config, at), issuedAt: at };
    return cached.jwt;
  }

  async function deliver(device: DeviceDoc): Promise<void> {
    let jwt: string | undefined;
    try { jwt = providerToken(now()); } catch { log("apns jwt failed"); return; }
    try {
      const request = (token: string) => send({ origin: origins[device.environment], token: device.token, jwt: token, topic: config.topic, body: BODY });
      let response = await request(jwt!);
      const retry = response.status === 403 && response.reason === "ExpiredProviderToken" ? providerToken(now(), jwt) : undefined;
      if (retry) response = await request(retry);
      const outcome = describe(response, device.environment);
      if (response.status >= 200 && response.status < 300) return log(`apns sent${outcome}`);
      if (!DROP.has(`${response.status} ${response.reason}`)) return log(`apns send failed${outcome}`);
      await dropToken(pool, device.token, device.environment);
      log(`apns token dropped${outcome}`);
    } catch {
      log(`apns send failed error ${device.environment}`);
    }
  }

  // Sends now and opens a new window, whatever Apple answers.
  function wakeNow(device: DeviceDoc): Promise<void> {
    paced.set(keyOf(device), { last: now(), later: false });
    return deliver(device);
  }

  // The later wake reads the devices again and wakes only one that still exists; it never throws.
  async function wakeLater(account: string, key: string): Promise<void> {
    // A newer wake took the window over after the plan (later is false then); this plan is void.
    const plan = paced.get(key);
    if (!plan?.later) return;
    // A wake during the read replaces the window object; then this plan is void too.
    const current = () => paced.get(key) === plan;
    try {
      const device = (await listTokens(pool, account)).find((d) => keyOf(d) === key);
      if (!current()) return;
      if (device) return await wakeNow(device);
      paced.delete(key);
    } catch {
      if (current()) plan.later = false;
      log("apns send failed list");
    }
  }

  // Inside the window: plan one later wake at its end, or drop the wake if one is planned already.
  function pace(account: string, device: DeviceDoc): Promise<void> | void {
    const key = keyOf(device);
    const state = paced.get(key);
    if (!state || now() - state.last >= minGapMs) return wakeNow(device);
    if (state.later) return log(`apns wake throttled ${device.environment}`);
    state.later = true;
    log(`apns wake later ${device.environment}`);
    schedule(() => wakeLater(account, key), Math.max(0, state.last + minGapMs - now()));
  }

  return {
    async wake(account) {
      try {
        const devices = await listTokens(pool, account);
        log(`apns wake devices=${devices.length}`);
        await Promise.allSettled(devices.map((device) => pace(account, device)));
      } catch {
        log("apns send failed list");
      }
    },
  };
}
