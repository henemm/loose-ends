# Adversary Dialog — feat-621-s4a-apple-web
Spec: docs/specs/feat-621-schnitt-4a-apple-web.md
Datum: 2026-11-06 09:23

## Checkliste
- [x] **AC-1:** Web-ID leer oder fehlend: GIVEN eine gültige Umgebung (`A_ENV`) WHEN `APPLE_WEB_CLIENT_ID` fehlt, `""` oder `"   "` ist THEN liefert `loadAppleConfig` eine Konfiguration mit `webClientId === undefined` und unveränderten `clientIds`, ohne Fehler. Test: „config: web-id leer“.
- [x] **AC-2:** Web-ID gültig: GIVEN eine gültige Umgebung WHEN `APPLE_WEB_CLIENT_ID=" com.henning.looseends.web "` (mit Blanks) THEN ist `webClientId === "com.henning.looseends.web"` (getrimmt) und `clientIds` enthält die Web-ID **nicht** (genau die Liste aus `APPLE_CLIENT_IDS`). Test: „config: web-id gültig und nicht in clientIds“.
- [x] **AC-3:** Web-ID ungültig: GIVEN eine gültige Umgebung WHEN `APPLE_WEB_CLIENT_ID` gleich einer Kennung aus `APPLE_CLIENT_IDS` ist (`com.henning.looseends`, auch mit Blanks außen) oder ein Komma enthält (`a.web,b.web`) THEN wirft `loadAppleConfig`, die Meldung enthält `APPLE_WEB_CLIENT_ID` und enthält den Wert nicht. Test: „config: web-id gleich app-id oder mit komma wirft“.
- [x] **AC-4:** Start-Abbruch mit allein gesetzter Web-ID: GIVEN `main()` als Kindprozess (Läufer aus `main.test.ts`, ohne andere `APPLE_*` der Umgebung) mit nur `APPLE_WEB_CLIENT_ID=com.henning.looseends.web` und gültigem `DATABASE_URL` WHEN gestartet THEN beendet er mit Exit-Code 1, die Ausgabe enthält `apple config invalid:` und den Namen einer der fünf Pflichtvariablen aus `APPLE_VARS` (welche, hängt von der Prüfreihenfolge in `loadAppleConfig` ab und wird nicht festgeschrieben), nicht den Wert der Web-ID, und es wurde weder Pool noch Port geöffnet; zusätzlich liefert `appleConfigFromEnv` mit nur dieser Variablen **nicht** `undefined`, sondern wirft. Test: „einhaengen: allein gesetzte web-id bricht start ab“ (in `main.test.ts`, bei „prozess bricht bei falscher config ab“).
- [x] **AC-5:** Web-Token am App-Weg standardmäßig abgelehnt: GIVEN ein gültig signiertes Identity-Token mit `aud = com.henning.looseends.web` und eine Konfiguration mit `clientIds = [com.henning.looseends]` und `webClientId` gesetzt WHEN `verifyIdentityToken` ohne `audiences` THEN `{ ok: false, reason: "aud" }`. Test: „verify: web-token ohne audiences abgelehnt“.
- [x] **AC-6:** Web-Token mit `audiences` angenommen: GIVEN dasselbe Token WHEN `verifyIdentityToken` mit `audiences: ["com.henning.looseends.web"]` THEN `{ ok: true, sub, aud: "com.henning.looseends.web" }`. Test: „verify: web-token mit audiences angenommen“.
- [x] **AC-7:** App-Token mit Web-Zielgruppe abgelehnt: GIVEN ein gültig signiertes Token mit `aud = com.henning.looseends` WHEN `verifyIdentityToken` mit `audiences: ["com.henning.looseends.web"]` THEN `{ ok: false, reason: "aud" }`; ohne `audiences` wird es wie bisher angenommen (`ok: true`, `aud: "com.henning.looseends"`). Test: „verify: app-token mit web-audiences abgelehnt, Standard unverändert“.
- [x] **AC-8:** `redeemCode` ohne `redirectUri`, App-Formular bytegleich: GIVEN eine Konfiguration mit App-ID WHEN `redeemCode(code, appId, { config, fetch, now })` ohne `redirectUri` THEN ist der gesendete Körper exakt `client_id=…&client_secret=…&code=…&grant_type=authorization_code` (gleiche Reihenfolge und Kodierung wie vor diesem Schnitt, kein `redirect_uri`). Test: „redeem: app-formular bytegleich ohne redirect_uri“.
- [x] **AC-9:** `redeemCode` mit `redirectUri`: GIVEN eine Konfiguration mit Web-ID WHEN `redeemCode(code, webId, { config, fetch, now, redirectUri: "https://loose-ends.test/oauth/apple/return" })` THEN enthält der Körper genau einmal `redirect_uri=https%3A%2F%2Floose-ends.test%2Foauth%2Fapple%2Freturn` zusätzlich zu den vier bekannten Feldern; `client_id` ist die Web-ID, das `client_secret` ist ein JWT mit `sub = webId`. Ein leerer `redirectUri` (`""`) wirft ohne Netzaufruf, die Meldung enthält keinen Wert. Test: „redeem: redirect_uri nur mit option, leer wirft“.
- [x] **AC-10:** `aud` des `id_token` für die Web-ID: GIVEN die Antwort von Apple (eingereichtes `fetch`) mit gültigem `id_token` WHEN `redeemCode` mit der Web-ID eingelöst wird THEN gelingt es nur bei `aud === webClientId` (`{ ok: true, refreshToken, sub }`); ein `id_token` mit `aud = App-ID` ergibt `{ ok: false, reason: "malformed_response" }`. Test: „redeem: id_token aud gleich web-id“.
- [x] **AC-11:** Web-ID bei `clientSecret`, `redeemCode`, `revokeToken` zugelassen, fremde ID weiter abgelehnt: GIVEN eine Konfiguration mit App- und Web-ID WHEN `clientSecret(config, webId, now)` THEN gültiges ES256-JWT mit `sub = webId`; `revokeToken(token, webId, …)` sendet `client_id = webId` und ein Secret mit `sub = webId`; WHEN `clientSecret`, `redeemCode` oder `revokeToken` mit einer fremden ID (`com.fremd.app`) THEN wirft jedes (`client id is not configured`, ohne den Wert in der Meldung), ohne Netzaufruf; ebenso mit der Web-ID bei einer Konfiguration **ohne** `webClientId`. Test: „client: web-id zugelassen, fremde id wirft“.
- [x] **AC-12:** `authorizeUrl` vollständig: GIVEN eine Konfiguration mit Web-ID WHEN `authorizeUrl(config, { redirectUri: "https://loose-ends.test/oauth/apple/return", state: "state-123", nonce: "roh-456" })` THEN beginnt die Adresse mit `https://appleid.apple.com/auth/authorize?`, und die geparsten Parameter sind genau `client_id=com.henning.looseends.web`, `redirect_uri=https://loose-ends.test/oauth/apple/return`, `response_type=code`, `response_mode=form_post`, `state=state-123`, `nonce=<SHA-256-Hex von "roh-456">` (64 Hexzeichen, gleich `createHash("sha256").update("roh-456").digest("hex")`); es gibt **keinen** Parameter `scope` und keine weiteren. Test: „authorizeUrl: parameter vollständig, ohne scope“.
- [x] **AC-13:** `authorizeUrl` Nonce passt zur Prüfung: GIVEN die Adresse aus AC-12 WHEN ein Identity-Token mit der `nonce` aus der Adresse als Claim gegen `verifyIdentityToken(token, "roh-456", { …, audiences: [webId] })` geprüft wird THEN `ok: true` (gleiche Hash-Form); mit anderem Rohwert `reason: "nonce"`. Test: „authorizeUrl: nonce passt zu verifyIdentityToken“.
- [x] **AC-14:** `authorizeUrl` wirft bei Fehlbedienung: WHEN die Konfiguration keine `webClientId` hat, oder `redirectUri`, `state` oder `nonce` leer ist (je ein Fall) THEN wirft sie; die Meldung nennt das Feld und enthält weder `state`, `nonce`, `redirectUri` noch die Web-ID als Wert. Test: „authorizeUrl: wirft ohne web-id und bei leeren feldern“.
- [x] **AC-15:** `appleReturnUrl`: tabellengetrieben WHEN `https://loose-ends.henemm.com` THEN `https://loose-ends.henemm.com/oauth/apple/return`; `https://loose-ends.henemm.com/` und `https://loose-ends.henemm.com/mcp?x=1` THEN dasselbe (Origin zählt); `http://localhost:8780` THEN `http://localhost:8780/oauth/apple/return`; `kein-url` und `""` THEN wirft, Meldung ohne den Wert. Test: „appleReturnUrl: origin plus fester pfad“.
- [x] **AC-16:** App-Weg unverändert: GIVEN alle bestehenden Tests in `apple.test.ts`, `apple-client.test.ts`, `auth.test.ts` und `main.test.ts` (ohne Änderung ihrer Erwartungen) WHEN `./server/scripts/test-local.sh` läuft THEN sind sie grün; zusätzlich lehnt `verifyIdentityToken` ohne `audiences` (genau der Aufruf, den `/auth/apple` in `auth.ts` unverändert macht) bei gesetzter `webClientId` ein Token mit `aud = webClientId` mit demselben Grund ab wie ein fremdes `aud`; damit antwortet `/auth/apple` darauf 401, ohne dass `auth.ts` geändert wird. Test: „auth: web-token am app-weg abgelehnt“ (in `apple.test.ts`; die bestehenden `auth`-Tests laufen unverändert mit).
- [x] **AC-17:** Keine Werte in Meldungen und im Log: GIVEN alle Fehlerfälle aus AC-3, AC-9, AC-11, AC-14 und AC-15 WHEN die Fehlermeldungen gesammelt werden THEN enthält keine die Web-ID, die App-ID, den Schlüssel (`APPLE_PRIVATE_KEY`, `APPLE_TOKEN_KEY`), `state`, `nonce`, `redirectUri` oder eine übergebene URL als Wert, und `console.*`, `process.stdout` und `process.stderr` bleiben in den Baustein-Tests stumm (Muster der bestehenden „silence“-Tests). Test: „silence: web-bausteine“.
- [x] **AC-18:** Gesamtlauf: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf; es gibt keinen neuen Eintrag in `server/package.json`. Dateigrenze und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Nachweis: `./server/scripts/test-local.sh`, CI `server.yml` und `/60-validate`.

