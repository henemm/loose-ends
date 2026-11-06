# Adversary Dialog — feat-621-s3-aussteller
Spec: docs/specs/feat-621-schnitt-3-aussteller.md
Datum: 2026-11-06 07:26

## Checkliste
- [x] **AC-1:** Metadaten unter beiden Discovery-Pfaden: GIVEN ein gestarteter Dienst mit gültigen Schlüsseln und fertiger Migration WHEN `GET /.well-known/oauth-authorization-server` und `GET /.well-known/openid-configuration` THEN beide antworten 200 mit JSON, in dem `issuer` exakt gleich `https://loose-ends.test` (Origin der `publicUrl`, derselbe Wert wie `authorization_servers[0]` aus `GET /.well-known/oauth-protected-resource/mcp`), `code_challenge_methods_supported` genau `["S256"]`, `client_id_metadata_document_supported` genau `true`, `token_endpoint_auth_methods_supported` genau `["none"]`, und `authorization_endpoint` und `token_endpoint` beginnen mit `https://loose-ends.test/oauth/` (gilt für `x-forwarded-proto: https`, also `proxy = true`). Test: „oauth-provider: metadaten unter beiden pfaden“.
- [x] **AC-2:** Voller Durchlauf bis `/mcp` (Spike-Gate): GIVEN `PgAdapter` auf Wegwerf-Postgres, eingereichtes CIMD-`fetch` (Dokument für `https://claude.ai/oauth/test-client` mit `redirect_uris: ["https://claude.ai/api/mcp/auth_callback"]`, `token_endpoint_auth_method: "none"`) und Test-Interaction, die ein Konto per `findOrCreate` anlegt WHEN `GET /oauth/auth` mit `client_id` = diese URL, `response_type=code`, `code_challenge` (S256), `resource=https://loose-ends.test/mcp`, danach die Interaction, dann `POST /oauth/token` (`application/x-www-form-urlencoded`, `grant_type=authorization_code`, `code_verifier`) THEN die Antwort enthält `access_token`, `refresh_token`, `token_type: "Bearer"`, `scope: "tasks"`; ein MCP-Aufruf `get_now` an `/mcp` mit diesem Token im `Authorization`-Header liefert 200 und das Ergebnis dieses einen Kontos (ein zweites Konto mit eigener Aufgabe erscheint nicht); `oauth_records` enthält Zeilen für Grant, AccessToken, RefreshToken und Interaction/Session mit `account_id` dieses Kontos, `consumed_at` des Codes ist gesetzt, und der Token-Aufruf kam an, obwohl er nicht vorgepuffert war (AC-6). Test: „oauth-provider: voller durchlauf bis get_now“.
- [x] **AC-3:** Code nicht doppelt einlösbar: GIVEN der Durchlauf aus AC-2 WHEN derselbe Code ein zweites Mal an `/oauth/token` gesendet wird THEN antwortet der Dienst 400 mit `invalid_grant`, es entsteht kein weiteres Token (`oauth_records` zählt die AccessToken-Zeilen gleich), und alles zu dieser Erlaubnis wird widerrufen (`oidc-provider` 9.13.3, `lib/helpers/grant_source.js` `consumeGrantSource` → `revoke(ctx, grantId)`): das zuerst ausgestellte AccessToken bekommt an `/mcp` danach 401, das zugehörige Refresh-Token antwortet an `/oauth/token` mit `invalid_grant`, und in `oauth_records` bleibt keine AccessToken- oder RefreshToken-Zeile mit dieser `grant_id`. Test: „oauth-provider: code nur einmal“.
- [x] **AC-4:** Ohne PKCE abgelehnt: GIVEN dasselbe CIMD WHEN `GET /oauth/auth` ohne `code_challenge` THEN wird der Client mit `error=invalid_request` (Hinweis auf PKCE) an `https://claude.ai/api/mcp/auth_callback` zurückgeleitet, es entsteht keine Interaction-Zeile mit Konto und kein Code; ebenso `code_challenge_method=plain` → `invalid_request`. Test: „oauth-provider: ohne pkce abgelehnt“.
- [x] **AC-5:** CIMD und Ressource streng: Tabellengetrieben, je Zeile `GET /oauth/auth` (mit PKCE) THEN Test: „oauth-provider: cimd und resource streng“.
- [x] **AC-6:** Aussteller-Pfade laufen vor `bridge`, Status im Fehlerfenster: GIVEN der Dienst mit eingereichter Uhr WHEN `POST /oauth/token` mit gültigem Körper unter 56 KiB gesendet wird THEN erreicht der Körper die Bibliothek ungelesen (der Durchlauf aus AC-2 gelingt; ein Test-Handler vor `provider.callback()` stellt fest, dass der Request-Stream noch nicht gelesen wurde); WHEN ein Körper über 56 KiB an `/oauth/token` geht THEN antwortet die Bibliothek (4xx) und nicht `bridge` (deren 413 mit `connection: close` bleibt aus); WHEN 20 Aussteller-Antworten mit Status ≥ 500 gezählt werden (z. B. `productInteraction` 501 gilt nicht, ein erzwungener `server_error` der Bibliothek schon) und weniger als 50 % der Anfragen im 5-Minuten-Fenster erfolgreich sind THEN meldet `/health` 503 (Fehlerfenster zählt Aussteller-Antworten); Anfragen an `/health` selbst zählen nicht. Test: „oauth-provider: vor bridge und im fehlerfenster“.
- [x] **AC-7:** Refresh rotiert: GIVEN ein Token-Paar aus AC-2 WHEN `POST /oauth/token` mit `grant_type=refresh_token` und dem Refresh-Token THEN antwortet der Dienst 200 mit einem **neuen** `access_token` und einem **neuen** `refresh_token` (beide ungleich den alten); das neue Access-Token lässt `get_now` an `/mcp` zu; WHEN das **alte** Refresh-Token erneut eingelöst wird THEN antwortet der Dienst 400 `invalid_grant`. Test: „oauth-provider: refresh rotiert, altes invalid_grant“.
- [x] **AC-8:** Verifizierer streng: Tabellengetrieben, je Zeile `POST /mcp` mit `Authorization: Bearer …` THEN 401 mit `WWW-Authenticate` samt `resource_metadata` bei: unbekanntem Token; abgelaufenem Token (eingereichte Uhr hinter dem Ablauf); Token, dessen `aud` nicht `https://loose-ends.test/mcp` ist (direkt in `oauth_records` für eine andere Ressource angelegt); Token ohne `accountId`; widerrufenem Token (`revokeByGrantId`); Token eines gelöschten Kontos (`deleteAccount`). Ein gültiges Token mit `extra.account` des Kontos liefert 200. Test: „oauth-provider: verifizierer streng“.
- [x] **AC-9:** App-Sitzungstoken gilt an `/mcp` weiter nicht: GIVEN ein Konto mit einer Sitzung aus `createSession` (App-Anmeldung `/auth/apple`-Weg) und der Dienst mit Schlüsseln (Verifizierer = `providerVerifier`) WHEN `POST /mcp` mit diesem Sitzungstoken THEN 401; ebenso ein Wert, der in `sessions` als SHA-256 steht. Test: „oauth-provider: app-sitzung an mcp weiter 401“.
- [x] **AC-10:** Produkt-Interaction meldet niemanden an: GIVEN der Dienst ohne eingereichte Interaction (Standard) und ein gültiger `GET /oauth/auth` (CIMD, PKCE, Ressource) WHEN der Browser der Weiterleitung auf `/oauth/interaction/<uid>` folgt (auch mit gesetztem Cookie, mit `POST` und mit beliebigen Formularfeldern wie `login=…&password=…`) THEN antwortet die Interaction fest mit 501 und einem Text ohne Werte; in `oauth_records` entsteht nie ein Grant, ein Code oder ein Token, und `account_id` bleibt in jeder Zeile `NULL`; ein Aufruf von `/oauth/token` mit erfundenem Code antwortet `invalid_grant`. Test: „oauth-provider: produkt-interaction meldet niemanden an“.
- [x] **AC-11:** Dev-Anmeldung aus: GIVEN der Dienst WHEN `GET /oauth/interaction/anything`, `POST /oauth/interaction/anything/login` und `…/confirm` ohne gültige Interaction THEN keine Antwort 200 und kein Formular der Bibliothek (die Standardseiten von `devInteractions` existieren nicht); `provider.configuration().features.devInteractions.enabled` ist `false`. Test: „oauth-provider: dev interactions aus“.
- [x] **AC-12:** Schlüssel aus der Umgebung, tabellengetrieben für `oauthKeysFromEnv` und `main()`: (a) keine der beiden Variablen gesetzt → Rückgabe `undefined`; (b) beide gültig (Cookie-Schlüssel ≥ 32 Zeichen, auch als Liste mit Komma; ES256-JWK mit privatem Teil) → Objekt; (c) nur `OAUTH_COOKIE_KEYS` oder nur `OAUTH_SIGNING_JWK` gesetzt → wirft, Meldung nennt die fehlende Variable; (d) `OAUTH_COOKIE_KEYS` mit Schlüssel unter 32 Zeichen, `OAUTH_SIGNING_JWK` kein JSON, öffentlicher statt privater Schlüssel, falsche Kurve (RS256/P-384) → wirft, Meldung nennt den Variablennamen und enthält keinen Wert (Test setzt erkennbare Werte wie `geheim-cookie-schluessel-…` und prüft, dass sie nicht in `message` stehen). Test: „oauth-provider: schluessel aus der umgebung“.
- [x] **AC-13:** Ohne Schlüssel ändert sich nichts: GIVEN `start()` ohne `oauth.keys` (und keine Variablen) WHEN `GET /.well-known/oauth-authorization-server`, `GET /oauth/auth?…`, `POST /oauth/token` THEN je 503 ohne Körper; `POST /mcp` mit beliebigem Bearer → 401 mit `resource_metadata` (Verifizierer bleibt `rejectAll`, auch für ein in `oauth_records` angelegtes gültiges Token); `GET /.well-known/oauth-protected-resource/mcp` und `/health` verhalten sich wie vor diesem Schnitt. Test: „oauth-provider: ohne schluessel 503 und mcp bleibt zu“.
- [x] **AC-14:** Start bricht bei ungültigen Schlüsseln ab: GIVEN `main()` (Kindprozess, wie die bestehenden Start-Tests) mit `OAUTH_COOKIE_KEYS=zu-kurz` und gültigem `DATABASE_URL` WHEN gestartet THEN beendet er mit Exit-Code 1, die Ausgabe enthält `oauth config invalid: OAUTH_COOKIE_KEYS` und nicht den Wert, und es wurde weder Pool noch Port geöffnet; dasselbe für nur `OAUTH_SIGNING_JWK` gesetzt (Name `OAUTH_COOKIE_KEYS` als fehlend) und für ungültiges JWK (Name `OAUTH_SIGNING_JWK`). Test: „main: ungueltige oauth schluessel brechen start ab“ (in `server/test/main.test.ts`, bei den bestehenden Start-Tests).
- [x] **AC-15:** 503 vor `migrate`: GIVEN ein Dienst mit Schlüsseln, dessen `migrate` noch nicht fertig ist (Datenbank-Verbindung verzögert) WHEN `GET /.well-known/oauth-authorization-server` und `POST /oauth/token` THEN 503 ohne Körper; nach Abschluss von `migrate` antworten dieselben Aufrufe fachlich (AC-1, AC-2). `GET /.well-known/oauth-protected-resource/mcp` und `/health` verhalten sich wie bisher (Metadaten ohne Datenbank nicht gegated). Test: „oauth-provider: 503 vor migrate“.
- [x] **AC-16:** Nichts im Log, auch nicht bei FK-Fehler: GIVEN der Mitschnitt von `console.*`, `process.stdout`, `process.stderr` und der Ausgabe von `logError` über die Fälle AC-1 bis AC-15 WHEN zusätzlich ein Durchlauf, dessen Konto zwischen Anmeldung und Grant gelöscht wird (`upsert` wirft FK `23503`, `detail` nennt die Konto-ID) THEN endet der Ablauf ohne Code und ohne Token mit `server_error` oder einer Fehlerseite der Bibliothek, und der Mitschnitt enthält weder ein Access-Token, Refresh-Token, einen Code, `code_verifier`, Cookie-Schlüssel, das JWK noch die Konto-ID noch `detail` des Postgres-Fehlers; erlaubt sind nur feste Ereignisnamen. Test: „oauth-provider: nichts im log, auch nicht beim fk fehler“.
- [x] **AC-17:** Abhängigkeit und Gesamtlauf: `server/package.json` führt `oidc-provider` exakt `9.13.3` in `dependencies` und `@types/oidc-provider` exakt `9.13.1` in `devDependencies` (kein `^`, kein `~`; Test liest die Datei), das Lockfile ist passend (`npm ci` gelingt), und `./server/scripts/test-local.sh` (typecheck + alle Tests, einschließlich aller Altfälle aus S1/S2 und `main.test.ts`) ist grün und räumt auf. Dateigrenze und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Nachweis: `./server/scripts/test-local.sh`, CI `server.yml` (Job `image` baut weiter) und `/60-validate`.

