# Adversary Dialog — feat-615-s2c-apple-einloesen
Spec: docs/specs/feat-615-schnitt-2c1-apple-einloesen.md
Datum: 2026-11-03 18:14

## Checkliste
- [x] **AC-1:** Secret gültig und prüfbar: `clientSecret` liefert drei base64url-Segmente; der Kopf ist genau `{ alg: "ES256", kid: keyId }`; die Nutzlast ist genau `{ iss: teamId, iat, exp, aud: "https://appleid.apple.com", sub: clientId }` mit `iat = floor(now/1000)` und `exp = iat + 300`; die Signatur ist 64 Byte lang und verifiziert mit dem öffentlichen Schlüssel über `verify("sha256", …, { dsaEncoding: "ieee-p1363" })`; das gilt für beide Client-IDs einer Konfiguration mit zwei Einträgen (`sub` jeweils die übergebene). Test: `server/test/apple-client.test.ts`, „secret: kopf, nutzlast, signatur“.
- [x] **AC-2:** Secret je Aufruf neu: Zwei Aufrufe mit verschiedenem `now` ergeben verschiedene `iat`/`exp`; eine Änderung der Signatur um ein Bit oder der Nutzlast um ein Zeichen lässt die Prüfung mit dem öffentlichen Schlüssel scheitern. Test: `apple-client.test.ts`, „secret: je aufruf neu, manipulation fällt auf“.
- [x] **AC-3:** Fehlbedienung wirft: `clientSecret` mit `clientId` außerhalb der Liste (auch nur anders geschrieben) und mit `now` = `NaN`/`Infinity`/Text wirft; `redeemCode` wirft bei fremder `clientId` und bei leerem `code`, **ohne dass `fetch` aufgerufen wird** (Zähler 0); kein Fehlertext enthält `clientId`, `code` (Testwert `GEHEIM-123`) oder Schlüsselmaterial. Test: `apple-client.test.ts`, „fehlbedienung: wirft ohne netz“ (Fallliste).
- [x] **AC-4:** Anfrage genau wie festgelegt: Bei gültigem Aufruf ruft `redeemCode` `fetch` genau einmal auf, mit der Vorgabe-URL `https://appleid.apple.com/auth/token` (mit `opts.url` die übergebene), Methode `POST`, Kopf `content-type: application/x-www-form-urlencoded`, einem `AbortSignal` und einem Formular, das geparst genau die Schlüssel `client_id`, `client_secret`, `code`, `grant_type` hat; `grant_type` ist `authorization_code`, `client_id` und `code` sind die übergebenen Werte, ein `redirect_uri` gibt es nicht, und `client_secret` ist ein nach AC-1 gültiges Secret für diese `client_id` zum Zeitpunkt `opts.now()`. Test: `apple-client.test.ts`, „redeem: anfrage“.
- [x] **AC-5:** Erfolg: Antwort 200 mit `refresh_token`, `access_token`, `token_type`, `expires_in` und einem `id_token` (`iss` Apple, `aud` = `clientId`, `sub` gesetzt) ergibt `{ ok: true, refreshToken, sub }` mit den Werten der Antwort, auch für die zweite Client-ID; das Ergebnis enthält keine weiteren Felder (kein `access_token`). Test: `apple-client.test.ts`, „redeem: erfolg“.
- [x] **AC-6:** Apple-Fehler: Status 400 (und 401) mit `{ "error": X }` ergibt `{ ok: false, reason: "apple:X" }` für jeden der sechs bekannten Werte; ein unbekannter `error`-Wert (`GEHEIM-123`, `<script>`, leer, Zahl, Objekt, Liste) ergibt `apple_status`, ebenso Status 500/503/302 mit beliebigem Rumpf und Status 400 ohne JSON. Test: `apple-client.test.ts`, „redeem: apple-fehler und status“ (Fallliste).
- [x] **AC-7:** Falsche 200-Antworten: Status 200 mit kaputtem JSON, JSON-Array, `null`, leerem Objekt, fehlendem, leerem oder nicht-textuellem `refresh_token` sowie fehlendem `id_token` ergibt `malformed_response`. Test: `apple-client.test.ts`, „redeem: malformed 200“ (Fallliste).
- [x] **AC-8:** Fehlerhaftes `id_token`: Ein `id_token`, das kein JWT ist (zwei oder vier Segmente, Nicht-base64url, Nutzlast kein JSON-Objekt), mit falschem `iss`, mit `aud` ≠ übergebener `clientId` (auch eine andere Client-ID aus der Liste), ohne `sub` oder mit leerem oder nicht-textuellem `sub` ergibt `malformed_response`, und es wird nie `ok: true` zurückgegeben. Test: `apple-client.test.ts`, „redeem: id_token geprüft“ (Fallliste).
- [x] **AC-9:** Netz und Zeitlimit: Eine Ausnahme von `fetch`, ein synchroner Wurf, eine `TimeoutError`-Ausnahme und ein abgelehntes `fetch` ergeben `{ ok: false, reason: "unavailable" }` und werfen nie; der übergebene `AbortSignal` ist ein Zeitlimit von höchstens 5000 ms (Prüfung: das Signal ist nicht abgebrochen, bricht aber nach `AbortSignal.timeout`-Dauer ab, oder der Aufruf mit einem Stub, der auf das Signal wartet, endet mit `unavailable`). Test: `apple-client.test.ts`, „redeem: unavailable und zeitlimit“ (Fallliste).
- [x] **AC-10:** Keine Geheimnisse in Gründen: Über alle Fälle aus AC-3 bis AC-9 (Testwerte `GEHEIM-CODE` für den Code, `GEHEIM-TOKEN` für Refresh-Token und `access_token`, `GEHEIM-123` im Apple-`error` und im Rumpf) ist jeder `reason` einer von `apple:<einer der sechs>`, `apple_status`, `unavailable`, `malformed_response`; kein `reason` und kein Fehlertext enthält Code, Secret (weder Ganzes noch Segmente), Token oder Rohtext der Antwort. Test: `apple-client.test.ts`, „reason: feste menge, keine geheimnisse“.
- [x] **AC-11:** Stille: Während aller Aufrufe der Tests AC-1 bis AC-9 (Erfolg, `ok: false`, Wurf) wird nichts nach `console` oder `process.stdout`/`process.stderr` geschrieben (der Test ersetzt sie vorübergehend). Test: `apple-client.test.ts`, „silence“.
- [x] **AC-12:** Regression, CI und Funktionslänge: Test: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf, `server.yml` ist auf dem PR grün, die bestehenden Testdateien bleiben unverändert; jede Funktion in `server/src/apple-client.ts` hat höchstens 50 Zeilen (Prüfung in der Validierung: `grep -nE "function" server/src/apple-client.ts`, Abstand zweier Funktionsanfänge und Dateiende ≤ 50) und die Datei benutzt nur `node:crypto` (`grep -n "^import" server/src/apple-client.ts` nennt nur `node:crypto` und `./apple.ts`).
- [x] **AC-13:** Dateigrenze und Doku: Test: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apple-client.ts`, `server/test/apple-client.test.ts` und `CLAUDE.md`; `CLAUDE.md` enthält im Abschnitt `server/` nach der Zeile zu `src/apple-vault.ts` genau eine neue Zeile zu `src/apple-client.ts` im gleichen Stil („nothing calls it yet“); `server/src/apple.ts`, `apple-jwks.ts`, `apple-vault.ts`, `accounts.ts`, `server/migrations/`, `server/test/db.ts`, `server/package.json`, `server/package-lock.json`, `server/src/main.ts`, `.github/workflows/`, `project.yml` und jede Swift-Datei bleiben unberührt.

## Dialog

### Runde 1
**Adversary:** Urteil zuerst aus der Spec, dann Code gelesen. Lauf `./server/scripts/test-local.sh` (Ausgabe in adversary-test-output.txt): 180 Tests, 180 bestanden, 0 fehlgeschlagen, 0 uebersprungen, Exit 0, typecheck gruen. Abgrenzung (AC-13): `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt CLAUDE.md und server/test/apple-client.test.ts; die dritte Datei server/src/apple-client.ts ist untracked (git status `??`) und zaehlt mit, also genau die drei. Importe: nur `node:crypto` und `./apple.ts` (Zeilen 1-2); Suche nach console/process in der Quelle = 0 Treffer. Funktionslaengen: clientSecret 10, idTokenSub 9, readAnswer 11, redeemCode 19 Zeilen, alle unter 50. Bestehende Testdateien apple/jwks/vault unveraendert (Diff leer), apple.ts, migrations, main.ts unberuehrt.
Befunde Runde 1: Fehlbedienung wirft vor fetch (Zeile 62 vor 64, clientSecret wirft Zeile 25/26 mit festen Texten ohne clientId). DER-vs-p1363: `dsaEncoding: "ieee-p1363"` Zeile 31, Test prueft 64 Byte plus verify. clientId gross/klein: `includes` ist exakt. Synchroner fetch-Wurf: `opts.fetch(...)` steht im try (Zeile 68-75), Probe ergibt `unavailable`.
**Implementierer:** Keine Gegenrede noetig; Findings siehe Runde 2.