## Dialog

### Runde 1
**Adversary:** Beweise je AC einfordern. Volle Suite `./server/scripts/test-local.sh` selbst gelaufen (Ausgabe: docs/artifacts/feat-621-s4a-apple-web/adversary-test-output.txt): typecheck gruen, 293 tests, 293 pass, 0 fail, 0 skipped.

Confirmation:
  AC: AC-1
  Code reference: server/src/apple.ts:44
  Evidence: webClientId() trimmt, leer/blank gibt undefined; Test "config: web-id leer" gruen (server/test/apple.test.ts:256)
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: server/test/apple.test.ts:264
  Evidence: getrimmt, clientIds unveraendert (kommt nicht in die Liste, apple.ts:40); Test gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: server/test/apple.test.ts:270
  Evidence: apple.ts:44-49 wirft bei Komma und bei Gleichheit mit App-ID; Meldung nennt nur APPLE_WEB_CLIENT_ID; eigener Lauf bestaetigt die Meldung "must differ from APPLE_CLIENT_IDS" ohne Wert
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: server/src/main.ts:36
  Evidence: APPLE_VARS enthaelt APPLE_WEB_CLIENT_ID, damit wirft appleConfigFromEnv bei alleiniger Web-ID (main.ts:40); Kindprozess-Test server/test/main.test.ts:499 gruen (Exit 1, "apple config invalid:", kein Wert)
  Status: CONFIRMED