## Dialog

### Runde 1
**Adversary:** Volltest `./server/scripts/test-local.sh`: typecheck ok, 276 Tests, 276 bestanden, 0 fehlgeschlagen, 0 uebersprungen (adversary-test-output.txt). Jeden AC gegen Code und Test gelesen. Der Test je AC existiert unter dem in der Spec genannten Namen (oauth-provider.test.ts Zeilen 246-590, main.test.ts AC-14). Code-Pruefung: allowFetch (https + Hostname exakt claude.ai), resourceIndicators (genau eine Ressource, sonst InvalidTarget), pkce required, clientAuthMethods none, devInteractions aus, findAccount nur mit Zeile in accounts, providerVerifier prueft Existenz, isExpired, aud exakt, accountId, clientId. Schluessel: signingJwk wirft nur den Variablennamen, Cookie-Schluessel unter 32 Zeichen werfen. main(): oauthKeysFromEnv vor Pool und Port, Meldung `oauth config invalid: <Name>`. Funktionslaenge: start() etwa 38 Zeilen, keine Funktion in oauth-provider.ts ueber 50; kein console.* in oauth-provider.ts.
**Implementierer:** Bewertung der gemeldeten Abweichungen: (1) 404 auf 503 in oauth-resource.test.ts:417 folgt zwingend aus AC-13 (503 ohne Schluessel), kein Verlust an Pruefschaerfe. (2) ES256-Default, findAccount, renderError sind Haertung, kein Spec-Widerspruch (renderError gibt nur Fehlercode, getestet durch AC-16-Log-Pruefung). (3) Interaction als Koa-Middleware: aequivalent, Pfad nur unter /oauth/interaction/. (4) 501 nicht im Fehlerfenster ist von AC-6 gedeckt; Vorrang eines expliziten oauth.verifier wird in main() nie genutzt (nur Tests/oauth-resource). (5) FK-Fall: Koa-500 mit fester Logzeile, kein Wert im Log (AC-16 Test gruen).

