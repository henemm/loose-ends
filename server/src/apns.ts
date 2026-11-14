import { createPrivateKey, sign, type KeyObject } from "node:crypto";
import http2 from "node:http2";
import type pg from "pg";
import { dropToken, listTokens, type DeviceDoc } from "./devices.ts";

export type ApnsConfig = { teamId: string; keyId: string; privateKey: KeyObject; topic: string };
export type ApnsRequest = { origin: string; token: string; jwt: string; topic: string; body: string };
export type ApnsResponse = { status: number; reason?: string };
type Origins = Record<DeviceDoc["environment"], string>;

const NAMES = ["APNS_TEAM_ID", "APNS_KEY_ID", "APNS_PRIVATE_KEY", "APNS_TOPIC"] as const;
const ORIGINS: Origins = { sandbox: "https://api.sandbox.push.apple.com", production: "https://api.push.apple.com" };
const BODY = JSON.stringify({ aps: { "content-available": 1 }, looseends: { v: 1 } });
const MIN = 60_000;
const RENEW_AFTER = 50 * MIN;
const MIN_AGE = 20 * MIN;
// Apple's reasons that mean the token is no good for this app; everything else keeps the row.
const DROP = new Set(["410 Unregistered", "400 BadDeviceToken", "400 DeviceTokenNotForTopic"]);

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
      stream.on("response", (headers) => { status = Number(headers[":status"]); });
      stream.on("data", (chunk: Buffer) => chunks.push(chunk));
      // Without a response header (status 0) the stream ended unanswered, which the close handler rejects.
      stream.on("end", () => { if (status) resolve({ status, ...reasonOf(Buffer.concat(chunks).toString("utf8")) }); });
      stream.on("error", reject);
      stream.on("close", () => reject(new Error("apns stream closed")));
      stream.end(request.body);
    });
  } finally {
    clearTimeout(timer);
    session.destroy();
  }
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
};

// wake(account) sends a silent push to every device of the account and drops dead tokens; it never throws.
export function createWaker(opts: WakerOptions): { wake(account: string): Promise<void> } {
  const { config, pool, send = sendHttp2, now = Date.now, origins = ORIGINS } = opts;
  const log = (event: string) => { try { opts.log?.(event); } catch { /* a broken log never stops a wake */ } };
  let cached: { jwt: string; issuedAt: number } | undefined;

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
      if (response.status >= 200 && response.status < 300) return;
      if (!DROP.has(`${response.status} ${response.reason}`)) return log("apns send failed");
      await dropToken(pool, device.token, device.environment);
      log("apns token dropped");
    } catch {
      log("apns send failed");
    }
  }

  return {
    async wake(account) {
      try {
        await Promise.allSettled((await listTokens(pool, account)).map(deliver));
      } catch {
        log("apns send failed");
      }
    },
  };
}
