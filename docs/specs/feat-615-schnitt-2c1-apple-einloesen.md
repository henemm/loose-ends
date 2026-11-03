---
entity_id: feat-615-schnitt-2c1-apple-einloesen
type: feature
created: 2026-11-03
updated: 2026-11-03
status: draft
workflow: feat-615-s2c-apple-einloesen
---

# Spec: Apples Autorisierungscode einlösen, Schnitt 2c-1 (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 2c-1; das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s2c-apple-einloesen.md`, Abschnitt „Analysis“. Vorgänger: Schnitt 2b-2 (Tresor), 2b-1 (JWKS-Cache) und Schnitt 2a (`docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md`), dessen Abschnitt „Festgelegt für S2b und S2c“ dieser Schnitt umsetzt. `revokeToken` (Widerruf bei Apple) ist ausdrücklich **nicht** Teil, das ist Schnitt 2c-2, ein eigener Workflow.

## Für den PO

Meldet sich jemand mit Apple an, gibt Apple der App einen einmaligen Code. Der Dienst muss diesen Code bei Apple einlösen, um den langlebigen Schlüssel zu bekommen, den er beim Löschen des Kontos zurückgeben muss (S2b-2 legt ihn verschlüsselt ab). Dafür muss sich der Dienst bei Apple mit einem selbst unterschriebenen Ausweis melden. Dieser Schnitt baut beides als Baustein: den Ausweis und das Einlösen. In der App ändert sich nichts Sichtbares, und nichts davon wird aufgerufen: Die App ruft den Dienst weiterhin nirgends auf (ADR-21). Das Zurückgeben beim Löschen folgt im nächsten Schnitt (2c-2).

## Purpose

Der Dienst löst den Autorisierungscode der App bei Apple (`POST https://appleid.apple.com/auth/token`) ein und erhält den Refresh-Token. Dieser Schnitt baut `server/src/apple-client.ts` mit `clientSecret` (das von Apple verlangte, selbst signierte ES256-JWT aus der `.p8`) und `redeemCode`. Die Antwort trägt zusätzlich ein `id_token`; aus ihm liest `redeemCode` das `sub` und gibt es mit zurück, damit S3 es mit dem `sub` des geprüften Identity-Tokens vergleichen kann (sonst könnte ein fremder Code ein Konto mit einem fremden Refresh-Token belegen).

Es entsteht nur Dienstcode ohne Port; das Netz wird hereingereicht (`fetch`, `now`), im Test durch einen Stub ersetzt. Nichts ruft ihn auf (ADR-21). S3 ruft `redeemCode` beim Anmelden, verschlüsselt den Token mit `encryptToken` und legt ihn mit `storeRefreshToken` ab.

**Regeln vor Modell:** Signatur, Formular und JSON-Auswertung, keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt die in S2a (Festlegung „Festgelegt für S2b und S2c“) und ADR-21 getroffene Entscheidung um (Refresh-Token einlösen, verschlüsselt ablegen, beim Löschen widerrufen), keine neue Architekturentscheidung, keine neue Abhängigkeit (nur `node:crypto`).
- **Rationale:** Neu festgeschrieben wird nur, was in S2a offen blieb: `client_id` als Parameter statt `clientIds[0]`, Secret je Aufruf mit 5 Minuten Lebensdauer, `sub` aus dem `id_token`, Gründe als Werte.

## Source

**Files:** `server/src/apple-client.ts`, `server/test/apple-client.test.ts`, `CLAUDE.md`
**Identifier:** `clientSecret`, `redeemCode`

Eigene Datei: `apple.ts`, `apple-jwks.ts`, `apple-vault.ts`, `accounts.ts` und `server/migrations/` bleiben wie gemergt.

### Schnittstelle