Confirmation:
  AC: AC-5, AC-6, AC-7, AC-16
  Code reference: server/src/apple.ts:107
  Evidence: audiences ?? config.clientIds; claimsReason (apple.ts:68) prueft nur gegen die uebergebene Liste. Tests apple.test.ts:284, 288, 292, 298 gruen; auth.ts laut git diff origin/main unveraendert (0 Zeilen Diff, ebenso package.json)
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: server/src/apple-client.ts:100
  Evidence: redirect_uri wird als letztes Feld nur bei gesetzter Option angehaengt, Reihenfolge der vier Altfelder unveraendert; Test apple-client.test.ts:358 vergleicht den Koerper als Zeichenfolge; eigener Lauf: client_id=..&client_secret=X&code=c&grant_type=authorization_code
  Status: CONFIRMED

Confirmation:
  AC: AC-9, AC-10, AC-11
  Code reference: server/src/apple-client.ts:27
  Evidence: clientSecret laesst App- oder Web-ID zu, sonst "client id is not configured" ohne Wert; redeemCode wirft bei leerem redirectUri vor dem Netzaufruf (apple-client.ts:93-95); idTokenSub prueft aud === clientId (apple-client.ts:47). Tests apple-client.test.ts:364, 377, 382 gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-12, AC-13, AC-14
  Code reference: server/src/apple-client.ts:123
  Evidence: URLSearchParams mit genau sechs Parametern, kein scope, nonce = SHA-256-Hex; Pflichtfeldpruefung ohne Werte in der Meldung. Tests apple-client.test.ts:399, 411, 420 gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-15
  Code reference: server/src/apple-client.ts:136
  Evidence: new URL(publicUrl).origin + fester Pfad, ungueltige URL wirft ohne Wert; Test apple-client.test.ts:430 gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-17
  Code reference: server/test/apple-client.test.ts:440
  Evidence: Test "silence: web-bausteine" sammelt alle Fehlermeldungen (collect) und prueft Stille von console/stdout/stderr; gruen
  Status: CONFIRMED

