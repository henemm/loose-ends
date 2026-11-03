---
entity_id: feat-615-schnitt-2a-apple-token-pruefen
type: feature
created: 2026-11-03
updated: 2026-11-03
status: draft
workflow: feat-615-s2-apple-anbindung
---

# Spec: Apple-Identity-Token prüfen, Schnitt 2a (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt 2a von (S1, S2a, S2b, S2c, S3, S4); das Issue bleibt offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s2-apple-anbindung.md`, Abschnitt „Analysis“. Vorgänger: Schnitt 1 (`docs/specs/feat-615-schnitt-1-konten-sitzungen.md`, PR #812).

## Purpose

Der Dienst muss einem „Mit Apple anmelden“-Token vertrauen können, bevor er ein Konto anlegt oder öffnet: Fälscht jemand das Token, öffnet er ein fremdes Konto. Dieser Schnitt liefert die Konfiguration für die Apple-Anbindung (`loadAppleConfig`) und die Prüfung des Identity-Tokens (`verifyIdentityToken`): Signatur gegen einen öffentlichen Schlüssel, `iss`, `aud`, Ablauf, `iat`, `nonce`.

Es entsteht nur Dienstcode ohne Port und ohne Netz: Die Schlüsselsuche wird als Funktion hereingereicht (`keys`), den Abruf von Apples Schlüsselliste samt Cache liefert S2b. Nichts ruft den Code auf (ADR-21: die App ruft den Dienst nirgends auf). Ein echter Apple-Aufruf ist offline nicht belegbar; die Tests belegen mit einem eigenen RSA-Paar und einer Stub-Suche, der echte Lauf folgt mit S3/S4.

**Regeln vor Modell:** Signatur, Datum, Zeichenvergleich. Es gibt keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — keine neue Abhängigkeit (nur `node:crypto`), kippt keine ADR; ADR-21 bleibt unberührt.
- **Rationale:** Umsetzung der Apple-Vorgabe „Verifying a user“; die Wahl `node:crypto` statt `jose` steht unter „Alternativen“.

## Source

**Files:** `server/src/apple.ts`, `server/test/apple.test.ts`, `CLAUDE.md`
**Identifier:** `loadAppleConfig`, `verifyIdentityToken`

### Konfiguration (`loadAppleConfig(env = process.env)`)

Wirft bei fehlendem, leerem oder ungültigem Wert; der Fehlertext nennt **nur den Variablennamen**, nie den Wert. S3 ruft sie beim Start, hier nur der Test.