- `clientSecret(config: AppleConfig, clientId: string, now: number): string` — JWT mit Kopf `{ alg: "ES256", kid: config.keyId }` und Nutzlast `{ iss: config.teamId, iat: s, exp: s + 300, aud: "https://appleid.apple.com", sub: clientId }`, wobei `s = Math.floor(now / 1000)` und `now` in Millisekunden (wie bei `verifyIdentityToken`). Signatur: `crypto.sign("sha256", data, { key: config.privateKey, dsaEncoding: "ieee-p1363" })`, also 64 Byte `r‖s`, als base64url. **Wirft** bei eigener Fehlbedienung: `clientId` nicht in `config.clientIds` (Groß-/Kleinschreibung zählt), `now` keine endliche Zahl. Der Fehlertext enthält weder Schlüssel noch `clientId`.
- `redeemCode(code: string, clientId: string, opts: { config: AppleConfig; fetch: typeof fetch; now: () => number; url?: string }): Promise<Redeemed>` mit `Redeemed = { ok: true; refreshToken: string; sub: string } | { ok: false; reason: string }`. `url` gibt es nur für Tests; Vorgabe `https://appleid.apple.com/auth/token`. **Wirft nur bei eigener Fehlbedienung:** `clientId` außerhalb von `config.clientIds`, leerer `code`. Bei fremder Antwort, Netzfehler und Zeitlimit **wirft sie nie**, sondern ergibt `{ ok: false, reason }`.

### Festlegungen

- **`client_id` als Parameter:** Apple verlangt beim Einlösen die Bundle-ID der App (Fallbericht developer.apple.com/forums/thread/118135), und mit #621 kommt eine zweite Client-ID für den Connector. Kein Rückgriff auf `clientIds[0]`. Woher S3 die `client_id` nimmt, entscheidet S3 (siehe „Für S3 festgehalten“).
- **Secret je Aufruf neu:** `iat` = jetzt, `exp` = jetzt + 300 s; kein Vorhalten, kein Ablauf nach sechs Monaten (Fallbericht `invalid_client`).
- **Anfrage:** `fetch(url, { method: "POST", headers: { "content-type": "application/x-www-form-urlencoded" }, body, signal: AbortSignal.timeout(5000) })`. Das Formular enthält genau `client_id`, `client_secret`, `code`, `grant_type=authorization_code`; **kein `redirect_uri`** (die native App hat keinen).
- **Antwort 200:** JSON-Objekt mit nicht leerem Text `refresh_token` und `id_token`. Das `id_token` wird **nur gelesen** (Nutzlast base64url-dekodiert, keine Signaturprüfung; zulässig nach OIDC Core 3.1.3.7 (6), weil die Antwort per TLS direkt von Apple kommt und die URL fest ist). Geprüft werden `iss === "https://appleid.apple.com"`, `aud === clientId` und ein nicht leerer Text `sub`; das `sub` wird zurückgegeben. Fehlt oder passt etwas nicht → `malformed_response`.
- **Gründe (`reason`):**
  - `apple:<error>` nur, wenn der Status ≠ 200 ist und `error` im JSON einer der sechs bekannten Apple-Werte ist: `invalid_request`, `invalid_client`, `invalid_grant`, `unauthorized_client`, `unsupported_grant_type`, `invalid_scope`.
  - `apple_status` bei jedem anderen Status ≠ 200 (unbekannter oder fehlender `error`, kein JSON, anderer Typ); der Wert aus Apples Antwort wird nie übernommen.
  - `unavailable` bei Netzfehler, Ausnahme von `fetch` (auch synchron) und Zeitlimit.
  - `malformed_response` bei Status 200 mit kaputtem JSON, Nicht-Objekt, fehlendem oder leerem `refresh_token`/`id_token` oder fehlerhaftem `id_token` (kein JWT, `iss`, `aud` oder `sub` falsch).
- **Keine Geheimnisse in Gründen und Fehlertexten:** weder `code`, `client_secret`, Refresh-Token noch `access_token` noch Rohtext der Antwort.
- **Stille und Länge:** kein `console`, kein `process.stdout`/`stderr`; jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; nur `node:crypto`.

### Für S3 festgehalten (nicht in diesem Schnitt)