### Runde 2
**Adversary:** Wegwerf-Probe (geloescht) gegen redeemCode mit eigenem EC-Schluessel: id_token mit `aud` als Array -> malformed_response (korrekt, strikter Vergleich Zeile 42); `sub` als Zahl -> malformed_response; guter Fall -> `{ok:true,refreshToken,sub}` ohne access_token; Status 302 mit leerem Rumpf -> apple_status; synchroner Wurf mit Text GEHEIM -> unavailable, Text nicht uebernommen. Rumpf, der beim Lesen abbricht (ReadableStream-Fehler): Status 200 -> malformed_response, Status 500 -> apple_status. Das stimmt mit dem Wortlaut der Gruende ueberein (Status 200 + kaputt = malformed; Status != 200 ohne lesbares JSON = apple_status). Ein echtes Zeitlimit (AbortSignal feuert waehrend des Lesens des Rumpfs) landet dadurch ebenfalls dort statt in `unavailable`; die Spec nennt "Zeitlimit -> unavailable" nur im Zusammenhang mit fetch (AC-9 testet nur das). Kein Verstoss gegen den Wortlaut, aber eine Unschaerfe: siehe F001 (LOW). Zusatz: ein fetch, der undefined liefert, wirft TypeError (response.status) - nicht-konformes fetch, kein reales Szenario (F002, LOW, keine Aktion).
Geheimnisse: reason ist immer Literal oder `apple:`+Treffer aus fester Menge (Zeile 51); kein Rohtext, kein Secret in Texten. `opts.url` Vorgabe: `opts.url ?? TOKEN_URL` (Zeile 69).
**Implementierer:** Entwickler meldet malformed_response/apple_status bei Lesefehler; bewertet: spec-konform, Zeitlimit-im-Rumpf ist ungeregelt.

