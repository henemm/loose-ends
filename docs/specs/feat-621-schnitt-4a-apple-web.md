---
entity_id: feat-621-schnitt-4a-apple-web
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-621-s4a-apple-web
---

# Spec: Apple-Web-Anmeldung, Bausteine (Schnitt 4a, #621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 4a; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-s4a-apple-web.md` (Abschnitte „Recherche“, „Analysis“, „Alternativen“); Schnittplan: `docs/context/feat-621-mcp-anmeldung.md`. Vorgänger: #615 S2a (`server/src/apple.ts`), #615 S2c-1/S2c-2 (`server/src/apple-client.ts`), #621 S3 (Aussteller, Interaction-Einhängepunkt). Folge: S4b (`oauth-login.ts`).

## Für den PO

Damit du Claude später im Browser mit Loose Ends verbinden kannst, musst du dich dabei mit Apple anmelden, so wie du es heute in der App tust. Für den Browser verlangt Apple eine eigene „Eintrittskarte“ (eine sogenannte Services ID) und eine feste Rücksprungadresse. Dieser Schnitt legt im Dienst die Bausteine dafür bereit: die Adresse, die dich zu Apple schickt, die Rücksprungadresse und das Einlösen des Ergebnisses mit der Browser-Eintrittskarte statt der App-Kennung. Die Anmeldung der App bleibt dabei unangetastet; ein Token aus dem Browser wird dort weiterhin nicht angenommen.

Für dich ändert sich **nichts Sichtbares**, die App und der laufende Dienst verhalten sich wie vorher: Diese Bausteine werden in diesem Schnitt noch von nichts aufgerufen. Erst der nächste Schnitt (S4b) setzt daraus die eigentliche Anmeldung zusammen. Zu entscheiden hast du nichts. Merken solltest du dir einen Folgeschritt vor dem Einschalten (S6): Die Services ID muss einmal in deinem Apple-Entwicklerkonto angelegt werden. Das geht nur im Portal, nicht per Programm; du meldest dich dort an, die Klicks danach übernehme ich im Browser-Tab.

## Purpose

Der Dienst bekommt die reinen Bausteine des Apple-Web-Ablaufs (OAuth-Code-Flow von „Sign in with Apple“ für das Web), ohne sie irgendwo einzuhängen:

- eine optionale Services ID (`APPLE_WEB_CLIENT_ID`) neben den App-Kennungen,
- die Prüfung des Identity-Tokens gegen eine wählbare Zielgruppe (`aud`),
- das Einlösen des Codes mit `redirect_uri` und mit der Web-Kennung,
- die Autorisierungs-Adresse (`authorizeUrl`) und die Rücksprungadresse (`appleReturnUrl`).