- S3 vergleicht das zurückgegebene `sub` mit dem `sub` des geprüften Identity-Tokens; bei Abweichung wird der Token nicht abgelegt.
- Welche `client_id` S3 beim Einlösen benutzt und wo sie für den Widerruf liegt, entscheidet S3: `aud` aus `verifyIdentityToken` zurückgeben und eine Spalte `client_id` in `apple_tokens` (additive Migration 003). Der Widerruf (2c-2) braucht dieselbe `client_id` wie die Anmeldung (Apple, Revoke Tokens).
- Ein neuer `APPLE_TOKEN_KEY` macht abgelegte Blobs unlesbar (S2b-2); dann entfällt der Widerruf (Best Effort nach TN3194), und S3 meldet das.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `node:crypto` (`sign`, `createPublicKey`/`verify` nur im Test) | Standardbibliothek, **keine neuen Pakete** |
| `AppleConfig` aus `server/src/apple.ts` | bestehend, `apple.ts` **unverändert** |
| globales `fetch` | hereingereicht; im Test durch Stub ersetzt (Muster aus `server/test/apple-jwks.test.ts`) |
| `loadAppleConfig` | im Test, um eine gültige Konfiguration mit eigenem EC-P-256-Schlüssel zu bauen |
| Downstream | 2c-2 (`revokeToken`), S3 (`POST /auth/apple`, `DELETE /account`), #621 |

## Acceptance Criteria

Alle Tests laufen im Prozess, ohne Port, ohne Netz und ohne Datenbank, mit `node:test` und `node:assert/strict`. Sie erzeugen ein eigenes EC-P-256-Paar, bauen die Konfiguration damit, setzen einen Stub-`fetch` mit Aufrufzähler, letzten Argumenten und austauschbarer Antwort sowie eine feste Uhr ein und signieren das `id_token` der Stub-Antwort selbst. Fehlerfälle stehen tabellengetrieben in einer Fallliste, ein Fall je Zeile.

