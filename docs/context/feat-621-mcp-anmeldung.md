# Context: feat-621-mcp-anmeldung

## Request Summary
#621 (Epic #612, Weg B): Claude verbindet sich in claude.ai (Web, Desktop, Mobil) als eigener Connector mit dem Dienst
`https://loose-ends.henemm.com/mcp`, meldet sich nach MCP-Vorgabe an (OAuth 2.1, PKCE) und liest Loose Ends: die Ansichten
Jetzt, Fällig, Als nächstes, Lose Enden, dazu Suche, Aufgabe mit Details, Projekte und Kontexte. DoD laut Ticket: in claude.ai
verbunden, die vier Ansichten liefern dasselbe wie die App für denselben Datenstand. Größe L, wird geschnitten.

Am 2026-11-05 von Henning gewählt (statt #795), weil der App-Teil von #615 (S4) auf den Datenschutztext #625 wartet.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/main.ts` | Routentabelle nur exakte Pfade (:63), Reihenfolge `mountAuth` → `extraRoutes` → `/health`, `/mcp` (:134-139); `/mcp` ruft `mcp.fetch(request)` **ohne** `authInfo` (:138); Body-Grenze 1 MiB (:30); `appleConfigFromEnv` (:34-37) |
| `server/src/mcp.ts` | Stateless `createMcpHandler`; Werkzeuge `get_now`, `list_tasks`, `capture_task`, `get_order_result`, `complete_task`, `set_due`; Konto aus `ctx.http?.authInfo?.extra?.account` (:13-16), heute nur im Test gesetzt (`server/test/mcp.test.ts:40-42`) |
| `server/src/auth.ts` | `bearerToken` (:21-24); `/auth/apple` ist der **native** App-Weg (Bundle-ID), kein Web-Ablauf |
| `server/src/accounts.ts` | `findOrCreate` über `apple_sub`, `createSession`/`resolveSession` (SHA-256, **kein Ablauf**), `deleteAccount` (:43-68) muss künftige OAuth-Tabellen mitlöschen |
| `server/src/apple.ts`, `apple-jwks.ts`, `apple-client.ts`, `apple-vault.ts` | Identitätstoken prüfen (`aud` exakt aus `APPLE_CLIENT_IDS`), JWKS, Code einlösen (ohne `redirect_uri`), Widerruf, Tresor mit `client_id` je Token |
| `server/src/transcripts.ts` | Abschrift v1: `now{knaeuel?, today, lined, waiting}`, `nowCount`, `tasks[]` mit 9 Feldern; Rohtext/Notiz abgelehnt (:95-105) |
| `server/migrations/001–003` | CHECKs erlauben nur die v1-Felder; keine OAuth-Tabellen; `sessions` ohne Ablaufspalte |
| `server/package.json` | `@modelcontextprotocol/server` 2.4.0, `pg`, `zod`; kein `oidc-provider`, kein `jose` zur Laufzeit |
| `docs/reference/claude-abschrift-vertrag.md` | Vertrag v1; „Mehr Felder sind eine Version 2 und brauchen vorher die Freigabe im Datenschutztext (#625)“ |
| `Shared/Services/TranscriptCodec.swift` | Baut die Abschrift; nur `now` über `ViewRules.now` vorberechnet |
| `Shared/Models/ViewRules.swift` | `.next` (:378, braucht `isBlocked`), `.due` (:384), `.open` = Lose Enden (:407, `byPressureThenWeight` :507 mit urgency/importance/capturedAt/parkedAt/Stufe), Kontexte (:424), Projekte (:430, nur ohne `parent`) |
| `docs/project/00-entscheidungen.md:308-323` | ADR-21: Weg B; „Ein OAuth-Server wird nie selbst geschrieben; Rückfall Supabase Pro“; Datenschutztext vor dem ersten externen Nutzer |
| `docs/context/spike-613-backend-weg-b.md:52,66-91` | Frühere Recherche: SDK v2 nur Ressourcenseite, Empfehlung `oidc-provider` mit CIMD; Warnung: Fällig/Lose Enden müssen nach `ViewRules` geordnet in der Abschrift kommen |
| `docs/specs/feat-615-*.md` | Merkposten an #621: Sitzungsablauf, Services-ID in `APPLE_CLIENT_IDS`, `client_id` je Token für Widerruf, ADR-21-Zusatz „App-Sitzung ≠ OAuth“ |
| `docs/specs/feat-796-schnitt-4a-betrieb.md:83` | nginx: `location = /mcp { return 404; }`; Betrieb in `henemm-infra` (extern, macht Claude selbst) |

## Existing Patterns
- Dienst: node:http ohne Framework, Routentabelle Pfad → `(Request) => Promise<Response>`, `gated` vor `migrate`, jede Ablehnung schlicht (401 ohne Körper), Geheimnisse nur gehasht oder AES-GCM, keine Werte im Log.
- Bausteine rein und mit eingereichten Abhängigkeiten (`fetch`, Uhr) testbar; Tests gegen Wegwerf-Postgres (`server/scripts/test-local.sh`), Tests ≈ 2,5× Code.
- Schema nur über nummerierte Migrationen, nur hinzufügen.
- Kleine Schnitte (≤ 250 LoC), je Schnitt eigene Spec und Freigabe (#615 lief in 9 Schnitten).

## Recherche (2026-11-05, mit Quellen)
- **MCP-Autorisierung, aktuelle Revision 2026-07-28** (https://modelcontextprotocol.io/specification/versioning, …/2026-07-28/basic/authorization):
  MUST OAuth 2.1, PKCE S256 (`code_challenge_methods_supported`), Protected Resource Metadata RFC 9728 (`WWW-Authenticate: Bearer resource_metadata=…` oder well-known, path-aware `/.well-known/oauth-protected-resource/mcp`), AS-Metadaten RFC 8414 mit identischem `issuer`, Audience-Bindung RFC 8707 (`resource` = `https://loose-ends.henemm.com/mcp`, fremde Token ablehnen), Token nur im Header, exakter Redirect-Vergleich, Refresh-Rotation für öffentliche Clients.
  SHOULD: CIMD (`client_id_metadata_document_supported: true`), kurzlebige Access-Token, `iss` in der Antwort (RFC 9207). DCR ist nur MAY und ausdrücklich veraltet.
- **claude.ai** (https://claude.com/docs/connectors/building/authentication.md, …/troubleshooting.md):
  CIMD nur, wenn Metadaten `client_id_metadata_document_supported: true` **und** `none` in `token_endpoint_auth_methods_supported`; sonst DCR. Claudes Client-Dokument `https://claude.ai/oauth/mcp-oauth-client-metadata` (selbst abgerufen): `redirect_uris: ["https://claude.ai/api/mcp/auth_callback"]`, `token_endpoint_auth_method: none`, Grants `authorization_code`, `refresh_token`.
  Anmeldung startet nur auf **401 mit `WWW-Authenticate`** (200 mit isError zeigt keinen Verbinden-Knopf). `/token` als `x-www-form-urlencoded`, 10 s Zeitlimit (Refresh 30 s), Refresh reaktiv und bis 5 min vor Ablauf, ungültiger Refresh → `invalid_grant`. Nur der erste `authorization_servers`-Eintrag zählt. Absender 160.79.104.0/21, nur IPv4. Stolperfallen: WAF vor `/.well-known`, Weiterleitung auf anderen Host verliert den Header, Issuer-/Audience-Abweichung.
  Nicht belegt: `https://claude.com/api/mcp/auth_callback` (nur Drittquellen), vorgegebene Token-Lebensdauer, welche Protokollrevision claude.ai spricht.
- **AS im selben Dienst erlaubt** (Spec „may be hosted with the resource server“; Anthropics Beispiel tut es). Ablauf: `/authorize` prüft CIMD, Redirect, PKCE, `resource`, `state` und hält das serverseitig → Weiterleitung zu Apple → Apple **POSTet** (`form_post`) `code` (5 min, einmalig), `id_token`, `state` an eine registrierte Return-URL → eigene Zustimmungsseite → eigener Code an Claude → eigene Token. Apple-Token gehen nie an Claude.
- **Sign in with Apple im Web** (developer.apple.com/documentation/signinwithapple/configuring-your-environment…, …configuring-your-webpage…): `client_id` ist eine **Services ID** mit verifizierter Domain und Return-URL; `aud` im Web-id_token = Services ID. Nicht belegt: ob Apples Token-Endpunkt im Web-Ablauf `redirect_uri` verlangt (unser `redeemCode` sendet keinen).
- **Bibliotheken:** `@modelcontextprotocol/server` 2.4.0 hat nur die Ressourcenseite (`requireBearerAuth` mit `expectedResource`, `oauthMetadataResponse`, `getOAuthProtectedResourceMetadataUrl`). Der AS-Teil (`mcpAuthRouter`) liegt eingefroren in `server-legacy`, veraltet, ohne CIMD. `oidc-provider` 9.13.3 (2026-10-29) hat CIMD (experimentell, aus) und Resource Indicators; groß. Better Auth hat ein MCP/CIMD-Plugin (Sekundärquelle).
- **Sicherheit:** kein Token-Passthrough (weder Apple-Token noch App-Sitzung an `/mcp`), Audience prüfen, Confused Deputy: eigene Zustimmung je Client **vor** dem Code, Host der Redirect-URI sichtbar (MUST), SSRF beim CIMD-Abruf (Erlaubnisliste nur `https://claude.ai/…` ist zulässig).

## Dependencies
- Upstream: `accounts.ts` (Konto über `apple_sub`, damit #615 und #621 dasselbe Konto haben), `apple*.ts` (Prüfen, Einlösen, Widerruf), MCP-SDK, Postgres, Apple Developer (neue Services ID mit Domain-Verifikation und Return-URL; einmalig im Konto, macht Claude über die ASC-/Developer-Wege oder braucht Hennings Konto).
- Downstream: `mcp.ts`-Werkzeuge bekommen echtes `authInfo`; `deleteAccount` löscht OAuth-Daten mit; nginx in `henemm-infra` öffnet `/mcp`, `/.well-known/*`, `/oauth/*` bzw. `/authorize`, `/token`, Apple-Return; `APPLE_*` (inkl. Services ID) in Compose.
- Daten: Ohne #795 schickt keine App eine Abschrift (`putTranscript` nur in Tests, keine Upload-Route). Die DoD „dasselbe wie die App“ ist erst mit #795 echt belegbar.

## Existing Specs
- `docs/specs/spike-613-schnitt-c4a-mcp-lesen.md`, `spike-613-schnitt-1-abschrift-auftraege.md` (C6a sah OAuth mit `oidc-provider` vor)
- `docs/specs/feat-615-schnitt-*.md` (Konten, Apple, HTTP-Rand)
- `docs/specs/feat-796-schnitt-4a-betrieb.md` (nginx, Stack)

## Risks & Considerations
- **ADR-21 „OAuth-Server nie selbst schreiben“** steht gegen den kleinen Eigenbau, den die Recherche nahelegt (AS-Fläche klein: Metadaten, `/authorize` mit CIMD, Zustimmung, `/token` mit PKCE und Rotation). Alternativen: `oidc-provider` (neue, große Abhängigkeit; CIMD experimentell), Supabase Pro (Rückfall laut ADR-21; zweites System), Eigenbau (kippt ADR-21). Braucht eine PO-Entscheidung in der Analyse, mit Beleg.
- **Datenschutz (ADR-21):** Kein externer Nutzer darf verbinden, bevor #625 steht. Bauen und gegen Henning selbst testen geht; öffentlich schalten (nginx, Verzeichnis) erst danach — oder nur für Hennings Konto (Erlaubnisliste).
- **Ansichten:** Abschrift v1 trägt nur „Jetzt“. Fällig, Als nächstes, Lose Enden, Projekte/Kontexte gleich wie die App brauchen Abschrift v2 mit vorberechneten Kennungslisten (Regel „Der Dienst rechnet nichts nach“) → Vertrag v2, CHECK-Migration, `TranscriptCodec`, Datenschutztext. Details über die 9 Felder hinaus ebenfalls v2.
- **Apple-Web-Ablauf:** Services ID, Domain-Verifikation, `form_post` (Cross-Site-POST: Zustand serverseitig unter `state`, kein Lax-Cookie), zweites erlaubtes `aud`, `redirect_uri` beim Einlösen ungeklärt.
- **Sitzungsablauf** (Merkposten aus #615) und Trennung App-Sitzung ≠ OAuth-Token (ADR-21-Zusatz).
- **Protokollrevision 2026-07-28** ändert den Handshake (kein `initialize`, `server/discover`); welche Revision claude.ai spricht, ist offen → SDK-Stand 2.4.0 prüfen.
- **Betrieb:** WAF/nginx vor `/.well-known`, Ratenbegrenzung für 160.79.104.0/21, 10-s-Zeitlimit.
- **Größe:** L; realistisch 5–8 Schnitte, Tests ≈ 2,5× Code.

## Analysis

### Type
Feature (Epic #612, Weg B). Größe L, wird in Schnitten geliefert; dieser Workflow spezifiziert **S1**.

### Make or Buy (Recherche 2026-11-05, Quellen)
| | A `oidc-provider` eingebettet | B eigener kleiner AS | C Supabase / verwaltet |
|---|---|---|---|
| CIMD für claude.ai | ja, experimentell (`features.clientIdMetadataDocument`, `ack`, `allowFetch` nur claude.ai) — [CHANGELOG](https://raw.githubusercontent.com/panva/node-oidc-provider/main/CHANGELOG.md), [docs](https://github.com/panva/node-oidc-provider/blob/main/docs/README.md) | ja | Supabase: **nein**, nur DCR, gemeinsame Grenze 10/h je IP ([supabase/auth#2850](https://github.com/supabase/auth/issues/2850)); WorkOS/Auth0/Stytch ja, EU/Preis offen |
| ADR-21 | eingehalten | kippt „nie selbst schreiben“ | Rückfall Supabase passt heute nicht zu claude.ai |
| Abhängigkeiten | `oidc-provider` 9.13.3 (koa, jose, debug; 34 Pakete, 2,9 MB) | keine | externer Dienst, zweiter Ort für Daten (#625) |
| RFC 8707 / Rotation | `resourceIndicators` stabil; Rotation für öffentliche Clients Standard | selbst | — |
| Einbettung | `provider.callback()` in node:http; Apple über Interaction-API | — | — |
| Schätzung Code+Tests | ~450 + ~1100 | ~600 + ~1500 | ~150 + ~400 + Integration |

**Entscheidung (technisch, Claude): A.** ADR-21 bleibt gültig; Nachtrag nötig: Supabase-Rückfall passt mangels CIMD nicht zu claude.ai,
Rückfall ist B nur nach PO-Änderung von ADR-21. S3 ist ein Spike-Gate: lokaler Test mit Claudes echtem Client-Dokument bis Token.

Weitere Belege: claude.ai folgt den MCP-Auth-Revisionen 2025-03-26/06-18/11-25, sendet weiter `initialize`, `resource` und PKCE S256
([building](https://claude.com/docs/connectors/building), [authentication](https://claude.com/docs/connectors/building/authentication)).
Apple-Web-Code verlangt beim Einlösen `redirect_uri` ([Apple](https://developer.apple.com/documentation/accountorganizationaldatasharing/generate-and-validate-tokens), [Forum 118135](https://developer.apple.com/forums/thread/118135)) → `redeemCode` braucht die Option (S4a).

### Schnittplan (je ≤ 250 LoC Code, Tests zusätzlich)
- **S1 Ressourcenseite (~120)** — `server/src/oauth-resource.ts` (neu), `server/src/main.ts`, `server/test/oauth-resource.test.ts` (neu), ggf. `server/test/main.test.ts`.
  `/mcp` ohne gültiges Token → 401 mit `WWW-Authenticate: Bearer resource_metadata="…/.well-known/oauth-protected-resource/mcp"`;
  die Metadaten (RFC 9728, `resource` = kanonische `/mcp`-URL, `authorization_servers` = Issuer) unter dem pfadbezogenen well-known;
  gültiges Token → `authInfo.extra.account` an `mcp.fetch`. SDK `requireBearerAuth` mit `expectedResource`, `verifyToken` eingereicht
  (in S1 ohne Aussteller: lehnt alles ab bzw. Test-Verifizierer). App-Sitzungen werden an `/mcp` nie angenommen. Kein AS, kein Apple.
- **S2 Ablage (~130)** — `migrations/004_oauth.sql`, `src/oauth-adapter.ts` (Postgres-Adapter für oidc-provider), `accounts.ts` (`deleteAccount` löscht mit), Sitzungsablauf (Merkposten #615).
- **S3 Provider + Einhängen (~200, Spike-Gate)** — `src/oauth-provider.ts`, `main.ts` (vor der Body-Pufferung, `proxy=true`, Issuer exakt), `package.json`/Lockfile; CIMD nur claude.ai, `none`, PKCE S256 Pflicht, Ressource `/mcp`, Rotation; `verifyToken` an AccessToken.
- **S4a Apple-Web-Bausteine (~100)** — `apple-client.ts` (`redirect_uri`), Services ID in `APPLE_CLIENT_IDS`. Braucht einmalig Services ID, Domain-Verifikation, Return-URL im Apple-Konto.
- **S4b Anmeldung (~220)** — `src/oauth-login.ts`: Interaction → Apple (`form_post`, Zustand in der DB) → Prüfen, Einlösen, `findOrCreate(apple_sub)` → `interactionFinished`.
- **S5 Zustimmung + Erlaubnisliste (~150)** — Zustimmungsseite je Client (Redirect-Host sichtbar, CSRF), Erlaubnisliste `apple_sub` = nur Henning bis #625.
- **S6 Betrieb + echter Connect** — nginx in `henemm-infra` (`/mcp`, `/.well-known/*`, `/oauth/*`, Apple-Rückweg; 404 aus #796 ersetzen), Compose-Variablen, Verbinden in claude.ai mit Hennings Konto.
- **S7 Abschrift v2 (eigene Specs, ≥ 3 Schnitte)** — vorsortierte Kennungslisten für Fällig, Als nächstes, Lose Enden, Projekte, Kontexte + Detailfelder; Vertrag v2, Migration, `transcripts.ts`, `TranscriptCodec`, Lesewerkzeuge. **Braucht #625** vor dem Speichern neuer Felder; Regel „Der Dienst rechnet nichts nach“.

### Affected Files (S1)
| File | Change Type | Description |
|------|-------------|-------------|
| server/src/oauth-resource.ts | CREATE | Metadaten-Antwort, 401 mit `WWW-Authenticate`, Bearer-Prüfung über eingereichten `verifyToken` |
| server/src/main.ts | MODIFY | well-known-Route, `/mcp` hinter der Prüfung, `authInfo` an `mcp.fetch` |
| server/test/oauth-resource.test.ts | CREATE | 401/Header, Metadaten, fremde Audience, App-Sitzung abgelehnt, Konto durchgereicht |
| server/test/main.test.ts | MODIFY | bestehender Test „/mcp ohne Konto“ auf 401 umstellen |

### Scope Assessment (S1)
- Files: 3–4
- Estimated LoC: ~+120 Code, ~+300 Tests
- Risk Level: MEDIUM — `/mcp` ändert sein Verhalten ohne Token von 200/isError auf 401; öffentlich ist `/mcp` noch 404 in nginx, kein Nutzer betroffen.

### Technical Approach
Ressourcenseite zuerst: unabhängig von der AS-Wahl, schaltet Claudes Verbinden-Knopf frei und legt die `authInfo`-Leitung, die jeder
spätere Schnitt braucht. Apple-Einrichtung (Services ID) läuft wegen Vorlauf parallel an.

### Dependencies
- #625 sperrt: Öffnen für Externe (Erlaubnisliste weg, Verzeichnis), neue Abschrift-Felder (S7), #795.
- DoD „dasselbe wie die App“ erst mit S7 + #795 belegbar; S1–S6 liefern Verbinden + „Jetzt“ (v1).

### Open Questions
- [ ] Services ID im Apple-Konto: über die vorhandenen Developer-/ASC-Wege oder braucht es Hennings Anmeldung? (erst für S4a, klären vor dessen Spec)
- [ ] Revision 2026-07-28 vs. SDK 2.4.0: Handshake mit claude.ai im S3-Spike prüfen.