Confirmation:
  AC: AC-18
  Code reference: server/src/apple-client.ts:123
  Evidence: test-local.sh Exit 0, 293/293; geaenderte Dateien unter server/ genau die sechs der Spec (git diff origin/main --name-only); package.json ohne Diff; alle Funktionen deutlich unter 50 Zeilen (redeemCode ca. 18, authorizeUrl 12, loadAppleConfig kurz)
  Status: CONFIRMED

**Implementierer:** (nicht beteiligt, Kontext-Isolation)

Early-Agreement-Skepsis: Runde 1 ist komplett gruen; deshalb folgt Runde 2 mit aktivem Brechen statt Zustimmung.

### Runde 2
**Adversary:** Wegwerf-Skript im Scratchpad (probe.ts / p1.ts) gegen die echten Quellen, Ergebnisse:

1. Bytegleiches App-Formular: Koerper `client_id=com.a&client_secret=X&code=c&grant_type=authorization_code`, Web-Weg haengt `&redirect_uri=https%3A%2F%2Fx%2Fr` hinten an. Kein Bruch.
2. Web-ID per Gross/Kleinschreibung in clientIds? `APPLE_WEB_CLIENT_ID=COM.A` (App-ID `com.a`) wird angenommen (exakter Vergleich, wie die Spec festlegt), landet nicht in clientIds. Auf dem App-Weg bleibt die Web-ID wirkungslos, da aud exakt verglichen wird. Kein Defekt, nur Hinweis H1.
3. Web-ID mit Blanks aussen: getrimmt; gleiche Kennung wie App-ID mit Blanks wirft (Test AC-3). Kennung mit Blank innen ("x y") wird akzeptiert, Spec schweigt, Hinweis H1.
4. `audiences: []`: `[] ?? clientIds` bleibt `[]` (?? greift nur bei null/undefined), includes ist false, also lehnt jede aud ab (fail-closed), kein Rueckfall auf den Standard (apple.ts:107). Gut.
5. redirectUri nur aus Blanks: redeemCode und authorizeUrl akzeptieren "   " (Koerper `redirect_uri=+++`). Spec verlangt nur Ablehnung von "" (AC-9, AC-14); Hinweis H2.
6. authorizeUrl mit Sonderzeichen: state `a b&c=d#é+/` wird korrekt als `a+b%26c%3Dd%23%C3%A9%2B%2F` kodiert, redirect_uri `https%3A%2F%2Fx%2Fy%3Fa%3Db%26c`. Kein Bruch.
7. appleReturnUrl: Benutzer/Passwort entfallen (`https://h.example:8443/oauth/apple/return`), Standardport faellt weg, Host klein. Aber `javascript:`, `file:` und `data:` liefern `null/oauth/apple/return`, `ftp://h/` liefert `ftp://h/oauth/apple/return`; kein Wurf. AC-15 nennt nur ungueltige URLs als Wurf; die publicUrl wird in main.ts vorher durch publicUrlFromEnv auf https oder localhost-http begrenzt. Hinweis H3, kein Defekt.
8. Werte in Fehlermeldungen: alle Messages sind feste Zeichenfolgen (apple.ts:44-49, apple-client.ts:27-29, 93-95, 123-128, 136-138); kein Wert interpoliert, nur Feldnamen. Kein console.* in den Bausteinen.
9. redeemCode mit null als redirectUri wirft ("redirectUri must not be empty"), undefined verhaelt sich wie nicht gesetzt.
10. Bestehende Tests: git diff origin/main zeigt in server/test nur geaenderte Importzeilen und den Konfigurations-Aufbau (keine geaenderten Erwartungen); auth.ts und package.json ohne Diff.
11. Nebenlaeufigkeit/Zustand: alle neuen Funktionen sind rein, ohne gemeinsamen Zustand; nichts ruft sie auf (grep: nur Tests nutzen authorizeUrl/appleReturnUrl).

