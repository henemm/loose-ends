# Context: feat-621-s4b-2b-finish

## Request Summary

Schnitt 4b-2b von #621 (Epic #612, Weg B): der Abschluss der Apple-Anmeldung im Browser. Der Rückweg (S4b-2a, PR #858) legt Apples
Ergebnis als einmaliges Ticket ab und leitet per 303 auf `GET /oauth/interaction/<uid>/finish?ticket=…`; dieser Schnitt baut den Handler
dafür: Interaktions-Cookie **und** Ticket verlangen, Ticket einmal einlösen und an die `uid` binden, dann `interactionFinished` mit dem
Konto oder dem Fehler. Ende-zu-Ende bis zur festen 501 der Zustimmung (S5). Dazu die zwei offenen Nachschärfungen aus S4b-1 im Hinweg-Test.

## Stand vor dem Schnitt (2026-11-06)

- `origin/main` = `32934fe` (Merge PR #858, S4b-2a). Der Arbeitsbaum steht auf `83eae42` (dieselben Dateien, nur ohne Merge-Commit).
- Offene PRs (#859 Store-Probe, #855 #837-Belege, #854 Dependabot) berühren `server/` nicht.
- Board: #621, #615, #796 „In progress“ — #621 ist dieses Ticket, #615/#796 andere Teile, keine Dateiüberschneidung mit `server/src/oauth-*`.

## Related Files

| File | Relevance |
|------|-----------|
| `server/src/oauth-interaction.ts` (67 Z.) | `appleInteraction(deps)`, Hinweg. `pathUid` liest **alles** hinter `/oauth/interaction/` als uid; für `<uid>/finish` ist das ≠ Cookie-uid → feste 400. Hier kommt die Pfadweiche (uid + Rest `finish`) und der Abschluss hin. `deps` hat schon `pool`, `now`, `log`, `fallback`. |
| `server/src/oauth-return.ts` (140 Z.) | Rückweg. Legt `AppleTicket` mit `{ uid, accountId }` oder `{ uid, error: "access_denied" \| "temporarily_unavailable" }`, TTL 60 s, an. Typ `Ticket` ist lokal (nicht exportiert); Konstanten `TICKET_TTL`, Modellname als Literal. |
| `server/src/oauth-provider.ts` (154 Z.) | `createProvider`: Weiche fängt alles unter `/oauth/interaction/` und ruft die Interaction (`ctx.respond = false`). `finish` landet damit schon bei `appleInteraction`, **keine Änderung an der Weiche nötig**. `findAccount` prüft das Konto per `SELECT 1 FROM accounts`. |
| `server/src/main.ts` (292 Z.) | `interactionFor`/`returnFor` bauen Hin- und Rückweg unter gleichen Bedingungen; `mountIssuer` zählt jede Antwort außer 501 im Fehlerfenster, Bibliotheksfehler nur als `oauth server error`/`oauth error`. Voraussichtlich unverändert. |
| `server/src/oauth-adapter.ts` | `PgAdapter(pool, model, now)`: `find`, `consume` (zweites wirft), Hash-IDs, `payload.accountId` → FK `account_id` mit Cascade. Ticket-Einlösung nutzt dasselbe Muster wie `redeemState` im Rückweg. |
| `server/node_modules/oidc-provider/lib/provider.js` (9.13.3) | `interactionFinished(req, res, result, { mergeWithLastSubmission })` → `interactionResult` → `#getInteraction` liest **nur** das Cookie `_interaction` (Pfad `/oauth/interaction/<uid>`, `SameSite=Lax`), speichert `result`, antwortet 303 auf `returnTo` (`/oauth/auth/<uid>`, braucht Cookie `_interaction_resume`). Mit `'error' in result` wird nicht gemergt; der Client bekommt den OAuth-Fehler am `redirect_uri`. Prüft die uid im Pfad nicht. |
| `server/test/oauth-return.test.ts` (542 Z.) | Testaufbau für den ganzen Weg (`begin`, `fakeApple`, `service`, `raw`, Mitschnitt). Test „rueckweg: finish ist noch nicht behandelt und verbraucht nichts“ (Z. 493, AC-16 von 2a) **widerspricht** dem neuen Verhalten und muss ersetzt werden. |
| `server/test/oauth-interaction.test.ts` (367 Z.) | Hinweg-Tests. Nachschärfung 1: „hinweg: fehlerfenster unberuehrt“ (Z. 323) zählt die `begin()`-Anfragen mit ins Fenster (Verdünnung). Nachschärfung 2: `after`-Mitschnitt (Z. 174) erlaubt jede Zeile der Form `<Zeit> [a-z ,]*`, nicht nur die festen Ereignisse. |
| `docs/specs/feat-621-schnitt-4b2a-rueckweg.md` | Vorgänger-Spec; Abschnitt „Out of Scope“ umreißt S4b-2b. |
| `docs/context/feat-621-s4b-2-rueckweg.md` | Analyse für S4b-2 gesamt (Recherche, Login-CSRF, Teilung 2a/2b: 2b ≈ 60 Code + ≈ 180 Test). |
| `docs/artifacts/feat-621-s4b-2-rueckweg/adversary-dialog.md` | Vier LOW-Befunde aus 2a (F001–F004), siehe Risiken. |
| `CLAUDE.md` (`server/`-Abschnitt) | Zeilen zu `oauth-interaction.ts` und `oauth-return.ts` nennen `finish` als S4b-2b; nachziehen. |

## Existing Patterns

- **Feste Antworten ohne Werte:** `badRequest` (400 `bad request`, `text/plain`, `no-store`) in Hin- und Rückweg; Protokoll nur feste Ereignisnamen
  (`oauth interaction refused`, `oauth interaction store failed`, `oauth return refused`, `oauth return store failed`).
- **Einmal-Einlösen:** `find` + Typprüfung des Payloads + `consume` (wirft beim zweiten Mal) → wie `redeemState` in `oauth-return.ts`.
- **Cookie-uid gegen Pfad-uid:** `interactionDetails` liest nur das Cookie; `appleInteraction` vergleicht `details.uid` selbst mit dem Pfad.
- **Tests:** `node:test` + `node:assert/strict`, Wegwerf-Schema je Dienst, eingereichtes `fetch`, kein Netz; Ende-zu-Ende mit CIMD-Client über
  `/oauth/auth`, Hinweg (`begin`), Rückweg (`fakeApple`) – echter Aussteller, echte Datenbank. Mitschnitt von stdout/stderr über das ganze File.
- **Fehlerfenster:** `mountIssuer` zählt jede Antwort außer 501; Tests stellen die Uhr vor, damit Vorbereitungs-Anfragen nicht im Fenster liegen
  (so in AC-18 von 2a gebaut, im Hinweg-Test noch nicht).

## Dependencies

- Upstream: oidc-provider 9.13.3 (`interactionDetails`, `interactionFinished`, Cookies `_interaction`/`_interaction_resume`, `SameSite=Lax`),
  `PgAdapter` (Modell `AppleTicket`), `findAccount` im Aussteller, `accounts`/`deleteAccount` (Cascade auf `oauth_records`).
- Downstream: S5 Zustimmungsseite (der `consent`-Prompt nach dem Login; heute feste 501), Web-Token-Ablage vor S6, S6 Betrieb
  (nginx `/oauth/*`, `APPLE_WEB_CLIENT_ID`, Schlüssel in Compose). Erst mit S5 bekommt Claude einen Code und ein Token.

## Existing Specs

- `docs/specs/feat-621-schnitt-4b2a-rueckweg.md` — Rückweg, Ticket-Format, Out-of-Scope-Beschreibung von 2b
- `docs/specs/feat-621-schnitt-4b1-hinweg.md` — Hinweg, Nachschärfungen 1–3 (3 in 2a erledigt)
- `docs/specs/feat-621-schnitt-3-aussteller.md` — Aussteller, Weiche, `productInteraction`
- `docs/specs/feat-621-mcp-anmeldung.md` — Gesamtbild Anmeldung

## Risks & Considerations

- **Login-CSRF ist die Kernprüfung:** Ticket allein reicht nicht (ein Angreifer könnte ein eigenes Ticket in einen fremden Browser schieben); Cookie
  allein reicht nicht. Verlangt: Cookie-uid == Pfad-uid == Ticket-uid, Ticket einmalig. Muss mit Gegenproben belegt werden (fremdes Ticket,
  fremdes Cookie, Ticket einer anderen Interaktion, Replay, abgelaufen).
- **Reist das Lax-Cookie mit?** Der Weg ist: Apples seitenübergreifender POST → 303 → top-level GET auf `finish`. Die Analyse von S4b-2 nimmt an,
  dass `SameSite=Lax` beim top-level GET nach dem 303 mitgeht. In der Analyse dieses Schnitts per Recherche belegen (Browser-Verhalten bei
  Redirect-Ketten mit seitenübergreifendem Ursprung; Safari/ITP). Sonst trägt der ganze Ticket-Weg nicht.
- **Konto zwischen Ticket und `finish` gelöscht:** `deleteAccount` räumt Tickets mit ab (Cascade) → kein Ticket → feste 400. Falls die Löschung
  zwischen Einlösen und `interactionFinished` fällt, schreibt die Bibliothek eine Session mit `accountId` → FK-Fehler im Aussteller (500,
  Fehlerobjekt nennt die Konto-ID, darf nie ins Protokoll; `mountIssuer` loggt nur feste Namen). Verhalten im Test festlegen.
- **Fehler-Tickets:** `access_denied` / `temporarily_unavailable` → `interactionFinished({ error, … })` ohne Merge; der Client (claude.ai) bekommt
  den Fehler am `redirect_uri`. Prüfen, dass keine `error_description` mit Werten entsteht.
- **Fehlerfenster:** ein fehlerhaftes `finish` darf kein 5xx sein; `temporarily_unavailable` endet als 303 zum Client, nicht als 5xx.
- **Bestehender Test widerspricht:** AC-16 von 2a („finish ist noch nicht behandelt“) muss ersetzt werden; die Streichung gehört in den
  Changelog der neuen Spec (Lehre aus F004 von 2a).
- **Offene LOW-Befunde aus 2a:** F001 (`redeemState` loggt Datenbankfehler im `consume` als `refused` statt `store failed`), F002 (nach 413 wird
  der Rest per `resume()` ohne Zeitgrenze gelesen). Beim Ticket-Einlösen in `finish` nicht wiederholen; ob F001/F002 im Rückweg mitbehoben werden,
  entscheidet die Analyse (Scope).
- **Umfang:** 2a lag bei ≈ 720 LoC statt geschätzt 320 (Code 1,6×, Tests 2,5×). Für 2b nannte die Analyse ≈ 60 + 180; realistisch mit den
  Gegenproben ≈ 90 Code + ≈ 300 Test plus die zwei Nachschärfungen. Liegt über ±250 LoC → in der Analyse ehrlich schätzen und vor dem Bauen
  melden, ggf. Nachschärfungen abtrennen.
- **Keine Gerätestufe:** nur `server/`, kein Pfad der Geräteliste; Abnahme endet nach `./server/scripts/test-local.sh` und CI `server.yml`.

## Analysis

### Type
Feature (Schnitt 4b-2b von #621: Abschluss der Apple-Anmeldung im Browser)

### Recherche (2026-11-06)

- **Reist das Lax-Cookie zu `finish`?** Ja, nach Standard. RFC 6265bis: `SameSite=Lax` geht mit jeder *top-level navigation* mit sicherer
  Methode mit, auch seitenübergreifend ([draft-ietf-httpbis-rfc6265bis](https://httpwg.org/http-extensions/draft-ietf-httpbis-rfc6265bis.html)).
  Apples `form_post` ist ein seitenübergreifender POST: dort fehlt das Cookie (deshalb trägt der Rückweg es nicht und legt ein Ticket an). Die 303
  macht daraus ein top-level **GET** auf `finish` → Lax-Cookie wird gesendet. Fallberichte anderer (Discourse, Spring, Ash) scheitern genau
  am POST-Schritt, nicht am anschließenden GET ([Discourse](https://meta.discourse.org/t/sign-in-with-apple/122790/40?tl=en),
  [Apple-Forum](https://developer.apple.com/forums/thread/133037), [Ash](https://elixirforum.com/t/ash-authentication-sign-in-with-apple-post-callback-missing/72697)).
  Für Safari/WebKit fand sich kein eigener Beleg; der Echtbrowser-Nachweis (Safari + Chrome, echte Apple-Anmeldung) gehört in S6.
- **Alternative, falls ein Browser das Cookie doch zurückhält:** Rückweg antwortet statt 303 mit einer kleinen Seite, die selbst auf `finish`
  weiterleitet (Navigation startet dann auf unserer eigenen Seite → same-site). Kippt keine ADR, nur `oauth-return.ts`. Erst bauen, wenn S6 es zeigt.
- **Bibliothek (oidc-provider 9.13.3, gelesen):** `interactionFinished` → `#getInteraction` liest nur Cookie `_interaction`, speichert `result`,
  303 auf `returnTo` (`/oauth/auth/<uid>`). `resume.js`: `result.error` → `errorMap` (`AccessDenied`, `TemporarilyUnavailable`, beide **ohne**
  Standard-`error_description`) → Fehler am `redirect_uri` des Clients; `result.login` → `session.loginAccount({ accountId, transient: !remember })`.
  Danach Prompt `consent` → neue Interaktion → `appleInteraction` → Fallback 501.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/oauth-interaction.ts` | MODIFY | Pfadweiche: `<uid>` → Hinweg wie bisher, `<uid>/finish` → Abschluss; alles andere feste 400. Abschluss (GET only): Cookie (`interactionDetails`) → Pfad-uid == Cookie-uid → Prompt `login` → genau ein `ticket` in der Query → `find` (Modell `AppleTicket`) → Ticket-uid == Cookie-uid → `consume` → `interactionFinished` mit `{ login: { accountId, remember: false } }` oder `{ error }` ohne Beschreibung, `mergeWithLastSubmission: false`. Jede Ablehnung feste 400; Ereignisse `oauth interaction refused` / `oauth interaction store failed`. ≈ +55 |
| `server/src/oauth-return.ts` | MODIFY | `Ticket`-Typ und Modellnamen/TTL exportieren (eine Quelle für beide Seiten), Kommentar „finish is S4b-2b“ nachziehen. ≈ +4/−3 |
| `server/test/oauth-return.test.ts` | MODIFY | Test „finish ist noch nicht behandelt“ (AC-16 von 2a) ersetzen durch die finish-Tests: Ende-zu-Ende bis Zustimmung 501 mit Session des Kontos; Fehler-Tickets → 303 an `claude.ai`-Callback mit `error=access_denied` bzw. `temporarily_unavailable`, ohne `error_description`; Gegenproben ohne Cookie, fremdes Cookie, Ticket einer anderen Interaktion, Replay, abgelaufen (Uhr), unbekannt, fehlendes/doppeltes `ticket`, anderer Pfadrest, POST; Konto gelöscht → Ticket weg → 400; Fehlerfenster; Protokoll. ≈ +230/−14 |
| `server/test/oauth-interaction.test.ts` | MODIFY | Nachschärfung 1: Uhr nach den `begin()`-Anfragen vorstellen, damit nur die 400er im Fenster stehen. Nachschärfung 2: `after`-Mitschnitt nur gegen die feste Ereignisliste prüfen. ≈ +12/−6 |
| `CLAUDE.md` | MODIFY | Zeilen zu `oauth-interaction.ts`/`oauth-return.ts`: finish gebaut. ≈ +2/−2 |

### Scope Assessment
- Files: 5
- Estimated LoC: ≈ +300 / −25 (Code ≈ 60, Tests ≈ 240, Doku ≈ 4) — **über ±250**, Grund: Gegenproben zur Login-CSRF-Sicherung
- Risk Level: MEDIUM — Sicherheitsgrenze (wer im Browser als welches Konto angemeldet wird), aber nur `server/`, noch nicht öffentlich erreichbar (`/oauth/*` erst mit S6 durch nginx)

### Technical Approach
Reihenfolge der Prüfungen so, dass ein falsches Ticket nichts verbraucht: erst Cookie und Pfad, dann Ticket finden und dessen uid vergleichen, **erst
dann** einlösen. So kann eine Anfrage mit fremdem Cookie das Ticket des echten Nutzers nicht verbrennen. Cookie-uid == Pfad-uid == Ticket-uid,
Ticket einmal (atomar über `consume`), 60 s. `remember: false`: die Browser-Sitzung beim Aussteller endet mit dem Browser; Claudes Zugang hält
das Refresh-Token, eine dauerhafte Sitzung bringt nichts und wäre auf fremden Rechnern ein Risiko. Alternative: `remember: true` (eine zweite
Verbindung aus claude.ai fragt Apple nicht erneut) — nicht gewählt, kein Nutzen im Ablauf „einmal verbinden“.
Fehlerfälle nach dem Einlösen (Speichern der Interaktion scheitert) → feste 400 `store failed`, nie 5xx. Nicht abfangbar und bewusst offen: Konto
wird genau zwischen Einlösen und Session-Schreiben gelöscht → FK-Fehler im Aussteller → 500, geloggt nur als `oauth server error` (Fenster von
Millisekunden; vor dem Einlösen räumt die Kaskade das Ticket ab → 400, wird getestet).
Nicht in diesem Schnitt: F001/F002 aus 2a (LOW, Rückweg) — bleiben wie in 2a angenommen; Web-Token-Ablage (eigener Schnitt vor S6); Zustimmungsseite (S5).
Alternative zum ganzen Schnitt: Nachschärfungen 1+2 abtrennen spart nur ≈ 18 LoC; die Gegenproben selbst lassen sich nicht abtrennen (sie sind der Beleg für die Sicherheitsgrenze).

### Dependencies
oidc-provider 9.13.3 (`interactionDetails`, `interactionFinished`, `resume`), `PgAdapter` (`find`/`consume`), Rückweg S4b-2a (Ticket-Format),
`accounts`-Kaskade. Downstream: S5 Zustimmung, S6 Betrieb (dort Echtbrowser-Nachweis Safari + Chrome).

### Open Questions
- [x] Umfang ≈ 325 LoC statt ±250: Henning 2026-11-06 „Ja, als ein Schritt“ — Spec nennt die Ausnahme mit Begründung
