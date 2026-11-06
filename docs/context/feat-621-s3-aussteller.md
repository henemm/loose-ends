# Context: feat-621-s3-aussteller

## Request Summary
#621 Schnitt 3 (Epic #612): Der Dienst bekommt seinen OAuth-Aussteller (Authorization Server). `oidc-provider` wird eingebettet,
auf die Ablage aus S2 (`PgAdapter`) gesetzt und vor `/mcp` gehängt, sodass claude.ai sich per CIMD ausweist, mit PKCE S256 ein
Token für genau `/mcp` bekommt und `bearerGate` dieses Token annimmt. Spike-Gate: lokal mit Claudes echtem Client-Dokument bis zum Token.
Die Anmeldung mit Apple (Interaction) ist **nicht** Teil davon (S4a/S4b); S3 braucht für den Durchlauf einen Test-Weg durch die Interaction.

Vorgänger: S1 Ressourcenseite (PR #848), S2 Ablage (PR #849). Schnittplan: `docs/context/feat-621-mcp-anmeldung.md` → „Schnittplan“.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/main.ts` | `start()`, Routentabelle, `bridge` (puffert den Körper bis 1 MiB und baut einen Web-`Request`), `gated`, `dispatch` mit Fehlerfenster. Der Aussteller braucht den rohen `IncomingMessage`/`ServerResponse` → Einhängen **vor** `bridge`/`buffered`. `StartOptions.oauth` = `{ publicUrl, verifier }` |
| `server/src/oauth-resource.ts` | `DEFAULT_PUBLIC_URL`, `resourceFor`, `metadataRoute` (issuer = Origin der `publicUrl`), `bearerGate` (SDK `requireBearerAuth`), `rejectAll` als Standard-Verifizierer, `publicUrlFromEnv` |
| `server/src/oauth-adapter.ts` | `PgAdapter(pool, name, now)`; `upsert`/`find`/`findByUid`/`consume`/`destroy`/`revokeByGrantId`; ids nur SHA-256, `jti` nie gespeichert, `consumed` aus `consumed_at` in Sekunden |
| `server/migrations/004_oauth.sql` | Tabelle `oauth_records`, `account_id` → `accounts` mit Cascade (FK-Fehler 23503 trägt Konto-ID in `detail`) |
| `server/src/accounts.ts` | `findOrCreate`, `deleteAccount` (nimmt OAuth-Zeilen mit, auch über `grant_id`) — Konto-Kennung = `accounts.id`, das wird `accountId` im Grant |
| `server/src/mcp.ts` | liest Konto aus `ctx.http?.authInfo?.extra?.account` — der neue Verifizierer muss `extra.account` setzen |
| `server/src/auth.ts` | App-Anmeldung `/auth/*`; Muster für reine Routen mit eingereichten Abhängigkeiten, keine Konsolen-Ausgabe |
| `server/package.json` | heute nur `@modelcontextprotocol/server` 2.4.0, `pg`, `zod`; neu: `oidc-provider` 9.13.3 (+ `@types/oidc-provider` 9.13.1 dev) |
| `server/test/oauth-resource.test.ts`, `server/test/main.test.ts`, `server/test/oauth-adapter.test.ts` | Testmuster: `node:test`, Wegwerf-Postgres über `server/scripts/test-local.sh`, `service(t, options)`-Helfer, Log-Mitschnitt |
| `docs/specs/feat-621-schnitt-1-ressourcenseite.md`, `docs/specs/feat-621-schnitt-2-ablage.md` | Merkposten für S3 (unten) |
| `docs/project/00-entscheidungen.md` (ADR-21) | „OAuth nie selbst schreiben“; Nachtrag fällig: Aussteller = `oidc-provider`, Supabase-Rückfall passt mangels CIMD nicht |
| `CLAUDE.md` („Where things live“ → `server/`) | Eintrag für `oauth-provider.ts` nachziehen |

## Existing Patterns
- Bausteine rein, Abhängigkeiten eingereicht (`fetch`, Uhr `now`), getestet gegen Wegwerf-Postgres; Tests ≈ 2,5× Code.
- Konfiguration nur aus `main()`/Env, nie aus `request.url`/Host (`publicUrl` ist die Wahrheit für issuer und resource).
- Keine Werte im Log: kein `console.*` in Bausteinen, Fehler neutral (`logError(event)` nur mit festem Text).
- Routen, die die DB brauchen, sind `gated` (503 vor `migrate`); Metadaten ohne DB sind nicht gegated.
- Feste Routen (`/health`, `/mcp`, Metadaten) können weder von `auth` noch `extraRoutes` ersetzt werden.

## Dependencies
- Upstream: `oidc-provider` 9.13.3 (2026-10-29; koa ^3.2.1, jose ^6.2.13, debug), `@modelcontextprotocol/server` 2.4.0 (`requireBearerAuth`, `OAuthTokenVerifier`), `PgAdapter`, `pg`.
- Downstream: S4a/S4b (Interaction → Apple → `findOrCreate` → `interactionFinished`), S5 (Zustimmungsseite, Erlaubnisliste), S6 (nginx öffnet `/mcp`, `/.well-known/*`, `/oauth/*`), `mcp.ts`-Werkzeuge über `authInfo.extra.account`.

## Recherche (2026-11-06, Quellen)
- **oidc-provider 9.13.3** ist die aktuelle Version (npm, 2026-10-29); 9.13.2 behebt „current resource scopes at token issuance“ und empfiehlt atomare Replay-Erkennung im Adapter (hat `PgAdapter`). Quelle: https://raw.githubusercontent.com/panva/node-oidc-provider/main/CHANGELOG.md
- **CIMD** `features.clientIdMetadataDocument` (draft-02, **experimentell**, braucht `ack`): Optionen `enabled`, `allowFetch(ctx, clientId)` (Erlaubnisliste der Hosts), `allowClient(ctx, client)`, `cacheDuration {min 30, max 86400}`. Der Cache liegt im Speicher (WeakMap je Provider), nicht im Adapter. Abruf über die Option `fetch` (für Tests einreichbar), blockiert Spezial-IP-Bereiche (SSRF-Schutz). Prüft: `client_id` im Dokument = URL, kein Shared-Secret-Verfahren, https-URIs. Quelle: `docs/README.md` § features.clientIdMetadataDocument, `lib/helpers/client_id_metadata_document.js`, `lib/helpers/fetch_request.js`.
- **Einbettung:** `provider.callback()` als node:http-Handler. Der Körper wird von der Bibliothek selbst gelesen (Grenze 56 KiB, `lib/shared/selective_body.js`); ein schon gelesener Körper geht nur über einen Rückfall mit Warnung → Aussteller-Pfade **vor** `bridge`/`buffered` abzweigen. `provider.proxy = true` hinter nginx (TLS-Offload, `x-forwarded-proto`).
- **devInteractions** ist standardmäßig **an** (nimmt jeden Namen/jedes Passwort) → muss aus. `resourceIndicators` standardmäßig an; `getResourceServerInfo` ist Platzhalter und muss ersetzt werden (Audience `/mcp`, Scopes, `accessTokenFormat`); `defaultResource` für Anfragen ohne `resource`.
- **claude.ai** (https://claude.com/docs/connectors/building/authentication.md, …/lazy-authentication.md, abgerufen 2026-11-06): CIMD nur, wenn die AS-Metadaten `client_id_metadata_document_supported: true` **und** `"none"` in `token_endpoint_auth_methods_supported` nennen, sonst DCR; PKCE S256 immer, `code_challenge_methods_supported: ["S256"]` muss in den Metadaten stehen; Rücksprung `https://claude.ai/api/mcp/auth_callback`; `/token` als `application/x-www-form-urlencoded`; ungültiger Refresh → `invalid_grant`; Refresh-Rotation für öffentliche Clients; 10 s für Discovery/Token, 30 s für Refresh; `offline_access` wird angehängt, wenn die AS-Metadaten es in `scopes_supported` führen; Discovery-Cache ~5 min; Absender 160.79.104.0/21; Zustimmungsseite soll den Host der `client_id`-URL zeigen, nicht `client_name`.
- **Claude Code** hat ein öffentliches CIMD unter `https://claude.ai/oauth/claude-code-client-metadata` (abgerufen: `redirect_uris` `http://localhost/callback`, `http://127.0.0.1/callback`, `token_endpoint_auth_method: none`, **kein** `application_type`). oidc-provider vergleicht Loopback ohne Port nur bei `applicationType === 'native'` (`lib/models/client.js` `#redirectAllowed`) → Claude Code würde mit Port-Rücksprung scheitern, solange nichts nachhilft. Die URL des **claude.ai-Web-CIMD** ist nicht veröffentlicht; sie zeigt sich erst beim echten Verbinden (S6) bzw. muss im Spike gefunden werden.
- **Typen:** `oidc-provider` bringt keine eigenen; `@types/oidc-provider` 9.13.1 (DefinitelyTyped, 2026-10-29). Node 26 entfernt nur Typen (kein Build), Typen also nur Dev-Abhängigkeit.

## Merkposten aus S1/S2
- `issuer` des Ausstellers **exakt** = Origin der `publicUrl` (= `authorization_servers[0]` aus `metadataRoute`); sonst stiller Verbindungsfehler (RFC 8414).
- AS-Metadaten unter `/.well-known/oauth-authorization-server` (heute 404); oidc-provider liefert von sich aus `/.well-known/openid-configuration` — prüfen, ob es den RFC-8414-Pfad selbst bedient oder eine Route nötig ist.
- FK-Fehler 23503 beim `upsert` mit gelöschtem Konto trägt die Konto-ID in `detail` → nie das Fehlerobjekt loggen, neutral weiterreichen; als Anmeldefehler behandeln.
- Spike-Gate prüft gegen die echte Bibliothek: `consumed`-Format, `findByUid` ohne `jti` (`provider.js:441`, `token_helpers.js:13` lesen nur `accountId`/`grantIdFor`).
- Standard-Verifizierer bleibt so, dass App-Sitzungstoken (`createSession`) an `/mcp` nie gelten.

## Existing Specs
- `docs/specs/feat-621-schnitt-1-ressourcenseite.md` — Ressourcenseite, `bearerGate`, AC-7 App-Sitzung abgelehnt
- `docs/specs/feat-621-schnitt-2-ablage.md` — `PgAdapter`-Vertrag, Klartextfreiheit, Atomarität
- `docs/specs/spike-613-*` — frühere Wahl `oidc-provider` mit CIMD

## Risks & Considerations
- **Experimentelles CIMD** (draft-02): API kann sich in Minor-Versionen ändern → Version exakt pinnen (wie alle Pakete hier), `ack` setzen.
- **Neue große Abhängigkeit** (~34 Pakete, 2,9 MB, koa): Hausregel „keine neuen Dependencies ohne Freigabe“ → in der Spec ausdrücklich zur Freigabe stellen; ADR-21-Nachtrag.
- **Geheimnisse neu:** Signierschlüssel (`jwks`, sonst erzeugt die Bibliothek flüchtige Dev-Schlüssel mit Warnung) und `cookies.keys` für Interaction-Cookies → neue Env-Variablen, fehlend/ungültig = Start bricht ab (Muster `appleConfigFromEnv`); oder opake Token ohne `openid`, sodass kein `id_token` signiert werden muss — in der Analyse klären.
- **Einhängen vor `bridge`:** Aussteller-Pfade umgehen `buffered` (eigene 56-KiB-Grenze der Bibliothek) und `dispatch`; Fehlerfenster und 503-vor-`migrate` müssen trotzdem gelten.
- **Interaction ohne Apple:** S3 hat noch keine Anmeldung. Für den Spike-Durchlauf braucht es eine Test-Interaction (nur in Tests eingereicht), im Produkt endet `/authorize` an einer Interaction-Seite, die noch niemanden anmeldet (sicherer Zustand bis S4b).
- **Scoping:** Schätzung S3 ~200 LoC Code; mit Konfig (resource, CIMD, PKCE, Rotation, TTLs, Env-Schlüssel) und Verifizierer realistisch näher an 250 → Analyse prüft Teilung (z. B. S3a Provider-Konfig + Metadaten, S3b Verifizierer + Spike-Durchlauf).
- **Claude Code** (Loopback ohne Port) ist ausdrücklich nicht Ziel von S3 („CIMD nur claude.ai“); `allowFetch` lässt nur claude.ai-Hosts zu.
- Kein Pfad der Geräteliste berührt (nur `server/`, keine App, kein `project.yml`).

## Analysis

### Type
Feature (Schnitt 3 von #621, Epic #612). Kein Pfad der Geräteliste berührt.

### Durchstich mit der echten Bibliothek (2026-11-06, Wegwerfordner im Scratchpad, `oidc-provider` 9.13.3, Node 26.13.0)
Aufbau: Speicher-Adapter (Standard), `fetch` eingereicht mit einem CIMD für `https://claude.ai/oauth/test-client`
(`redirect_uris: [https://claude.ai/api/mcp/auth_callback]`, `none`), Test-Interaction (login → consent per Grant), opake Token.
Ergebnis, alles belegt durch Ausgabe:
- `/.well-known/oauth-authorization-server` **und** `/.well-known/openid-configuration` bedient die Bibliothek selbst
  (`lib/helpers/initialize_app.js:180–186`) → keine eigene Route; `issuer` = übergebene URL exakt.
- Metadaten: `client_id_metadata_document_supported: true`, `code_challenge_methods_supported: ["S256"]`,
  `token_endpoint_auth_methods_supported` enthält `none` (plus vier Secret-Verfahren → auf `["none"]` einschränken),
  `scopes_supported` hängt `openid` von selbst an.
- CIMD-Abruf über eingereichtes `fetch`, `allowFetch` nach Host; `ack: "draft-02"` nötig.
- Ohne PKCE → Rücksprung mit `invalid_request` („requires PKCE“). Mit PKCE S256 → Code → `/token` (form-urlencoded) →
  `access_token`, `refresh_token`, `scope: tasks`, `Bearer`.
- `provider.AccessToken.find(token)` liefert `accountId` (= Interaction-Konto), `aud` = `<issuer>/mcp`, `scope`, `clientId`
  → Verifizierer = Nachschlagen in der Ablage, keine Signatur nötig (opak).
- Refresh rotiert (neues Token ≠ altes); altes Refresh danach `invalid_grant` (claude.ai erwartet genau das).
- Zwei Interaction-Schritte: `login` und `consent` (`missingResourceScopes {<issuer>/mcp: [tasks]}`); `loadExistingGrant`
  vor der Anmeldung liest kein Konto → Grant nur im consent-Schritt bauen.
- Warnungen ohne Konfiguration: Speicher-Adapter, flüchtige Dev-Signierschlüssel, Standard-TTLs für Interaction/Grant/Session
  → im Produkt `adapter: PgAdapter`, `jwks` aus Env, `cookies.keys` aus Env, eigene `ttl`.
Noch **nicht** belegt (gehört ins Spike-Gate von S3): derselbe Ablauf gegen `PgAdapter` + echtes Postgres (`consumed`, `findByUid`,
Grant mit `accountId` → FK auf `accounts`), Einhängen hinter `main.ts`, `proxy = true` mit `x-forwarded-proto`.

### Alternativen (mit gekippter Entscheidung)
| Weg | Was | Spricht dafür | Spricht dagegen |
|---|---|---|---|
| **A `oidc-provider` + CIMD (Empfehlung)** | Bibliothek einbetten, claude.ai weist sich per Dokument aus | Durchstich grün; CIMD, PKCE, Ressource, Rotation fertig; zertifizierte Bibliothek; ADR-21 „nie selbst schreiben“ | neue Abhängigkeit (34 Pakete, koa); CIMD experimentell (draft-02) → Version exakt gepinnt |
| B `oidc-provider` + DCR | dieselbe Bibliothek, Clients registrieren sich offen (claude.ai fällt ohne CIMD darauf zurück) | nicht experimentell | offener Registrier-Endpunkt schreibt fremde Clients in die DB (Missbrauch, Aufräumen), Erlaubnisliste schwerer |
| C Eigenbau auf dem SDK | `@modelcontextprotocol/server` 2.4.0 hat **keinen** Aussteller (geprüft: kein `mcpAuthRouter`/`OAuthServerProvider` im Paket) | keine neue Abhängigkeit | kippt ADR-21; PKCE, Rotation, Replay, CIMD selbst geschrieben — genau die Fehlerklasse, die ADR-21 ausschließt |
| D Supabase Auth (ADR-21-Rückfall) | fremder Aussteller | nichts selbst betreiben | kein CIMD; Konten lägen außerhalb (`apple_sub`-Modell aus #615 doppelt) |

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/oauth-provider.ts` | CREATE | `createProvider({ publicUrl, pool, now, fetch, keys, interaction })`: issuer = `publicUrl`, `proxy = true`, `adapter` = `PgAdapter`, Routen unter `/oauth/*`, `devInteractions` aus, `clientIdMetadataDocument` (ack, `allowFetch` nur Host `claude.ai`), `clientAuthMethods: ["none"]`, PKCE Pflicht, `resourceIndicators` (`defaultResource`/`getResourceServerInfo` nur `<publicUrl>/mcp`, opak, Scope `tasks`), `rotateRefreshToken`, `issueRefreshToken`, TTLs; `providerVerifier(provider, publicUrl)` (`AccessToken.find`, `aud` = Ressource, `extra.account = accountId`, sonst `InvalidToken`); `oauthKeysFromEnv(env)` (Cookie-Schlüssel + Signier-JWK; keins gesetzt → `undefined`, teils/ungültig → wirft mit Variablennamen); Standard-Interaction ohne Anmeldung (feste Antwort, niemand wird angemeldet bis S4b) |
| `server/src/main.ts` | MODIFY | `StartOptions.oauth` um `keys`, `fetch`, `interaction` (nur Tests); Aussteller-Pfade (`/oauth/*`, die zwei Discovery-Pfade) **vor** `bridge` an `provider.callback()`, 503 vor `migrate` und ohne Schlüssel, Status ins Fehlerfenster (`res` `finish`); mit Schlüsseln wird `providerVerifier` statt `rejectAll` vor `/mcp` gesetzt; `main()` liest `oauthKeysFromEnv` (Muster `appleConfigFromEnv`, ungültig → exit 1) |
| `server/package.json` + `package-lock.json` | MODIFY | `oidc-provider` 9.13.3 exakt; `@types/oidc-provider` 9.13.1 dev |
| `server/test/oauth-provider.test.ts` | CREATE | Spike-Gate als Test: voller Ablauf gegen Wegwerf-Postgres mit `PgAdapter`, eingereichtem CIMD-`fetch` und Test-Interaction (login → `findOrCreate`-Konto → consent) bis Token → `/mcp` liefert `get_now` für dieses Konto; Metadaten-Felder; ohne PKCE abgelehnt; fremder CIMD-Host abgelehnt; `resource` fremd abgelehnt; Refresh-Rotation + altes Refresh `invalid_grant`; App-Sitzungstoken an `/mcp` weiter 401; Produkt-Interaction meldet niemanden an; Env-Schlüssel-Tabelle; 503 vor `migrate`; Log ohne Token/Konto-ID |
| `server/test/main.test.ts` | MODIFY | ggf. Altfälle, die `/oauth/*` oder Discovery als 404 erwarten |
| `CLAUDE.md`, `docs/project/00-entscheidungen.md` | MODIFY | `server/`-Zeile für `oauth-provider.ts`; ADR-21-Nachtrag: Aussteller = `oidc-provider` mit CIMD, Supabase-Rückfall entfällt mangels CIMD |

### Scope Assessment
- Files: 4 Code/Test (+ Lockfile, CLAUDE.md, ADR) — `main.test.ts` nur falls Altfälle brechen.
- Estimated LoC: Code ≈ +190–220 (`oauth-provider.ts` ≈ 150, `main.ts` ≈ +40, `package.json` +2); Tests ≈ 450–550
  (Praxis Tests ≈ 2,5× Code, offen genannt wie in S1/S2); Lockfile zählt nicht als Code.
- Risk Level: MEDIUM — neue große Abhängigkeit mit experimentellem Teil; Aussteller-Pfade laufen an `bridge`/`dispatch` vorbei.
  Öffentlich bleibt alles zu (nginx lässt nur `/health` durch bis S6); ohne neue Env-Schlüssel antwortet der Aussteller 503 und `/mcp`
  bleibt bei `rejectAll` → der laufende Dienst auf rennwienix ändert sein Verhalten nicht.

### Technical Approach
Ein Schnitt (Weg A). Teilung S3a/S3b (Provider + Einhängen | Verifizierer + Durchlauf) geprüft und verworfen: S3a hätte keinen
Nachweis, dass ein Token an `/mcp` ankommt — genau den Fehler „halber Weg“, den das Spike-Gate verhindern soll; der Code passt mit
≈ 200 in ≤ 250. Reihenfolge im TDD: Env-Schlüssel und Metadaten → Einhängen (503, Fehlerfenster) → Durchlauf bis Token gegen `PgAdapter`
→ Verifizierer an `/mcp`. Fallen im Spike-Gate Abweichungen des `PgAdapter` auf (`consumed`, `findByUid`), werden sie in S3 korrigiert
und in der Spec benannt (Datei `oauth-adapter.ts` käme dann hinzu → vorab als mögliche fünfte Datei nennen).

Festlegungen für die Spec:
- Signierschlüssel trotz opaker Token konfigurieren (sonst flüchtige Dev-Schlüssel mit Warnung, `openid` steht in `scopes_supported`).
  Vorschlag: `OAUTH_COOKIE_KEYS` (≥ 32 Byte, Komma-Liste für Wechsel) und `OAUTH_SIGNING_JWK` (privater ES256-JWK). Keiner gesetzt →
  Aussteller 503, `/mcp` bleibt `rejectAll`; einer fehlt/ungültig → Start bricht ab mit Variablennamen.
- Fehler aus dem Provider (`server_error`, FK 23503 mit Konto-ID in `detail`) nie loggen; nur feste Ereignisnamen.
- `allowFetch` nur `claude.ai`; Claude Code (Loopback ohne Port) bleibt draußen (bekannt, nicht Ziel).
- Interaction im Produkt: feste Antwort ohne Anmeldung (sicherer Zustand bis S4b); Test-Interaction nur über `StartOptions`.

### Dependencies
- Upstream: `oidc-provider` 9.13.3 (koa ^3.2.1, jose ^6, 34 Pakete), `PgAdapter` (S2), `findOrCreate`, `bearerGate`/`metadataRoute` (S1), `mcp.ts` (`extra.account`).
- Downstream: S4b ersetzt die Produkt-Interaction (Apple), S5 Zustimmungsseite + Erlaubnisliste, S6 nginx `/oauth/*` + `/.well-known/*` + Env-Schlüssel in Compose.

### Open Questions
- [ ] PO-Freigabe der neuen Abhängigkeit `oidc-provider` (Hausregel „keine neuen Dependencies ohne Freigabe“) — wird mit der Spec zur Freigabe gestellt, kein Vorab-Stopp.
- [ ] URL des claude.ai-Web-CIMD unbekannt (nicht veröffentlicht) → `allowFetch` nach Host statt nach exakter URL; exakte URL in S6 beim echten Verbinden ablesen.
