// Probe für #795 S5b: gilt die APNs-Anmeldung des Dienstes? Läuft per stdin im Image (`node --input-type=module -`).
// Nimmt apnsConfigFromEnv und sendHttp2 aus dem Image, baut das JWT selbst (ES256, ieee-p1363) und schickt je Host ein
// erfundenes, wohlgeformtes Token. Nie createWaker, nie die Datenbank, nie ein echtes Token.
// Ausgabe nur Variablennamen mit Länge, Hostnamen, Statuscodes und Apples reason, nie ein Wert, das JWT oder das Token.
// EXPECT (Standard Fall a): "production=400:BadDeviceToken,sandbox=400:BadDeviceToken";
// Fall c: "production=400:BadDeviceToken,sandbox=403:InvalidProviderToken". APNS_SRC: Pfad zu apns.ts (Standard im Image).
// Exit 0 nur, wenn jeder erwartete Status eintrat.
import { randomBytes, sign } from "node:crypto";

const NAMES = ["APNS_TEAM_ID", "APNS_KEY_ID", "APNS_PRIVATE_KEY", "APNS_TOPIC"];
const ORIGINS = { production: "https://api.push.apple.com", sandbox: "https://api.sandbox.push.apple.com" };
const EXPECT = process.env.EXPECT ?? "production=400:BadDeviceToken,sandbox=400:BadDeviceToken";
const SRC = process.env.APNS_SRC ?? "/app/src/apns.ts";

let failed = false;
const fail = (line) => { console.log(`FEHLT ${line}`); failed = true; };

for (const name of NAMES) {
  const value = process.env[name] ?? "";
  if (!value.trim()) fail(`${name} fehlt oder leer`);
  else console.log(`OK    ${name} vorhanden, Länge ${value.length}`);
}
const pem = process.env.APNS_PRIVATE_KEY ?? "";
if (pem && /[\r\n]/.test(pem)) fail("APNS_PRIVATE_KEY enthält echte Zeilenumbrüche (erwartet einzeilig mit \\n)");
if (pem && !pem.replace(/\\n/g, "\n").trim().startsWith("-----BEGIN PRIVATE KEY-----")) fail("APNS_PRIVATE_KEY beginnt nicht mit der PKCS#8-Kopfzeile");

if (!failed) {
  const { apnsConfigFromEnv, sendHttp2 } = await import(SRC);
  let config;
  try {
    config = apnsConfigFromEnv(process.env);
  } catch (error) {
    fail(`Konfiguration: ${error instanceof Error ? error.message : "unlesbar"}`);
  }
  if (config) {
    const segment = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
    const data = `${segment({ alg: "ES256", kid: config.keyId })}.${segment({ iss: config.teamId, iat: Math.floor(Date.now() / 1000) })}`;
    const jwt = `${data}.${sign("sha256", Buffer.from(data), { key: config.privateKey, dsaEncoding: "ieee-p1363" }).toString("base64url")}`;
    const body = JSON.stringify({ aps: { "content-available": 1 }, looseends: { v: 1, probe: true } });
    for (const pair of EXPECT.split(",")) {
      const [env, want] = pair.split("=");
      const origin = ORIGINS[env];
      if (!origin) { fail(`unbekannte Umgebung in EXPECT: ${env}`); continue; }
      const token = randomBytes(32).toString("hex"); // erfunden, nie ausgegeben
      const host = new URL(origin).host;
      try {
        const { status, reason } = await sendHttp2({ origin, token, jwt, topic: config.topic, body }, { timeoutMs: 10_000 });
        const got = `${status}:${reason ?? "-"}`;
        if (got === want) console.log(`OK    ${host} ${status} ${reason ?? "-"} (soll ${want.replace(":", " ")})`);
        else fail(`${host} ${status} ${reason ?? "-"} (soll ${want.replace(":", " ")})`);
      } catch (error) {
        fail(`${host} kein Status: ${error instanceof Error ? error.message : "Fehler"}`);
      }
    }
  }
}
console.log(`Stand: ${new Date().toISOString()}, erwartet: ${EXPECT}`);
process.exit(failed ? 1 : 0);
