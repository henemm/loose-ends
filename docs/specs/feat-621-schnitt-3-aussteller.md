---
entity_id: feat-621-schnitt-3-aussteller
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-621-s3-aussteller
---

# Spec: OAuth-Aussteller (Authorization Server) für /mcp, Schnitt 3 (#621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 3; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-s3-aussteller.md` (Abschnitte „Analysis“, „Recherche“, „Merkposten aus S1/S2“); Schnittplan: `docs/context/feat-621-mcp-anmeldung.md`. Vorgänger: #621 S1 (`server/src/oauth-resource.ts`, `/mcp` hinter `rejectAll`), #621 S2 (`server/src/oauth-adapter.ts`, Tabelle `oauth_records`).

## Für den PO

Damit sich Claude (claude.ai) später bei Loose Ends anmelden kann, braucht der Dienst eine eigene „Ausweisstelle“: Sie prüft, wer Claude ist, verlangt einen Beweis, dass die Anfrage nicht abgefangen wurde (PKCE), und stellt dann einen Schlüssel aus, der nur für den Zugang zu deinen Aufgaben gilt und sich nach Gebrauch erneuert. Dieser Schnitt baut diese Ausweisstelle fertig ein und beweist im Test den ganzen Weg: von der Anfrage bis zu dem Moment, in dem Claude mit dem Schlüssel „Jetzt“ für genau ein Konto abfragt. Eine Bibliothek (`oidc-provider`) übernimmt dabei das Sicherheitsgerüst, weil du und ich das nie selbst schreiben wollen (ADR-21).

Was **nicht** dabei ist: die Anmeldung mit Apple (kommt in S4) und die Zustimmungsseite (S5). Die Ausweisstelle meldet heute niemanden an, also bekommt auch niemand einen Schlüssel. Die Tür nach außen bleibt zu (nginx lässt nur `/health` durch, bis S6). Von außen und für die App ändert sich nichts, deine Daten sind nicht berührt. **Zu entscheiden hast du eine Sache:** die neue Bibliothek `oidc-provider` (siehe Abschnitt „Freigabe der neuen Abhängigkeit“).

## Purpose

Der Dienst bekommt seinen OAuth-Aussteller. `oidc-provider` 9.13.3 wird eingebettet, nutzt die Ablage aus S2 (`PgAdapter`) und hängt vor `/mcp`, sodass ein Client sich per Client-ID-Metadata-Dokument (CIMD, draft-02, experimentell) ausweist, mit PKCE S256 ein opakes Token genau für die Ressource `<publicUrl>/mcp` bekommt und `bearerGate` (S1) dieses Token annimmt. Das Token trägt die Konto-Kennung (`accounts.id`), die `mcp.ts` aus `authInfo.extra.account` liest.

**Regeln vor Modell:** Protokoll und Sicherheitsablauf ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Festlegungen aus der Analyse (Durchstich mit der echten Bibliothek, 2026-11-06, Node 26.13.0):