### Runde 2
**Adversary:** Eigene Probe-Tests (temporaer, wieder geloescht) gegen den laufenden Dienst: Token-Missbrauch: Refresh-Token als Access-Token an /mcp 401; Access-Token als Refresh invalid_grant; Refresh mit fremder resource invalid_target; Refresh mit Scope admin invalid_scope; client_credentials unsupported_grant_type; Token-Austausch mit fremder resource invalid_target; kein id_token, nur Scope tasks; Auth mit Scope `tasks admin openid` ergibt Code, Token traegt nur tasks. 60 fehlerhafte Token-Aufrufe (400) lassen /health bei 200 (4xx zaehlt nicht ins Fehlerfenster). /oauth/jwks enthaelt kein `d`. Pfade: /OAUTH/token, /oauth/%61uth, /oauth//token, /oauth/interaction ohne Slash alle 404 aus Bibliothek oder Bruecke, kein Umgehen; introspection, registration, backchannel, device 404. Mitschnitt von console.* ueber einen vollen Durchlauf: 0 Zeilen. Funde: F001, F002 (beide LOW).
**Implementierer:** F001: nginx muss X-Forwarded-Host/Proto selbst setzen (Betrieb S6), im Code kein Eingriff noetig, issuer bleibt fest. F002: /oauth/session/end und /oauth/me sind Bibliotheks-Standard, keine Spec-Vorgabe; niedriges Risiko, kann in S4/S5 deaktiviert werden.

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: security
  Code reference: server/src/oauth-provider.ts:96
  Description: provider.proxy = true laesst die Bibliothek den Host aus X-Forwarded-Host und das Schema aus X-Forwarded-Proto lesen. Probe: Discovery mit X-Forwarded-Host evil.test liefert issuer https://loose-ends.test, aber authorization_endpoint https://evil.test/oauth/auth.
  Spec requirement: AC-1 — authorization_endpoint und token_endpoint beginnen mit der oeffentlichen Origin
  Conflict: gilt nur, wenn der vorgeschaltete nginx die Header immer ueberschreibt; der Dienst selbst lauscht nur auf 127.0.0.1.
  Remediation: in S6 nginx proxy_set_header X-Forwarded-Host/Proto fest setzen; optional Host aus publicUrl erzwingen.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: server/src/oauth-provider.ts:72
  Description: Die ROUTES-Tabelle laesst /oauth/session/end (200 mit Bibliotheksseite), /oauth/me und /oauth/jwks aktiv; Logout- und Userinfo-Endpunkt sind fuer Claude nicht noetig.
  Spec requirement: keine; Spec verlangt nur Auth, Token, Metadaten
  Conflict: unnoetige Angriffsflaeche, keine Spec-Verletzung.
  Remediation: spaeter features.rpInitiatedLogout und userinfo ausschalten.

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: server/src/oauth-provider.ts:95
  Evidence: Issuer aus publicUrl-Origin, Test metadaten unter beiden pfaden gruen.
  Status: CONFIRMED
