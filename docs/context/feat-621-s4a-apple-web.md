# Context: feat-621-s4a-apple-web (#621 Schnitt 4a)

## Request Summary
Damit sich Henning beim Verbinden von Claude im Browser mit Apple anmelden kann, braucht der Dienst die Bausteine des
Apple-Web-Ablaufs: die Adresse, die den Browser zu Apple schickt, den Rückweg (`redirect_uri`) und das Einlösen des Codes für
eine Services ID statt der App-Kennung. S4b baut daraus die eigentliche Anmeldung in der Interaction des Ausstellers (S3).

## Recherche (2026-11-06, Quellen)
- **Einrichtung im Apple-Konto** ([Apple Account Help: Configure Sign in with Apple for the web](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web)):
  Services ID unter Identifiers anlegen, „Sign in with Apple“ → Configure, mit einer primären App ID verbinden (hier
  `com.henning.looseends`), unter „Website URLs“ Domains und Return-URLs eintragen (mindestens eine Domain). **„You don't need
  to upload a file on your server to complete the registration process for domains and subdomains.“** Die frühere
  Domain-Prüfung per Datei entfällt. Grenze bei einer Organisation: 100 Website-URLs.
- **Kein API-Weg für Services IDs:** Die App Store Connect API kennt Bundle IDs samt Fähigkeiten, aber keine Services IDs; alle
  Anleitungen legen sie im Portal an ([Repl.it](https://docs.repl.it/references/auth-and-identity/apple), [Stytch](https://stytch.com/docs/consumer-auth/authentication/oauth/adding-providers/apple)).
  Das Portal braucht Hennings Anmeldung (Passkey, wie beim CloudKit-Deploy); die Klicks danach kann ich im Chrome-Tab übernehmen.
- **Autorisierung** ([Apple REST: Request an authorization](https://developer.apple.com/documentation/signinwithapplerestapi/request-an-authorization-to-the-sign-in-with-apple-server.)):
  `https://appleid.apple.com/auth/authorize` mit `client_id` (Services ID), `redirect_uri`, `response_type`, `state`, `scope`,
  `response_mode` (`query`, `fragment`, `form_post`). Bei `form_post` kommt ein POST mit `code`, `id_token`, `state`, beim ersten
  Mal `user`. Einziger Fehlercode: `user_cancelled_authorize`. Mehr als `scope=openid` (Name, E-Mail) geht nur mit `form_post`
  ([Ping Identity](https://pingidentity.com/en/resources/blog/post/sign-in-with-apple.html)); die `redirect_uri` muss einer
  eingetragenen Return-URL entsprechen ([Apple-Forum 122388](https://developer.apple.com/forums/thread/122388)).
- **Einlösen** ([Apple REST: Token validation](https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens)):
  `client_id`, `client_secret`, `code`, `grant_type`, `redirect_uri`; „include the `redirect_uri` parameter only if the
  application provided a `redirect_uri` in the initial authorization request“, und dann identisch. Der App-Weg (#615) schickt
  keine, der Web-Weg muss sie schicken. Der Code gilt 5 Minuten.

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/apple-client.ts` | `redeemCode` (ohne `redirect_uri`), `clientSecret` (`sub` = Client-ID, muss in `clientIds` stehen), `revokeToken`; hier kommt `redirect_uri` hinzu |
| `server/src/apple.ts` | `AppleConfig` (`clientIds` aus `APPLE_CLIENT_IDS`), `verifyIdentityToken` (aud ∈ `clientIds`, Nonce als SHA-256-Hex des Rohwerts) |
| `server/src/auth.ts` | App-Anmeldung `/auth/apple`: prüft Token, löst Code mit `verdict.aud` ein; muss unverändert weiterlaufen |
| `server/src/main.ts` | `appleConfigFromEnv`, `isIssuerPath` (alles unter `/oauth/` geht an den Aussteller), Routentabelle, `publicUrl` |
| `server/src/oauth-provider.ts` | Interaction-URL `/oauth/interaction/:uid`, `productInteraction` (501) — Einhängepunkt für S4b |
| `server/test/apple-client.test.ts` | 17 Tests mit eingereichtem `fetch`; Muster für die neuen Fälle |
| `docs/context/feat-621-mcp-anmeldung.md` | Schnittplan: S4a ≈ 100 LoC, S4b ≈ 220 LoC |

## Existing Patterns
- Apple-Aufrufe immer mit eingereichtem `fetch` und `now`, 5 s Zeitgrenze, Gründe als feste Wörter (`apple:<error>`,
  `unavailable`, `malformed_response`), nie Apples Text oder ein Wert in Meldungen.
- Konfiguration nur aus der Umgebung, Fehler nennen nur den Variablennamen (`loadAppleConfig`, `oauthKeysFromEnv`);
  `main()` bricht vor Pool und Port ab.
- `publicUrl` ist die einzige Wahrheit für eigene Adressen, nie der Host-Header (S1, S3).
- Tests: `node:test`, Wegwerf-Postgres, Schema je Test, keine Netzaufrufe.

## Dependencies
- Upstream: `AppleConfig`/`loadAppleConfig`, `clientSecret`, `verifyIdentityToken`, JWKS-Cache (`createJwks`), `publicUrl`.
- Downstream: S4b (`src/oauth-login.ts`: Interaction → Apple → prüfen, einlösen, `findOrCreate` → `interactionFinished`),
  S6 (nginx muss den Rückweg durchlassen, `APPLE_*` samt Services ID in Compose).

## Existing Specs
- `docs/specs/feat-615-schnitt-2a-apple-token-pruefen.md`, `…-2c1-apple-einloesen.md`, `…-3b-anmelden-abmelden.md` (App-Weg)
- `docs/specs/feat-621-schnitt-3-aussteller.md` (Aussteller, Interaction-Einhängepunkt)

## Risks & Considerations
- **Services ID existiert noch nicht.** Für Code und Tests nicht nötig (Apple wird eingereicht), für den echten Ablauf (S6)
  schon. Die Einrichtung braucht Hennings Portal-Anmeldung; früh einplanen, weil sie nicht per API geht.
- **Rückweg und Cookies:** Bei `form_post` kommt ein seitenübergreifender POST von `appleid.apple.com`; Cookies mit
  `SameSite=Lax` (Interaction-Cookies von oidc-provider) reisen dabei nicht mit. Der Zustand muss dann serverseitig liegen
  (Plan: „Zustand in der DB“). Bei `response_mode=query` (nur ohne Name/E-Mail möglich, die wir nicht brauchen) ist der Rückweg
  eine normale Weiterleitung, bei der Lax-Cookies mitreisen. Das ist eine echte Alternative für die Analyse.
- **Rückweg-Pfad:** Alles unter `/oauth/` geht an den Aussteller (`isIssuerPath`). Ein Rückweg dort muss im Aussteller behandelt
  werden, ein Pfad außerhalb (z. B. unter `/auth/`) läuft über `bridge`/`dispatch`. Muss mit der Return-URL im Apple-Konto übereinstimmen.
- **Nonce:** `verifyIdentityToken` erwartet im Token den SHA-256-Hex des Rohwerts (App-Muster). Im Web-Ablauf wird der Hash als
  `nonce` mitgeschickt, damit dieselbe Prüfung greift.
- **App-Weg darf nicht brechen:** `redeemCode` ohne `redirect_uri` muss genau so bleiben (Apple lehnt eine unerwartete ab).
- **Welche Client-ID ist die Web-ID:** `APPLE_CLIENT_IDS` enthält heute die App-Kennung; die Services ID kommt dazu. Der
  Web-Ablauf muss wissen, welche er nimmt (eigene Variable oder Konvention), ohne dass die App-Anmeldung sie annimmt, wo sie
  nicht hingehört.
- **Datenschutz:** Ohne `scope` liefert Apple weder Name noch E-Mail; der Dienst braucht beides nicht (`apple_sub` reicht, #615).

## Analysis

### Type
Feature (Dienst-Bausteine, kein sichtbarer App-Teil; kein UI-Entwurf nötig)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/apple.ts` | MODIFY | `AppleConfig.webClientId?` aus der neuen, optionalen Variable `APPLE_WEB_CLIENT_ID` (eine Services ID; leer = kein Web-Weg; gleich einer App-Kennung oder mit Komma → Fehler, der nur den Variablennamen nennt). `verifyIdentityToken` bekommt die Option `audiences` (Standard `config.clientIds`, App-Weg unverändert) |
| `server/src/apple-client.ts` | MODIFY | `redeemCode`-Option `redirectUri` (nur gesendet, wenn gesetzt); `clientSecret` nimmt auch `webClientId` an; neu `authorizeUrl(config, { redirectUri, state, nonce })` (client_id = Web-ID, `response_type=code`, `response_mode=form_post`, kein `scope`, `nonce` = SHA-256-Hex des Rohwerts, wirft ohne Web-ID); neu `appleReturnUrl(publicUrl)` = `<origin>/oauth/apple/return` |
| `server/src/main.ts` | MODIFY | `APPLE_WEB_CLIENT_ID` in `APPLE_VARS` (allein gesetzt → Start bricht mit Variablennamen ab, statt still ohne Apple zu laufen) |
| `server/test/apple-client.test.ts` | MODIFY | `redirect_uri` im Formular nur mit Option, App-Formular bytegleich wie bisher; `authorizeUrl`-Parameter vollständig und ohne `scope`; `clientSecret` mit Web-ID, fremde ID weiter abgelehnt; `appleReturnUrl` |
| `server/test/apple.test.ts` | MODIFY | `APPLE_WEB_CLIENT_ID` leer/gültig/gleich App-ID/mit Komma; `audiences`: Web-Token am App-Weg (Standard) abgelehnt, mit `audiences: [web]` angenommen, App-Token mit `[web]` abgelehnt |

### Scope Assessment
- Files: 5
- Estimated LoC: ≈ +45 Code, ≈ +130 Tests → ≈ 175 (Plan sagte ~100; Tests ≈ 2,5× Code laut Memory „LoC-Überhang durch Sicherheitstests“), unter 250
- Risk Level: LOW–MEDIUM — berührt die Prüfung der App-Anmeldung (#615), aber nur über eine Option mit unverändertem Standard; bestehende 17 + apple.test-Tests sichern den App-Weg

### Technical Approach
1. **Eigene Variable für die Web-ID, nicht in `APPLE_CLIENT_IDS`.** Stünde die Services ID dort, nähme `/auth/apple` auch ein Web-Token an. Getrennt: App-Weg prüft `aud ∈ clientIds`, Web-Weg (S4b) prüft `aud = webClientId`. `revokeToken`/`clientSecret` funktionieren für beide, weil `apple_tokens.client_id` die ID je Token speichert (S3a).
2. **`response_mode=form_post`, `response_type=code`, kein `scope`.** Der Code steht so nie in einer URL (nginx-Zugriffslog, Browserverlauf, Referrer). Name/E-Mail brauchen wir nicht (`apple_sub` reicht). Der Rückweg ist ein seitenübergreifender POST ohne Lax-Cookies → S4b legt den Zustand unter `state` in der DB ab (Schnittplan).
3. **Rückweg `https://loose-ends.henemm.com/oauth/apple/return`.** Unter `/oauth/` geht er an den Aussteller (`isIssuerPath`), S4b hängt ihn dort ein wie die Interaction; nginx (S6) muss nur `/oauth/*` durchlassen. Diese URL wird so im Apple-Konto als Return-URL eingetragen.
4. **`redeemCode(…, { redirectUri })`** sendet `redirect_uri` nur mit Option; Apple verlangt sie genau dann, wenn sie beim Autorisieren gesendet wurde (Recherche oben), und lehnt sie im App-Weg ab.
5. Alles rein, mit eingereichtem `fetch`/`now`, keine Netzaufrufe in Tests, Meldungen ohne Werte (bestehende Muster).

### Alternativen (geprüft)
- **`response_mode=query`:** spart S4b das Lesen eines Formular-Rumpfs und Lax-Cookies reisen mit; dafür steht der Code in URL und nginx-Log. Verworfen, weil `form_post` nur ~15 Zeilen in S4b kostet.
- **Services ID per Konvention in `APPLE_CLIENT_IDS`:** eine Variable weniger, aber der App-Weg nähme Web-Token an. Verworfen.
- **Kein Apple im Browser, sondern Kopplungscode aus der App** (App zeigt einen Einmalcode, die Anmeldeseite fragt ihn ab): keine Services ID, kein Portal-Schritt. Kippt den S4b-Plan aus dem ADR-21-Nachtrag und hängt an der App-Anmeldung (#615 S4), die auf #625 wartet; außerdem verbindet ein Nutzer ohne App dann nie. Nicht gewählt, bleibt Rückfall, falls die Services ID scheitert.

### Dependencies
- Upstream: `loadAppleConfig`, `clientSecret`, `verifyIdentityToken`, `publicUrl`/`resourceFor`.
- Downstream: S4b (`oauth-login.ts` nutzt `authorizeUrl`, `appleReturnUrl`, `redeemCode` mit `redirectUri`, `verifyIdentityToken` mit `audiences: [webClientId]`); S6 (`APPLE_WEB_CLIENT_ID` in Compose, nginx `/oauth/*`).
- Einmalig im Apple-Konto (vor S6, nicht für S4a): Services ID anlegen, mit `com.henning.looseends` verbinden, Domain `loose-ends.henemm.com` und Return-URL oben eintragen. Kein API-Weg; Henning meldet sich im Portal an, die Klicks übernehme ich im Chrome-Tab. Keine Datei-Verifikation mehr nötig.

### Open Questions
- keine für S4a (Portal-Termin wird vor S6 abgestimmt)