- Die Bibliothek bedient `/.well-known/oauth-authorization-server` **und** `/.well-known/openid-configuration` selbst (`lib/helpers/initialize_app.js:180–186`); keine eigene Route. `issuer` ist die übergebene URL exakt.
- Opake Token: Der Verifizierer ist ein Nachschlagen in der Ablage (`provider.AccessToken.find`), keine Signatur nötig. Trotzdem werden Signierschlüssel und Cookie-Schlüssel konfiguriert, sonst erzeugt die Bibliothek flüchtige Dev-Schlüssel mit Warnung (`openid` steht in `scopes_supported`).
- Es gibt zwei Interaction-Schritte, `login` und `consent`; ein bestehender Grant wird nur im `consent`-Schritt gebaut (`loadExistingGrant` vor der Anmeldung liest kein Konto).
- `devInteractions` ist standardmäßig **an** (nimmt jeden Namen und jedes Passwort) und wird abgeschaltet.
- `allowFetch` lässt nur den Host `claude.ai` zu (die URL des claude.ai-Web-CIMD ist nicht veröffentlicht, daher Host statt exakter URL; die exakte URL liest S6 beim echten Verbinden ab). Claude Code (Loopback-Rücksprung ohne Port, braucht `applicationType: native`) ist ausdrücklich nicht Ziel dieses Schnitts.
- Abweichungen des `PgAdapter` gegen die echte Bibliothek (Format von `consumed`, `findByUid` ohne `jti`), die das Spike-Gate zeigt, werden in S3 korrigiert (siehe Scope: mögliche sechste Datei).

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** Nachtrag zu ADR-21 (`docs/project/00-entscheidungen.md`) — Aussteller = `oidc-provider` 9.13.3 mit CIMD (Weg A); der Rückfall „Supabase Auth“ aus ADR-21 entfällt, weil Supabase Auth kein CIMD kann und Konten dann doppelt (außerhalb und als `apple_sub`-Modell aus #615) lägen. Der Nachtrag steht im selben PR (Dokumentation, zählt nicht gegen die Dateigrenze).

**Rationale:** (1) ADR-21 sagt „OAuth nie selbst schreiben“; das SDK `@modelcontextprotocol/server` 2.4.0 hat **keinen** Aussteller (geprüft: kein `mcpAuthRouter`, kein `OAuthServerProvider` im Paket). (2) claude.ai nutzt CIMD nur, wenn die Metadaten `client_id_metadata_document_supported: true` und `"none"` in `token_endpoint_auth_methods_supported` führen, sonst fällt es auf offene Registrierung (DCR) zurück, die fremde Clients in die Datenbank schreibt. (3) Der Durchstich mit der echten Bibliothek lief grün. (4) Keys und Cookie-Schlüssel kommen aus der Umgebung, nie aus dem Code (Muster `appleConfigFromEnv`).

## Freigabe der neuen Abhängigkeit (PO)

Hausregel: keine neuen Abhängigkeiten ohne ausdrückliche Freigabe. Mit der Freigabe dieser Spec stellt der PO zur Entscheidung:

- **`oidc-provider` 9.13.3**, exakt gepinnt (kein `^`, wie alle Pakete in `server/`), zieht rund **34 Pakete** (u. a. `koa` ^3.2.1, `jose` ^6.2.13, `debug`), etwa 2,9 MB, in `dependencies` von `server/package.json`.
- **`@types/oidc-provider` 9.13.1**, exakt gepinnt, in `devDependencies` (die Bibliothek bringt keine eigenen Typen; Node 26 entfernt nur Typen, kein Build, daher laufen die Typen nur beim Typecheck).

Begründung: ADR-21 („OAuth nie selbst schreiben“) und die Lage im SDK (kein Aussteller). Die Bibliothek ist zertifiziert, bringt CIMD, PKCE, Ressourcen-Indikatoren, Refresh-Rotation und Replay-Erkennung mit; der Eigenbau (Weg C) schriebe genau die Fehlerklasse selbst, die ADR-21 ausschließt. Risiko: CIMD ist experimentell (draft-02, braucht `ack`) und kann sich in Minor-Versionen ändern, daher die exakte Pinnung; Updates nur bewusst mit Spike-Gate-Test. Lehnt der PO ab, ist Weg B oder D die Folge (siehe „Alternativen“) und die Spec wird neu geschrieben.

## Source

**Files:** `server/src/oauth-provider.ts` (neu), `server/src/main.ts` (ändern), `server/package.json` samt `server/package-lock.json` (ändern), `server/test/oauth-provider.test.ts` (neu), `server/test/main.test.ts` (ändern: AC-14, dazu Altfälle, falls sie brechen); mögliche sechste Datei `server/src/oauth-adapter.ts`, falls das Spike-Gate Abweichungen zeigt.
**Identifier:** `createProvider`, `providerVerifier`, `oauthKeysFromEnv`, `StartOptions.oauth`

### Schnittstelle

- **`server/src/oauth-provider.ts`** (kein `console.*`, jede Funktion höchstens 50 Zeilen, Kommentare knapp auf Englisch):
  - `createProvider({ publicUrl, pool, now, fetch, keys, interaction })` baut den `oidc-provider`:
    - Aussteller: `issuer` = Origin der `publicUrl` (exakt gleich `authorization_servers[0]` aus `metadataRoute`), `proxy = true` (nginx macht TLS, `x-forwarded-proto` gilt).
    - Ablage: `adapter: (name) => new PgAdapter(pool, name, now)`.
    - Routen unter `/oauth/*`; die zwei Discovery-Pfade bedient die Bibliothek.
    - `features.devInteractions.enabled = false`.
    - `features.clientIdMetadataDocument` mit `ack: "draft-02"`, `enabled: true`, eingereichtem `fetch`, `allowFetch(ctx, clientId)` nur für Host `claude.ai` (https), Standard-Cache.
    - `clientAuthMethods: ["none"]` (Metadaten nennen genau `["none"]`), PKCE Pflicht mit `S256`.
    - `features.resourceIndicators` mit `defaultResource` und `getResourceServerInfo` nur für `<publicUrl>/mcp`: Audience `<publicUrl>/mcp`, Scope `tasks`, `accessTokenFormat: "opaque"`; jede andere `resource` wird abgelehnt.
    - Refresh: `rotateRefreshToken` an, `issueRefreshToken` für Clients ohne Secret; eigene `ttl` als feste Werte im Modul: AuthorizationCode 60 s, Interaction 10 min, AccessToken 1 h, RefreshToken 30 Tage (rotiert bei jeder Nutzung), Grant 30 Tage, Session 14 Tage (nicht Teil der Abnahme, ändern ohne neue Spec erlaubt).
    - `cookies.keys` und `jwks` aus `keys`.
    - Interaction: `interactions.url` auf `/oauth/interaction/:uid`; die Interaction-Behandlung kommt aus dem Parameter `interaction` (nur Tests reichen eine ein); der Standard (`productInteraction`) antwortet fest und ohne Anmeldung (HTTP 501, Text ohne Werte), beendet die Interaction nie mit einem Konto und stellt damit nie einen Code aus.
  - `providerVerifier(provider, publicUrl)` liefert einen `OAuthTokenVerifier`: schlägt das Token mit `provider.AccessToken.find` nach; unbekannt, abgelaufen, nicht für die Ressource `<publicUrl>/mcp` (`aud`) oder ohne `accountId` → `InvalidTokenError`; sonst `AuthInfo` mit `clientId`, `scopes`, `expiresAt` (Sekunden), `resource` und `extra.account = accountId`.
  - `oauthKeysFromEnv(env)`: liest `OAUTH_COOKIE_KEYS` (Komma-Liste, jeder Schlüssel mindestens 32 Zeichen, der erste signiert, die weiteren dienen dem Wechsel) und `OAUTH_SIGNING_JWK` (privater ES256-JWK als JSON). Keins gesetzt → `undefined`. Genau eins gesetzt oder ein Wert ungültig (kein JSON, kein privater ES256-Schlüssel, Cookie-Schlüssel zu kurz) → wirft einen `Error`, dessen Meldung nur den Variablennamen nennt, nie den Wert.
- **`server/src/main.ts`**:
  - `StartOptions.oauth` bekommt `keys?`, `fetch?`, `interaction?` (die letzten beiden nur für Tests).
  - Aussteller-Pfade (alles unter `/oauth/`, `/.well-known/oauth-authorization-server`, `/.well-known/openid-configuration`) werden im `http.createServer`-Handler **vor** `bridge`/`buffered` an `provider.callback()` übergeben (der rohe `IncomingMessage` bleibt ungelesen; die Bibliothek liest den Körper selbst, Grenze 56 KiB).
  - Vor `migrate` und ohne Schlüssel antworten diese Pfade `503` ohne Körper; mit Schlüsseln setzt `start()` den Verifizierer `providerVerifier(...)` statt `rejectAll` vor `/mcp`; ohne Schlüssel bleibt `rejectAll`.
  - Der Status jeder Aussteller-Antwort wird über das `finish`-Ereignis von `res` ins Fehlerfenster (`ErrorWindow`) gezählt (nicht `/health`).
  - Fehler der Bibliothek (`server_error`, FK-Fehler `23503`, dessen `detail` die Konto-ID trägt) werden nie als Objekt geloggt; nur feste Ereignisnamen über `logError`. Ein FK-Fehler im Anmeldeablauf wird als Anmeldefehler behandelt (Antwort der Bibliothek mit `server_error`, ohne Token, ohne Code).
  - `main()` liest `oauthKeysFromEnv(process.env)` (Muster `appleConfigFromEnv`): ungültig → `logError("oauth config invalid: <variable>")` und `exit 1` vor Pool und Listen.
  - Feste Routen (`/health`, `/mcp`, Metadaten der Ressource) bleiben nicht ersetzbar.

### Festlegungen

- **Konfiguration nur aus `main()`/Env**, nie aus `request.url` oder Host; `publicUrl` ist die Wahrheit für `issuer` und Ressource.
- **Keine Werte im Log:** weder Token, Code, Cookie-Schlüssel, JWK noch Konto-ID; kein `console.*` im Baustein.
- **Der laufende Dienst ändert sein Verhalten nicht**, solange die neuen Variablen fehlen (Aussteller 503, `/mcp` bleibt `rejectAll`).
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Test-Stil wie S1/S2 (`node:test`, `node:assert/strict`, `freshPool(t)`, Helfer `service(t, options)`).
- **Unberührt:** `oauth-resource.ts`, `accounts.ts`, `mcp.ts`, `auth.ts`, alle `apple*.ts`, Migrationen 001–004, jede Swift-Datei, `.github/`, nginx und Compose in `henemm-infra`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `oidc-provider` 9.13.3 (exakt), `@types/oidc-provider` 9.13.1 (dev, exakt) | **neu, zur PO-Freigabe** (siehe oben) |
| `@modelcontextprotocol/server` 2.4.0 (`requireBearerAuth`, `OAuthTokenVerifier`), `pg`, `zod` | bestehend |
| `PgAdapter`, `oauth_records` (S2), `findOrCreate` (`accounts.ts`), `bearerGate`/`metadataRoute` (S1), `mcp.ts` (`extra.account`) | bestehend, unverändert |
| `freshPool` (`server/test/db.ts`), `migrate` | bestehend, in Tests |
| Downstream | S4a/S4b (Interaction → Apple → `findOrCreate` → `interactionFinished`), S5 (Zustimmungsseite, Erlaubnisliste), S6 (nginx öffnet `/mcp`, `/.well-known/*`, `/oauth/*`; Env-Schlüssel in Compose) |

## Acceptance Criteria

Neue Tests in `server/test/oauth-provider.test.ts` mit `node:test` und `node:assert/strict` gegen ein Wegwerf-Postgres über `freshPool(t)` und `migrate` (kein Überspringen). `fetch` für das CIMD wird eingereicht (kein Netz); die Test-Interaction (login → Konto über `findOrCreate` → consent mit Grant) wird über `StartOptions.oauth.interaction` eingereicht. Tabellengetrieben, ein Fall je Zeile. Als `publicUrl` dient `https://loose-ends.test`; Aufrufe laufen mit `x-forwarded-proto: https` gegen den echten `start()`.

- **AC-1:** Metadaten unter beiden Discovery-Pfaden: GIVEN ein gestarteter Dienst mit gültigen Schlüsseln und fertiger Migration WHEN `GET /.well-known/oauth-authorization-server` und `GET /.well-known/openid-configuration` THEN beide antworten 200 mit JSON, in dem `issuer` exakt gleich `https://loose-ends.test` (Origin der `publicUrl`, derselbe Wert wie `authorization_servers[0]` aus `GET /.well-known/oauth-protected-resource/mcp`), `code_challenge_methods_supported` genau `["S256"]`, `client_id_metadata_document_supported` genau `true`, `token_endpoint_auth_methods_supported` genau `["none"]`, und `authorization_endpoint` und `token_endpoint` beginnen mit `https://loose-ends.test/oauth/` (gilt für `x-forwarded-proto: https`, also `proxy = true`). Test: „oauth-provider: metadaten unter beiden pfaden“.
- **AC-2:** Voller Durchlauf bis `/mcp` (Spike-Gate): GIVEN `PgAdapter` auf Wegwerf-Postgres, eingereichtes CIMD-`fetch` (Dokument für `https://claude.ai/oauth/test-client` mit `redirect_uris: ["https://claude.ai/api/mcp/auth_callback"]`, `token_endpoint_auth_method: "none"`) und Test-Interaction, die ein Konto per `findOrCreate` anlegt WHEN `GET /oauth/auth` mit `client_id` = diese URL, `response_type=code`, `code_challenge` (S256), `resource=https://loose-ends.test/mcp`, danach die Interaction, dann `POST /oauth/token` (`application/x-www-form-urlencoded`, `grant_type=authorization_code`, `code_verifier`) THEN die Antwort enthält `access_token`, `refresh_token`, `token_type: "Bearer"`, `scope: "tasks"`; ein MCP-Aufruf `get_now` an `/mcp` mit diesem Token im `Authorization`-Header liefert 200 und das Ergebnis dieses einen Kontos (ein zweites Konto mit eigener Aufgabe erscheint nicht); `oauth_records` enthält Zeilen für Grant, AccessToken, RefreshToken und Interaction/Session mit `account_id` dieses Kontos, `consumed_at` des Codes ist gesetzt, und der Token-Aufruf kam an, obwohl er nicht vorgepuffert war (AC-6). Test: „oauth-provider: voller durchlauf bis get_now“.
- **AC-3:** Code nicht doppelt einlösbar: GIVEN der Durchlauf aus AC-2 WHEN derselbe Code ein zweites Mal an `/oauth/token` gesendet wird THEN antwortet der Dienst 400 mit `invalid_grant`, es entsteht kein weiteres Token (`oauth_records` zählt die AccessToken-Zeilen gleich), und alles zu dieser Erlaubnis wird widerrufen (`oidc-provider` 9.13.3, `lib/helpers/grant_source.js` `consumeGrantSource` → `revoke(ctx, grantId)`): das zuerst ausgestellte AccessToken bekommt an `/mcp` danach 401, das zugehörige Refresh-Token antwortet an `/oauth/token` mit `invalid_grant`, und in `oauth_records` bleibt keine AccessToken- oder RefreshToken-Zeile mit dieser `grant_id`. Test: „oauth-provider: code nur einmal“.
- **AC-4:** Ohne PKCE abgelehnt: GIVEN dasselbe CIMD WHEN `GET /oauth/auth` ohne `code_challenge` THEN wird der Client mit `error=invalid_request` (Hinweis auf PKCE) an `https://claude.ai/api/mcp/auth_callback` zurückgeleitet, es entsteht keine Interaction-Zeile mit Konto und kein Code; ebenso `code_challenge_method=plain` → `invalid_request`. Test: „oauth-provider: ohne pkce abgelehnt“.
- **AC-5:** CIMD und Ressource streng: Tabellengetrieben, je Zeile `GET /oauth/auth` (mit PKCE) THEN
  - `client_id` = `https://evil.example/client` (fremder Host): abgelehnt (`invalid_client`, Fehlerseite, kein Rücksprung), das eingereichte `fetch` wurde für diese URL **nicht** aufgerufen;
  - `client_id` = `http://claude.ai/oauth/test-client` (kein https): abgelehnt;
  - CIMD-Dokument, dessen `client_id` nicht der URL entspricht oder das `token_endpoint_auth_method: "client_secret_basic"` verlangt: abgelehnt;
  - `redirect_uri` nicht im Dokument (`https://evil.example/cb`): abgelehnt, kein Rücksprung dorthin;
  - `resource=https://loose-ends.test/andere` oder `resource=https://evil.example/mcp`: `invalid_target`, kein Code;
  - ohne `resource`: Standardressource `https://loose-ends.test/mcp` gilt (`aud` des Tokens).
  Test: „oauth-provider: cimd und resource streng“.
- **AC-6:** Aussteller-Pfade laufen vor `bridge`, Status im Fehlerfenster: GIVEN der Dienst mit eingereichter Uhr WHEN `POST /oauth/token` mit gültigem Körper unter 56 KiB gesendet wird THEN erreicht der Körper die Bibliothek ungelesen (der Durchlauf aus AC-2 gelingt; ein Test-Handler vor `provider.callback()` stellt fest, dass der Request-Stream noch nicht gelesen wurde); WHEN ein Körper über 56 KiB an `/oauth/token` geht THEN antwortet die Bibliothek (4xx) und nicht `bridge` (deren 413 mit `connection: close` bleibt aus); WHEN 20 Aussteller-Antworten mit Status ≥ 500 gezählt werden (z. B. `productInteraction` 501 gilt nicht, ein erzwungener `server_error` der Bibliothek schon) und weniger als 50 % der Anfragen im 5-Minuten-Fenster erfolgreich sind THEN meldet `/health` 503 (Fehlerfenster zählt Aussteller-Antworten); Anfragen an `/health` selbst zählen nicht. Test: „oauth-provider: vor bridge und im fehlerfenster“.
- **AC-7:** Refresh rotiert: GIVEN ein Token-Paar aus AC-2 WHEN `POST /oauth/token` mit `grant_type=refresh_token` und dem Refresh-Token THEN antwortet der Dienst 200 mit einem **neuen** `access_token` und einem **neuen** `refresh_token` (beide ungleich den alten); das neue Access-Token lässt `get_now` an `/mcp` zu; WHEN das **alte** Refresh-Token erneut eingelöst wird THEN antwortet der Dienst 400 `invalid_grant`. Test: „oauth-provider: refresh rotiert, altes invalid_grant“.
- **AC-8:** Verifizierer streng: Tabellengetrieben, je Zeile `POST /mcp` mit `Authorization: Bearer …` THEN 401 mit `WWW-Authenticate` samt `resource_metadata` bei: unbekanntem Token; abgelaufenem Token (eingereichte Uhr hinter dem Ablauf); Token, dessen `aud` nicht `https://loose-ends.test/mcp` ist (direkt in `oauth_records` für eine andere Ressource angelegt); Token ohne `accountId`; widerrufenem Token (`revokeByGrantId`); Token eines gelöschten Kontos (`deleteAccount`). Ein gültiges Token mit `extra.account` des Kontos liefert 200. Test: „oauth-provider: verifizierer streng“.
- **AC-9:** App-Sitzungstoken gilt an `/mcp` weiter nicht: GIVEN ein Konto mit einer Sitzung aus `createSession` (App-Anmeldung `/auth/apple`-Weg) und der Dienst mit Schlüsseln (Verifizierer = `providerVerifier`) WHEN `POST /mcp` mit diesem Sitzungstoken THEN 401; ebenso ein Wert, der in `sessions` als SHA-256 steht. Test: „oauth-provider: app-sitzung an mcp weiter 401“.
- **AC-10:** Produkt-Interaction meldet niemanden an: GIVEN der Dienst ohne eingereichte Interaction (Standard) und ein gültiger `GET /oauth/auth` (CIMD, PKCE, Ressource) WHEN der Browser der Weiterleitung auf `/oauth/interaction/<uid>` folgt (auch mit gesetztem Cookie, mit `POST` und mit beliebigen Formularfeldern wie `login=…&password=…`) THEN antwortet die Interaction fest mit 501 und einem Text ohne Werte; in `oauth_records` entsteht nie ein Grant, ein Code oder ein Token, und `account_id` bleibt in jeder Zeile `NULL`; ein Aufruf von `/oauth/token` mit erfundenem Code antwortet `invalid_grant`. Test: „oauth-provider: produkt-interaction meldet niemanden an“.
- **AC-11:** Dev-Anmeldung aus: GIVEN der Dienst WHEN `GET /oauth/interaction/anything`, `POST /oauth/interaction/anything/login` und `…/confirm` ohne gültige Interaction THEN keine Antwort 200 und kein Formular der Bibliothek (die Standardseiten von `devInteractions` existieren nicht); `provider.configuration().features.devInteractions.enabled` ist `false`. Test: „oauth-provider: dev interactions aus“.
- **AC-12:** Schlüssel aus der Umgebung, tabellengetrieben für `oauthKeysFromEnv` und `main()`: (a) keine der beiden Variablen gesetzt → Rückgabe `undefined`; (b) beide gültig (Cookie-Schlüssel ≥ 32 Zeichen, auch als Liste mit Komma; ES256-JWK mit privatem Teil) → Objekt; (c) nur `OAUTH_COOKIE_KEYS` oder nur `OAUTH_SIGNING_JWK` gesetzt → wirft, Meldung nennt die fehlende Variable; (d) `OAUTH_COOKIE_KEYS` mit Schlüssel unter 32 Zeichen, `OAUTH_SIGNING_JWK` kein JSON, öffentlicher statt privater Schlüssel, falsche Kurve (RS256/P-384) → wirft, Meldung nennt den Variablennamen und enthält keinen Wert (Test setzt erkennbare Werte wie `geheim-cookie-schluessel-…` und prüft, dass sie nicht in `message` stehen). Test: „oauth-provider: schluessel aus der umgebung“.
- **AC-13:** Ohne Schlüssel ändert sich nichts: GIVEN `start()` ohne `oauth.keys` (und keine Variablen) WHEN `GET /.well-known/oauth-authorization-server`, `GET /oauth/auth?…`, `POST /oauth/token` THEN je 503 ohne Körper; `POST /mcp` mit beliebigem Bearer → 401 mit `resource_metadata` (Verifizierer bleibt `rejectAll`, auch für ein in `oauth_records` angelegtes gültiges Token); `GET /.well-known/oauth-protected-resource/mcp` und `/health` verhalten sich wie vor diesem Schnitt. Test: „oauth-provider: ohne schluessel 503 und mcp bleibt zu“.
- **AC-14:** Start bricht bei ungültigen Schlüsseln ab: GIVEN `main()` (Kindprozess, wie die bestehenden Start-Tests) mit `OAUTH_COOKIE_KEYS=zu-kurz` und gültigem `DATABASE_URL` WHEN gestartet THEN beendet er mit Exit-Code 1, die Ausgabe enthält `oauth config invalid: OAUTH_COOKIE_KEYS` und nicht den Wert, und es wurde weder Pool noch Port geöffnet; dasselbe für nur `OAUTH_SIGNING_JWK` gesetzt (Name `OAUTH_COOKIE_KEYS` als fehlend) und für ungültiges JWK (Name `OAUTH_SIGNING_JWK`). Test: „main: ungueltige oauth schluessel brechen start ab“ (in `server/test/main.test.ts`, bei den bestehenden Start-Tests).
- **AC-15:** 503 vor `migrate`: GIVEN ein Dienst mit Schlüsseln, dessen `migrate` noch nicht fertig ist (Datenbank-Verbindung verzögert) WHEN `GET /.well-known/oauth-authorization-server` und `POST /oauth/token` THEN 503 ohne Körper; nach Abschluss von `migrate` antworten dieselben Aufrufe fachlich (AC-1, AC-2). `GET /.well-known/oauth-protected-resource/mcp` und `/health` verhalten sich wie bisher (Metadaten ohne Datenbank nicht gegated). Test: „oauth-provider: 503 vor migrate“.
- **AC-16:** Nichts im Log, auch nicht bei FK-Fehler: GIVEN der Mitschnitt von `console.*`, `process.stdout`, `process.stderr` und der Ausgabe von `logError` über die Fälle AC-1 bis AC-15 WHEN zusätzlich ein Durchlauf, dessen Konto zwischen Anmeldung und Grant gelöscht wird (`upsert` wirft FK `23503`, `detail` nennt die Konto-ID) THEN endet der Ablauf ohne Code und ohne Token mit `server_error` oder einer Fehlerseite der Bibliothek, und der Mitschnitt enthält weder ein Access-Token, Refresh-Token, einen Code, `code_verifier`, Cookie-Schlüssel, das JWK noch die Konto-ID noch `detail` des Postgres-Fehlers; erlaubt sind nur feste Ereignisnamen. Test: „oauth-provider: nichts im log, auch nicht beim fk fehler“.
- **AC-17:** Abhängigkeit und Gesamtlauf: `server/package.json` führt `oidc-provider` exakt `9.13.3` in `dependencies` und `@types/oidc-provider` exakt `9.13.1` in `devDependencies` (kein `^`, kein `~`; Test liest die Datei), das Lockfile ist passend (`npm ci` gelingt), und `./server/scripts/test-local.sh` (typecheck + alle Tests, einschließlich aller Altfälle aus S1/S2 und `main.test.ts`) ist grün und räumt auf. Dateigrenze und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Nachweis: `./server/scripts/test-local.sh`, CI `server.yml` (Job `image` baut weiter) und `/60-validate`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/oauth-provider.ts` | CREATE | `createProvider`, `providerVerifier`, `oauthKeysFromEnv`, `productInteraction`, ≈ 150 |
| `server/src/main.ts` | MODIFY | `StartOptions.oauth` erweitert, Aussteller-Pfade vor `bridge`, 503-Regeln, Fehlerfenster, Verifizierer, `main()` liest Schlüssel, ≈ +40 |
| `server/package.json` + `server/package-lock.json` | MODIFY | `oidc-provider` 9.13.3, `@types/oidc-provider` 9.13.1 (dev), +2 Zeilen; das Lockfile zählt nicht als Code |
| `server/test/oauth-provider.test.ts` | CREATE | AC-1 bis AC-13, AC-15, AC-16, ≈ 450–550 |
| `server/test/main.test.ts` | MODIFY | AC-14 (Start-Abbruch); dazu Altfälle, falls sie `/oauth/*` oder Discovery als 404 erwarten |
| `server/src/oauth-adapter.ts` | MODIFY (möglich) | nur falls das Spike-Gate Abweichungen von `PgAdapter` zeigt (`consumed`-Format, `findByUid` ohne `jti`); dann sechste Datei, wird im Abschlussbericht benannt |

### Estimated Changes

- **Files: 5 bis 6** (Code: `oauth-provider.ts`, `main.ts`, `package.json`; Tests: `oauth-provider.test.ts`, `main.test.ts`; sechste Datei `oauth-adapter.ts` nur bei Abweichung). Lockfile, `CLAUDE.md`, ADR-Nachtrag, Spec und Kontext zählen nicht.
- **Code ≈ +190–220 LoC**, **Tests ≈ 450–550 LoC** (≈ 2,5× Code, offen genannt wie in S1/S2), insgesamt ≈ 650–770 LoC.
- **Das 250-LoC-Limit wird insgesamt überschritten.** Die Überschreitung stammt aus Sicherheitstests (voller Durchlauf, PKCE, CIMD, Ressource, Rotation, Verifizierer, Log); der Code-Anteil allein bleibt innerhalb des Limits. Das folgt der Projekt-Präzedenz #615 S2a, #621 S1 und S2 (Freigabe vor dem Bauen). Eine Teilung in S3a (Provider und Einhängen) und S3b (Verifizierer und Durchlauf) wurde geprüft und verworfen: S3a hätte keinen Nachweis, dass ein Token an `/mcp` ankommt, also den „halben Weg“, den das Spike-Gate verhindern soll. Mit der Freigabe dieser Spec wird die Überschreitung ausdrücklich angenommen.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Migration, kein `generate`. **Kein Pfad der Geräteliste berührt.**
- Seiteneffekte nach außen: keine, solange die zwei neuen Variablen im Betrieb fehlen (Aussteller 503, `/mcp` bleibt zu) und nginx nur `/health` durchlässt (bis S6).

## Risiken

- **Experimentelles CIMD** (draft-02): API kann sich in Minor-Versionen ändern. Gegenmaßnahme: Version exakt gepinnt, `ack` gesetzt, AC-2 bis AC-5 fangen eine Änderung beim Update.
- **Neue große Abhängigkeit** (≈ 34 Pakete, koa): siehe „Freigabe der neuen Abhängigkeit“; Aufnahme nur nach PO-Freigabe.
- **Aussteller-Pfade umgehen `bridge` und `dispatch`:** Fehlerfenster und 503-Regeln müssen eigens gelten (AC-6, AC-15); eine neue eigene Körpergrenze (56 KiB der Bibliothek) gilt statt der 1 MiB der Brücke.
- **Fehlerobjekte der Bibliothek tragen Werte** (FK `23503`: Konto-ID im `detail`): nie loggen, nur feste Ereignisnamen (AC-16).
- **Abweichung des `PgAdapter` von der echten Bibliothek:** das Spike-Gate (AC-2, AC-3) zeigt sie; Korrektur in S3 und Benennung im Abschlussbericht (mögliche sechste Datei).
- **Claude Code** (Loopback ohne Port, kein `application_type: native` im öffentlichen Dokument) scheitert vorerst am Rücksprung; bekannt, nicht Ziel dieses Schnitts, kein Test erwartet Erfolg.
- **URL des claude.ai-Web-CIMD unbekannt:** `allowFetch` nach Host `claude.ai`; die exakte URL liest S6 beim echten Verbinden ab und kann `allowFetch` dann verengen.
- **Flüchtige Schlüssel:** Ohne die Variablen laufen weder Aussteller noch Anmeldung; mit gesetzten Variablen sind Wechsel der Cookie-Schlüssel (Komma-Liste) möglich, ein Wechsel des Signierschlüssels invalidiert nur `id_token`/Sitzungen, nicht die opaken Token.

## Test Plan

### Automated Tests (TDD RED)

RED: `server/src/oauth-provider.ts` existiert nicht, `oidc-provider` ist nicht installiert; die Tests schlagen fehl (fehlender Import, Aussteller-Pfade antworten 404, `/mcp` bleibt bei `rejectAll`).

| Testname | AC |
|---|---|
| „oauth-provider: metadaten unter beiden pfaden“ | AC-1 |
| „oauth-provider: voller durchlauf bis get_now“ | AC-2 |
| „oauth-provider: code nur einmal“ | AC-3 |
| „oauth-provider: ohne pkce abgelehnt“ | AC-4 |
| „oauth-provider: cimd und resource streng“ | AC-5 |
| „oauth-provider: vor bridge und im fehlerfenster“ | AC-6 |
| „oauth-provider: refresh rotiert, altes invalid_grant“ | AC-7 |
| „oauth-provider: verifizierer streng“ | AC-8 |
| „oauth-provider: app-sitzung an mcp weiter 401“ | AC-9 |
| „oauth-provider: produkt-interaction meldet niemanden an“ | AC-10 |
| „oauth-provider: dev interactions aus“ | AC-11 |
| „oauth-provider: schluessel aus der umgebung“ | AC-12 |
| „oauth-provider: ohne schluessel 503 und mcp bleibt zu“ | AC-13 |
| „main: ungueltige oauth schluessel brechen start ab“ | AC-14 |
| „oauth-provider: 503 vor migrate“ | AC-15 |
| „oauth-provider: nichts im log, auch nicht beim fk fehler“ | AC-16 |
| `./server/scripts/test-local.sh`, `package.json`-Pinnung, `/60-validate` (Dateiliste per `git diff`) | AC-17 |

- [ ] Test 1 (AC-1, AC-12, AC-13, AC-14, AC-15): GIVEN Schlüssel gesetzt, fehlend oder ungültig, Migration fertig oder nicht WHEN Start und Discovery THEN Metadaten laut Vorgabe, sonst 503 bzw. Abbruch mit Variablennamen.
- [ ] Test 2 (AC-2, AC-3, AC-7): GIVEN `PgAdapter`, CIMD-`fetch`, Test-Interaction WHEN Anmeldung, Token, `get_now`, Code-Wiederholung, Refresh THEN Token für genau dieses Konto, Code einmalig, Refresh rotiert, altes Refresh `invalid_grant`.
- [ ] Test 3 (AC-4, AC-5): GIVEN fehlerhafte Anfragen WHEN `/oauth/auth` THEN ohne PKCE, fremder CIMD-Host, falscher Rücksprung und fremde `resource` abgelehnt.
- [ ] Test 4 (AC-6): GIVEN Aussteller-Pfade WHEN Körper klein, groß, Fehlerserie THEN Körper ungelesen an die Bibliothek, Status im Fehlerfenster.
- [ ] Test 5 (AC-8, AC-9): GIVEN verschiedene Token WHEN `/mcp` THEN nur gültige Aussteller-Token für `<publicUrl>/mcp` gelten, App-Sitzung nie.
- [ ] Test 6 (AC-10, AC-11): GIVEN Produkt-Interaction WHEN Anmeldeversuche THEN niemand angemeldet, kein Grant, kein Code, keine Dev-Seiten.
- [ ] Test 7 (AC-16): GIVEN Mitschnitt und gelöschtes Konto mitten im Ablauf WHEN FK-Fehler THEN Ablauf endet neutral, Log ohne Werte.
- [ ] Test 8 (AC-17): GIVEN fertiger Stand WHEN `./server/scripts/test-local.sh` THEN typecheck und alle Tests grün, Pinnung stimmt.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): `oidc-provider` + CIMD** | Bibliothek einbetten, claude.ai weist sich per Dokument aus | Durchstich grün; CIMD, PKCE, Ressource, Rotation fertig; zertifiziert; ADR-21 „nie selbst schreiben“ | neue Abhängigkeit (≈ 34 Pakete, koa); CIMD experimentell (draft-02), daher exakt gepinnt | — |
| B `oidc-provider` + DCR | dieselbe Bibliothek, Clients registrieren sich offen (claude.ai fällt ohne CIMD darauf zurück) | nicht experimentell | offener Registrier-Endpunkt schreibt fremde Clients in die Datenbank (Missbrauch, Aufräumen), Erlaubnisliste schwerer | die Wahl „CIMD statt DCR“ dieser Spec; Zeilen für Clients in `oauth_records` ohne Ablauf müssten aufgeräumt werden |
| C Eigenbau auf dem SDK | `@modelcontextprotocol/server` 2.4.0 hat **keinen** Aussteller (geprüft) | keine neue Abhängigkeit | PKCE, Rotation, Replay, CIMD selbst geschrieben, genau die Fehlerklasse, die ADR-21 ausschließt | ADR-21 „OAuth nie selbst schreiben“ |
| D Supabase Auth (ADR-21-Rückfall) | fremder Aussteller | nichts selbst betreiben | kein CIMD; Konten lägen außerhalb (das `apple_sub`-Modell aus #615 doppelt); S1/S2 (`oauth_records`) wären verworfen | ADR-21 „eigener Dienst statt Supabase“ (Weg B aus #612) und die Ablage aus S2 |

Befunde gegen den Plan: keine blockierenden. Nicht gewählte Unterfrage „Signierschlüssel weglassen, weil Token opak sind“: verworfen, weil die Bibliothek dann flüchtige Dev-Schlüssel erzeugt (Warnung, Zustand nach Neustart anders) und `openid` in `scopes_supported` steht.

## Out of Scope / Folgeschnitte

- **Apple-Anmeldung in der Interaction (S4a Apple-Web-Flow, S4b Anbindung):** Die Produkt-Interaction meldet niemanden an (AC-10); S4b ersetzt sie durch Apple → `findOrCreate` → `interactionFinished`. Die Test-Interaction bleibt nur in Tests.
- **Zustimmungsseite und Erlaubnisliste (S5):** Zustimmung mit Host der `client_id`-URL, Erlaubnisliste der Clients; hier nur der grobe Host-Filter `claude.ai` in `allowFetch`.
- **nginx-Freigabe und Compose-Env (S6):** `/mcp`, `/.well-known/*`, `/oauth/*` durchlassen, `OAUTH_COOKIE_KEYS`, `OAUTH_SIGNING_JWK` in Compose (Repo `henemm-infra`), echter Connect mit claude.ai und Ablesen der exakten CIMD-URL.
- **Claude Code** (Loopback-Rücksprung ohne Port, `applicationType: native`): kein Ziel dieses Schnitts, `allowFetch` lässt nur claude.ai-Hosts zu.
- **S7 Abschrift v2** und alles in `mcp.ts`: unberührt.

## Abnahme

Kein Pfad der Geräteliste berührt (nur `server/`, keine App, kein `project.yml`). Die Abnahme endet nach den Tests: `./server/scripts/test-local.sh` (typecheck + `npm test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün. Sichtbar ändert sich nichts; `/mcp` bleibt öffentlich hinter nginx zu, der Aussteller antwortet ohne gesetzte Schlüssel 503. Stufe 3 entfällt.

## Definition of Done

- [ ] PO-Freigabe der Abhängigkeit `oidc-provider` 9.13.3 / `@types/oidc-provider` 9.13.1 liegt vor
- [ ] AC-1 bis AC-17 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `src/oauth-provider.ts` und die zwei neuen Variablen; ADR-21 in `docs/project/00-entscheidungen.md` trägt den Nachtrag (Dokumentation, zählt nicht gegen die Dateigrenze)
- [ ] #621 kommentiert (Stand Schnitt 3, Folge: S4a/S4b Apple-Interaction), Board-Karte aktuell

## Changelog

- 2026-11-06: Initial spec created (Schnitt 3)