Hinweise (ausserhalb der Spec, kein BROKEN):
  H1 (LOW, edge_case) server/src/apple.ts:44 Web-ID wird nur exakt, nicht klein/gross-unabhaengig und ohne Formpruefung verglichen; spec-konform ("exakter Vergleich").
  H2 (LOW, edge_case) server/src/apple-client.ts:93 und :125 blanke redirectUri wird nicht als leer behandelt; Apple wuerde sie ablehnen, S4b liefert sie aus appleReturnUrl.
  H3 (LOW, edge_case) server/src/apple-client.ts:136 appleReturnUrl wirft nicht bei Nicht-http(s)-Schema (origin "null"); durch publicUrlFromEnv vorgelagert abgefangen.

**Implementierer:** (nicht beteiligt)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Confirmation:
  AC: AC-4 (Kindprozess-Test)
  Code reference: server/test/main.test.ts:499
  Evidence: Test startet main() als Kindprozess mit nur APPLE_WEB_CLIENT_ID, Exit 1, Ausgabe ohne Wert
  Status: CONFIRMED

## Verdict

VERDICT: VERIFIED

Tests: 293 passed, 0 failed, 0 uebersprungen (docs/artifacts/feat-621-s4a-apple-web/adversary-test-output.txt)
Edge cases: geprueft, keine Spec-Verletzung; drei LOW-Hinweise H1 bis H3
Regressions: keine (auth.ts, package.json unveraendert; Altfaelle unveraendert gruen)
Checklist: 18/18 points proven

## Geprüfte Dateien

- sha256:0cb9e46213da96c65eff5246cf8a7201f80abba3ed3b94bad5d70e9302ebcef9  server/src/apple-client.ts
- sha256:60b650d7b2f89e059c7a8dcc2df63e98bc749ec856642c86d37a12a46cb5113e  server/src/apple.ts
- sha256:228b616032a93267dec084cd93c34e377442bf09ecde967f32083c87aa5d58d9  server/src/main.ts
- sha256:38e936da06cfdd541265d8bc964359311c2808ede74463193fa095985fe458e1  server/test/apple-client.test.ts
- sha256:672adc9959d7a6cba37fa625889416786b9545e98ea7381e09285ce975e15130  server/test/apple.test.ts
- sha256:ebb1147dcfb353b929b317816d722b8e5db2e480c4c169bc7465fab02a20969f  server/test/main.test.ts

## Prüfbasis

- base: fedc9e983b31ee4d3c0770598d4ff42b853bac57
- blob:021c55753c9e0de4415468a27e8188cee0ab244b  server/src/apple-client.ts
- blob:224d90294d604f93a6950e712c1806bf02b8e393  server/src/apple.ts
- blob:8101246423bb1a400a8f772ddb083f8fb238a542  server/src/main.ts
- blob:f8c47a869f13d528c7b5496eda96fdf66c728df0  server/test/apple-client.test.ts
- blob:bac4483eaa925efce0718f58740f91c7bb0f2da7  server/test/apple.test.ts
- blob:8fcaca40017a1b3805cd5242e828f658761cfc25  server/test/main.test.ts
