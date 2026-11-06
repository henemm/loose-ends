# Context: feat-621-s4b-2-rueckweg (#621 Schnitt 4b-2)

## Request Summary
Der Hinweg (S4b-1, PR #856) leitet die Anmelde-Interaktion zu Apple und legt `state → { uid, nonce }` als Modell `AppleLogin` ab.
S4b-2 baut den Rückweg: Apple schickt den Browser per `form_post` an `/oauth/apple/return`; der Dienst prüft `state`, löst den Code
ein, prüft das Identitätstoken, legt das Konto an oder erkennt es wieder und schließt die Interaktion ab (`interactionFinished`).
Dazu die drei in der Validierung von S4b-1 als zu schwach befundenen Tests. Gesamtplan: `docs/context/feat-621-mcp-anmeldung.md`;
Analyse und Alternativen des Gesamtschnitts: `docs/context/feat-621-s4b-anmeldung.md` (Abschnitte „Recherche“, „Alternativen“, „Analysis“).

## Related Files
| File | Relevance |
|------|-----------|
| `server/src/oauth-interaction.ts` (67 Z.) | `appleInteraction(deps)`: Hinweg. `deps.keys` ist schon da, wird erst jetzt benutzt. `pathUid` liest alles hinter `/oauth/interaction/` als uid, also würde `<uid>/finish` dort als fremde uid abgelehnt: der Abschluss braucht eine eigene Pfadweiche |
| `server/src/oauth-provider.ts` | `createProvider`: `provider.use` fängt nur Pfade unter `/oauth/interaction/` ab (`ctx.respond = false`, rohe Antwort). `/oauth/apple/return` liegt außerhalb und landet heute im Router des Ausstellers (404). Die Weiche muss um den Rückweg erweitert werden; `Interaction`-Typ ist `(provider, req, res)`; `productInteraction` = feste 501 |
| `server/src/main.ts` | `isIssuerPath` schickt alles unter `/oauth/` roh an den Aussteller, also auch `/oauth/apple/return` (kein `bridge`-Puffer: Körper selbst lesen, Limit selbst). `interactionFor` baut `appleInteraction` nur mit Web-ID, Schlüsseln, ohne gesetzte `oauth.interaction`. Fehlerfenster: `finish`-Haken zählt jede Antwort außer 501 |
| `server/src/apple-client.ts` | `redeemCode(code, webClientId, { config, fetch, now, redirectUri })` (prüft `aud` des id_token, liefert `sub` und Refresh-Token); `appleReturnUrl(publicUrl)`; Gründe `unavailable` → 503-Pfad, sonst Ablehnung |
| `server/src/apple.ts` | `verifyIdentityToken(token, rawNonce, { config, keys, now, audiences: [webClientId] })`, Grund `keys_unavailable` |
| `server/src/apple-jwks.ts` | geteilte `KeyLookup`, in `main.ts` je `start()` einmal erzeugt |
| `server/src/accounts.ts` | `findOrCreate(pool, appleSub)` (ein Statement, nebenläufig sicher), `deleteAccount` räumt `oauth_records` per `account_id` und `grant_id` |
| `server/src/auth.ts` | Vorbild App-Weg `signIn`: Token prüfen → Code einlösen → gleicher `sub` → `findOrCreate` → Sitzung; jede Ablehnung nackter Status; `readLimited` (Körper zählend lesen) als Muster |
| `server/src/oauth-adapter.ts` | `PgAdapter`: Hash-Ablage, `consume` atomar einmalig, `find` liefert auch verbrauchte Zeilen (allein `consume` entscheidet), Ablauf aus injizierter Uhr |
| `server/test/oauth-interaction.test.ts` (381 Z.) | Testaufbau von S4b-1: `service`, `begin`, `raw`, `jar`, `cimdFetch`, `fakeApple`, `idToken`, `toConsent`, `after`-Mitschnitt. Dort sitzen die drei schwachen Tests (AC-10, Mitschnitt in `after`, AC-13) |
| `docs/specs/feat-621-schnitt-4b1-hinweg.md` | Vorgänger-Spec; Changelog nennt die drei Nachschärfungen; Abschnitt „Out of Scope“ umreißt S4b-2 |

## Existing Patterns
- Reine Bausteine mit eingereichtem `fetch`/`now`, kein Netz in Tests; Apple wird in Tests nie erreicht (`fakeApple`).
- Jede Ablehnung ohne Wert: feste Antwort (`bad request` 400 im Hinweg, bei `auth.ts` nackte Status), Protokoll nur feste Ereignisnamen,
  nie Fehlerobjekte (FK-`detail` nennt die Konto-ID).
- Kennungen und Geheimnisse in der DB nur als SHA-256; Einmal-Einlösen über `consume`.
- Reihenfolge der Prüfungen fest wie in `signIn`; `keys_unavailable`/`unavailable` → 503, alles andere Ablehnung.
- Fehlerfenster in `main.ts`: 5xx zählt, die bewusste 501 nicht.

## Dependencies
- Upstream: oidc-provider 9.13.3 (`interactionDetails`, `interactionFinished`, Cookie `_interaction` mit Pfad `/oauth/interaction/<uid>`, `SameSite=Lax`),
  S4a-Bausteine, `accounts.findOrCreate`, Apple-JWKS, `PgAdapter`.
- Downstream: S5 (Zustimmung, Erlaubnisliste: nur Henning bis #625) hängt an derselben Interaktion; Web-Token-Ablage (eigener Schnitt vor S6,
  Migration 005); S6 (nginx `/oauth/*` einschließlich `/oauth/apple/return`, `APPLE_WEB_CLIENT_ID`, Schlüssel in Compose).

## Existing Specs
- `docs/specs/feat-621-schnitt-4b1-hinweg.md` (Hinweg, Out-of-Scope-Liste = Umriss von S4b-2)
- `docs/specs/feat-621-schnitt-4a-apple-web.md` (Wahl `form_post`, Zustand serverseitig unter `state`)
- `docs/specs/feat-621-schnitt-3-aussteller.md`, `docs/specs/feat-621-schnitt-2-ablage.md`

## Festgelegtes aus der Analyse von S4b (nicht neu verhandeln, nur prüfen)
- Rückweg = **POST** `/oauth/apple/return`, Körper selbst lesen (Limit, `application/x-www-form-urlencoded`), Feld `user` ignorieren.
- `state` per `consume` einlösen; Apple-`error` → Ergebnis `access_denied` (Form noch offen); sonst `redeemCode` (Web-ID, `redirectUri`),
  `verifyIdentityToken` (rohe Nonce, `audiences: [webClientId]`), gleicher `sub`, `findOrCreate`.
- Login-CSRF: Ergebnis unter einem **einmaligen Ticket** (60 s, an `uid` gebunden) ablegen, 303 auf `GET /oauth/interaction/<uid>/finish?ticket=…`;
  dort verlangt der Dienst Interaktions-Cookie **und** Ticket, dann `interactionFinished({ login: { accountId } })`. Der seitenübergreifende
  POST trägt wegen `SameSite=Lax` das Cookie nicht, der anschließende top-level GET schon. `Referrer-Policy: no-referrer`, `no-store`.
- **Web-Refresh-Token wird nicht gespeichert** (`apple_tokens` hat eine Zeile je Konto, würde das App-Token überschreiben; `revokeAfterDelete` kennt
  nur App-IDs). Eigener Schnitt vor S6 mit Migration 005. Offen für die Analyse: Wird das Web-Token **sofort widerrufen** (`revokeToken`), damit bei Apple
  keine unverwaltete Berechtigung liegen bleibt? Das war in S4b als Frage notiert, nicht entschieden.
- Consent bleibt feste 501 bis S5: der Ende-zu-Ende-Durchlauf endet bis dahin an der Zustimmung.

## Nachzuschärfen (aus /60-validate von S4b-1)
1. AC-10 (Fehlerfenster): die `begin()`-Anfragen verdünnen die Quote, daher belegt der Test nicht, dass 501/400 ungezählt bleiben. Sie müssen aus dem Fenster
   heraus oder die Quote muss ohne sie gerechnet werden.
2. Mitschnitt in `after`: lässt jedes kleingeschriebene Ereignis zu, soll nur `oauth interaction refused`/`store failed` plus die festen Ereignisse des Rückwegs erlauben.
3. AC-13: die geteilte JWKS-Instanz ist bisher nur für `/auth/apple` belegt; mit dem Rückweg wird `keys` benutzt, also über den Rückweg belegen
   (Abruf-Zähler am eingereichten `fetch`).

## Risks & Considerations
- **Schnittgröße:** S4b-1 endete bei 496 LoC (112 Code, 381 Tests) und wurde vom PO angenommen (Memory `feedback-loc-ueberhang-sicherheitstests`).
  S4b-2 hat mehr Pfade (POST lesen, Apple-Fehler, Einlösen, Prüfung, Konto, Ticket, Abschluss) als der Hinweg: Überhang absehbar, **vor dem Bauen mit Zahl nennen**;
  mögliche Teilung: Rückweg bis Ticket / Abschluss `finish` mit Ticket.
- **Bindung an den Browser:** ohne Ticket-Prüfung plus Cookie wäre Login-CSRF (fremde Anmeldung unterschieben) möglich. Kernprüfung dieses Schnitts.
- **Weiche im Aussteller:** `/oauth/apple/return` und `/oauth/interaction/<uid>/finish` müssen die Weiche in `createProvider` erreichen, ohne dass der
  Hinweg die Pfad-uid falsch liest (`pathUid` kennt nur `<uid>`).
- **Körper lesen:** der Aussteller bekommt den rohen Request; Größenlimit (Vorschlag 16 KiB wie `auth.ts`) beim Lesen zählen, nicht nur `Content-Length`;
  falscher Inhaltstyp, fehlende Felder, doppelte Felder → feste Ablehnung.
- **Apple nicht erreichbar:** `unavailable`/`keys_unavailable` → 503 (zählt im Fehlerfenster) oder Weiterleitung mit `temporarily_unavailable`? Entscheidung in der Analyse.
- **Konto gelöscht zwischendurch:** `interactionFinished` mit einer Konto-ID, die nicht mehr existiert, darf keine Sitzung erzeugen (FK-Fehler nennt die Konto-ID, nie loggen).
- **Protokoll ohne Werte:** kein `state`, `code`, `sub`, `ticket`, `uid`, kein Fehlerobjekt; nur feste Ereignisnamen.
- **Ohne `APPLE_WEB_CLIENT_ID`/Apple-Konfiguration:** der Rückweg ist dann gar nicht gebaut, `/oauth/apple/return` bleibt die 404 des Ausstellers.
- **Nach außen unsichtbar:** nginx lässt bis S6 nur `/health` durch; Henning merkt keine Änderung. Stufe 3 entfällt (nur `server/`).
- **Hinweis zur Umgebung:** im Worktree fehlt `server/node_modules`; für Tests `./server/scripts/test-local.sh` (installiert und startet Wegwerf-Postgres).

## Alternativen (für /20-analyse)
1. **Ticket-Weg (Kandidat, aus S4b entschieden):** POST → Ergebnis als Ticket in der DB → 303 → GET `finish` mit Cookie + Ticket.
2. **Abschluss direkt im POST** über `provider.Interaction.find(uid)` ohne Cookie: kein Ticket, aber keine Bindung an den Browser (Login-CSRF). Verworfen in S4b.
3. **Eigenes `SameSite=None; Secure`-Cookie** statt DB-Zustand: zweite Cookie-Sorte, schwächere Haltung. Verworfen in S4b.
4. **`response_mode=query`:** kippt S4a „Code nie in einer URL“. Verworfen.
5. **Fertige Funktion der Bibliothek / Social-Login-Bibliothek** für Apple statt eigener Rückweg: neue Abhängigkeit, würde ADR-21 und #615 „nur Apple“ berühren; der eigene Weg nutzt vorhandene geprüfte Bausteine. In der Analyse kurz belegen.

## Recherche (2026-11-06, Schnitt 4b-2)
- Apple `form_post`, Fehlerfall: der Körper trägt `error`; dokumentiert ist nur `user_cancelled_authorize`; im Erfolgsfall `state` und `code` (das Feld `user` fehlt oft, wird ignoriert).
  Quelle: [Apple REST API, Authorization request](https://developer.apple.com/tutorials/data/documentation/signinwithapplerestapi/request-an-authorization-to-the-sign-in-with-apple-server..md),
  [Forum 742820](https://developer.apple.com/forums/thread/742820).
- Widerruf: `/auth/revoke` antwortet 200 auch für schon ungültige Token; `client_id` muss die der Ausgabe sein
  ([revoke tokens](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens.md), [TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple.md)).
  **Ungeklärt und von Apple nirgends belegt:** ob der Widerruf eines Web-Tokens (Services ID) die Berechtigung der App-Kennung desselben Nutzers mit aufhebt
  ([Forum 844628](https://developer.apple.com/forums/thread/844628), unbeantwortet).
- oidc-provider: `interactionFinished` braucht das Cookie `_interaction`; ein eigener Pfad außerhalb von `/oauth/interaction/<uid>` bekommt es nicht (Cookie-Pfad). Bestätigt die Wahl, den Abschluss unter dem Interaktionspfad zu halten.

## Analysis

### Type
Feature (#621, Epic #612, Schnitt 4b-2). Nur `server/`, nach außen unsichtbar (nginx bis S6). Stufe 3 entfällt: „Kein Pfad der Geräteliste berührt.“

### Befunde
- `provider.use` in `createProvider` fängt nur `/oauth/interaction/…` ab. `/oauth/apple/return` landet heute im Router des Ausstellers (404). Damit die 404 **ohne** Apple-Konfiguration bleibt,
  darf die Weiche den Rückweg nur abfangen, wenn ein Rückweg-Handler übergeben ist (neue optionale Option an `createProvider`), nicht über `productInteraction` (das würde 404 zu 501 machen).
- `finish` liegt unter `/oauth/interaction/<uid>/finish` und erreicht dieselbe Weiche; `pathUid` darf dort nicht die ganze Restzeichenkette als uid lesen: eigene Pfadauswertung (uid, Rest).
- `PgAdapter` schreibt `payload.accountId` in die Spalte `account_id` (FK, Cascade) und `payload.uid` in `uid`. Ein Ticket mit `accountId` scheitert also beim Anlegen, wenn das Konto
  nicht existiert, und `deleteAccount` räumt offene Tickets mit ab. Das deckt „Konto gelöscht zwischendurch“ ohne eigenen Code für den Fall ab (FK-Fehler nie loggen).
- **Einheitlicher Abschluss:** Auch ein Apple-Fehler (`access_denied`) und „Apple nicht erreichbar“ brauchen `interactionFinished`, also das Cookie. Deshalb legt der Rückweg in **jedem** Fall
  ein Ticket ab (Konto, oder Fehlername) und leitet auf `finish`; es gibt nur einen Abschlusspfad.
- **Apple nicht erreichbar (`unavailable`, `keys_unavailable`):** Ergebnis `temporarily_unavailable` über `finish`, **kein 5xx**. Ein Apple-Ausfall soll das Fehlerfenster nicht füllen
  und `/health` nicht auf 503 ziehen (der Dienst ist im Monitor kritisch, Memory `loose-ends-dienst-kritisch-im-monitor`). Der Client (Claude) bekommt einen sauberen OAuth-Fehler.
- **Web-Token:** der Rückweg muss den Code einlösen (ohne `scope` liefert Apple keinen `id_token` im POST). Das Refresh-Token wird **nicht gespeichert und nicht widerrufen**:
  Speichern braucht Migration 005 (eigener Schnitt vor S6), Widerrufen ist wegen der ungeklärten Wirkung auf die App-Berechtigung riskanter als Liegenlassen (nichts ist öffentlich,
  zugelassen ist bis #625 nur Henning). Der Verzicht wird im Code mit Kommentar und Verweis auf das Ticket der Token-Ablage festgehalten.

### Alternativen (mit gekippter Entscheidung)
| Weg | Urteil |
|---|---|
| **A Ticket-Weg (empfohlen):** POST → alles prüfen → Ticket in `oauth_records` (60 s, an uid gebunden, einmalig) → 303 → GET `finish` mit Cookie + Ticket | bindet an denselben Browser, kein neues Cookie, keine Migration |
| B Abschluss direkt im POST über `provider.Interaction.find(uid)` | kein Cookie-Nachweis → Login-CSRF; verworfen |
| C eigenes `SameSite=None; Secure`-Cookie | zweite Cookie-Sorte; verworfen |
| D `response_mode=query` | Code in der URL, kippt S4a; verworfen |
| E Social-Login-Bibliothek für Apple | neue Abhängigkeit, berührt ADR-21 und „nur Apple“ (#615); die vorhandenen geprüften Bausteine reichen. Würde ADR-21 kippen, wird nicht vorgeschlagen |
| Widerruf des Web-Tokens sofort | wegen unbelegter Wirkung auf die App-Berechtigung verworfen, bis die Token-Ablage gebaut ist |
„Ohne Modell“-Frage entfällt: kein Sprachmodell im Spiel.

### Teilung (Schnittgröße vorab genannt, Memory `feedback-loc-ueberhang-sicherheitstests`)
Gesamt ≈ 150 Zeilen Code + ≈ 380 Test = **≈ 530 LoC**, über dem Limit. Empfehlung: zwei Workflows.
- **S4b-2a Rückweg bis Ticket** (≈ 90 Code + ≈ 200 Test): `server/src/oauth-return.ts` (CREATE: POST lesen mit zählendem 16-KiB-Limit, Inhaltstyp `application/x-www-form-urlencoded`, fehlende/doppelte Felder → feste 400;
  `state` per `consume`; Apple-`error` → Ticket `access_denied`; `redeemCode`, `verifyIdentityToken`, gleicher `sub`, `findOrCreate` → Ticket; 303 auf `finish`, `no-store`, `no-referrer`),
  `oauth-provider.ts` (MODIFY: Rückweg-Option an der Weiche), `main.ts` (MODIFY: Rückweg bauen, wenn der Hinweg gebaut wird), `test/oauth-return.test.ts` (CREATE). Dazu die Nachschärfung 3 (JWKS über den Rückweg).
- **S4b-2b Abschluss `finish`** (≈ 60 Code + ≈ 180 Test): Pfadweiche in `oauth-interaction.ts` (uid und Rest), Cookie + Ticket prüfen, `interactionFinished({ login: { accountId } })` oder `{ error }`;
  Nachschärfungen 1 (Fehlerfenster ohne `begin()`-Anfragen) und 2 (Protokoll nur feste Ereignisse). Ende-zu-Ende bis zur festen 501 der Zustimmung.
Vor 2b ist 2a allein nutzlos, aber ungefährlich: das Ticket läuft nach 60 s ab, `finish` bleibt bis dahin die feste 501.

### Risiko
MITTEL: Sicherheitskern (Login-CSRF, Replay), aber nichts öffentlich erreichbar und keine bestehenden Konten verändert.

### Offene Fragen
- keine für den PO (Teilung, Fehlerform und Token-Verzicht sind technisch entschieden; für Henning ändert sich bis S6 nichts Sichtbares).
