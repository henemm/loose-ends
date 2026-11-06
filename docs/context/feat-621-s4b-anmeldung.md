# Context: feat-621-s4b-anmeldung (#621 Schnitt 4b)

## Request Summary
Der Aussteller (S3) antwortet bei jeder Anmelde-Interaktion noch mit einer festen 501. S4b ersetzt das für den Schritt
„login“ durch die echte Anmeldung über Apple im Browser: Interaktion → Apple (`form_post`) → Rückweg `/oauth/apple/return`
→ Identitätstoken prüfen, Code einlösen, `findOrCreate(apple_sub)` → `interactionFinished`. Schnittplan:
`docs/context/feat-621-mcp-anmeldung.md` (S4b ~220 LoC). Zustimmung (consent) und Erlaubnisliste sind S5, nginx und
Schlüssel S6.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/oauth-provider.ts` | `createProvider`, `productInteraction` (501), Einhängepunkt `interaction?: Interaction` = `(provider, req, res)`; Routen unter `/oauth/`, Interaktion unter `/oauth/interaction/<uid>`, TTL Interaction 600 s |
| `server/src/main.ts` | `isIssuerPath` schickt alles unter `/oauth/` roh an den Aussteller (also auch `/oauth/apple/return`); `mountIssuer` reicht `options.oauth.interaction` durch, `main()` setzt sie bisher nicht; 501 zählt nicht im Fehlerfenster |
| `server/src/apple-client.ts` | S4a-Bausteine: `authorizeUrl(config,{redirectUri,state,nonce})` (nonce roh rein, SHA-256 hex an Apple), `appleReturnUrl(publicUrl)` = `<origin>/oauth/apple/return`, `redeemCode(code, webClientId, {redirectUri})` prüft `aud` des id_token |
| `server/src/apple.ts` | `verifyIdentityToken(token, rawNonce, {audiences:[webClientId]})`, `AppleConfig.webClientId` optional |
| `server/src/apple-jwks.ts` | `createJwks({fetch,now}).keys` — `KeyLookup` für die Prüfung; in `main.ts` bisher nur in `mountAuth` erzeugt |
| `server/src/accounts.ts` | `findOrCreate(pool, appleSub)` (ein Statement, nebenläufig sicher); `deleteAccount` räumt `oauth_records` per `account_id`/`grant_id` |
| `server/src/auth.ts` | Vorbild App-Weg `signIn`: Token prüfen → Code einlösen → gleicher `sub` → `findOrCreate` → `storeRefreshToken` → Sitzung; jede Ablehnung nackter Status |
| `server/src/apple-vault.ts` | `storeRefreshToken(pool, account, blob, clientId)` — Upsert, `apple_tokens` hat PK `account_id` (eine Zeile je Konto) |
| `server/src/oauth-adapter.ts`, `migrations/004_oauth.sql` | `oauth_records` für oidc-provider-Modelle; Muster für Hash-Ablage, Ablauf, Einmal-Einlösen (`consume` atomar) |
| `server/test/oauth-provider.test.ts` | Bestehende Tests des Ausstellers (Interaktion 501, CIMD, PKCE) — Muster für Ende-zu-Ende über `/oauth/auth` |
| `server/test/apple-client.test.ts`, `test/auth.test.ts` | Muster für eingereichtes `fetch`, Apple-Schlüssel, signierte Test-Identitätstoken |
| `node_modules/oidc-provider/lib/provider.js` (9.13.3) | `interactionDetails`/`interactionResult`/`interactionFinished` lesen die Interaktion **nur über das Cookie `_interaction`** (`#getInteraction`), sonst `SessionNotFound` |
| `node_modules/oidc-provider/lib/actions/authorization/interactions.js` | Cookie `_interaction` = uid, `path` = Interaktions-URL-Pfad (`/oauth/interaction/<uid>`), `_interaction_resume` auf `/oauth/auth/<uid>`; beide `SameSite=Lax`, `httpOnly` |