- `APPLE_TEAM_ID`, `APPLE_KEY_ID`: Text, nicht leer.
- `APPLE_CLIENT_IDS`: kommagetrennt, getrimmt, leere Einträge verworfen, mindestens ein Eintrag (heute die Bundle-ID; #621 ergänzt die Services-ID).
- `APPLE_PRIVATE_KEY`: PEM der .p8; `\n` als Zeichenfolge wird zu Zeilenumbruch; muss ein privater EC-Schlüssel der Kurve P-256 sein. S2a lädt und prüft ihn nur, verwendet wird er in S2c.
- `APPLE_TOKEN_KEY`: base64, genau 32 Byte. S2a prüft nur die Form, verwendet wird er in S2b.

Rückgabe: `{ teamId, keyId, clientIds: string[], privateKey: KeyObject, tokenKey: Buffer }`.

### Prüfung (`verifyIdentityToken(token, rawNonce, { config, keys, now })`)

`keys: (kid: string) => Promise<JsonWebKey | "unknown_kid" | "keys_unavailable">` ist die hereingereichte Schlüsselsuche, `now` die Uhr in Millisekunden. Ergebnis `{ ok: true, sub } | { ok: false, reason }` mit `reason` genau aus `malformed|alg|unknown_kid|signature|iss|aud|expired|iat|nonce|keys_unavailable`. Die beiden Schlüssel-Gründe liefert die Suche, `verifyIdentityToken` reicht sie unverändert durch. Die Funktion wirft nie auf Eingabewerten; der Grund enthält nie Token-, `sub`- oder Apple-Text. Reihenfolge:

1. `malformed`: kein Text, nicht genau drei base64url-Segmente, Header oder Payload kein JSON-Objekt.
2. `alg`: `header.alg` ist nicht exakt `"RS256"`, geprüft vor jeder Schlüsselsuche.
3. Schlüsselsuche mit `header.kid` (fehlt er oder ist kein Text: `unknown_kid`); Antwort `unknown_kid`/`keys_unavailable` wird durchgereicht; ein JWK ohne `kty: "RSA"` oder mit gesetztem `alg` ≠ `"RS256"` gilt als `unknown_kid`.
4. `signature`: `createPublicKey({ key: jwk, format: "jwk" })` und `crypto.verify("sha256", …)` über `header.payload`; ein JWK, das sich nicht laden lässt, ebenfalls `signature`.
5. `iss` exakt `https://appleid.apple.com`.
6. `aud` ist ein Text und exakt ein Eintrag aus `config.clientIds` (kein Teilstring, kein Array).
7. `expired`: `exp` keine Zahl oder `exp * 1000 ≤ now − 60 000`.
8. `iat`: keine Zahl oder `iat * 1000 > now + 60 000`.
9. `nonce`: Der Dienst bekommt den Rohwert, verglichen wird dessen SHA-256 (hex) mit dem Claim per `timingSafeEqual`; fehlender oder nicht-Text-Claim, andere Länge oder Abweichung ist `nonce`.
10. `sub` nicht leerer Text, sonst `malformed`.

Kein `console`, kein `process.stdout`/`stderr`; jede Funktion ≤ 50 Zeilen (Parsen, Claims, Konfiguration je eigene Funktion).

### Festgelegt für S2b und S2c (keine ACs in diesem Schnitt)

- **S2b, JWKS-Cache** (`createJwks({ fetch, now, url? })`, liefert die Suche `keys`): TTL 1 h; unbekannter `kid` löst ein einmaliges Neuladen aus, höchstens alle 60 s; Abruf mit `AbortSignal.timeout(5000)`; misslungener Abruf (Ausnahme, Status ≠ 200, kein JSON, keine `keys`-Liste) behält den alten Cache; `keys_unavailable` nur, wenn kein Cache da ist oder er abgelaufen ist und das Neuladen misslang, sonst `unknown_kid`; Tests mit injiziertem `fetch` und `now`.
- **S2b, Tresor** (`apple-vault.ts`): Blob `[0x01 | iv 12 | tag 16 | ciphertext]`, AES-256-GCM, `iv = randomBytes(12)`, `account_id` als AAD; `decryptToken` gibt bei Manipulation, falschem Schlüssel, falschem Konto, falscher Version oder zu kurzem Blob `null`; `storeRefreshToken(pool, accountId, blob)` als Upsert in `apple_tokens`; Test gegen Wegwerf-Postgres (`server/scripts/test-local.sh`); der von `deleteAccount` zurückgegebene Blob muss entschlüsselbar sein.
- **S2c:** `clientSecret` (ES256 aus der .p8), `redeemCode`, `revokeToken` (Fehler melden, nie das Löschen verhindern).

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `node:crypto` (`createPublicKey`, `createPrivateKey`, `verify`, `createHash`, `timingSafeEqual`) | Standardbibliothek, **keine neuen Pakete** |
| `server/src/accounts.ts`, `server/migrations/`, `server/test/db.ts`, `server/src/main.ts` | bestehend, **unverändert**, von S2a nicht berührt |
| Apple JWKS | im Test durch Stub-Suche ersetzt; Abruf in S2b |
| Downstream | S2b (Cache, Tresor), S2c (Einlösen, Widerruf), S3 (HTTP-Rand), #621 (zweite Client-ID) |

## Acceptance Criteria

Alle Tests laufen im Prozess, ohne Port, ohne Netz und ohne Datenbank. Sie erzeugen ein eigenes RSA-2048-Paar, signieren Token selbst und setzen eine Stub-Suche und eine feste Uhr ein. Die Angriffsfälle stehen tabellengetrieben in einer Fallliste (Name, Token, erwarteter Grund), ein Fall je Zeile.

- **AC-1:** Konfiguration gültig: `loadAppleConfig` mit fünf gültigen Variablen liefert `teamId`, `keyId`, `clientIds` (aus `" a.b , c.d ,"` wird `["a.b", "c.d"]`), einen EC-P-256-`privateKey` (auch bei `\n` als Zeichenfolge im PEM) und `tokenKey` mit 32 Byte. Test: `server/test/apple.test.ts`, „config: gültige Umgebung“.
- **AC-2:** Konfiguration ungültig: `loadAppleConfig` wirft für jede der fünf Variablen, wenn sie fehlt oder leer ist, außerdem bei RSA-Schlüssel oder Müll in `APPLE_PRIVATE_KEY`, bei 31 oder 33 Byte oder Nicht-base64 in `APPLE_TOKEN_KEY` und bei nur Kommas in `APPLE_CLIENT_IDS`; der Fehlertext nennt den Variablennamen und enthält den übergebenen Wert nicht (Testwert `GEHEIM-123`). Test: `apple.test.ts`, „config: fehlend und ungültig“.
- **AC-3:** Gültiges Token: Ein korrekt signiertes Token (RS256, `kid` bekannt, `iss`, `aud` aus der Liste, `exp` in der Zukunft, `iat` jetzt, `nonce` = SHA-256-hex des Rohwerts, `sub` gesetzt) ergibt `{ ok: true, sub }` mit dem `sub` des Tokens, auch mit der zweiten Client-ID als `aud`, und auch, wenn das JWK kein `alg` trägt. Test: `apple.test.ts`, „verify: gültiges Token“.
- **AC-4:** Malformed: `undefined`, Zahl, leerer Text, zwei oder vier Segmente, Nicht-base64url-Zeichen, Header oder Payload als JSON-Array, `null` oder Text sowie ein gültig signiertes Token mit leerem oder fehlendem `sub` ergeben `malformed` und werfen nie. Test: `apple.test.ts`, „attack: malformed“ (Fallliste).
- **AC-5:** Angriff alg none: `alg: "none"` und `"NONE"`, auch mit leerer Signatur, ergeben `alg`, und die Schlüsselsuche wird nicht aufgerufen (Zähler 0). Test: `apple.test.ts`, „attack: alg none“.
- **AC-6:** Angriff HS256 mit öffentlichem Schlüssel: Ein HS256-Token, dessen HMAC mit dem öffentlichen Schlüssel als Secret gebildet ist, ergibt `alg`; die Fallliste hat zwei Zeilen, eine mit dem PEM-Text, eine mit den Modulus-Bytes. Test: `apple.test.ts`, „attack: HS256 mit öffentlichem Schlüssel“.
- **AC-7:** Angriff ES256: Ein ES256-Token mit gültiger Signatur eines eigenen EC-Schlüssels ergibt `alg`. Test: `apple.test.ts`, „attack: ES256“.
- **AC-8:** Kid und Schlüsselsuche: Liefert die Stub-Suche `unknown_kid`, ergibt das `unknown_kid`; liefert sie `keys_unavailable`, ergibt das `keys_unavailable`; ein Token ohne `kid` im Header ergibt `unknown_kid`. Test: `apple.test.ts`, „attack: kid und Schlüsselsuche“.
- **AC-9:** Angriff JWK mit fremdem alg oder kty: Liefert die Suche ein JWK mit `alg: "RS384"` oder `kty: "EC"`, ergibt ein sonst gültiges Token `unknown_kid`. Test: `apple.test.ts`, „attack: JWK mit fremdem alg oder kty“.
- **AC-10:** Angriff Signatur: Ein geändertes Zeichen in Payload oder Signatur und ein mit anderem RSA-Schlüssel signiertes Token mit dem `kid` des echten ergeben `signature`; ein nicht ladbares JWK (`n` leer) ebenfalls. Test: `apple.test.ts`, „attack: Signatur“.
- **AC-11:** Angriff iss: `iss` = `https://appleid.apple.com/`, `http://appleid.apple.com`, `https://evil.example` oder fehlend ergibt `iss`. Test: `apple.test.ts`, „attack: iss“.
- **AC-12:** Angriff aud: `aud` als Teilstring einer erlaubten ID, als Oberstring, als Array mit erlaubtem und fremdem Eintrag, als Array nur mit dem erlaubten Eintrag, in anderer Groß-/Kleinschreibung, fehlend oder als Zahl ergibt `aud`. Test: `apple.test.ts`, „attack: aud“.
- **AC-13:** Abgelaufen, Spielraum 60 s: `exp` = `now − 59 s` wird akzeptiert; `exp` = `now − 60 s`, `now − 1 h`, fehlend, als Text oder `NaN` ergibt `expired`. Test: `apple.test.ts`, „attack: abgelaufen“.
- **AC-14:** Angriff iat in der Zukunft: `iat` = `now + 60 s` wird akzeptiert; `now + 61 s`, `now + 1 d`, fehlend oder als Text ergibt `iat`. Test: `apple.test.ts`, „attack: iat“.
- **AC-15:** Nonce: Fehlender Claim, der Rohwert statt seines SHA-256, falscher Hash, Zahl oder Array als Claim, andere Länge und ein falsch übergebener Rohwert ergeben `nonce`; der richtige Rohwert ergibt `ok`. Test: `apple.test.ts`, „attack: nonce“.
- **AC-16:** Feste Gründe: Über alle Angriffsfälle ist `reason` immer einer der zehn Werte `malformed|alg|unknown_kid|signature|iss|aud|expired|iat|nonce|keys_unavailable`, jeder Wert kommt in mindestens einem Fall vor, und kein Grund enthält Teile des Tokens, des `sub` oder eines Apple-Textes. Test: `apple.test.ts`, „reasons: feste Liste“ (sammelt die Ergebnisse der Falllisten).
- **AC-17:** Stille: Während aller Aufrufe von `loadAppleConfig` (gültig und ungültig) und `verifyIdentityToken` (gültig und abgelehnt) wird nichts nach `console` oder `process.stdout`/`process.stderr` geschrieben (der Test ersetzt sie vorübergehend), und kein Fehlertext enthält Token, PEM, Schlüssel oder `sub`. Test: `apple.test.ts`, „silence“.
- **AC-18:** Regression, CI und Funktionslänge: Test: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, die bestehenden Testdateien bleiben unverändert; jede Funktion in `server/src/apple.ts` hat höchstens 50 Zeilen (Prüfung in der Validierung: `grep -nE "^(export )?(async )?function" server/src/apple.ts`, Abstand zweier Treffer und letzte Zeile ≤ 50).
- **AC-19:** Dateigrenze: Test: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple.ts`, `server/test/apple.test.ts` und `CLAUDE.md`; `server/package.json`, `server/package-lock.json`, `server/src/accounts.ts`, `server/src/main.ts`, `server/migrations/`, `server/test/db.ts`, `.github/workflows/`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple.ts` | CREATE | `loadAppleConfig`, `verifyIdentityToken` samt Hilfsfunktionen, ~+80 |
| `server/test/apple.test.ts` | CREATE | AC-1 bis AC-17, tabellengetrieben, ~+155 |
| `CLAUDE.md` | MODIFY | eine Zeile im Abschnitt `server/`: `src/apple.ts`, ~+1 |

### Estimated Changes

- Files: 3 (2 neu, 1 geändert).
- LoC: ≈ +236 gesamt, gezählt wie in Schnitt 1 (alles zusammen, Tests und Doku eingerechnet): Code ≈ 80, Tests ≈ 155, Doku ≈ 1. Limit ±250. Zeichnet sich eine Überschreitung ab, wird gestoppt und nachgefragt. Funktionen ≤ 50 Zeilen.
- Aufteilung gegenüber dem ersten Entwurf: Cache (`createJwks`) und Tresor (`apple-vault.ts`) wären zusammen bei ≈ 430 LoC gelandet und wandern nach S2b, Einlösen und Widerruf nach S2c.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, kein `generate`, keine Migration. Fünf Umgebungsvariablen werden erst von S3 beim Start gelesen (Betrieb: #796). Seiteneffekt außerhalb des Tickets: keiner; nichts ruft den Code auf.

## Risiken

- **Sicherheitskritisch:** `alg`-Verwechslung, `aud`-Teilstring und `kid`-Treffer auf Schlüssel mit anderem `alg`/`kty` sind je ein eigener Angriffsfall (AC-5 bis AC-12). Es gilt strikt nur RS256; Apples Doku nennt „E256“, das Live-JWKS (abgerufen 2026-11-03) liefert drei RSA-Schlüssel mit `alg` RS256. Fail-closed: Stellt Apple um, schlägt die Prüfung laut mit `alg` fehl.
- **Replay:** Ein vom Client mitgeschickter Rohnonce bindet Token und Anfrage, verhindert aber keinen Replay. Für S3 festgehalten: `/auth/token` liefert selbst ein `id_token`; mit derselben Funktion geprüft, ist der einmalige Authorization-Code der Replay-Schutz. Hier nicht gelöst.
- **Uhrabweichung:** `now` wird hereingereicht; 60 s Spielraum bei `exp` und `iat`.
- **Echtes Apple-Verhalten** offline nicht belegbar; echter Lauf mit S3/S4.
- **Betriebsrisiko für S2b/S2c:** `deleteAccount` löscht die Zeile vor dem Widerruf; fällt der Widerruf aus, ist der Token weg. Nach TN3194 als Best Effort zulässig, in der S2c-Spec zu nennen.

## Test Plan

### Automated Tests (TDD RED)

RED: Zuerst `apple.test.ts`; `apple.ts` fehlt, die Tests schlagen fehl.

- [ ] Test 1 (AC-1, AC-2): GIVEN fünf gültige Umgebungsvariablen bzw. je eine fehlende oder ungültige WHEN `loadAppleConfig` THEN Konfigurationsobjekt bzw. Fehler, der nur den Variablennamen nennt.
- [ ] Test 2 (AC-3, AC-4): GIVEN ein selbst signiertes Token und Stub-Suche WHEN `verifyIdentityToken` THEN `ok` mit `sub`; für Nicht-Token `malformed`.
- [ ] Test 3 (AC-5 bis AC-10): GIVEN Token mit alg none, HS256, ES256, unbekanntem kid, fremdem JWK, manipulierter Signatur WHEN geprüft THEN `alg`, `unknown_kid`, `keys_unavailable` bzw. `signature`; bei alg none ohne Aufruf der Suche.
- [ ] Test 4 (AC-11 bis AC-15): GIVEN falsches iss, aud als Teilstring und Array, abgelaufen (Grenze 60 s), iat in der Zukunft, nonce fehlt oder falsch WHEN geprüft THEN `iss`, `aud`, `expired`, `iat`, `nonce`.
- [ ] Test 5 (AC-16): GIVEN alle Ergebnisse der Falllisten WHEN gesammelt THEN nur die zehn festen Werte, jeder mindestens einmal, kein Token- oder Apple-Text.
- [ ] Test 6 (AC-17): GIVEN `console.*` und `process.stdout/stderr` vorübergehend ersetzt WHEN alle Aufrufe laufen THEN keine Ausgabe, kein Geheimnis im Fehlertext.
- [ ] Test 7 (AC-18, AC-19): GIVEN der fertige Zweig WHEN `./server/scripts/test-local.sh`, `server.yml` und `git diff --name-only origin/main -- . ':!docs' ':!.claude'` THEN grün, grün, genau die drei Dateien.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): `node:crypto` allein.** Keine neue Abhängigkeit auf dem sicherheitskritischen Pfad, jede Zeile testbar. Preis: `alg`-Bindung und (S2b) Cache selbst geschrieben.
- **B: `jose`.** Cache, `alg`-Bindung und Claims eingebaut. Dagegen: neue Abhängigkeit (Hennings Freigabe nötig); gebraucht werden nur RS256-Prüfung und in S2c die ES256-Signatur (~40 Zeilen). Nicht gewählt; kippt keine ADR, lässt sich später nachrüsten.
- **C: Verschlüsselung der Refresh-Token mit `pgcrypto`** (betrifft S2b): Der Schlüssel läge als SQL-Parameter vor (Logs, `pg_stat_statements`). Abgelehnt.
- **D: Refresh-Token nicht speichern** (betrifft S2b): unmöglich, der Code gilt einmal und etwa fünf Minuten; ohne Token kein Widerruf (TN3194).
- **E: Dienst gibt den Nonce aus** (einmalig, kurzlebig) statt Hash-Vergleich: echter Replay-Schutz, aber Tabelle und Endpunkt; falls gewollt, S3.
- **F: Schlüsselsuche hereinreichen statt `createJwks` hier einzubauen** (gewählt): hält den Schnitt im Limit und macht die Prüfung ohne Netz und Uhr testbar.

## Nicht in diesem Schnitt / Folgeschnitte

- S2b: JWKS-Cache (`createJwks`) und Tresor (`apple-vault.ts`, Upsert in `apple_tokens`), Festlegungen oben.
- S2c: `clientSecret`, `redeemCode`, `revokeToken`.
- S3 HTTP-Rand: `POST /auth/apple`, Bearer-Prüfung, `DELETE /account` mit Widerruf, Konfiguration beim Start.
- S4 App (nach #625); Merkposten S1 (Klartextprüfung in S1-AC-3); Datenschutztext (#625), Betrieb (#796), Connector (#621).

## Abnahme

- Reine Dienständerung, keine Oberfläche, kein Simulatorablauf sinnvoll. Nachweis: `./server/scripts/test-local.sh` (typecheck + test) grün und der CI-Job `server.yml` auf dem PR grün.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-19 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `src/apple.ts`
- [ ] #615 kommentiert (Stand Schnitt 2a, Folge S2b/S2c), Board-Karte aktuell

## Changelog

- 2026-11-03: Initial spec created (Schnitt 2a)
- 2026-11-03: Auf Token-Prüfung beschränkt (Limit 250 LoC inkl. Tests); Cache und Tresor nach S2b, Einlösen und Widerruf nach S2c; Datei umbenannt