S4b (`server/src/oauth-login.ts`: Interaction → Apple → Rückweg → `findOrCreate` → `interactionFinished`) nutzt sie. Der App-Weg (`/auth/apple`, #615) bleibt bytegleich in seinem Verhalten.

**Regeln vor Modell:** Protokoll- und Konfigurationsarbeit ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Festlegungen aus der Analyse (Recherche 2026-11-06, Quellen im Kontextdokument):

- **Eigene Variable für die Web-ID, nicht in `APPLE_CLIENT_IDS`.** Stünde die Services ID dort, nähme `/auth/apple` auch ein Web-Token an.
- **`response_mode=form_post`, `response_type=code`, kein `scope`.** Der Code steht so nie in einer URL (nginx-Zugriffslog, Verlauf, Referrer); Name und E-Mail braucht der Dienst nicht (`apple_sub` reicht, #615).
- **Rückweg `<publicUrl-Origin>/oauth/apple/return`**, unter `/oauth/` und damit im Zuständigkeitsbereich des Ausstellers (`isIssuerPath`); diese Adresse wird im Apple-Konto als Return-URL eingetragen.
- **`redirect_uri` beim Einlösen nur, wenn sie beim Autorisieren gesendet wurde** (Apple: „only if the application provided a redirect_uri in the initial authorization request“, dann identisch). Der App-Weg sendet keine, der Web-Weg muss sie senden.
- **Nonce:** Wie im App-Weg erwartet `verifyIdentityToken` den SHA-256-Hex des Rohwerts im Token; `authorizeUrl` schickt genau diesen Hash als `nonce` mit.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt den Plan aus dem ADR-21-Nachtrag (Schnitt 4: Apple in der Interaction des Ausstellers) um; keine neue Abhängigkeit, keine neue Grundsatzentscheidung.

**Rationale:** Die Aufteilung in Bausteine (S4a) und Zusammenbau (S4b) hält jeden Schnitt prüfbar: S4a ist rein (eingereichtes `fetch` und `now`, kein Netz in Tests), S4b braucht Zustand in der Datenbank und den Rückweg im Aussteller.

## Source

**Files:** `server/src/apple.ts` (ändern), `server/src/apple-client.ts` (ändern), `server/src/main.ts` (ändern, eine Zeile), `server/test/apple.test.ts` (ändern), `server/test/apple-client.test.ts` (ändern), `server/test/main.test.ts` (ändern, ein Fall).
**Identifier:** `AppleConfig.webClientId`, `verifyIdentityToken` (Option `audiences`), `redeemCode` (Option `redirectUri`), `authorizeUrl`, `appleReturnUrl`, `APPLE_WEB_CLIENT_ID`

### Schnittstelle

- **`server/src/apple.ts`**
  - `AppleConfig` bekommt `webClientId?: string`.
  - `loadAppleConfig(env)` liest zusätzlich die optionale Variable `APPLE_WEB_CLIENT_ID` (getrimmt). Fehlt sie oder ist sie leer/blank → `webClientId` ist `undefined` (der Schlüssel fehlt im Objekt oder ist `undefined`; kein Fehler). Gesetzt und gleich einer Kennung aus `APPLE_CLIENT_IDS` (nach Trimmen, exakter Vergleich) oder mit Komma darin → wirft; die Meldung nennt nur den Variablennamen (`APPLE_WEB_CLIENT_ID …`), nie den Wert. Die Web-ID kommt **nicht** in `clientIds`.
  - `verifyIdentityToken(token, rawNonce, opts)`: `opts` bekommt die optionale Zielgruppenliste `audiences?: string[]`. Ohne die Option gilt unverändert `config.clientIds`; mit ihr muss `aud` in genau dieser Liste stehen (und nur dort). Bestehende Aufrufer (`auth.ts`) ändern sich nicht. `claimsReason` bekommt die Liste als Parameter statt `config.clientIds` direkt zu lesen.
- **`server/src/apple-client.ts`**
  - `clientSecret(config, clientId, now)`, `redeemCode(code, clientId, opts)` und `revokeToken(token, clientId, opts)` akzeptieren als `clientId` jede Kennung aus `config.clientIds` **oder** `config.webClientId`; jede andere wirft wie bisher (`client id is not configured`, ohne Wert). Die Prüfung des `aud` im `id_token` in `redeemCode` (`idTokenSub`) vergleicht gegen die übergebene `clientId`, für die Web-ID gilt also `aud === webClientId`.
  - `redeemCode` bekommt die Option `redirectUri?: string`. Gesetzt: `redirect_uri` steht im Formular (nach `grant_type`); nicht gesetzt: das Formular ist bytegleich wie heute (App-Weg). Eine leere Zeichenfolge als `redirectUri` gilt als Fehlbedienung und wirft (Meldung ohne Wert), statt still ohne zu senden.
  - Neu `authorizeUrl(config, { redirectUri, state, nonce }): string`: baut `https://appleid.apple.com/auth/authorize?…` mit `client_id` = `config.webClientId`, `redirect_uri`, `response_type=code`, `response_mode=form_post`, `state` und `nonce` = SHA-256-Hex des übergebenen Rohwerts (dieselbe Hash-Form, die `verifyIdentityToken` erwartet). Kein `scope`. Wirft bei fehlendem `config.webClientId` und bei leerem `redirectUri`, `state` oder `nonce`; Meldungen nennen nur das Feld, nie einen Wert.
  - Neu `appleReturnUrl(publicUrl: string): string` = `<origin der publicUrl>/oauth/apple/return`. `publicUrl` ist die einzige Wahrheit (nie Host-Header); ein Pfad, Query oder Schrägstrich am Ende der `publicUrl` ändert das Ergebnis nicht. Eine ungültige URL wirft (Meldung ohne Wert).
- **`server/src/main.ts`**: `APPLE_WEB_CLIENT_ID` kommt in `APPLE_VARS`. Damit gilt eine allein gesetzte Web-ID als „teilweise gesetzt“ und der Start bricht mit `apple config invalid: …` und dem Variablennamen der fehlenden Pflichtvariable ab, statt still ohne Apple zu laufen. Sonst keine Änderung.

### Festlegungen

- **Nichts davon wird in S4a aufgerufen.** Weder `main.ts` noch `auth.ts` noch der Aussteller nutzen `authorizeUrl`, `appleReturnUrl`, `redirectUri` oder `audiences`.
- **Keine Werte in Meldungen:** weder Web-ID, Schlüssel, `state`, `nonce` noch `redirectUri`; kein `console.*` in den Bausteinen.
- **Der laufende Dienst ändert sein Verhalten nicht**, solange `APPLE_WEB_CLIENT_ID` fehlt; die App-Anmeldung nimmt Web-Token auch mit gesetzter Variable nicht an.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; Test-Stil wie bisher (`node:test`, `node:assert/strict`, eingereichtes `fetch`, kein Netz).
- **Unberührt:** `auth.ts`, `oauth-provider.ts`, `oauth-resource.ts`, `accounts.ts`, `mcp.ts`, `apple-jwks.ts`, `apple-vault.ts`, Migrationen, jede Swift-Datei, `.github/`, nginx und Compose in `henemm-infra`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `AppleConfig`/`loadAppleConfig`, `clientSecret`, `redeemCode`, `revokeToken`, `verifyIdentityToken` | bestehend, erweitert (Standardverhalten unverändert) |
| `node:crypto` (`createHash`) | bestehend (Node), keine neue Abhängigkeit |
| Tests: bestehende Helfer in `apple.test.ts`, `apple-client.test.ts`, `main.test.ts` (`A_ENV`, Kindprozess-Läufer) | bestehend |
| Downstream | S4b (`oauth-login.ts` nutzt `authorizeUrl`, `appleReturnUrl`, `redeemCode` mit `redirectUri`, `verifyIdentityToken` mit `audiences: [webClientId]`); S6 (`APPLE_WEB_CLIENT_ID` in Compose, nginx lässt `/oauth/*` durch) |
| Einmalig im Apple-Konto (vor S6, nicht für S4a) | Services ID anlegen, mit `com.henning.looseends` verbinden, Domain `loose-ends.henemm.com` und Return-URL `https://loose-ends.henemm.com/oauth/apple/return` eintragen; kein API-Weg, keine Datei-Verifikation mehr nötig |

## Acceptance Criteria

Tests in `server/test/apple.test.ts`, `server/test/apple-client.test.ts` und `server/test/main.test.ts` mit `node:test` und `node:assert/strict`; tabellengetrieben, ein Fall je Zeile; Apple wird nie erreicht (eingereichtes `fetch`). Als Web-ID dient `com.henning.looseends.web`, als App-ID `com.henning.looseends`.

- **AC-1:** Web-ID leer oder fehlend: GIVEN eine gültige Umgebung (`A_ENV`) WHEN `APPLE_WEB_CLIENT_ID` fehlt, `""` oder `"   "` ist THEN liefert `loadAppleConfig` eine Konfiguration mit `webClientId === undefined` und unveränderten `clientIds`, ohne Fehler. Test: „config: web-id leer“.
- **AC-2:** Web-ID gültig: GIVEN eine gültige Umgebung WHEN `APPLE_WEB_CLIENT_ID=" com.henning.looseends.web "` (mit Blanks) THEN ist `webClientId === "com.henning.looseends.web"` (getrimmt) und `clientIds` enthält die Web-ID **nicht** (genau die Liste aus `APPLE_CLIENT_IDS`). Test: „config: web-id gültig und nicht in clientIds“.
- **AC-3:** Web-ID ungültig: GIVEN eine gültige Umgebung WHEN `APPLE_WEB_CLIENT_ID` gleich einer Kennung aus `APPLE_CLIENT_IDS` ist (`com.henning.looseends`, auch mit Blanks außen) oder ein Komma enthält (`a.web,b.web`) THEN wirft `loadAppleConfig`, die Meldung enthält `APPLE_WEB_CLIENT_ID` und enthält den Wert nicht. Test: „config: web-id gleich app-id oder mit komma wirft“.
- **AC-4:** Start-Abbruch mit allein gesetzter Web-ID: GIVEN `main()` als Kindprozess (Läufer aus `main.test.ts`, ohne andere `APPLE_*` der Umgebung) mit nur `APPLE_WEB_CLIENT_ID=com.henning.looseends.web` und gültigem `DATABASE_URL` WHEN gestartet THEN beendet er mit Exit-Code 1, die Ausgabe enthält `apple config invalid:` und den Namen einer der fünf Pflichtvariablen aus `APPLE_VARS` (welche, hängt von der Prüfreihenfolge in `loadAppleConfig` ab und wird nicht festgeschrieben), nicht den Wert der Web-ID, und es wurde weder Pool noch Port geöffnet; zusätzlich liefert `appleConfigFromEnv` mit nur dieser Variablen **nicht** `undefined`, sondern wirft. Test: „einhaengen: allein gesetzte web-id bricht start ab“ (in `main.test.ts`, bei „prozess bricht bei falscher config ab“).
- **AC-5:** Web-Token am App-Weg standardmäßig abgelehnt: GIVEN ein gültig signiertes Identity-Token mit `aud = com.henning.looseends.web` und eine Konfiguration mit `clientIds = [com.henning.looseends]` und `webClientId` gesetzt WHEN `verifyIdentityToken` ohne `audiences` THEN `{ ok: false, reason: "aud" }`. Test: „verify: web-token ohne audiences abgelehnt“.
- **AC-6:** Web-Token mit `audiences` angenommen: GIVEN dasselbe Token WHEN `verifyIdentityToken` mit `audiences: ["com.henning.looseends.web"]` THEN `{ ok: true, sub, aud: "com.henning.looseends.web" }`. Test: „verify: web-token mit audiences angenommen“.
- **AC-7:** App-Token mit Web-Zielgruppe abgelehnt: GIVEN ein gültig signiertes Token mit `aud = com.henning.looseends` WHEN `verifyIdentityToken` mit `audiences: ["com.henning.looseends.web"]` THEN `{ ok: false, reason: "aud" }`; ohne `audiences` wird es wie bisher angenommen (`ok: true`, `aud: "com.henning.looseends"`). Test: „verify: app-token mit web-audiences abgelehnt, Standard unverändert“.
- **AC-8:** `redeemCode` ohne `redirectUri`, App-Formular bytegleich: GIVEN eine Konfiguration mit App-ID WHEN `redeemCode(code, appId, { config, fetch, now })` ohne `redirectUri` THEN ist der gesendete Körper exakt `client_id=…&client_secret=…&code=…&grant_type=authorization_code` (gleiche Reihenfolge und Kodierung wie vor diesem Schnitt, kein `redirect_uri`). Test: „redeem: app-formular bytegleich ohne redirect_uri“.
- **AC-9:** `redeemCode` mit `redirectUri`: GIVEN eine Konfiguration mit Web-ID WHEN `redeemCode(code, webId, { config, fetch, now, redirectUri: "https://loose-ends.test/oauth/apple/return" })` THEN enthält der Körper genau einmal `redirect_uri=https%3A%2F%2Floose-ends.test%2Foauth%2Fapple%2Freturn` zusätzlich zu den vier bekannten Feldern; `client_id` ist die Web-ID, das `client_secret` ist ein JWT mit `sub = webId`. Ein leerer `redirectUri` (`""`) wirft ohne Netzaufruf, die Meldung enthält keinen Wert. Test: „redeem: redirect_uri nur mit option, leer wirft“.
- **AC-10:** `aud` des `id_token` für die Web-ID: GIVEN die Antwort von Apple (eingereichtes `fetch`) mit gültigem `id_token` WHEN `redeemCode` mit der Web-ID eingelöst wird THEN gelingt es nur bei `aud === webClientId` (`{ ok: true, refreshToken, sub }`); ein `id_token` mit `aud = App-ID` ergibt `{ ok: false, reason: "malformed_response" }`. Test: „redeem: id_token aud gleich web-id“.
- **AC-11:** Web-ID bei `clientSecret`, `redeemCode`, `revokeToken` zugelassen, fremde ID weiter abgelehnt: GIVEN eine Konfiguration mit App- und Web-ID WHEN `clientSecret(config, webId, now)` THEN gültiges ES256-JWT mit `sub = webId`; `revokeToken(token, webId, …)` sendet `client_id = webId` und ein Secret mit `sub = webId`; WHEN `clientSecret`, `redeemCode` oder `revokeToken` mit einer fremden ID (`com.fremd.app`) THEN wirft jedes (`client id is not configured`, ohne den Wert in der Meldung), ohne Netzaufruf; ebenso mit der Web-ID bei einer Konfiguration **ohne** `webClientId`. Test: „client: web-id zugelassen, fremde id wirft“.
- **AC-12:** `authorizeUrl` vollständig: GIVEN eine Konfiguration mit Web-ID WHEN `authorizeUrl(config, { redirectUri: "https://loose-ends.test/oauth/apple/return", state: "state-123", nonce: "roh-456" })` THEN beginnt die Adresse mit `https://appleid.apple.com/auth/authorize?`, und die geparsten Parameter sind genau `client_id=com.henning.looseends.web`, `redirect_uri=https://loose-ends.test/oauth/apple/return`, `response_type=code`, `response_mode=form_post`, `state=state-123`, `nonce=<SHA-256-Hex von "roh-456">` (64 Hexzeichen, gleich `createHash("sha256").update("roh-456").digest("hex")`); es gibt **keinen** Parameter `scope` und keine weiteren. Test: „authorizeUrl: parameter vollständig, ohne scope“.
- **AC-13:** `authorizeUrl` Nonce passt zur Prüfung: GIVEN die Adresse aus AC-12 WHEN ein Identity-Token mit der `nonce` aus der Adresse als Claim gegen `verifyIdentityToken(token, "roh-456", { …, audiences: [webId] })` geprüft wird THEN `ok: true` (gleiche Hash-Form); mit anderem Rohwert `reason: "nonce"`. Test: „authorizeUrl: nonce passt zu verifyIdentityToken“.
- **AC-14:** `authorizeUrl` wirft bei Fehlbedienung: WHEN die Konfiguration keine `webClientId` hat, oder `redirectUri`, `state` oder `nonce` leer ist (je ein Fall) THEN wirft sie; die Meldung nennt das Feld und enthält weder `state`, `nonce`, `redirectUri` noch die Web-ID als Wert. Test: „authorizeUrl: wirft ohne web-id und bei leeren feldern“.
- **AC-15:** `appleReturnUrl`: tabellengetrieben WHEN `https://loose-ends.henemm.com` THEN `https://loose-ends.henemm.com/oauth/apple/return`; `https://loose-ends.henemm.com/` und `https://loose-ends.henemm.com/mcp?x=1` THEN dasselbe (Origin zählt); `http://localhost:8780` THEN `http://localhost:8780/oauth/apple/return`; `kein-url` und `""` THEN wirft, Meldung ohne den Wert. Test: „appleReturnUrl: origin plus fester pfad“.
- **AC-16:** App-Weg unverändert: GIVEN alle bestehenden Tests in `apple.test.ts`, `apple-client.test.ts`, `auth.test.ts` und `main.test.ts` (ohne Änderung ihrer Erwartungen) WHEN `./server/scripts/test-local.sh` läuft THEN sind sie grün; zusätzlich lehnt `verifyIdentityToken` ohne `audiences` (genau der Aufruf, den `/auth/apple` in `auth.ts` unverändert macht) bei gesetzter `webClientId` ein Token mit `aud = webClientId` mit demselben Grund ab wie ein fremdes `aud`; damit antwortet `/auth/apple` darauf 401, ohne dass `auth.ts` geändert wird. Test: „auth: web-token am app-weg abgelehnt“ (in `apple.test.ts`; die bestehenden `auth`-Tests laufen unverändert mit).
- **AC-17:** Keine Werte in Meldungen und im Log: GIVEN alle Fehlerfälle aus AC-3, AC-9, AC-11, AC-14 und AC-15 WHEN die Fehlermeldungen gesammelt werden THEN enthält keine die Web-ID, die App-ID, den Schlüssel (`APPLE_PRIVATE_KEY`, `APPLE_TOKEN_KEY`), `state`, `nonce`, `redirectUri` oder eine übergebene URL als Wert, und `console.*`, `process.stdout` und `process.stderr` bleiben in den Baustein-Tests stumm (Muster der bestehenden „silence“-Tests). Test: „silence: web-bausteine“.
- **AC-18:** Gesamtlauf: `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf; es gibt keinen neuen Eintrag in `server/package.json`. Dateigrenze und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Nachweis: `./server/scripts/test-local.sh`, CI `server.yml` und `/60-validate`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple.ts` | MODIFY | `webClientId?` aus `APPLE_WEB_CLIENT_ID` samt Prüfungen; `verifyIdentityToken`-Option `audiences`, ≈ +14 |
| `server/src/apple-client.ts` | MODIFY | `clientSecret` nimmt die Web-ID an; `redeemCode`-Option `redirectUri`; neu `authorizeUrl`, `appleReturnUrl`, ≈ +35 |
| `server/src/main.ts` | MODIFY | `APPLE_WEB_CLIENT_ID` in `APPLE_VARS`, ≈ +1 |
| `server/test/apple.test.ts` | MODIFY | AC-1 bis AC-3, AC-5 bis AC-7, AC-13, AC-16 (Teil), ≈ +65 |
| `server/test/apple-client.test.ts` | MODIFY | AC-8 bis AC-15, AC-17, ≈ +95 |
| `server/test/main.test.ts` | MODIFY | AC-4 (ein Fall im Start-Abbruch-Test), ≈ +12 |

### Estimated Changes

- **Files: 6** (Code: `apple.ts`, `apple-client.ts`, `main.ts`; Tests: `apple.test.ts`, `apple-client.test.ts`, `main.test.ts`). `CLAUDE.md`, Spec und Kontext zählen nicht.
- **Code ≈ +50 LoC**, **Tests ≈ +170 LoC** (≈ 3× Code, Tests ≥ 2,5× Code wie in den Vorgängern), insgesamt ≈ 220 LoC, **unter dem Limit von 250**, aber mit Luft nach oben nur für Fall-Tabellen; wächst die Testmenge, wird das vor dem Bauen gemeldet.
- **Die Dateigrenze (4–5 Dateien) wird um eine überschritten.** Begründung: `main.ts` ändert eine Zeile (`APPLE_VARS`) und `main.test.ts` bekommt einen Fall; beide sind nicht trennbar von der Konfiguration (ohne die Zeile liefe ein allein gesetztes `APPLE_WEB_CLIENT_ID` still ohne Apple). Eine Teilung in S4a-1 (`apple.ts`) und S4a-2 (`apple-client.ts`) wurde geprüft und verworfen: Beide Hälften bräuchten die Konfiguration, und die Nonce-Passung (AC-13) prüft beide gemeinsam. Mit der Freigabe dieser Spec wird die Überschreitung ausdrücklich angenommen (Präzedenz #621 S3).
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Migration, kein `generate`, keine neue Abhängigkeit. **Kein Pfad der Geräteliste berührt.**
- Seiteneffekte nach außen: keine. Nichts ruft die Bausteine auf; ohne `APPLE_WEB_CLIENT_ID` im Betrieb ändert sich kein Verhalten.

## Risiken

- **Berührt die Prüfung der App-Anmeldung (#615):** Gegenmaßnahme: `audiences` hat einen Standard, der exakt `config.clientIds` ist; AC-5, AC-7 und AC-16 sichern, dass der App-Weg weder Web-Token annimmt noch App-Token verliert, und alle bestehenden Tests bleiben unverändert grün.
- **Bytegleiches App-Formular:** Apple lehnt eine unerwartete `redirect_uri` im App-Weg ab. Gegenmaßnahme: AC-8 vergleicht den Körper als Zeichenfolge.
- **Verwechslung App-ID und Web-ID:** `redeemCode` und `clientSecret` akzeptieren beide, dürfen aber keine dritte; `revokeToken` für gespeicherte Tokens funktioniert, weil `apple_tokens.client_id` die ID je Token speichert (S3a). AC-11 und AC-10 decken Zulassung, Ablehnung und `aud`-Prüfung ab.
- **Services ID existiert noch nicht:** Für Code und Tests nicht nötig (Apple wird eingereicht), für den echten Ablauf (S6) schon. Das Portal braucht Hennings Anmeldung und geht nicht per API; früh vor S6 abstimmen (siehe „Out of Scope“).
- **Rückweg mit `form_post` ist ein seitenübergreifender POST ohne Lax-Cookies:** betrifft S4b (Zustand serverseitig unter `state`), nicht diesen Schnitt.
- **Datenschutz:** Ohne `scope` liefert Apple weder Name noch E-Mail; der Dienst braucht beides nicht. Der Datenschutztext bleibt unberührt (kein neues Datum wird gespeichert).

## Test Plan

### Automated Tests (TDD RED)

RED: `webClientId`, `audiences`, `redirectUri`, `authorizeUrl` und `appleReturnUrl` existieren nicht; die Tests schlagen fehl (fehlender Export, unbekannte Option wirkt nicht, `clientSecret` wirft für die Web-ID, Start mit allein gesetzter Web-ID läuft still ohne Apple).

| Testname | AC |
|---|---|
| „config: web-id leer“ | AC-1 |
| „config: web-id gültig und nicht in clientIds“ | AC-2 |
| „config: web-id gleich app-id oder mit komma wirft“ | AC-3 |
| „einhaengen: allein gesetzte web-id bricht start ab“ | AC-4 |
| „verify: web-token ohne audiences abgelehnt“ | AC-5 |
| „verify: web-token mit audiences angenommen“ | AC-6 |
| „verify: app-token mit web-audiences abgelehnt, Standard unverändert“ | AC-7 |
| „redeem: app-formular bytegleich ohne redirect_uri“ | AC-8 |
| „redeem: redirect_uri nur mit option, leer wirft“ | AC-9 |
| „redeem: id_token aud gleich web-id“ | AC-10 |
| „client: web-id zugelassen, fremde id wirft“ | AC-11 |
| „authorizeUrl: parameter vollständig, ohne scope“ | AC-12 |
| „authorizeUrl: nonce passt zu verifyIdentityToken“ | AC-13 |
| „authorizeUrl: wirft ohne web-id und bei leeren feldern“ | AC-14 |
| „appleReturnUrl: origin plus fester pfad“ | AC-15 |
| „auth: web-token am app-weg abgelehnt“ + alle Altfälle | AC-16 |
| „silence: web-bausteine“ | AC-17 |
| `./server/scripts/test-local.sh`, `/60-validate` (Dateiliste per `git diff`) | AC-18 |

- [ ] Test 1 (AC-1 bis AC-4): GIVEN Umgebung mit leerer, gültiger, doppelter, komma-haltiger oder allein gesetzter Web-ID WHEN Konfiguration geladen oder `main()` gestartet THEN `undefined`, Web-ID, Fehler mit Variablenname oder Start-Abbruch.
- [ ] Test 2 (AC-5 bis AC-7, AC-13, AC-16): GIVEN Tokens mit App- oder Web-`aud` WHEN `verifyIdentityToken` mit und ohne `audiences` THEN Standard unverändert, Web nur mit Liste, Nonce-Hash passt.
- [ ] Test 3 (AC-8 bis AC-11): GIVEN eingereichtes `fetch` WHEN Einlösen mit und ohne `redirectUri`, mit App-, Web- und fremder ID THEN Formular bytegleich bzw. um `redirect_uri` ergänzt, `aud` geprüft, fremde ID wirft.
- [ ] Test 4 (AC-12, AC-14, AC-15): GIVEN Konfiguration mit und ohne Web-ID WHEN `authorizeUrl` und `appleReturnUrl` THEN Parameter vollständig, ohne `scope`, Fehlbedienung wirft, Rückweg aus der Origin.
- [ ] Test 5 (AC-17, AC-18): GIVEN alle Fehlerfälle und der Gesamtlauf WHEN gesammelt und `./server/scripts/test-local.sh` THEN keine Werte in Meldungen und Ausgabe, alles grün.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): `response_mode=form_post`, eigene Variable `APPLE_WEB_CLIENT_ID`** | Code kommt per POST-Formular zurück, Web-ID getrennt von den App-Kennungen | Code steht nie in einer URL (nginx-Log, Verlauf, Referrer); der App-Weg nimmt keine Web-Token an | S4b muss einen Formular-Körper lesen (≈ 15 Zeilen) und den Zustand serverseitig unter `state` halten, weil Lax-Cookies beim seitenübergreifenden POST nicht reisen | — |
| B `response_mode=query` | Rückweg als normale Weiterleitung | Lax-Cookies reisen mit; kein Formular-Körper | der Code steht in URL und nginx-Zugriffslog; nur ohne Name/E-Mail möglich (die wir ohnehin nicht brauchen) | die Wahl „Code nie in einer URL“ dieser Spec; der Zustand in der DB (S4b) würde überflüssig |
| C Web-ID in `APPLE_CLIENT_IDS` (Konvention) | eine Variable weniger | einfacher | `/auth/apple` nähme auch Web-Token an; der Web-Ablauf wüsste nicht, welche Kennung gemeint ist | die Trennung App-/Web-Zielgruppe (`audiences`) und AC-5 |
| D Kopplungscode aus der App (Rückfall) | die App zeigt einen Einmalcode, die Anmeldeseite fragt ihn ab | keine Services ID, kein Portal-Schritt | kippt den S4-Plan aus dem ADR-21-Nachtrag; hängt an der App-Anmeldung (#615 S4, wartet auf #625); wer keine App hat, verbindet nie | der Plan „Apple im Browser“ aus dem ADR-21-Nachtrag; bleibt Rückfall, falls die Services ID scheitert |

Befunde gegen den Plan: keine blockierenden. Der Schnittplan nannte S4a mit ≈ 100 LoC; die ehrliche Schätzung mit Sicherheitstests liegt bei ≈ 220 (Tests ≈ 3× Code), unter dem Limit.

## Out of Scope / Folgeschnitte

- **Rückweg-Behandlung und Anmeldung (S4b):** `oauth-login.ts` (Interaction → Apple → Rückweg `/oauth/apple/return` → Prüfen → Einlösen → `findOrCreate` → `interactionFinished`), Zustand unter `state` in der Datenbank. Hier wird nur geliefert, was S4b aufruft.
- **Services ID im Apple-Konto (vor S6):** Anlegen, mit `com.henning.looseends` verbinden, Domain und Return-URL eintragen. Kein API-Weg; Henning meldet sich im Portal an, die Klicks übernimmt Claude im Chrome-Tab. Vor S6 abstimmen, nicht Teil von S4a.
- **nginx und Compose (S6):** `/oauth/*` durchlassen, `APPLE_WEB_CLIENT_ID` in Compose (Repo `henemm-infra`).
- **Zustimmungsseite (S5)** und alles in `mcp.ts`: unberührt.

## Abnahme

Kein Pfad der Geräteliste berührt (nur `server/`, keine App, kein `project.yml`). Die Abnahme endet nach den Tests: `./server/scripts/test-local.sh` (typecheck + `npm test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün. Ein Simulator-Durchlauf entfällt, weil es reiner Dienstcode ohne Port und ohne Oberfläche ist: nichts ruft die Bausteine auf, es gibt nichts zu benutzen außer den Tests. Sichtbar ändert sich nichts. Stufe 3 entfällt.

## Definition of Done

- [ ] AC-1 bis AC-18 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) aktualisiert: die Zeilen zu `src/apple.ts` (`webClientId` aus `APPLE_WEB_CLIENT_ID`, `verifyIdentityToken`-Option `audiences`) und `src/apple-client.ts` (`redirectUri`, Web-ID bei `clientSecret`/`redeemCode`/`revokeToken`, `authorizeUrl`, `appleReturnUrl`) nennen die neuen Bausteine und dass sie bis S4b nicht aufgerufen werden
- [ ] #621 kommentiert (Stand Schnitt 4a, Folge: S4b Anbindung und Services-ID-Einrichtung vor S6), Board-Karte aktuell

## Changelog

- 2026-11-06: Initial spec created (Schnitt 4a)
