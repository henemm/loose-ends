# Adversary Dialog — feat-795-s5a2-apns-absender
Spec: docs/specs/feat-795-schnitt-5a2a-apns-absender.md
Datum: 2026-11-14 08:00

## Checkliste
- [x] **AC-1:** Konfiguration, Fälle ohne Fehler: GIVEN eine Umgebung ohne `APNS_*` (auch nur Leerraum) WHEN `apnsConfigFromEnv` THEN `undefined`; GIVEN alle vier Variablen gültig (Schlüssel als PEM, auch mit `\n` als Text) THEN eine Config mit `teamId`, `keyId`, `topic` und einem `KeyObject` vom Typ `ec`. Test: „apns: config alles oder nichts“.
- [x] **AC-2:** Konfiguration, Fehlerfälle: GIVEN jede echte Teilmenge der vier Variablen (je eine fehlt) und je ein ungültiger Schlüssel (kein PEM, RSA-Schlüssel, andere EC-Kurve) WHEN `apnsConfigFromEnv` THEN wirft es einen `Error`, dessen Text genau den Namen der fehlenden oder ungültigen Variable enthält und weder den Wert des Schlüssels noch von Team, Schlüssel-ID oder Topic. Test: „apns: config alles oder nichts“.
- [x] **AC-3:** Anbieter-Token: GIVEN eine Config und eine feste Uhr WHEN der erste Sendevorgang eines Wakers den Token erzeugt THEN hat der `authorization`-Kopf der Anfrage die Form `bearer <Kopf>.<Inhalt>.<Signatur>`, der Kopf ist `{alg: "ES256", kid: <keyId>}`, der Inhalt `{iss: <teamId>, iat: <Sekunden der Uhr>}` ohne weitere Schlüssel, und die Signatur ist 64 Byte lang (`ieee-p1363`) und prüft mit dem öffentlichen Schlüssel (`verify` mit `dsaEncoding: "ieee-p1363"`). Test: „apns: anbieter-jwt“.
- [x] **AC-4:** Cache und Erneuerung: GIVEN ein Waker und eine verstellbare Uhr WHEN mehrere `wake`-Aufrufe bei +0, +19 und +49 Minuten laufen THEN tragen alle denselben Token (gleicher `iat`); WHEN ein Aufruf bei +50 Minuten läuft THEN trägt er einen neuen Token (`iat` = Zeit der Uhr), und der nächste Aufruf bei +60 Minuten (10 Minuten später) trägt wieder diesen neuen Token. Test: „apns: jwt cache und erneuerung“.
- [x] **AC-5:** `ExpiredProviderToken`: GIVEN ein Stub, der beim ersten Versuch 403 mit `reason: "ExpiredProviderToken"` antwortet WHEN (a) der Cache-Token mindestens 20 Minuten alt ist THEN genau ein Wiederholversuch mit einem **neu erzeugten** Token (anderer `iat`), bei Erfolg des zweiten Versuchs nichts gelöscht und nichts geloggt; WHEN (b) der Cache-Token jünger als 20 Minuten ist THEN **kein** Wiederholversuch (genau ein `send`-Aufruf), `apns send failed` einmal, nichts gelöscht; WHEN (c) zwei Geräte gleichzeitig 403 `ExpiredProviderToken` bekommen und der Token mindestens 20 Minuten alt ist THEN wird er genau einmal erneuert und beide Wiederholversuche tragen denselben neuen Token; WHEN (d) auch der Wiederholversuch 403 `ExpiredProviderToken` antwortet THEN gibt es keinen dritten Versuch (je Gerät höchstens zwei `send`-Aufrufe), `apns send failed`, nichts gelöscht. Test: „apns: expiredprovidertoken genau ein wiederholversuch“.
- [x] **AC-6:** Anfrage: GIVEN ein Konto mit je einem Gerät in `sandbox` und `production` und ein Stub-`send` WHEN `wake(account)` THEN bekommt der Stub genau zwei Aufrufe, einen mit Ursprung `https://api.sandbox.push.apple.com` und einen mit `https://api.push.apple.com`, jeweils mit dem Token der Zeile (Pfad `/3/device/<token>`), dem Topic der Config und dem Körper, der als JSON genau `{"aps":{"content-available":1},"looseends":{"v":1}}` entspricht; die Köpfe, die `sendHttp2` setzt, sind `apns-push-type: background`, `apns-priority: 5`, `content-type: application/json` (belegt in AC-11). Test: „apns: anfrage kopfzeilen und koerper“.
- [x] **AC-7:** Ungültige Tokens löschen: GIVEN ein Konto mit mehreren Geräten WHEN der Stub für ein Gerät 410 `Unregistered`, für ein zweites 400 `BadDeviceToken`, für ein drittes 400 `DeviceTokenNotForTopic` und für ein viertes 200 antwortet THEN sind die ersten drei Zeilen in `device_tokens` weg, die vierte und die Zeilen anderer Konten bleiben; je gelöschtem Token wird `apns token dropped` geloggt. Test: „apns: ungueltige tokens loeschen“.
- [x] **AC-8:** Alles andere löscht nichts: GIVEN je ein Gerät WHEN der Stub antwortet mit 500, 503, 429, 403 mit anderem Grund, 400 mit anderem Grund (z. B. `PayloadEmpty`), 410 ohne `reason`, 400 ohne `reason`, einem abgelehnten Aufruf (Netzfehler) oder einem Zeitlimit-Fehler THEN bleibt jede Zeile in `device_tokens` stehen und je Fall wird `apns send failed` genau einmal geloggt; ein Gerät mit 200 wird nicht geloggt. Ein Fehler eines Geräts hindert das Senden an die anderen nicht (alle Geräte werden angefragt). Test: „apns: andere fehler loeschen nichts“.
- [x] **AC-9:** `wake` wirft nie: GIVEN (a) ein Pool, dessen `query` wirft, (b) ein `send`, das synchron wirft, (c) ein `send`, das ablehnt, (d) ein `log`, das wirft, (e) ein Konto ohne Geräte, (f) ein Anbieter-Token, das nicht erzeugt werden kann (Uhr liefert `NaN`) WHEN `await wake(account)` THEN resolved es jeweils ohne Fehler, es gibt keine unbehandelte Ablehnung (Handler auf `process.on("unhandledRejection")` bleibt leer), bei (e) wird `send` nie aufgerufen, bei (f) wird `apns jwt failed` geloggt und `send` nie aufgerufen. Test: „apns: wake wirft nie“.
- [x] **AC-10:** Log: GIVEN alle Fehler- und Löschfälle aus AC-5 bis AC-9 mit Tokens, Konto-ID und Apple-Gründen als erkennbaren Wörtern WHEN `wake` läuft THEN ist jede an `log` übergebene Zeichenkette genau eine von `apns send failed`, `apns token dropped`, `apns jwt failed`, und keine geloggte Zeichenkette enthält ein Token, die Konto-ID, den Grund der Antwort oder einen Fehlertext; zusätzlich bleibt `console.error`/`console.log` (Spion) über den ganzen Lauf leer. Test: „apns: log nur feste namen“.
- [x] **AC-11:** Transport, Rahmung: GIVEN ein lokaler `node:http2`-Server ohne TLS (h2c, über die Option `origins` als Ursprung für beide Umgebungen) WHEN `sendHttp2` eine Anfrage sendet THEN sieht der Server Methode `POST`, Pfad `/3/device/<token>`, die Köpfe `authorization`, `apns-topic`, `apns-push-type: background`, `apns-priority: 5` und den Körper wie in AC-6, und die Antwort `{status, reason}` entspricht dem Status und dem `reason` im JSON-Körper der Serverantwort (ohne Körper: kein `reason`); WHEN der Server nie antwortet THEN lehnt der Aufruf nach dem Zeitlimit ab (Test mit einem kurzen, über eine Option gesetzten Limit) und der Server sieht danach keine offene Sitzung; WHEN der Server die Sitzung hart schließt THEN lehnt der Aufruf ab, ohne unbehandeltes Ereignis. TLS wird nicht geprüft; der echte Weg gegen Apple folgt in S5b. Test: „apns: http2 rahmung“.
- [x] **AC-12:** Gerätetokens lesen und löschen: GIVEN zwei Konten mit Geräten WHEN `listTokens(pool, A)` THEN genau die Zeilen von A als `{token, environment}`, nach `device` aufsteigend, keine von B, leere Liste für ein Konto ohne Geräte; WHEN `dropToken(pool, token, environment)` mit passender Umgebung THEN `true` und genau diese Zeile ist weg; WHEN die Umgebung nicht passt, das Token unbekannt ist oder das Gerät das Token inzwischen mit `putDevice` gegen ein neues getauscht hat THEN `false` und `device_tokens` ist unverändert; ein großgeschriebenes Token trifft die Zeile ebenfalls. Test: „apns: listtokens und droptoken“.
- [x] **AC-13:** Nichts verdrahtet: `server/src/mcp.ts`, `server/src/main.ts`, `server/src/orders.ts` und `server/src/app-routes.ts` enthalten die Zeichenfolge `apns` nicht, und keine Datei in `server/src/` außer `apns.ts` importiert `./apns.ts`. **Kein dauerhafter Test**, weil Schnitt 2b genau diese Verdrahtung herstellt und der Test dort wieder fallen müsste: Beleg einmalig in `/60-validate` per `grep -il apns server/src/*.ts` (Ausgabe genau `server/src/apns.ts`) im Validierungsprotokoll.
- [x] **AC-14:** Grenze und Länge: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/apns.ts`, `server/src/devices.ts`, `server/test/apns.test.ts` und höchstens `CLAUDE.md`; `mcp.ts`, `main.ts`, `orders.ts`, `app-routes.ts`, `.github/`, `project.yml`, `server/package.json` und jede Swift-Datei sind unverändert (keine neue Abhängigkeit); jede Funktion hat höchstens 50 Zeilen. **Kein dauerhafter Test** (ein Test gegen `origin/main` scheitert im flachen CI-Checkout): Beleg einmalig in `/60-validate`, Befehl, Ausgabe und Funktionslängen im Validierungsprotokoll (festes Vorgehen seit S1 AC-17, Ausnahme vom Tech Lead bestätigt).

## Dialog

### Runde 1
**Adversary:** Testlauf `./server/scripts/test-local.sh` (Ausgabe in adversary-test-output.txt): Typecheck gruen, 433 tests, 433 pass, 0 fail, 0 skipped. Alle elf apns-Tests und der listtokens-Test laufen (Zeilen 32-42 der Ausgabe). Halbe Wege geprueft: der AC-8-Test (apns.test.ts:136-145) sendet in zwei Teilen (1-5, 6-11) wegen MAX_DEVICES=10 und assertiert `s.calls.length === envs.length`, jeder Fall wird also wirklich gesendet; der AC-10-Test (apns.test.ts:168-187) assertiert `s.calls.map(nr)` = 1..13, also alle 10 Fehler- und 3 Loeschfaelle gesendet. Mutationsblick: dropToken ohne Umgebung braeche apns.test.ts:232, ein zweiter Wiederholversuch AC-5d (Zeile 109-110), Erneuerung bei <20 min AC-5b (Zeile 104-105).
Code-Lesung: apns.ts:21-35 Konfig (Fehlertexte nur Variablenname, Leerraum = nicht gesetzt, RSA/andere Kurve abgewiesen); apns.ts:39-43 JWT ieee-p1363, NaN-Uhr wirft; apns.ts:94-100 providerToken (50 min, 20 min Untergrenze, anderer Cache-Token ohne Erneuerung; bei gleichzeitigen 403 sieht der zweite `cached.jwt !== rejected` und verwendet den neuen); apns.ts:88-127 wake ganz in try/catch, log in eigenem try/catch (Zeile 90), je Geraet eigenes try/catch (Zeile 105-116), allSettled; apns.ts:111 nur die drei DROP-Paare loeschen, "410 undefined" nicht in DROP; devices.ts:51-54 listTokens ORDER BY device, devices.ts:57-60 dropToken mit token+environment im WHERE, lower().
AC-13: `grep -il apns server/src/*.ts` liefert genau server/src/apns.ts; `grep -n apns mcp.ts main.ts orders.ts app-routes.ts` leer; devices.ts enthaelt kein "apns". AC-14: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` = server/src/devices.ts, server/test/apns.test.ts; dazu untracked server/src/apns.ts (noch nicht committet, per `git status --short`); CLAUDE.md, package.json, mcp/main/orders/app-routes, .github, project.yml unveraendert; laengste Funktion createWaker 41 Zeilen, sendHttp2 26, putDevice 26; apns.ts 128 Zeilen (unter 150), apns.test.ts 236 Zeilen (ueber der Meldeschwelle 200, im Changelog der Spec als Tech-Lead-Entscheidung angenommen).
**Implementierer:** (nicht beteiligt, Kontextisolation) Keine Einwaende.

### Runde 2
**Adversary:** Eigene Wegwerf-Probe (nicht im Repo) gegen den echten `sendHttp2`: Verbindung abgelehnt -> reject (ECONNREFUSED); ungueltige/leere Ursprungs-URL -> reject "Invalid URL" (synchroner connect-Wurf wird im async-Rumpf zur Ablehnung); Server antwortet nur mit Kopf 200 ohne Ende -> reject "apns timeout"; Antwortkoerper `null` -> `{status:400}` ohne reason, kein Absturz; Stream-RST -> reject "apns stream closed"; GOAWAY vor Antwort -> reject per Zeitlimit. In keinem Fall unhandledRejection oder uncaughtException. Weitere Bohrungen im Code: (1) Timer im finally geloescht, Sitzung immer destroy (apns.ts:67-70). (2) providerToken: Uhr rueckwaerts -> Cache-Token bleibt; Grenzen exakt 20 min / 50 min sind `<` und damit "mindestens" wie die Spec. (3) Zweite now()-Auswertung im Wiederholversuch (apns.ts:108) liegt im aeusseren try; ein Wurf gibt genau einmal `apns send failed`. (4) 403 ohne Wiederholversuch loggt genau einmal (`return log`). (5) Geheimnisse: Fehlertexte von apnsConfigFromEnv nennen nur Variablennamen; auch verschluesselter oder oeffentlicher PEM faellt in den catch ohne Wert. (6) Kleinschreibung: dropToken lowercased, listTokens liefert gespeicherte Kleinschreibung. (7) Datenbankfehler im dropToken (apns.ts:112) -> catch -> `apns send failed`, wake bleibt resolved. Keine Luecke gefunden, die eine Spec-Zeile verletzt.
Beobachtungen ohne Spec-Verstoss (LOW, nicht blockierend): (a) Ein vom Aufrufer gestelltes `send` ohne eigenes Zeitlimit koennte `wake` haengen lassen; der Standardtransport hat 5 s. (b) Bei GOAWAY ohne Antwort dauert die Ablehnung bis zum 5-s-Limit. (c) apns.test.ts hat 236 Zeilen > 200 Meldeschwelle; im Changelog der Spec als Tech-Lead-Entscheidung angenommen (Produktcode 128 < 150).
**Implementierer:** (nicht beteiligt) Keine Einwaende.

### Bestaetigungen
Confirmation:
  AC: AC-1
  Code reference: server/src/apns.ts:21
  Evidence: nichts oder Leerraum -> undefined, alle vier -> ec-Config, `\n` als Text wird ersetzt (Test apns.test.ts:51-65)
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: server/src/apns.ts:24
  Evidence: je fehlende Variable und je ungueltiger Schluessel wirft Error mit nur dem Namen (apns.ts:29,32; Test apns.test.ts:58-64)
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: server/src/apns.ts:39
  Evidence: JWT-Kopf/Inhalt/64-Byte-Signatur ieee-p1363, Test prueft verify (apns.test.ts:67-75)
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: server/src/apns.ts:94
  Evidence: Cache 0/19/49 gleich, 50 neu, 60 wieder neu (apns.test.ts:77-85)
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: server/src/apns.ts:108
  Evidence: Faelle a-d in apns.test.ts:87-111, genau ein Wiederholversuch, gleichzeitige 403 erneuern einmal (apns.ts:95)
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: server/src/apns.ts:106
  Evidence: Ursprung je Umgebung, Topic, Koerper (apns.ts:12-13; Test apns.test.ts:113-120)
  Status: CONFIRMED
Confirmation:
  AC: AC-7
  Code reference: server/src/apns.ts:111
  Evidence: nur die drei DROP-Paare loeschen und loggen `apns token dropped` (apns.ts:18,112-113; Test apns.test.ts:122-128)
  Status: CONFIRMED
Confirmation:
  AC: AC-8
  Code reference: server/src/apns.ts:114
  Evidence: alle anderen Antworten und Fehler -> `apns send failed`, nichts geloescht; alle 10 Faelle werden wirklich gesendet (apns.test.ts:136-145)
  Status: CONFIRMED
Confirmation:
  AC: AC-9
  Code reference: server/src/apns.ts:120
  Evidence: wake in try/catch, log gekapselt (apns.ts:90), Faelle a-f in apns.test.ts:147-166 inkl. unhandledRejection-Waechter
  Status: CONFIRMED
Confirmation:
  AC: AC-10
  Code reference: server/src/apns.ts:90
  Evidence: nur drei feste Namen, console-Spion leer (apns.test.ts:168-187; alle 13 Faelle gesendet)
  Status: CONFIRMED
Confirmation:
  AC: AC-11
  Code reference: server/src/apns.ts:46
  Evidence: h2c-Server sieht Koepfe/Koerper, Zeitlimit, offene Sitzung 0, harter Abbruch rejected (apns.test.ts:189-225) plus eigene Probe
  Status: CONFIRMED
Confirmation:
  AC: AC-12
  Code reference: server/src/devices.ts:52
  Evidence: listTokens nach device, dropToken nur Token+Umgebung, Grossschreibung (devices.ts:57-60; Test apns.test.ts:227-236)
  Status: CONFIRMED
Confirmation:
  AC: AC-13
  Code reference: server/src/devices.ts:51
  Evidence: grep -il apns server/src/*.ts = server/src/apns.ts; mcp/main/orders/app-routes ohne apns
  Status: CONFIRMED
Confirmation:
  AC: AC-14
  Code reference: server/test/apns.test.ts:1
  Evidence: Dateiliste wie gefordert (apns.ts noch untracked), keine Paketaenderung, Funktionen <= 41 Zeilen
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
The implementation withstood adversary testing.
Tests: 433 passed, 0 failed, 0 uebersprungen
Edge cases: All checked (Token-Cache, Wiederholversuch, wake wirft nie, Logs, Transport-Fehlerwege), none broken
Regressions: None found
Checklist: 14/14 points proven
Findings: keine (nur LOW-Beobachtungen in Runde 2, nicht blockierend)

## Geprüfte Dateien

- sha256:046108030ca5063f6205071056a1c6e25c542684f2f08c68fb3d2109e831af75  server/src/apns.ts
- sha256:a33141f0d06eee33a8d917dba787d57280b27ae76e16b23860f52134d974e5c6  server/src/devices.ts
- sha256:947b39d941e0eeda2ebd9499a8eecdb3be878389df965039d3641c1bd819ad43  server/test/apns.test.ts

## Prüfbasis

- base: 92e8ab7970263177bae543486eac463224c2c1a2
- blob:b0f7e2bccfe0acb337b6d04ea283b293acd6eacd  server/src/apns.ts
- blob:8015fffb7d1cac6bb9f879447acf85c40fce7417  server/src/devices.ts
- blob:8549f7218d7d68f5837fb677b04ee072462318f8  server/test/apns.test.ts
