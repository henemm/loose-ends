---
entity_id: feat-621-schnitt-1-ressourcenseite
type: feature
created: 2026-11-05
updated: 2026-11-05
status: draft
workflow: feat-621-mcp-anmeldung
---

# Spec: Ressourcenseite für die MCP-Anmeldung, Schnitt 1 (#621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 1; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-mcp-anmeldung.md` (Abschnitte „Recherche“, „Analysis“, „Schnittplan“, „Affected Files (S1)“). Vorgänger: #613 C4a/C4b (`server/src/mcp.ts`, Konto aus `authInfo`), #615 (Konten, Sitzungen), #796 S4a (nginx lässt `/mcp` öffentlich noch 404).

## Für den PO

Dieser Schnitt bringt Loose Ends bei, an der Tür für Claude zu sagen: „Bitte erst anmelden, hier steht, wo.“ Damit kann claude.ai später den Knopf „Verbinden“ zeigen; ohne diese Antwort zeigt es ihn nicht. Von außen ändert sich noch nichts: Die Adresse ist öffentlich weiter zu, und es gibt noch keine Stelle, an der man sich anmelden könnte, also nimmt die Tür vorerst niemanden herein. Das eigentliche Anmelden folgt in späteren Schnitten. Deine Daten sind nicht berührt, und die App ruft diese Tür nicht auf.

## Purpose

Der Dienst wird zur „Ressourcenseite“ nach der MCP-Autorisierung (RFC 9728 Protected Resource Metadata, RFC 8707 Resource Indicators, RFC 6750 Bearer): `/mcp` verlangt ein Bearer-Token und antwortet sonst 401 mit `WWW-Authenticate`, das auf ein Metadaten-Dokument zeigt, das den Aussteller nennt. Ein geprüftes Token reicht sein Konto über `authInfo.extra.account` an die Werkzeuge in `mcp.ts` durch. Es gibt noch **keinen Aussteller (AS)**, kein Apple, keine Migration, keine neue Abhängigkeit: Der Standard-Verifizierer lehnt jedes Token ab; Tests reichen einen eigenen ein. Schnitt 1 legt damit die `authInfo`-Leitung, die jeder Folgeschnitt braucht, unabhängig von der AS-Wahl.