## Existing Patterns
- Reine Bausteine mit eingereichtem `fetch` und `now`, kein Netz in Tests (S4a, #615).
- Jede Ablehnung ohne Wert: fester Status oder feste Fehlerseite (`renderError` gibt nur den Code aus), Protokoll nur
  feste Ereignisnamen (`logError("oauth error")`), nie Fehlerobjekte (FK-`detail` nennt die Konto-ID, S2/S3-Lehre).
- Geheimnisse/Kennungen in der DB nur als SHA-256 (`sessions.token_hash`, `oauth_records.id_hash`).
- Migrationen nummeriert, nur hinzufügen (`005_…` wäre die nächste).
- Reihenfolge der Prüfungen fest wie in `auth.ts::signIn`; `keys_unavailable`/`unavailable` → 503, alles andere 401.

## Dependencies
- Upstream: oidc-provider 9.13.3 (Interaction-Modell, Cookies), S4a-Bausteine, `accounts.findOrCreate`, Apple-JWKS.
- Downstream: S5 (Zustimmungsseite, Erlaubnisliste `apple_sub` = nur Henning bis #625) hängt sich an dieselbe Interaktion;
  S6 (nginx `/oauth/*` inkl. `/oauth/apple/return`, `APPLE_WEB_CLIENT_ID`, OAuth-Schlüssel in Compose).

## Existing Specs
- `docs/specs/feat-621-schnitt-3-aussteller.md` — Interaktions-Einhängepunkt, 501-Platzhalter, Fehlerfenster
- `docs/specs/feat-621-schnitt-4a-apple-web.md` — Wahl `form_post` + Zustand serverseitig unter `state` (Alternative A)
- `docs/specs/feat-621-schnitt-2-ablage.md` — `oauth_records`, Hash-Ablage, Konto-Löschung

## Recherche (2026-11-06)
- Apple schickt bei `response_mode=form_post` einen **seitenübergreifenden POST**; `SameSite=Lax`-Cookies reisen dabei
  nicht mit. Andere Projekte lösen das entweder mit `response_mode=query` (OpenStreetMap, ohne Name/E-Mail) oder mit einem
  eigenen `SameSite=None; Secure`-Cookie für den Zustand (allauth, Rust-Provider).
  Quellen: [OSM rails-dev #2799](https://lists.openstreetmap.org/pipermail/rails-dev/2025-August/043293.html),
  [allauth Apple](https://docs.allauth.org/en/latest/socialaccount/providers/apple.html),
  [cheers-providers apple/redirect.rs](https://docs.rs/crate/cheers-providers/latest/source/src/providers/apple/redirect.rs)
- oidc-provider findet die Interaktion in `interactionFinished` ausschließlich über das Cookie `_interaction`
  (Quelltext 9.13.3, `provider.js` `#getInteraction`; [README](https://github.com/panva/node-oidc-provider/blob/main/docs/README.md)).
  Der Rückweg `/oauth/apple/return` liegt außerhalb des Cookie-Pfads `/oauth/interaction/<uid>` und bekommt das Cookie
  wegen Lax ohnehin nicht.
- Ein **top-level GET** trägt Lax-Cookies auch nach einer seitenübergreifenden Weiterleitung. Daraus folgt der naheliegende
  Weg: Rückweg prüft `state` gegen die DB und leitet per 303 auf einen GET unter `/oauth/interaction/<uid>/…` weiter, der
  das Cookie wieder hat und dort `interactionFinished` ruft (Bindung an denselben Browser bleibt erhalten).

## Alternativen (für /20-analyse)
1. **Zustand in DB + 303 auf GET unter dem Interaktionspfad** (Kandidat): kein Cookie-Umbau, Browser-Bindung über das
   Bibliotheks-Cookie, Code nie in einer URL (nur `state`-Referenz). Kostet eine Tabelle oder Zeilen in `oauth_records`.
2. **Eigenes `SameSite=None; Secure`-Cookie** für `state`/nonce statt DB: keine Migration, aber schwächere Cookie-Haltung;
   `interactionFinished` bräuchte trotzdem den Sprung zurück unter den Interaktionspfad.
3. **Interaktion ohne Cookie direkt per `provider.Interaction.find(uid)`** im Rückweg abschließen: keine Weiterleitung, aber
   die Bindung an den Browser, der die Anmeldung begonnen hat, fällt weg (Login-CSRF / Sitzungsunterschiebung).
4. **`response_mode=query`** (kippt die S4a-Wahl „Code nie in einer URL“): Lax-Cookies reisen, keine DB, aber Code im
   nginx-Log und Verlauf.

## Risks & Considerations
- **Zustimmung (consent):** Nach dem Login verlangt oidc-provider standardmäßig den Prompt `consent` → neue Interaktion, die
  bis S5 weiter 501 antworten würde. S4b muss festlegen, ob es nur `login` beendet (Ende-zu-Ende erst mit S5) oder `consent`
  vorläufig selbst gewährt. Der Dienst ist öffentlich erst nach S6 erreichbar.
- **`apple_tokens` hat eine Zeile je Konto:** Speichert der Web-Weg sein Refresh-Token mit der Web-ID, überschreibt er das
  der App; `revokeAfterDelete` widerruft nur `config.clientIds` (App-IDs), die Web-ID würde übersprungen. Entscheiden: Web-Token
  gar nicht speichern (sofort widerrufen?) oder Löschweg erweitern.
- **Login-CSRF / Sitzungsfixierung:** `state` einmalig, an die Interaktions-uid gebunden, kurzlebig (≤ Interaction-TTL 600 s),
  nur als Hash gespeichert; nonce serverseitig, Abgleich im Identitätstoken.
- **Formular-Körper selbst lesen:** Der Aussteller bekommt den rohen Request (kein `bridge`-Puffer) — Größenlimit und
  `application/x-www-form-urlencoded` selbst prüfen.
- **Fehlerfenster:** Ablehnungen im Rückweg zählen als 4xx; Apple nicht erreichbar → 503 zählt; nur die bewusste 501 ist
  ausgenommen.
- **Protokoll ohne Werte:** kein `state`, `code`, `sub`, kein Fehlerobjekt im Log.
- **JWKS-Instanz:** `mountIssuer` braucht eine eigene `KeyLookup` (bisher nur in `mountAuth`); eine gemeinsame Instanz je
  `start()` vermeidet doppelte Abrufe.
- **Ohne `APPLE_WEB_CLIENT_ID` oder ohne Apple-Konfiguration** muss die Interaktion weiter fest ablehnen (wie heute 501/503).
- Scoping: ~220 LoC Code laut Plan, Tests erfahrungsgemäß ≈ 2,5× → Überhang über 250 LoC wahrscheinlich; vor dem Bauen nennen.

## Analysis

### Type
Feature (#621, Epic #612). S4b wird geteilt; **dieser Workflow spezifiziert S4b-1 (Hinweg)**. S4b-2 (Rückweg + Abschluss) folgt als eigener Workflow.

### Befunde (Code + Recherche 2026-11-06)
- oidc-provider 9.13.3: `_interaction`-Cookie hat `path = /oauth/interaction/<uid>` (Lax) → reist auch zu `/oauth/interaction/<uid>/finish`
  (top-level GET nach Weiterleitung). Resume-Cookie gilt für `/oauth/auth/<uid>`. `interactionDetails` wirft `SessionNotFound` ohne Cookie
  → fest beantworten. `interactionFinished` setzt selbst 303 auf `returnTo`; mit `ctx.respond=false` danach nichts mehr schreiben.
- `provider.use` liegt vor dem Router (`provider.js:453`) → `/oauth/apple/return` erreicht den Handler vor jedem Body-Parser; Körper selbst lesen.
- **Zustimmung:** `consent.js` verlangt beim ersten Grant immer `rs_scopes_missing` → nach dem Login neue Interaktion mit Prompt `consent`.
  Entscheidung: S4b beendet nur `login`; `consent` bleibt feste 501 bis S5. Ende-zu-Ende endet bis dahin an der Zustimmung.
- **Ablage ohne Migration:** `new PgAdapter(pool, "AppleLogin", now)` (nur SHA-256 der id, `consume` atomar einmalig, Ablauf) trägt
  `state → {uid, nonce}`. `find` liefert auch verbrauchte Zeilen → allein `consume` entscheidet. TTL = `min(600, Interaction.exp − jetzt)`.
- **Nonce:** `authorizeUrl` hasht selbst (SHA-256 hex an Apple); abgelegt wird die rohe Nonce, die `verifyIdentityToken` erwartet.
- **Apple-Refresh-Token (Web):** Apple empfiehlt Ablage für den Widerruf beim Löschen
  ([TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple),
  [Forum 706792](https://developer.apple.com/forums/thread/706792)). `apple_tokens` hat PK `account_id` → das Web-Token würde das App-Token
  überschreiben; `revokeAfterDelete` kennt nur `config.clientIds`. Entscheidung (technisch): S4b speichert das Web-Token **nicht**; eigener
  Schnitt **vor S6** (Ablage je Konto + client_id, Migration 005, Widerruf aller Tokens beim Löschen). Bis S6 ist nichts öffentlich.
- **Login-CSRF:** Rückweg (S4b-2) legt das Ergebnis unter einem einmaligen Ticket (60 s, an uid gebunden) ab und leitet per 303 auf
  `GET /oauth/interaction/<uid>/finish?ticket=…`; nur der Browser mit dem Interaktions-Cookie **und** dem Ticket schließt ab.
  `Referrer-Policy: no-referrer`, `cache-control: no-store`.
- **Fehlerfenster:** `main.ts` zählt ≥ 500. Apple-Ausfall nie als 5xx an den Browser ohne Absicht; S4b-2 legt fest, ob 503 (zählt) oder
  `access_denied`/`temporarily_unavailable` per Weiterleitung.

### Schnitt S4b-1 (dieser Workflow): Hinweg
GET `/oauth/interaction/<uid>`: `interactionDetails` → Prompt `login` → zufälliges `state` + `nonce`, Ablage `AppleLogin`, 303 auf
`authorizeUrl(config, { redirectUri: appleReturnUrl(publicUrl), state, nonce })`, `no-store`. Jeder andere Prompt → feste 501 wie heute.
Ohne Apple-Konfiguration oder ohne `webClientId` → feste 501 (unverändert, zählt nicht). Fehlendes/fremdes Cookie → feste 400 ohne Wert.
`main()` setzt die Interaktion, wenn Apple-Konfiguration mit `webClientId` und OAuth-Schlüssel vorliegen; eine JWKS-Instanz je `start()`
für `mountAuth` und Aussteller (S4b-1 reicht sie nur durch, genutzt in S4b-2). `/oauth/apple/return` bleibt in S4b-1 unbehandelt (404 des Ausstellers).

### Schnitt S4b-2 (Folge): Rückweg + Abschluss
POST `/oauth/apple/return` (Körper selbst lesen, Limit, urlencoded; `user`-Feld ignorieren) → `state` consume → Apple-`error` → Ergebnis
`access_denied`; sonst `redeemCode` (Web-ID, `redirectUri`), `verifyIdentityToken` (rohe Nonce, `audiences: [webClientId]`), gleicher `sub`,
`findOrCreate` → Ticket → 303 → GET `finish` → `interactionFinished({ login: { accountId } })`. Absehbar > 250 LoC mit Tests → dort vorher nennen.

### Affected Files (S4b-1)
| File | Change Type | Description |
|------|-------------|-------------|
| server/src/oauth-interaction.ts | CREATE | `appleInteraction(deps)`: Prompt-Weiche, State/Nonce-Ablage, 303 zu Apple, feste Ablehnungen |
| server/src/oauth-provider.ts | MODIFY | `productInteraction` als Rückfall für Nicht-login-Prompts exportiert/nutzbar; ggf. Pfadweiche vorbereiten |
| server/src/main.ts | MODIFY | JWKS-Instanz teilen, Interaktion aus Apple-Konfiguration bauen und an `mountIssuer` reichen |
| server/test/oauth-interaction.test.ts | CREATE | Ende-zu-Ende über `/oauth/auth` (CIMD-Client wie in oauth-provider.test.ts): 303 an Apple mit Parametern, Ablage gehasht + TTL, consent → 501, ohne Konfiguration 501, ohne Cookie 400, keine Werte im Log |

### Scope Assessment (S4b-1)
- Files: 4
- Estimated LoC: ~+80–100 Code, ~+150 Tests
- Risk Level: LOW–MEDIUM — nur die Login-Interaktion ändert ihre Antwort (501 → 303 zu Apple), nur mit Web-ID konfiguriert; Dienst nach außen
  noch nicht erreichbar (nginx bis S6), keine Konten berührt.

### Technical Approach
Weg 1 aus „Alternativen“: Zustand in der DB (über `PgAdapter`, keine Migration) + 303 auf GET unter dem Interaktionspfad mit einmaligem Ticket.
Unabhängig bestätigt (Plan-Agent gegen Quelltext). Alternativen verworfen: 2 eigenes `SameSite=None`-Cookie (zweites Cookie, schwächere Haltung),
3 Interaktion ohne Cookie per `Interaction.find(uid)` (Login-CSRF), 4 `response_mode=query` (kippt S4a „Code nie in einer URL“).
Alternative zur Ticket-URL: eigenes Lax-Cookie `_apple_state` auf dem Interaktionspfad — kein Wert in der URL, aber zweites Cookie mit eigener
Signierung; Ticket reicht (einmalig, 60 s, ohne Interaktions-Cookie wertlos). ADR: keine gekippt (ADR-21 und S4a-Wahl bleiben).

### Dependencies
- Upstream: S3 (Einhängepunkt), S4a (Bausteine), S2 (`PgAdapter`).
- Downstream: S4b-2, Web-Token-Schnitt vor S6, S5 Zustimmung, S6 Betrieb (Services ID, nginx `/oauth/*`).

### Open Questions
- keine für den PO (Teilung und Token-Ablage sind technisch entschieden; für Henning ändert sich bis S6 nichts Sichtbares)