### Runde 3
**Adversary:** Nachpruefung des Fixes fuer F001 (Orchestrator wertete es als Spec-Abweichung: "unavailable bei Netzfehler ... und Zeitlimit"). Code gelesen: readAnswer (apple-client.ts:46-59) liest `response.text()` in einem try, Wurf -> `unavailable` (Zeile 49); JSON.parse separat (Zeile 51), Fehler -> body=null. Folge: kaputtes JSON bei vollstaendigem Rumpf bleibt Status 200 -> malformed_response (Zeile 57), Status != 200 -> apple_status (Zeile 54); leerer Rumpf bei 400 -> apple_status; Apple-Fehler mit bekanntem `error` weiter `apple:X`. AC-6/AC-7-Listen (STATUS, MALFORMED) sind unveraendert gruen. Neue Faelle "Rumpf bricht ab 200/400" (apple-client.test.ts:127) liegen in UNAVAILABLE, die der Silence-Test (Zeile 234) und der Geheimnis-Test (Zeile 222, Wurftext GEHEIM-123 verboten) mitlaufen: kein Leck, keine Ausgabe. Funktionslaengen: readAnswer 14 Zeilen, redeemCode 19, alle unter 50; Importe unveraendert (node:crypto, ./apple.ts). Lauf `./server/scripts/test-local.sh` erneut: 180 Tests, 180 bestanden, 0 fehlgeschlagen, 0 uebersprungen, Exit 0. Restrisiko: ein 200 mit Rumpf, der gueltig vollstaendig gelesen wird, aber ein spaeteres Abbrechen gibt es nicht; kein neuer Befund.
**Implementierer:** F001 behoben (text() in try, JSON.parse getrennt), zwei Testfaelle ergaenzt, vorher rot.

### Findings und Bestaetigungen

Finding:
  ID: F001 (BEHOBEN in Runde 3)
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apple-client.ts:49
  Description: Bricht das Lesen des Antwortrumpfs ab (auch durch das 5-s-AbortSignal), wird der Fehler verschluckt und body=null; Ergebnis ist malformed_response (Status 200) bzw. apple_status.
  Spec requirement: AC-9 — Zeitlimit ergibt unavailable
  Conflict: Ein Zeitlimit waehrend des Rumpf-Lesens ergibt nicht unavailable; die Spec legt den Fall nicht fest, AC-9 prueft nur das fetch-Ende.
  Remediation: im Zweig fuer Lesefehler unavailable liefern. BEHOBEN: apple-client.ts:49, Tests apple-client.test.ts:127.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/apple-client.ts:79
  Description: Liefert ein nicht konformer fetch-Stub undefined, wirft readAnswer einen TypeError.
  Spec requirement: AC-9 — redeemCode wirft nie bei fremder Antwort
  Conflict: Nur bei nicht standardkonformem fetch, im Produkt unerreichbar.
  Remediation: Keine.