Confirmation:
  AC: AC-2, AC-3, AC-7
  Code reference: server/test/oauth-provider.test.ts:264
  Evidence: Voller Durchlauf, Code einmalig mit Widerruf, rotierender Refresh; PgAdapter aus S2 unveraendert.
  Status: CONFIRMED
Confirmation:
  AC: AC-4, AC-5, AC-10, AC-11
  Code reference: server/src/oauth-provider.ts:36
  Evidence: allowFetch nur https://claude.ai, pkce required, resource exakt, productInteraction fest 501, devInteractions aus.
  Status: CONFIRMED
Confirmation:
  AC: AC-6, AC-13, AC-15
  Code reference: server/src/main.ts:150
  Evidence: Aussteller-Pfade vor bridge, 503 vor migrate und ohne Schluessel, Status im ErrorWindow ausser 501.
  Status: CONFIRMED
Confirmation:
  AC: AC-8, AC-9
  Code reference: server/src/oauth-provider.ts:108
  Evidence: providerVerifier prueft Existenz, Ablauf, aud, accountId; App-Sitzung nie, Test app-sitzung an mcp 401.
  Status: CONFIRMED
Confirmation:
  AC: AC-12, AC-14
  Code reference: server/test/main.test.ts:1
  Evidence: oauthKeysFromEnv wirft nur Variablennamen; main bricht mit oauth config invalid ab, vor Pool und Port.
  Status: CONFIRMED