- **AC-1:** Secret gültig und prüfbar: `clientSecret` liefert drei base64url-Segmente; der Kopf ist genau `{ alg: "ES256", kid: keyId }`; die Nutzlast ist genau `{ iss: teamId, iat, exp, aud: "https://appleid.apple.com", sub: clientId }` mit `iat = floor(now/1000)` und `exp = iat + 300`; die Signatur ist 64 Byte lang und verifiziert mit dem öffentlichen Schlüssel über `verify("sha256", …, { dsaEncoding: "ieee-p1363" })`; das gilt für beide Client-IDs einer Konfiguration mit zwei Einträgen (`sub` jeweils die übergebene). Test: `server/test/apple-client.test.ts`, „secret: kopf, nutzlast, signatur“.
- **AC-2:** Secret je Aufruf neu: Zwei Aufrufe mit verschiedenem `now` ergeben verschiedene `iat`/`exp`; eine Änderung der Signatur um ein Bit oder der Nutzlast um ein Zeichen lässt die Prüfung mit dem öffentlichen Schlüssel scheitern. Test: `apple-client.test.ts`, „secret: je aufruf neu, manipulation fällt auf“.
- **AC-3:** Fehlbedienung wirft: `clientSecret` mit `clientId` außerhalb der Liste (auch nur anders geschrieben) und mit `now` = `NaN`/`Infinity`/Text wirft; `redeemCode` wirft bei fremder `clientId` und bei leerem `code`, **ohne dass `fetch` aufgerufen wird** (Zähler 0); kein Fehlertext enthält `clientId`, `code` (Testwert `GEHEIM-123`) oder Schlüsselmaterial. Test: `apple-client.test.ts`, „fehlbedienung: wirft ohne netz“ (Fallliste).
- **AC-4:** Anfrage genau wie festgelegt: Bei gültigem Aufruf ruft `redeemCode` `fetch` genau einmal auf, mit der Vorgabe-URL `https://appleid.apple.com/auth/token` (mit `opts.url` die übergebene), Methode `POST`, Kopf `content-type: application/x-www-form-urlencoded`, einem `AbortSignal` und einem Formular, das geparst genau die Schlüssel `client_id`, `client_secret`, `code`, `grant_type` hat; `grant_type` ist `authorization_code`, `client_id` und `code` sind die übergebenen Werte, ein `redirect_uri` gibt es nicht, und `client_secret` ist ein nach AC-1 gültiges Secret für diese `client_id` zum Zeitpunkt `opts.now()`. Test: `apple-client.test.ts`, „redeem: anfrage“.
- **AC-5:** Erfolg: Antwort 200 mit `refresh_token`, `access_token`, `token_type`, `expires_in` und einem `id_token` (`iss` Apple, `aud` = `clientId`, `sub` gesetzt) ergibt `{ ok: true, refreshToken, sub }` mit den Werten der Antwort, auch für die zweite Client-ID; das Ergebnis enthält keine weiteren Felder (kein `access_token`). Test: `apple-client.test.ts`, „redeem: erfolg“.
- **AC-6:** Apple-Fehler: Status 400 (und 401) mit `{ "error": X }` ergibt `{ ok: false, reason: "apple:X" }` für jeden der sechs bekannten Werte; ein unbekannter `error`-Wert (`GEHEIM-123`, `<script>`, leer, Zahl, Objekt, Liste) ergibt `apple_status`, ebenso Status 500/503/302 mit beliebigem Rumpf und Status 400 ohne JSON. Test: `apple-client.test.ts`, „redeem: apple-fehler und status“ (Fallliste).
- **AC-7:** Falsche 200-Antworten: Status 200 mit kaputtem JSON, JSON-Array, `null`, leerem Objekt, fehlendem, leerem oder nicht-textuellem `refresh_token` sowie fehlendem `id_token` ergibt `malformed_response`. Test: `apple-client.test.ts`, „redeem: malformed 200“ (Fallliste).
- **AC-8:** Fehlerhaftes `id_token`: Ein `id_token`, das kein JWT ist (zwei oder vier Segmente, Nicht-base64url, Nutzlast kein JSON-Objekt), mit falschem `iss`, mit `aud` ≠ übergebener `clientId` (auch eine andere Client-ID aus der Liste), ohne `sub` oder mit leerem oder nicht-textuellem `sub` ergibt `malformed_response`, und es wird nie `ok: true` zurückgegeben. Test: `apple-client.test.ts`, „redeem: id_token geprüft“ (Fallliste).
- **AC-9:** Netz und Zeitlimit: Eine Ausnahme von `fetch`, ein synchroner Wurf, eine `TimeoutError`-Ausnahme und ein abgelehntes `fetch` ergeben `{ ok: false, reason: "unavailable" }` und werfen nie; der übergebene `AbortSignal` ist ein Zeitlimit von höchstens 5000 ms (Prüfung: das Signal ist nicht abgebrochen, bricht aber nach `AbortSignal.timeout`-Dauer ab, oder der Aufruf mit einem Stub, der auf das Signal wartet, endet mit `unavailable`). Test: `apple-client.test.ts`, „redeem: unavailable und zeitlimit“ (Fallliste).
- **AC-10:** Keine Geheimnisse in Gründen: Über alle Fälle aus AC-3 bis AC-9 (Testwerte `GEHEIM-CODE` für den Code, `GEHEIM-TOKEN` für Refresh-Token und `access_token`, `GEHEIM-123` im Apple-`error` und im Rumpf) ist jeder `reason` einer von `apple:<einer der sechs>`, `apple_status`, `unavailable`, `malformed_response`; kein `reason` und kein Fehlertext enthält Code, Secret (weder Ganzes noch Segmente), Token oder Rohtext der Antwort. Test: `apple-client.test.ts`, „reason: feste menge, keine geheimnisse“.
- **AC-11:** Stille: Während aller Aufrufe der Tests AC-1 bis AC-9 (Erfolg, `ok: false`, Wurf) wird nichts nach `console` oder `process.stdout`/`process.stderr` geschrieben (der Test ersetzt sie vorübergehend). Test: `apple-client.test.ts`, „silence“.
- **AC-12:** Regression, CI und Funktionslänge: Test: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, die bestehenden Testdateien bleiben unverändert; jede Funktion in `server/src/apple-client.ts` hat höchstens 50 Zeilen (Prüfung in der Validierung: `grep -nE "function" server/src/apple-client.ts`, Abstand zweier Funktionsanfänge und Dateiende ≤ 50) und die Datei benutzt nur `node:crypto` (`grep -n "^import" server/src/apple-client.ts` nennt nur `node:crypto` und `./apple.ts`).
- **AC-13:** Dateigrenze und Doku: Test: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple-client.ts`, `server/test/apple-client.test.ts` und `CLAUDE.md`; `CLAUDE.md` enthält im Abschnitt `server/` nach der Zeile zu `src/apple-vault.ts` genau eine neue Zeile zu `src/apple-client.ts` im gleichen Stil („nothing calls it yet“); `server/src/apple.ts`, `apple-jwks.ts`, `apple-vault.ts`, `accounts.ts`, `server/migrations/`, `server/test/db.ts`, `server/package.json`, `server/package-lock.json`, `server/src/main.ts`, `.github/workflows/`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple-client.ts` | CREATE | `clientSecret`, `redeemCode`, Hilfsfunktionen für Formular und `id_token`, ~+65 |
| `server/test/apple-client.test.ts` | CREATE | AC-1 bis AC-11, tabellengetrieben, ~+165 |
| `CLAUDE.md` | MODIFY | eine Zeile im Abschnitt `server/`: `src/apple-client.ts`, ~+1 |