**Regeln vor Modell:** Protokollarbeit ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Quelle (Recherche 2026-11-05, aus der Analyse): claude.ai startet die Anmeldung nur bei 401 mit `WWW-Authenticate` (200 mit `isError` zeigt keinen Verbinden-Knopf) und liest dann das Metadaten-Dokument; nur der erste `authorization_servers`-Eintrag zählt (https://claude.com/docs/connectors/building/authentication.md, …/troubleshooting.md). Die MCP-Spezifikation (Revision 2026-07-28, https://modelcontextprotocol.io/specification/versioning, …/2026-07-28/basic/authorization) verlangt das Metadaten-Dokument nach RFC 9728 (pfadbezogen `/.well-known/oauth-protected-resource/mcp`), Audience-Bindung nach RFC 8707 und Token nur im Header; die Ressourcenseite ist in der Revision 2025-11-25, die claude.ai spricht, dieselbe.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Ressourcenseite nach MCP-Spezifikation mit Bausteinen des SDK (`requireBearerAuth`, `getOAuthProtectedResourceMetadataUrl`); ADR-21 bleibt unberührt. Der ADR-21-Nachtrag zur Wahl des Ausstellers (Supabase hat kein CIMD, `oidc-provider` gewählt) folgt mit dem Schnitt, der den Aussteller einbaut (S3).
- **Rationale:** (1) Die Ressource kommt aus der Konfiguration (`publicUrl` + `/mcp`), nie aus `request.url`: Der `bridge` baut dort `http://<host>`, hinter nginx wäre das falsch, und ein Host-Header darf die Audience nicht verschieben. (2) Das SDK prüft Audience, Ablauf und Header-Format bereits; eine eigene Bearer-Prüfung würde dasselbe schlechter nachbauen. (3) Den Standard-Verifizierer ohne Aussteller auf „alles ablehnen“ zu stellen, hält App-Sitzungstoken aus `createSession` von `/mcp` fern (kein Token-Passthrough) und macht den Zustand vor S3 eindeutig.

## Source

**Files:** `server/src/oauth-resource.ts` (neu), `server/src/main.ts` (ändern), `server/test/oauth-resource.test.ts` (neu), `server/test/main.test.ts` (bestehende Tests umstellen), `CLAUDE.md`
**Identifier:** `resourceFor`, `metadataRoute`, `bearerGate`, `rejectAll`, `publicUrlFromEnv`, `StartOptions.oauth`

### Schnittstelle

- **`server/src/oauth-resource.ts`** (rein, ohne Datenbank, ohne Umgebungslese):
  - `DEFAULT_PUBLIC_URL = "https://loose-ends.henemm.com"`.
  - `resourceFor(publicUrl: string): URL` liefert `new URL("/mcp", publicUrl)`; die Metadaten-URL ist `getOAuthProtectedResourceMetadataUrl(resource)` und lautet `<publicUrl>/.well-known/oauth-protected-resource/mcp` (pfadbezogen).
  - `rejectAll: OAuthTokenVerifier`: `verifyAccessToken` wirft immer `new OAuthError(OAuthErrorCode.InvalidToken, …)`; der Standard in S1, weil es noch keinen Aussteller gibt.
  - `metadataRoute(publicUrl): Route`: nur `GET`; 200, `content-type: application/json`, Körper genau `{ "resource": "<publicUrl>/mcp", "authorization_servers": ["<issuer>"], "bearer_methods_supported": ["header"] }`; jede andere Methode (auch `HEAD`, `POST`) 405 mit `Allow: GET` und ohne Körper. Kein CORS-Header: claude.ai holt die Metadaten serverseitig. `issuer` ist der Origin der `publicUrl` (`https://loose-ends.henemm.com`, ohne Pfad, ohne Schrägstrich am Ende).
  - `bearerGate(publicUrl, verifier): (request) => Promise<AuthInfo | Response>` baut `requireBearerAuth({ verifier, expectedResource: resourceFor(publicUrl), resourceMetadataUrl })` aus dem SDK; ein `Response` ist eine fertige Ablehnung, ein `AuthInfo` ein geprüftes Token.
  - `publicUrlFromEnv(env): string`: `PUBLIC_URL` leer oder fehlend (auch nur Leerzeichen) → `DEFAULT_PUBLIC_URL`; gültige `https://`-URL ohne Pfad, Anfrage-Teil und Fragment → ihr Origin; `http://localhost` und `http://127.0.0.1` (mit oder ohne Port) → erlaubt (für Tests und lokale Läufe); alles andere (nicht lesbar, `http://` fremd, Pfad, Anfrage, Fragment, Zugangsdaten in der URL) → wirft `Error("PUBLIC_URL invalid")` ohne den Wert zu nennen.
- **`StartOptions`** erhält `oauth?: { publicUrl?: string; verifier?: OAuthTokenVerifier }`. Standard: `publicUrl = DEFAULT_PUBLIC_URL`, `verifier = rejectAll`. `start()` liest keine Umgebung.
- **Routentabelle** in `start()`: `{ ...mountAuth, ...extraRoutes, "/.well-known/oauth-protected-resource/mcp": metadataRoute(publicUrl), "/health": …, "/mcp": gated(isReady, mcpWithBearer) }`. Metadaten-Route, `/health` und `/mcp` stehen zuletzt und sind weder durch `auth` noch durch `extraRoutes` überschreibbar. Die Metadaten-Route ist **nicht** gated (braucht keine Datenbank) und antwortet auch vor `migrate`.
- **`/mcp`**: `gated(isReady, route)` außen (vor `migrate` weiter 503 ohne Körper), innen `const checked = await gate(request); return checked instanceof Response ? checked : mcp.fetch(request, { authInfo: checked })`.
- **`main()`**: ruft nach `DATABASE_URL` und `appleConfigFromEnv` die Funktion `publicUrlFromEnv(process.env)`; wirft sie, schreibt `main()` genau die Logzeile `public url invalid` über `logError` und beendet mit Exit 1 vor Pool und Listen (Muster wie `apple config invalid`). Sonst `start({ …, oauth: { publicUrl } })`.

### Festlegungen

- **Gemessenes Verhalten des SDK-Prüftors** (selbst geprüft am 2026-11-05 mit `@modelcontextprotocol/server` 2.4.0; die ACs halten es fest): ohne Header 401 mit `WWW-Authenticate: Bearer error="invalid_token", error_description="Missing Authorization header", resource_metadata="https://loose-ends.henemm.com/.well-known/oauth-protected-resource/mcp"` und OAuth-Fehler-JSON im Körper; `Basic x` 401 mit demselben Header-Typ; unbekanntes Token 401; Token mit `resource` eines anderen Dienstes 401 „Token was not issued for this resource“; Token ohne `expiresAt` 401 „Token has no expiration time“; wirft der Verifizierer einen Nicht-`OAuthError`, antwortet das SDK 500 `server_error`; ein gültiges Token ergibt `AuthInfo` mit `extra` unverändert.
- **Bewusste Abweichung von der Hausregel „Ablehnung schlicht“** der `/auth/*`-Routen (401 ohne Körper): Der 401-Körper an `/mcp` ist das OAuth-Fehler-JSON des SDK, weil MCP-Clients den Fehlercode lesen und `WWW-Authenticate` zwingend ist. Das Log bleibt dennoch ohne Inhalt: kein Token, keine Konto-ID, kein Wert aus Anfrage oder Verifizierer.
- **Fehlerfenster:** 401 zählt wie jede Antwort unter 500 nicht ins Fehlerfenster (`health.ts` zählt nur ≥ 500); ein werfender Verifizierer (500) zählt, wie jeder 500.
- **Aussteller (`issuer`)** ist festgelegt auf den Origin der `publicUrl`; er muss in S3 exakt dem `issuer` des Ausstellers gleichen (RFC 8414 verlangt Gleichheit). Die AS-Metadaten unter `/.well-known/oauth-authorization-server` kommen mit S3; in S1 antwortet dieser Pfad 404.
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; keine neuen Pakete; kein `console.*` in `oauth-resource.ts`.
- **Unberührt:** `mcp.ts`, `auth.ts`, `accounts.ts`, alle `apple*.ts`, Migrationen, `package.json` und Lockfile, jede Swift-Datei, `.github/`, nginx in `henemm-infra`, `server/test/mcp.test.ts`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `requireBearerAuth`, `getOAuthProtectedResourceMetadataUrl`, `OAuthError`, `OAuthErrorCode`, `OAuthTokenVerifier`, `AuthInfo` aus `@modelcontextprotocol/server` 2.4.0 | bestehend, **keine neuen Pakete** |
| `mcpHandler` (`mcp.ts`, Konto aus `ctx.http?.authInfo?.extra?.account`) | bestehend, unverändert |
| `gated`, `Route`, `start()` (`main.ts`) | bestehend, erweitert |
| `createSession`, `findOrCreate` (`accounts.ts`), `putTranscript` (`transcripts.ts`) | bestehend, nur in Tests benutzt |
| Downstream | S2 Ablage, S3 Aussteller (`verifier` an AccessToken, AS-Metadaten, ADR-21-Nachtrag), S6 nginx öffnet `/mcp` und `/.well-known/*` |

## Acceptance Criteria

Neue Tests in `server/test/oauth-resource.test.ts` mit `node:test` und `node:assert/strict`, gegen `start()` mit Wegwerf-Postgres (Aufbau wie `service(t, options)` in `main.test.ts`, eigene Kopie des Helfers in der neuen Datei); Test-Verifizierer eingereicht, der ein Token-Muster auf `AuthInfo` abbildet (`token`, `clientId`, `scopes`, `expiresAt` in Sekunden, `resource`, `extra: { account }`). Ablehnungsfälle tabellengetrieben, ein Fall je Zeile. `<RESOURCE>` steht für `https://loose-ends.henemm.com/mcp`, `<META>` für `https://loose-ends.henemm.com/.well-known/oauth-protected-resource/mcp`.

- **AC-1:** Metadaten-Dokument: `GET /.well-known/oauth-protected-resource/mcp` antwortet 200 mit `content-type: application/json` und einem Körper, der als JSON genau gleich `{ "resource": "<RESOURCE>", "authorization_servers": ["https://loose-ends.henemm.com"], "bearer_methods_supported": ["header"] }` ist (`deepEqual`, keine weiteren Schlüssel); kein `access-control-allow-origin`-Header. Test: „oauth-resource: metadaten dokument“.
- **AC-2:** Metadaten nur lesend: `POST`, `PUT`, `DELETE` und `HEAD` auf dieselbe URL antworten je 405 mit Header `Allow: GET` und leerem Körper (tabellengetrieben, eine Methode je Zeile). Test: „oauth-resource: metadaten nur get“.
- **AC-3:** Metadaten vor `migrate`: Ist die Datenbank nicht erreichbar (wie S1-AC-2 in `main.test.ts`), antwortet `GET <META>` trotzdem 200 mit dem Dokument aus AC-1, während `/mcp` 503 ohne Körper antwortet (nicht 401). Nach `ready` antwortet `/mcp` ohne Token 401. Test: „oauth-resource: metadaten vor migrate“.
- **AC-4:** `/mcp` ohne Token: `POST /mcp` ohne `Authorization`-Header antwortet 401; der Header `WWW-Authenticate` beginnt mit `Bearer`, enthält `error="invalid_token"` und genau `resource_metadata="<META>"`; der Körper ist JSON mit `error: "invalid_token"`. Der Aufruf erreicht `mcp.fetch` nicht (kein MCP-Antwortkörper). Test: „oauth-resource: mcp ohne token 401“.
- **AC-5:** Ablehnungstabelle am Prüftor, je Zeile eine Anfrage an `/mcp` mit dem Test-Verifizierer: (a) `Authorization: Basic eDp4` → 401 mit `WWW-Authenticate`-Typ `Bearer`; (b) `Bearer unbekannt` (Verifizierer wirft `OAuthError InvalidToken`) → 401; (c) gültiges Token, aber `resource` = `https://anderer.example/mcp` → 401, Beschreibung nennt „not issued for this resource“; (d) gültiges Token, aber `resource` fehlt → 401; (e) gültiges Token ohne `expiresAt` → 401, Beschreibung nennt „no expiration time“; (f) abgelaufenes Token (`expiresAt` in der Vergangenheit) → 401. Jede 401 trägt `resource_metadata="<META>"`. Test: „oauth-resource: ablehnungstabelle“.
- **AC-6:** Verifizierer wirft Nicht-`OAuthError`: Antwort 500 (OAuth-Fehler `server_error`), im Fehlerfenster gezählt; die gesammelten Logzeilen enthalten weder das Token noch den Text der Ausnahme. Test: „oauth-resource: verifizierer wirft 500“.
- **AC-7:** App-Sitzungstoken wird nie angenommen: Mit dem **Standard-Verifizierer** (`oauth` ohne `verifier`) antwortet `/mcp` für ein echtes Token aus `createSession(pool, accountId)` (Konto über `findOrCreate`) 401 mit `resource_metadata="<META>"`; ebenso für beliebige andere Token-Zeichenfolgen. Test: „oauth-resource: app-sitzung abgelehnt“.
- **AC-8:** Gültiges Token reicht das Konto durch: Mit eingereichtem Test-Verifizierer (`extra.account` = Konto A, `resource` = `<RESOURCE>`, `expiresAt` in der Zukunft) verbindet ein MCP-Client (`StreamableHTTPClientTransport` mit `requestInit.headers.Authorization = "Bearer …"`); ist über `putTranscript` die Abschrift für A vorbereitet, liefert `get_now` genau deren Jetzt-Zeilen; ohne vorbereitete Abschrift liefert es „noch keine Abschrift“ ohne `isError`. Test: „oauth-resource: konto durchgereicht“.
- **AC-9:** Kein Mitlesen über Konten: Zwei Tokens (Konto A und Konto B, je mit eigener Abschrift über `putTranscript`) lesen über `get_now` jeweils nur die eigene Abschrift; die Antwort für A enthält keine Kennung aus B und umgekehrt. Test: „oauth-resource: konten getrennt“.
- **AC-10:** Reihenfolge vor `migrate`: Vor `migrate` antwortet `/mcp` auch mit einem gültigen Test-Token und auch ohne Token 503 ohne Körper (der Verifizierer wird nicht aufgerufen, Zähler 0); danach greift die Prüfung. Test: „oauth-resource: mcp vor migrate 503“.
- **AC-11:** Ressource aus der Konfiguration, nicht aus der Anfrage: Mit `oauth: { publicUrl: "http://127.0.0.1" }` (Testfall) stehen `resource` im Dokument und `resource_metadata` im Header auf dieser URL (`http://127.0.0.1/mcp` bzw. `http://127.0.0.1/.well-known/oauth-protected-resource/mcp`); ein abweichender `Host`-Header (`evil.example`) ändert weder das Dokument noch den Header noch die geprüfte Audience (ein Token mit `resource = http://evil.example/mcp` wird abgelehnt). Test: „oauth-resource: ressource folgt public url“.
- **AC-12:** `publicUrlFromEnv`, tabellengetrieben, ein Fall je Zeile: leer, fehlend und nur Leerzeichen → `https://loose-ends.henemm.com`; `https://loose-ends.henemm.com` → derselbe Wert; `https://example.org/` → `https://example.org`; `http://localhost:8080` und `http://127.0.0.1` → erlaubt (Origin zurück); `http://example.org`, `https://example.org/pfad`, `https://example.org/?a=1`, `https://example.org/#x`, `https://nutzer:pw@example.org`, `kein-url` → wirft `Error` mit der Meldung `PUBLIC_URL invalid`, in der der gesetzte Wert nicht vorkommt. Test: „oauth-resource: public url aus env“.
- **AC-13:** Abbruch im Prozess: Ein Kindprozess (`main.ts`, `DATABASE_URL` gesetzt, Muster aus `main.test.ts` „einhaengen: prozess bricht bei falscher config ab“) mit `PUBLIC_URL=http://example.org` endet mit Exit-Code 1, ohne zu lauschen und ohne den Pool zu öffnen; die Ausgabe enthält die Zeile `public url invalid` und nicht den Wert `example.org`. Ein Kindprozess ohne `PUBLIC_URL` startet, lauscht und antwortet `GET <META>` mit dem Standard-Dokument (nach `SIGTERM` Exit 0). Test: „oauth-resource: prozess bricht bei falscher public url ab“.
- **AC-14:** Nicht überschreibbar: `extraRoutes` mit den Schlüsseln `/.well-known/oauth-protected-resource/mcp` und `/mcp` (Funktionen, die 418 liefern) ändern nichts: `GET <META>` liefert das Dokument aus AC-1, `/mcp` ohne Token 401. `GET /.well-known/oauth-authorization-server` antwortet 404 (kein Aussteller in S1). Test: „oauth-resource: nicht ueberschreibbar“.
- **AC-15:** Umgestellte bestehende Tests in `server/test/main.test.ts`, ohne eine Prüfung zu schwächen: (a) „AC-3 (S1)“ (Zeile ~98): `/mcp` ohne Token → 401 mit `WWW-Authenticate`; mit eingereichtem Test-Verifizierer ohne `extra.account` verbindet der Client, `serverInfo.name === "loose-ends"`, und `get_now` liefert weiter `isError` mit „kein Konto“; (b) „einhaengen: health und mcp nicht ueberschreibbar“ (Zeile ~551): der Client verbindet nur mit Test-Verifizierer und Bearer-Header, `/mcp` ohne Token bleibt 401 statt 418; (c) „einhaengen: body ueber 1 mib 413“ (Zeilen ~486, ~503): die Prüfung `status !== 413` bei genau 1 MiB bleibt unverändert und trifft nun 401, die 413-Fälle bleiben unberührt; die Tests bei Zeile ~92 und ~337 (503 vor `migrate`) bleiben unverändert. `server/test/mcp.test.ts` bleibt unberührt. Test: die genannten Testfälle in `main.test.ts`.
- **AC-16:** Grenze, Länge, Doku: `git diff --name-only origin/main -- . ':!docs' ':!.claude'` nennt genau `server/src/oauth-resource.ts`, `server/src/main.ts`, `server/test/oauth-resource.test.ts`, `server/test/main.test.ts` und `CLAUDE.md`; `mcp.ts`, `auth.ts`, `accounts.ts`, alle `apple*.ts`, `server/migrations/`, `server/package.json` und das Lockfile sind unverändert; jede Funktion hat höchstens 50 Zeilen; `./server/scripts/test-local.sh` (typecheck + alle Tests) ist grün und räumt auf. `CLAUDE.md` nennt im Abschnitt `server/` in einer Zeile `src/oauth-resource.ts` (Metadaten-Route, Prüftor, Standard-Verifizierer lehnt alles ab, `publicUrlFromEnv`, `/mcp` ohne Token 401, noch kein Aussteller). Test: „oauth-resource: grenze und doku“ (Prüfung per `git diff --name-only` und `grep` auf `CLAUDE.md`).

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/oauth-resource.ts` | CREATE | `resourceFor`, `rejectAll`, `metadataRoute`, `bearerGate`, `publicUrlFromEnv`, ≈ 60–80 |
| `server/src/main.ts` | MODIFY | `StartOptions.oauth`, Metadaten-Route in der Tabelle, `/mcp` hinter der Bearer-Prüfung mit `authInfo`, `publicUrlFromEnv` in `main()`, ≈ +30 |
| `server/test/oauth-resource.test.ts` | CREATE | AC-1 bis AC-14, Kindprozess für AC-13, ≈ 250 |
| `server/test/main.test.ts` | MODIFY | drei bestehende Testfälle auf das neue Verhalten umgestellt (AC-15), ≈ ±40 |
| `CLAUDE.md` | MODIFY | eine Zeile unter `server/` zu `oauth-resource.ts` |

### Estimated Changes

- **Files: 5** (Spec und Kontext zählen nicht). **Code ≈ +100–110 LoC** (innerhalb ≤ 250); **Tests ≈ 290** (Projekterfahrung: Tests ≈ 2,5× Code, hier offen genannt); Doku ≈ 2. Gesamt ≈ 400, davon die Tests der größte Teil; der Code-Anteil hält das Limit von ±250 ein, die Testmenge entspricht der bei #615 und #613 angenommenen Praxis.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine neuen Pakete, keine Migration, kein `generate`. Seiteneffekt außerhalb des Tickets: keiner nach außen, solange nginx `/mcp` nicht durchlässt.

## Risiken

- **`/mcp` ändert sein Verhalten ohne Token** von 200 mit `isError` auf 401: öffentlich ist `/mcp` in nginx noch 404 (#796 S4a), keine App ruft `/mcp`, niemand ist betroffen. Bis S3 kann sich niemand an `/mcp` anmelden (gewollt, AC-7).
- **Issuer festgelegt auf den Origin:** muss in S3 exakt dem `issuer` des Ausstellers gleichen (RFC 8414); Abweichung ist ein stiller Verbindungsfehler in claude.ai. Merkposten für S3.
- **Protokollrevision:** Die Revision 2026-07-28 ändert den Handshake (kein `initialize`), claude.ai spricht 2025-11-25. Die Ressourcenseite (Header, Metadaten) ist in beiden gleich; der Handshake wird im S3-Spike mit claude.ai geprüft (offene Frage der Analyse).
- **Ressource aus der Anfrage statt aus der Konfiguration:** ausgeschlossen durch Festlegung und AC-11.
- **Falsche `PUBLIC_URL` im Betrieb:** Eine ungültige Angabe stoppt den Start mit `public url invalid` (AC-13); eine gültige, aber falsche (anderer Host) bleibt bis zum Connect in S6 unbemerkt. Im Betrieb ist `PUBLIC_URL` heute nicht gesetzt, der Standard gilt.
- **Tests fälschen den Aussteller:** Der Test-Verifizierer prüft die Leitung (Prüftor → `authInfo` → Werkzeug), nicht echte Token; das echte Verhalten belegt erst S3 mit Claudes Client-Dokument und S6 mit dem echten Connect.
- **SDK-Verhalten bei einem Update:** Die gemessenen Antworten (Festlegungen) sind als Tests festgehalten (AC-4 bis AC-6) und fangen eine Änderung beim Aktualisieren des SDK.

## Test Plan

### Automated Tests (TDD RED)

RED: `server/src/oauth-resource.ts` und die Option `oauth` existieren nicht; die Tests schlagen fehl (404 auf die Metadaten-URL, `/mcp` ohne Token antwortet 200 statt 401, fehlender Import `publicUrlFromEnv`).

| Testname | AC |
|---|---|
| „oauth-resource: metadaten dokument“ | AC-1 |
| „oauth-resource: metadaten nur get“ | AC-2 |
| „oauth-resource: metadaten vor migrate“ | AC-3 |
| „oauth-resource: mcp ohne token 401“ | AC-4 |
| „oauth-resource: ablehnungstabelle“ | AC-5 |
| „oauth-resource: verifizierer wirft 500“ | AC-6 |
| „oauth-resource: app-sitzung abgelehnt“ | AC-7 |
| „oauth-resource: konto durchgereicht“ | AC-8 |
| „oauth-resource: konten getrennt“ | AC-9 |
| „oauth-resource: mcp vor migrate 503“ | AC-10 |
| „oauth-resource: ressource folgt public url“ | AC-11 |
| „oauth-resource: public url aus env“ | AC-12 |
| „oauth-resource: prozess bricht bei falscher public url ab“ | AC-13 |
| „oauth-resource: nicht ueberschreibbar“ | AC-14 |
| umgestellte Fälle in `main.test.ts` („AC-3 (S1)“, „einhaengen: health und mcp nicht ueberschreibbar“, „einhaengen: body ueber 1 mib 413“) | AC-15 |
| „oauth-resource: grenze und doku“ (`test-local.sh`, `git diff --name-only`, `grep`) | AC-16 |

- [ ] Test 1 (AC-1, AC-2, AC-3, AC-14): GIVEN Dienst mit und ohne erreichbare Datenbank WHEN GET und andere Methoden auf die Metadaten-URL THEN exakt das Dokument, 405 mit `Allow: GET`, vor `migrate` 200, nicht überschreibbar, AS-Metadaten 404.
- [ ] Test 2 (AC-4, AC-5, AC-6, AC-7): GIVEN Test-Verifizierer bzw. Standard-Verifizierer WHEN `/mcp` mit fehlendem, falschem, fremdem, abgelaufenem Token und App-Sitzungstoken THEN 401 mit `resource_metadata="<META>"`, bei werfendem Verifizierer 500 ohne Inhalt im Log.
- [ ] Test 3 (AC-8, AC-9, AC-10): GIVEN zwei Konten mit Abschrift WHEN MCP-Client mit Bearer-Token `get_now` ruft THEN jeweils nur die eigene Abschrift; vor `migrate` 503.
- [ ] Test 4 (AC-11, AC-12, AC-13): GIVEN `publicUrl`, abweichender Host-Header, Umgebungstabelle, Kindprozess WHEN Dokument, Header und Start geprüft werden THEN Konfiguration gewinnt, ungültige URL bricht mit Exit 1 ab.
- [ ] Test 5 (AC-15, AC-16): GIVEN die umgestellten Altfälle und der Gesamtlauf WHEN `./server/scripts/test-local.sh`, `git diff`, `grep` THEN grün, genau fünf Dateien, `CLAUDE.md` aktualisiert.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

- **A (gewählt): Eigene Metadaten-Route plus SDK-`requireBearerAuth`, Standard-Verifizierer lehnt alles ab, Ressource aus der Konfiguration.** Unabhängig von der AS-Wahl, kleinste Fläche, kein Aussteller nötig.
- **B: `oauthMetadataResponse` des SDK nutzen:** verworfen. Er lieferte zusätzlich `/.well-known/oauth-authorization-server`, für das es in S1 noch keinen Aussteller gibt; ein Dokument ohne Aussteller dahinter wäre irreführend.
- **C: Metadaten nur über `WWW-Authenticate`, ohne well-known-Route:** verworfen. Die Spezifikation verlangt das Dokument, und der Header verweist darauf.
- **D: Eigene Bearer-Prüfung statt SDK:** verworfen. Das SDK prüft Audience (RFC 8707), Ablauf und Header-Format bereits; eine Eigenprüfung wäre mehr Code und mehr Fehlerfläche.
- **E: Erst den Aussteller bauen, dann die Ressourcenseite:** verworfen. S1 ist von der AS-Wahl unabhängig, legt die `authInfo`-Leitung und lässt sich ohne Aussteller vollständig testen; der Aussteller ist der riskantere Schnitt (S3, Spike-Gate) und profitiert von einer fertigen Gegenstelle.
- **F: App-Sitzungstoken (`createSession`) an `/mcp` zulassen:** verworfen. Das wäre Token-Passthrough und vermischte „App-Sitzung“ mit „OAuth-Token“; AC-7 hält es fest.
- Befunde gegen den Plan: keine blockierenden. Die PO-Entscheidung zur AS-Wahl (ADR-21: `oidc-provider` statt Eigenbau) fällt erst mit S3.

## Nicht in diesem Schnitt / Folgeschnitte

- **S2 Ablage:** Migration 004, Adapter, `deleteAccount` löscht OAuth-Daten mit, Sitzungsablauf (Merkposten aus #615).
- **S3 Aussteller:** `oidc-provider` einhängen, Spike-Gate mit Claudes echtem Client-Dokument bis Token, ADR-21-Nachtrag, `verifier` an AccessToken, AS-Metadaten, Handshake-Prüfung der Revision.
- **S4a/S4b Apple-Web:** Services ID, `redirect_uri` beim Einlösen, Anmeldung über Apple.
- **S5 Zustimmung und Erlaubnisliste:** Zustimmungsseite je Client, nur Hennings Konto bis #625.
- **S6 Betrieb und echter Connect:** nginx und Compose in `henemm-infra` (`/mcp`, `/.well-known/*`, `/oauth/*`), Verbinden in claude.ai.
- **S7 Abschrift v2:** weitere Ansichten und Detailfelder (braucht #625).

## Abnahme

- Reine Dienständerung, keine App-Datei berührt, kein Simulator-Durchlauf nötig. Nachweis: `./server/scripts/test-local.sh` (typecheck + `npm test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün.
- Zusätzlich ein lokaler Probe-Lauf: Dienst mit Wegwerf-Postgres starten; `curl -i -X POST http://127.0.0.1:<port>/mcp` ohne Token zeigt 401 mit `WWW-Authenticate: Bearer …resource_metadata="…/.well-known/oauth-protected-resource/mcp"`; `curl -i http://127.0.0.1:<port>/.well-known/oauth-protected-resource/mcp` zeigt das Dokument aus AC-1.
- Stufe 3 entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-16 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün, lokaler Probe-Lauf belegt
- [ ] `CLAUDE.md` (`server/`-Abschnitt) nennt `src/oauth-resource.ts`
- [ ] #621 kommentiert (Stand Schnitt 1, Folge: S2 Ablage), Board-Karte aktuell

## Changelog

- 2026-11-05: Initial spec created (Schnitt 1)