Confirmation:
  AC: AC-16
  Code reference: server/src/main.ts:148
  Evidence: nur feste Logzeilen oauth error und oauth server error, Probe: 0 console-Zeilen im Durchlauf.
  Status: CONFIRMED
Confirmation:
  AC: AC-17
  Code reference: server/test/oauth-resource.test.ts:417
  Evidence: Pinnung exakt 9.13.3 und 9.13.1 in package.json, test-local.sh gruen (276/276); Altfall auf 503 begruendet durch AC-13.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:bba816bc793220b0feb3a30f16c4eb7f5cd39e39e60ec796fa0eed2167d795f1  server/src/main.ts
- sha256:496c70a6fc4842ad17a502ebc14513d8c5b61ce355109eeb110e943c41ef653f  server/src/oauth-provider.ts
- sha256:a962172b4b1a09f9e1b51da2e3931a56ba8f2a5a21530150caecc64661a934bc  server/test/main.test.ts
- sha256:7a99ec1b5d3d8f04f4168f48ba0acb8ae19f00938c42132008eddcade68def71  server/test/oauth-provider.test.ts
- sha256:1e8fd7eb3434d11afaea349b43d7989aa8bae6312f357d07b904766022d0cd4b  server/test/oauth-resource.test.ts

## Prüfbasis

- base: d5b8c961eee06b98f6ac17993c4bf0f19c2417f5
- blob:8476254667e5b3325ad4fb5e8aa4d6f2b04d1c03  server/src/main.ts
- blob:083c78182ac90ec1bcf720f903a72c17c6135280  server/src/oauth-provider.ts
- blob:1d6be876a6d569c6aae43edf4e955b3c1e78f205  server/test/main.test.ts
- blob:a541f83882371235eae7bf9a3cf6906120c21781  server/test/oauth-provider.test.ts
- blob:7c06297410857f6264ee717664be0ced8f887cc3  server/test/oauth-resource.test.ts