### Estimated Changes

- Files: 3 (2 neu, 1 geändert).
- LoC: ≈ 230 gesamt, gezählt wie in S1, S2a, S2b-1 und S2b-2 (Code, Tests und Doku zusammen): Code ≈ 65, Tests ≈ 165, Doku ≈ 1. Limit ±250. Wird es knapp, wird vor dem Bauen gefragt; die Tests werden nicht gekürzt. `revokeToken` (Code ≈ 20, Tests ≈ 60) bleibt aus diesem Grund in Schnitt 2c-2.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, kein `generate`, keine Migration, kein Eingriff in bestehenden Code. Seiteneffekt außerhalb des Tickets: keiner; nichts ruft den Code auf.

## Risiken

- **Falsche `client_id`:** Der Code der App gilt nur mit der Bundle-ID; eine Services-ID ergibt `invalid_grant` (Fallbericht forums/thread/118135). Darum Parameter statt Voreinstellung und Wurf bei Werten außerhalb der Liste (AC-3).
- **Fremder Code, fremdes Konto:** Ohne den Vergleich des zurückgegebenen `sub` mit dem geprüften Identity-Token könnte ein Konto einen fremden Refresh-Token tragen. `redeemCode` liefert das `sub`; der Vergleich ist S3 (oben festgehalten).
- **`id_token` ohne Signaturprüfung:** zulässig nach OIDC nur, solange die URL fest auf `appleid.apple.com` (https) steht; ein überschreibbares `url` gibt es nur für Tests und ist kein Konfigurationswert.
- **DER statt `r‖s`:** `crypto.sign` liefert ECDSA standardmäßig als DER; Apple lehnt das ab. Darum `dsaEncoding: "ieee-p1363"`, geprüft an der 64-Byte-Länge und der Gegenprobe mit dem öffentlichen Schlüssel (AC-1).
- **Secret-Ablauf:** Ein dauerhaft gespeichertes Secret läuft nach sechs Monaten ab (`invalid_client`); darum je Aufruf neu mit 5 Minuten (AC-2).
- **Geheimnisse in Fehlern:** Code, Secret, Token nie in Gründen oder Fehlertexten; Apples `error` nur aus der festen Menge (AC-6, AC-10).
- **Apple antwortet nicht:** Zeitlimit 5 s, Ergebnis `unavailable` statt Ausnahme oder Hängen (AC-9).
- **LoC:** Tests ≈ 2,5-faches des Codes; darum die Teilung in 2c-1 und 2c-2.

## Test Plan

### Automated Tests (TDD RED)

RED: Zuerst `apple-client.test.ts`; `apple-client.ts` fehlt, die Tests schlagen fehl.