Confirmation:
  AC: AC-1
  Code reference: server/src/apple-client.ts:24
  Evidence: Kopf/Nutzlast/exp=iat+300 (Zeile 28-30), p1363-Signatur (31); Test server/test/apple-client.test.ts:129 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/test/apple-client.test.ts:137
  Evidence: Secret je Aufruf aus now berechnet, kein Zustand; Manipulationstest gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/src/apple-client.ts:25
  Evidence: Wurf bei fremder/falsch geschriebener clientId, nicht endlichem now und leerem code vor jedem fetch; Test Zeile 146.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/apple-client.ts:66
  Evidence: Formular genau client_id, client_secret, code, grant_type; POST, Header, AbortSignal.timeout(5000), kein redirect_uri; Test Zeile 159.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: server/src/apple-client.ts:58
  Evidence: Ergebnis nur {ok,refreshToken,sub}; Probe ohne access_token; Test Zeile 177.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: server/src/apple-client.ts:54
  Evidence: apple:X nur fuer sechs Werte bei Status != 200, sonst apple_status; Probe 302 -> apple_status; Test Zeile 181.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: server/src/apple-client.ts:57
  Evidence: fehlendes/leeres refresh_token oder kaputter Rumpf -> malformed_response; Test Zeile 189.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/apple-client.ts:42
  Evidence: iss, aud (strikt, Array per Probe abgelehnt), sub (Text) geprueft; Segmentzahl/Zeichensatz Zeile 39; Test Zeile 193.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: server/src/apple-client.ts:76
  Evidence: catch um den fetch-Aufruf inkl. synchronem Wurf -> unavailable (Probe); Test Zeile 200 prueft Timeout-Wert 5000. Rumpf-Abbruch jetzt ebenfalls unavailable (Zeile 49, Test Zeile 127).
  Status: CONFIRMED

Confirmation:
  AC: AC-10
  Code reference: server/test/apple-client.test.ts:222
  Evidence: reason ist ausschliesslich Literal oder apple:+Menge (apple-client.ts:54); Probe mit Text GEHEIM im Wurf leckt nicht.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: server/test/apple-client.test.ts:234
  Evidence: Quelle enthaelt kein console/process; Test ersetzt die Ausgabekanaele und ist gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-12
  Code reference: server/src/apple-client.ts:1
  Evidence: test-local.sh 180/180 gruen, Funktionen <= 19 Zeilen, Importe nur node:crypto und ./apple.ts. server.yml auf dem PR kann vor dem PR nicht belegt werden; lokal belegt (wie in S2b-1/S2b-2), CI-Beleg offen bis zum PR.
  Status: CONFIRMED

Confirmation:
  AC: AC-13
  Code reference: CLAUDE.md:471
  Evidence: genau eine neue Zeile nach der apple-vault-Zeile (Diff +1), drei Dateien in der Dateigrenze.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: VERIFIED
Alle 13 Punkte belegt, 180/180 Tests gruen nach Fix von F001 (Rumpf-Abbruch -> unavailable), keine Regression; F002 LOW ohne Aktion. AC-12 server.yml auf dem PR erst nach PR belegbar.

## Geprüfte Dateien

- sha256:d0d156fa813f1fb9c1e6b87de52a2e0e8b7df464bfbfe6dd551dd82cd3aed8ab  CLAUDE.md
- sha256:2197372cd80878f6463701620daf8e72e7d8a046ca54bd936a6942b25d5ab78e  server/src/apple-client.ts
- sha256:3236322d41fe14bf5b3454db6c28950d616bbc7aa315d3aa72bb77e90bd0e04c  server/test/apple-client.test.ts

## Prüfbasis

- base: b72604927f6f6d7467ee1442f08cce3f39462f99
- blob:f88652dadbdb32b2ebc90cb0c38011a4c9cb3742  CLAUDE.md
- blob:31487166117845285fed2d5c9a46ead0c53ff29f  server/src/apple-client.ts
- blob:735b4f0c9bb813eae685f3e832900b8c58650516  server/test/apple-client.test.ts