- [ ] Test 1 (AC-1, AC-2): GIVEN eine Konfiguration mit eigenem EC-P-256-Paar und zwei Client-IDs WHEN `clientSecret` aufgerufen wird THEN Kopf, Nutzlast und 64-Byte-Signatur stimmen und verifizieren mit dem öffentlichen Schlüssel; Manipulation fällt auf, `iat` folgt `now`.
- [ ] Test 2 (AC-3): GIVEN Fehlbedienungen WHEN `clientSecret`/`redeemCode` aufgerufen werden THEN Wurf, kein `fetch`, keine Geheimnisse im Text.
- [ ] Test 3 (AC-4, AC-5): GIVEN ein Stub-`fetch` mit gültiger Antwort WHEN `redeemCode` aufgerufen wird THEN die Anfrage entspricht der Festlegung und das Ergebnis ist `{ ok: true, refreshToken, sub }`.
- [ ] Test 4 (AC-6, AC-7, AC-8): GIVEN die Fallliste der Apple-Fehler, falschen 200-Antworten und fehlerhaften `id_token` WHEN `redeemCode` aufgerufen wird THEN der erwartete Grund und nie ein Wurf.
- [ ] Test 5 (AC-9, AC-10): GIVEN Netzfehler, Zeitlimit und Kennwörter in Stub-Antworten WHEN `redeemCode` aufgerufen wird THEN `unavailable` bzw. nur Gründe aus der festen Menge, ohne Geheimnisse.
- [ ] Test 6 (AC-11): GIVEN `console.*` und `process.stdout/stderr` vorübergehend ersetzt WHEN alle Aufrufe laufen THEN keine Ausgabe.
- [ ] Test 7 (AC-12, AC-13): GIVEN der fertige Zweig WHEN `./server/scripts/test-local.sh`, `server.yml` und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` THEN grün, grün, genau die drei Dateien.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): Code einlösen, Refresh-Token verschlüsselt ablegen, beim Löschen widerrufen.** Wie in S2a festgelegt; klein, jede Zeile testbar, keine neue Abhängigkeit.
- **B: Keinen Refresh-Token speichern; beim Löschen schickt die App einen frischen Autorisierungscode, der Dienst löst ihn ein und widerruft sofort.** Kein Tresor, kein `APPLE_TOKEN_KEY`, kein Schlüsselwechsel-Problem. Kippt S2b-2 (Tresor würde überflüssig); Löschen ginge nur aus der App mit frischer Apple-Anmeldung, nie vom Dienst allein (zum Beispiel Löschung per Mail-Anfrage).
- **C: `client_id` im verschlüsselten Blob statt in einer eigenen Spalte.** Keine Migration. Kippt das Blobformat `0x01` aus S2b-2 (neue Version nötig). Entscheidung liegt bei S3.
- **D: Nur `clientIds[0]` bis #621.** Zwei Zeilen weniger. Der Widerruf für Connector-Konten wäre später falsch, Umbau in #621.
- Befunde gegen den Plan: `apple_tokens` hat keine `client_id`-Spalte und `verifyIdentityToken` gibt `aud` nicht zurück; beides bewusst nach S3 verlegt, kein Blocker für 2c-1.

## Nicht in diesem Schnitt / Folgeschnitte

- **2c-2:** `revokeToken(refreshToken, clientId, opts)` in derselben Datei (`POST /auth/revoke`, Fehler melden, nie das Löschen verhindern).
- S3 HTTP-Rand: Routen, `createJwks` einmal beim Start, Konfiguration, Vergleich des `sub`, `client_id`-Ablage. S4 App (nach #625).
- Schlüsselrotation des Tresors.

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulator nötig. Nachweis: `./server/scripts/test-local.sh` (typecheck + `node --test`) grün und der CI-Job `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-13 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `src/apple-client.ts`
- [ ] #615 kommentiert (Stand Schnitt 2c-1, Folge 2c-2), Board-Karte aktuell

## Changelog

- 2026-11-03: Initial spec created (Schnitt 2c-1)
