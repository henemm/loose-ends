---
entity_id: feat-621-schnitt-4b2b-finish
type: feature
created: 2026-11-06
updated: 2026-11-06
status: draft
workflow: feat-621-s4b-2b-finish
---

# Spec: Anmeldung über Apple im Browser, Abschluss `finish` (Schnitt 4b-2b, #621, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#621 (Epic #612). Schnitt 4b-2b; das Issue bleibt offen (`Refs #621`, nie `Closes #621`, Größe L, mehrere Schnitte).
Analyse: `docs/context/feat-621-s4b-2b-finish.md` (Abschnitte „Analysis“, „Recherche“, „Technical Approach“, „Risks“); Vorgänger: `docs/specs/feat-621-schnitt-4b2a-rueckweg.md` (Rückweg, Ticket `AppleTicket`), `docs/specs/feat-621-schnitt-4b1-hinweg.md` (Hinweg, Nachschärfungen 1 und 2), S3 (Aussteller), S2 (`PgAdapter`). Folge: S5 (Zustimmung), Web-Token-Ablage vor S6, S6 (Betrieb).

## Für den PO

Wenn du Claude im Browser mit Loose Ends verbindest, schickt dich der Dienst zu Apple, Apple schickt dich zurück, und der Dienst hält das Ergebnis eine Minute bereit. Dieser Schnitt baut den **letzten Schritt**: Dein Browser holt das Ergebnis ab, und der Dienst schließt die Anmeldung ab. Er prüft dabei streng, dass das Ergebnis zu **genau diesem Browser und genau dieser einen Anmeldung** gehört. Damit kann niemand einem fremden Browser eine Anmeldung unterschieben, und ein abgefangener oder wiederholter Abruf bewirkt nichts.

Für dich ändert sich **nichts Sichtbares**: Der Dienst ist von außen noch nicht erreichbar, die App und deine Daten sind nicht berührt. Auch nach diesem Schnitt bekommt Claude noch keinen Zugang, weil die Zustimmungsseite (S5) fehlt; der Ablauf endet vorerst an einer festen Absage an dieser Stelle. **Zu entscheiden hast du nichts.** Technisch entschieden: Die Anmeldung im Browser wird nicht „gemerkt“ (sie endet mit dem Browser; Claudes Zugang hält sein eigenes Token).

## Purpose

Der Handler `GET /oauth/interaction/<uid>/finish?ticket=<ticket>` schließt die Login-Interaktion ab, die der Hinweg (S4b-1) gestartet und der Rückweg (S4b-2a) mit einem Ticket beantwortet hat. Er verlangt **zwei Dinge zugleich**: das Interaktions-Cookie des Browsers (Cookie-`uid`) und das Ticket (Ticket-`uid`), beide müssen der `uid` im Pfad gleichen. Das Ticket allein reicht nicht (ein Angreifer könnte sein eigenes Ticket in einen fremden Browser schieben: Login-CSRF), das Cookie allein reicht nicht (es sagt nichts über das Ergebnis).

Der Abschluss tut genau dies und nicht mehr:

1. Pfad lesen und aufteilen: `/oauth/interaction/<uid>` → Hinweg wie bisher, `/oauth/interaction/<uid>/finish` → Abschluss, jeder andere Rest → feste 400.
2. Im Abschluss, in fester Reihenfolge, **so dass ein falsches Ticket nichts verbraucht**: Methode, Cookie (`interactionDetails`), Pfad-`uid` = Cookie-`uid`, Prompt `login`, genau ein `ticket` in der Query, Ticket finden und seine Form prüfen, Ticket-`uid` = Cookie-`uid`, **erst dann** das Ticket einlösen (`consume`), dann `provider.interactionFinished`.
3. Ergebnis an den Aussteller: `{ login: { accountId, remember: false } }` bzw. `{ error }` (`access_denied` oder `temporarily_unavailable`, ohne `error_description`), `mergeWithLastSubmission: false`. Die Bibliothek antwortet mit 303 auf `/oauth/auth/<uid>`; von dort geht der Browser mit dem Cookie `_interaction_resume` weiter: bei Erfolg legt der Aussteller die Browser-Sitzung für das Konto an und fragt danach die Zustimmung ab (heute feste 501, S5); bei einem Fehler-Ticket bekommt der Client (claude.ai) den OAuth-Fehler an seinem `redirect_uri`.

Jede Ablehnung ist eine feste Antwort ohne Wert (400 `bad request`, 405 bei falscher Methode), nie ein 5xx aus eigenem Code.

**Regeln vor Modell:** Protokoll- und Sicherheitsablauf ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

Festlegungen aus der Analyse (Recherche 2026-11-06):

- **Reihenfolge schützt das Ticket.** Cookie, Pfad und Prompt werden vor dem Ticket geprüft, `find` mit Formprüfung und Vergleich der Ticket-`uid` vor `consume`. Eine Anfrage mit fremdem Cookie oder fremdem Ticket verbrennt deshalb nie das Ticket des echten Nutzers (AC-3, AC-4, AC-6, AC-8).
- **`remember: false`.** Die Browser-Sitzung beim Aussteller endet mit dem Browser (`transient`). Der Zugang für Claude hält das Refresh-Token; eine dauerhafte Sitzung bringt im Ablauf „einmal verbinden“ nichts und wäre auf fremden Rechnern ein Risiko. Die Bibliothek-Voreinstellung wäre `remember = true`. Gelesen in oidc-provider 9.13.3: `transient` wirkt nur auf das Cookie (`shared/session.js` hängt dann kein `expires` an), die Sitzung wird trotzdem mit `session.save(ttl)` in `oauth_records` abgelegt — AC-1 kann sie dort belegen.
- **Fehler-Tickets enden beim Client, nicht in einem 5xx.** `interactionFinished({ error })` ohne Zusammenführung; die Bibliothek (`resume.js`, `errorMap`) bildet `access_denied` und `temporarily_unavailable` auf `AccessDenied` bzw. `TemporarilyUnavailable` ohne Standard-Beschreibung ab; weil das Ticket keine `error_description` trägt, entsteht keine (gelesen: `errors.js` definiert beide ohne Standardtext, `err_out.js` setzt `error_description` nur, wenn sie nicht `undefined` ist).
- **Das Cookie reist mit (Annahme, nach Standard belegt).** Der seitenübergreifende POST von Apple trägt das `SameSite=Lax`-Cookie nicht (deshalb das Ticket); die 303 macht daraus eine top-level-Navigation mit sicherer Methode (GET), und Lax-Cookies gehen dabei mit (RFC 6265bis). Safari ist ohne eigenen Beleg; der Echtbrowser-Nachweis gehört in S6 (siehe Risiken).
- **Protokoll:** nur feste Ereignisnamen `oauth interaction refused` und `oauth interaction store failed`, nie Ticket, `uid`, Konto-ID, `sub`, Cookie, Fehlertexte oder Fehlerobjekte.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — setzt den Plan aus dem ADR-21-Nachtrag (Schnitt 4: Apple in der Interaction des Ausstellers) um; ADR-21, die S4a-Wahl `form_post` und die Teilung 2a/2b bleiben unberührt, keine neue Abhängigkeit, keine Migration.

**Rationale:** Der Abschluss ist die Stelle, an der entschieden wird, wer im Browser als welches Konto angemeldet wird. Er gehört in die Interaction des Ausstellers (nur dort ist `interactionFinished` mit dem Cookie sauber verfügbar), die Weiche in `createProvider` fängt `/oauth/interaction/` bereits ab und bleibt unverändert.

## Source

**Files:** `server/src/oauth-interaction.ts` (ändern), `server/src/oauth-return.ts` (ändern), `server/test/oauth-return.test.ts` (ändern), `server/test/oauth-interaction.test.ts` (ändern), `CLAUDE.md` (ändern).
**Identifier:** `appleInteraction`, `Ticket`, `TICKET_MODEL`, `PgAdapter` (Modell `AppleTicket`), `Provider.interactionDetails`, `Provider.interactionFinished`, `createProvider`, `mountIssuer`, `interactionFor`, `ErrorWindow`

### Schnittstelle

- **`server/src/oauth-return.ts`** (ändern): `Ticket` (heute lokal) und eine Konstante `TICKET_MODEL = "AppleTicket"` werden exportiert und im Rückweg statt des Literals benutzt; damit gibt es **eine Quelle** für Schreiber (Rückweg) und Leser (`finish`). Der Kopfkommentar („finish itself … is S4b-2b; until then nobody signs in“) wird auf „finish closes the sign-in (oauth-interaction.ts, S4b-2b)“ nachgezogen. Verhalten, Ablauf und Meldungen des Rückwegs bleiben unverändert; `TICKET_TTL` bleibt lokal (nur der Schreiber braucht sie).
- **`server/src/oauth-interaction.ts`** (ändern): `appleInteraction(deps)` behält Signatur und Deps (`pool`, `config`, `publicUrl`, `now`, `fallback`, `keys`, `log`). Der Pfad wird in `uid` und Rest zerlegt (heute liest `pathUid` alles hinter `/oauth/interaction/` als `uid`):
  - kein `/` hinter der `uid` → **Hinweg**, Verhalten byte-gleich zu S4b-1 (inklusive: ohne `webClientId` der `fallback`; Cookie-/Pfad-Vergleich; Prompt ≠ `login` → `fallback`; Ablauf der Interaktion; Ablage `AppleLogin`);
  - Rest genau `finish` → **Abschluss** (unten);
  - jeder andere Rest (`<uid>/`, `<uid>/finishx`, `<uid>/finish/x`, `<uid>/x`) → feste 400 `bad request` (Protokoll `oauth interaction refused`). Ohne `webClientId` gilt für beide Pfade wie bisher der `fallback`.
  - Aufteilung (jede Funktion ≤ 50 Zeilen, Namen als Vorschlag): `route` (Weiche), `startLogin` (heutiger Hinweg), `finishLogin` (Abschluss), `redeemTicket` (Ticket finden, prüfen, einlösen), `ticketQuery` (genau ein `ticket`).
- **Abschluss** (`finishLogin`), feste Reihenfolge; jede Ablehnung nennt keinen Wert:
  1. Methode ≠ GET → **405**, Header `allow: GET`, `cache-control: no-store`, leerer Körper, Protokoll `oauth interaction refused`. Begründung der Festlegung 405 statt 400: Der Rückweg antwortet auf eine falsche Methode ebenso (405 mit `allow`), die Antwort enthält keinen Wert und ist für eine Navigation des Browsers nie der Normalfall; der bestehende Hinweg prüft die Methode nicht und bleibt dabei unangetastet. Es wird nichts gelesen, nichts verbraucht.
  2. `provider.interactionDetails(req, res)` (liest nur das Cookie `_interaction`): wirft (kein Cookie, unbekannt, abgelaufen) → 400, `refused`.
  3. `details.uid` ≠ `uid` im Pfad → 400, `refused`.
  4. `details.prompt.name` ≠ `login` → 400, `refused` (anders als beim Hinweg **kein** Rückfall auf die 501: `finish` schließt nur einen Login ab; ein Ticket für eine Interaktion im Prompt `consent` hat keinen Sinn).
  5. `ticket` in der Query: genau ein Wert, nicht leer (`URLSearchParams.getAll`); sonst 400, `refused`. Weitere Parameter werden ignoriert und nicht gelesen.
  6. `new PgAdapter(pool, TICKET_MODEL, now).find(ticket)`: Datenbankfehler → 400, `store failed`; unbekannt, abgelaufen (Uhr > 60 s), Modell fremd oder bereits verbraucht (`consumed` gesetzt) → 400, `refused`. Der Payload wird auf genau eine der beiden Formen geprüft: `{ uid: string (nicht leer), accountId: string (nicht leer) }` oder `{ uid: string (nicht leer), error: "access_denied" | "temporarily_unavailable" }`, beide zugleich oder weitere Form → 400, `refused`, **ohne** einzulösen.
  7. Ticket-`uid` ≠ `details.uid` → 400, `refused`, **ohne** einzulösen (das fremde Ticket bleibt unverbraucht).
  8. `consume(ticket)`: wirft mit der Meldung des Adapters für „nicht einlösbar“ (`oauth record not consumable`, z. B. zweiter Abruf) → 400, `refused`; jeder andere Fehler (Datenbank) → 400, `store failed`. (So wird der Befund F001 aus 2a hier nicht wiederholt.)
  9. `provider.interactionFinished(req, res, result, { mergeWithLastSubmission: false })` mit `result = { login: { accountId, remember: false } }` bzw. `{ error }` (nur `error`, kein `error_description`). Die Bibliothek schreibt die 303 auf `/oauth/auth/<uid>` selbst. Wirft sie vor dem Schreiben (z. B. Interaktion inzwischen abgelaufen) → 400, `store failed`; geschrieben wird dann nichts.
  - Feste 400: `content-type: text/plain; charset=utf-8`, `cache-control: no-store`, Körper genau `bad request`.
- **Unverändert:** `server/src/oauth-provider.ts` (Weiche, `INTERACTION_PATH`, `productInteraction`), `server/src/main.ts` (`interactionFor`, `returnFor`, `mountIssuer`, Fehlerfenster: jede Antwort außer der festen 501 zählt; 400 und 303 sind keine 5xx), `server/src/oauth-adapter.ts`, `accounts.ts`, `apple*.ts`, Migrationen.

### Festlegungen

- **Keine Werte in Antworten, Protokoll, Fehlern:** weder Ticket, `uid`, Konto-ID, `sub`, Cookie noch Fehlertext; die einzige Antwort mit `uid` ist die `location` der Bibliothek.
- **Nie 5xx aus eigenem Code:** jede Ablehnung ist 400/405; Fehler beim Speichern ergeben 400 `store failed`. Nicht abgefangen (siehe Risiken) ist allein ein Fehlerfall **in** der Bibliothek nach dem Einlösen.
- **Alles Bestehende bleibt grün,** außer dem ersetzten Test (AC-16 aus 2a, siehe AC-15 und Changelog).
- **Länge und Stil:** jede Funktion höchstens 50 Zeilen; Kommentare knapp auf Englisch; Tests `node:test` + `node:assert/strict`, eingereichtes `fetch`, kein Netz, Wegwerf-Schema je Dienst.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `oidc-provider` 9.13.3: `interactionDetails`, `interactionFinished`, `resume`-Aktion, Cookies `_interaction` / `_interaction_resume` (`SameSite=Lax`) | bestehend, ungeändert |
| `PgAdapter` (`find`, `consume`, Modell `AppleTicket`, Fremdschlüssel `account_id` mit Kaskade) | bestehend, ungeändert |
| Rückweg S4b-2a (Ticket-Format, `Ticket`/`TICKET_MODEL` neu exportiert) | bestehend, minimal erweitert |
| `findAccount` im Aussteller (prüft das Konto per `SELECT 1 FROM accounts`), `deleteAccount` | bestehend, ungeändert |
| Tests: `begin`, `fakeApple`, `service`, `raw`, `through`, `ticketOf`, Mitschnitt aus `oauth-return.test.ts`; CIMD-Client `https://claude.ai/...` | bestehend im Testfile |
| Downstream | S5 (Zustimmungsseite, `consent`-Prompt), Web-Token-Ablage vor S6, S6 (nginx `/oauth/*`, `APPLE_WEB_CLIENT_ID`, Schlüssel in Compose, Echtbrowser-Nachweis) |

## Acceptance Criteria

Tests in `server/test/oauth-return.test.ts` (Aufbau wie in 2a: `start()` mit `oauth: { publicUrl: "https://loose-ends.test", keys, fetch: <CIMD-Client> }` und `auth: { config, fetch: <fakeApple> }`, Web-ID `com.henning.looseends.web`; die Anmeldung läuft mit dem CIMD-Client über `/oauth/auth`, den Hinweg und den Rückweg bis zur 303 auf `finish`; Apple ist immer `fakeApple`). „`finish`“ meint `GET <location der 303 des Rückwegs>` mit dem Interaktions-Cookie des Browsers, der den Hinweg gemacht hat, soweit nicht anders genannt. „Weiterlaufen“ meint `GET` der `location` von `finish` mit dem Cookie `_interaction_resume` aus dessen Antwort.

- **AC-1:** Erfolg bis zur Sitzung: GIVEN ein vollständiger Durchlauf bis zur 303 des Rückwegs mit Ticket `{ uid, accountId }` WHEN `finish` aufgerufen wird THEN Status 303, `location` ist genau `/oauth/auth/<uid>` (die `uid` der Interaktion), die Antwort setzt das Cookie `_interaction_resume`, der Körper ist leer; das Ticket ist verbraucht (`consumed_at` gesetzt). WHEN danach weitergelaufen wird THEN legt der Aussteller eine Sitzung an: genau eine Zeile in `oauth_records` mit Modell `Session` und `account_id` = das Konto aus dem Rückweg; die Antwort ist 303 auf eine neue Interaktion (`/oauth/interaction/<neue uid>`) mit Prompt `consent`, und deren Abruf (mit dem neuen Cookie) endet bei der festen 501 der Zustimmung (S5); es gibt noch keinen Code und kein Token (`AuthorizationCode`, `AccessToken`, `RefreshToken`: keine Zeile). Test: „finish: erfolg legt sitzung des kontos an und endet bei der zustimmung“.
- **AC-2:** Fehler-Tickets enden beim Client: GIVEN je ein Durchlauf, dessen Ticket `{ uid, error: "access_denied" }` (Apple-Fehler im Rückweg) bzw. `{ uid, error: "temporarily_unavailable" }` (Apple nicht erreichbar) trägt, Client = CIMD-Client `https://claude.ai/...` mit `redirect_uri` und `state` des Clients WHEN `finish` und danach das Weiterlaufen THEN antwortet `finish` mit 303 auf `/oauth/auth/<uid>`, das Weiterlaufen mit 303 auf den `redirect_uri` des Clients mit `error=access_denied` bzw. `error=temporarily_unavailable` und dem `state` des Clients; die `location` enthält **kein** `error_description` und keinen `code`; es gibt keine Sitzung mit `account_id` und keine Zeile `AuthorizationCode`; das Ticket ist verbraucht. Test: „finish: fehler-tickets enden als oauth-fehler beim client ohne beschreibung“.
- **AC-3:** Ohne Cookie und mit fremdem Cookie scheitert es, ohne das Ticket zu verbrennen: GIVEN zwei Durchläufe A und B bis zur 303 des Rückwegs WHEN `finish` von A (a) ohne Cookie, (b) mit dem Cookie von B, (c) mit einem erfundenen Cookie-Wert aufgerufen wird THEN jeweils 400 mit Körper genau `bad request`, `content-type: text/plain; charset=utf-8`, `cache-control: no-store`, ohne `location`; das Ticket von A ist unverbraucht (`consumed_at` leer), es entsteht keine Sitzung, die Interaktion von A und B ist unverändert (kein `result`); danach gelingt `finish` von A mit dem **richtigen** Cookie wie in AC-1. Test: „finish: ohne cookie und mit fremdem cookie 400 und ticket bleibt“.
- **AC-4:** Ein Ticket einer anderen Interaktion scheitert, auch mit dem eigenen Cookie: GIVEN zwei Durchläufe A und B bis zur 303 des Rückwegs, B mit anderem Konto WHEN `finish` mit dem Cookie von A, aber dem **Ticket von B** aufgerufen wird (Pfad-`uid` und Cookie von A) THEN 400 `bad request`, keine Sitzung, die Interaktion von A bekommt kein `result`; das Ticket von B **und** das von A sind unverbraucht, beide gelingen danach mit den jeweils richtigen Cookies. Gleiches mit dem Pfad von B und dem Cookie von A (Pfad-`uid` ≠ Cookie-`uid`) → 400, nichts verbraucht. Test: „finish: ticket einer anderen interaktion 400 und ticket bleibt“.
- **AC-5:** Replay, Ablauf, unbekannt, fremdes Modell: GIVEN ein Durchlauf bis zur 303 des Rückwegs WHEN (a) `finish` zweimal nacheinander mit dem Cookie aufgerufen wird, (b) die Uhr um mehr als 60 s hinter die Ausgabe vorgestellt wird (Ticket abgelaufen, Interaktion noch gültig), (c) ein nie ausgegebenes Ticket (32 Zufallsbytes base64url) benutzt wird, (d) als `ticket` der `state` aus dem Hinweg (Zeile `AppleLogin`) benutzt wird THEN (a) das erste gelingt (303), das zweite ist 400 `bad request` ohne zweite Sitzung, (b) bis (d) jeweils 400 `bad request`, kein Eintrag in `Session`, `result` der Interaktion unverändert; die Zeile `AppleLogin` aus (d) bleibt unverbraucht. Test: „finish: replay abgelaufen unbekannt und fremdes modell 400“.
- **AC-6:** Das Feld `ticket` genau einmal und nicht leer: GIVEN ein gültiger Durchlauf WHEN `finish` aufgerufen wird (a) ohne `ticket`, (b) mit `ticket=` (leer), (c) mit zwei `ticket`-Werten (beide gültig bzw. einer gültig, einer erfunden), (d) mit einem gültigen `ticket` und weiteren Parametern THEN (a) bis (c) jeweils 400 `bad request`, das Ticket bleibt unverbraucht; (d) gelingt wie AC-1 (weitere Parameter sind ohne Wirkung). Test: „finish: ticket genau einmal und nicht leer“.
- **AC-7:** Falsche Form des Tickets lässt sich nicht einlösen: GIVEN direkt mit `new PgAdapter(pool, "AppleTicket", now)` geschriebene Zeilen für die `uid` einer laufenden Interaktion, deren Payload (a) keine `uid` trägt, (b) `uid` und weder `accountId` noch `error`, (c) `accountId` und `error` zugleich, (d) `error: "server_error"`, (e) `accountId` als Zahl, (f) leere Strings trägt WHEN `finish` mit dem Cookie und dem jeweiligen Ticket aufgerufen wird THEN jeweils 400 `bad request`, die Zeile ist unverbraucht, keine Sitzung, kein `result`. Test: „finish: ticket in falscher form wird abgelehnt und nicht verbraucht“.
- **AC-8:** Pfad, Methode und Prompt: GIVEN ein gültiger Durchlauf WHEN `finish` aufgerufen wird mit dem Pfad (a) `/oauth/interaction/<uid>/finishx`, (b) `/oauth/interaction/<uid>/finish/x`, (c) `/oauth/interaction/<uid>/x`, (d) `/oauth/interaction/<uid>/` (mit Schrägstrich), (e) `/oauth/interaction/<uid>/finish/` THEN jeweils 400 `bad request` ohne Verbrauch des Tickets; GIVEN POST, PUT, DELETE auf den richtigen Pfad THEN jeweils 405 mit `allow: GET`, leerer Körper, Ticket unverbraucht; GIVEN ein Ticket für die **neue** Interaktion mit Prompt `consent` (aus AC-1, Ticket per `PgAdapter` für deren `uid` geschrieben) WHEN `finish` mit deren Cookie THEN 400 `bad request` (kein Rückfall auf die 501) und das Ticket ist unverbraucht. Gegenprobe: Der Hinweg auf `/oauth/interaction/<uid>` antwortet unverändert mit 303 zu Apple. Test: „finish: anderer pfadrest falsche methode und anderer prompt 400“.
- **AC-9:** Konto gelöscht, bevor `finish` kommt: GIVEN ein Durchlauf bis zur 303 des Rückwegs mit Ticket `{ uid, accountId }` WHEN danach `deleteAccount` für dieses Konto läuft und dann `finish` aufgerufen wird THEN ist das Ticket mit abgeräumt (Kaskade), `finish` antwortet 400 `bad request`, es entsteht keine Sitzung und kein Eintrag mit der Konto-ID. Test: „finish: geloeschtes konto raeumt das ticket ab und ergibt 400“.
- **AC-10:** Speicherfehler ergeben 400 und nie 5xx: GIVEN ein Pool-Ersatz, dessen `query` (a) beim Lesen der Zeile `AppleTicket`, (b) beim Einlösen (`UPDATE … consumed_at`) mit einem Fehler scheitert, dessen Text eine Konto-ID und das Ticket nennt, (c) die Interaktion zwischen Ticket-Einlösung und `interactionFinished` löscht, sodass die Bibliothek wirft (Aufbau wie der Pool-Ersatz im Hinweg-Test AC-8) WHEN `finish` aufgerufen wird THEN jeweils 400 `bad request` ohne `location`, Protokoll genau `oauth interaction store failed` (nicht `refused`), weder Konto-ID noch Ticket noch Fehlertext in Antwort oder Protokoll; in (a) und (b) ist das Ticket unverbraucht bzw. bleibt der Zustand der Datenbank konsistent (kein halber Zustand: keine Sitzung). Test: „finish: speicherfehler 400 store failed ohne werte“.
- **AC-11:** Das Fehlerfenster bleibt unberührt: GIVEN ein Dienst mit injizierter Uhr, die Vorbereitung (Anmeldungen, Hinwege, Rückwege) läuft zuerst, danach wird die Uhr um mehr als 5 min vorgestellt und neue Tickets werden geschrieben WHEN ≥ 25 abgelehnte `finish`-Anfragen (400, 405) und mindestens 5 erfolgreiche (303) in 5 min beantwortet werden THEN antwortet `/health` mit 200; Gegenprobe: dieselbe Anzahl Anfragen, bei der ein Ersatz-Handler über `interaction` mit 500 antwortet (Aufbau wie `ret` in 2a AC-18), lässt `/health` auf 503 stehen (5xx zählt). Test: „finish: fehlerfenster zaehlt weder 400 noch 303“.
- **AC-12:** Keine Werte im Protokoll: GIVEN alle Fälle aus AC-1 bis AC-11 WHEN `console.log`, `console.error`, `process.stdout` und `process.stderr` mitgeschnitten werden THEN besteht jede Zeile aus genau einem der festen Ereignisnamen `oauth interaction refused`, `oauth interaction store failed`, `oauth return refused`, `oauth return store failed` oder einem bestehenden festen Ereignis aus `main.ts` (`oauth server error`, `oauth error`); `refused` kommt in den Ablehnungsfällen und `store failed` in AC-10 vor; keine Zeile enthält Ticket, `uid`, Konto-ID, `sub`, Cookie-Wert, Web-ID, Apple-Adresse oder Fehlertext. Test: „finish: protokoll nur feste ereignisse ohne werte“.
- **AC-13:** Der Hinweg bleibt unverändert: GIVEN die bestehenden Hinweg-Tests in `oauth-interaction.test.ts` (ohne die Nachschärfungen aus AC-14 und AC-15) und die Rückweg-Tests AC-1 bis AC-15 und AC-17 bis AC-19 aus 2a WHEN der gesamte Lauf geführt wird THEN sind alle grün. Test: bestehende Tests, unverändert.
- **AC-14:** Nachschärfung 1 (Fehlerfenster des Hinweges): GIVEN der Test „hinweg: fehlerfenster unberuehrt“ WHEN er so umgebaut wird, dass die Uhr **nach** den vorbereitenden `begin()`-Anfragen um mehr als 5 min vorgestellt wird, bevor die 400er gezählt werden THEN stehen im Fenster nur noch die gezählten 400er und die 501er des Zustimmungsweges (die 501 zählt nicht), und die Gegenprobe belegt, dass der Test **rot würde**, wenn das Fenster nicht unberührt wäre: GIVEN dieselbe Anzahl 400er-Anfragen, aber dazu ≥ 25 Anfragen, die mit 500 enden, THEN antwortet `/health` mit 503 (ohne die Vorstellung der Uhr wären die 303 und die 400er der Vorbereitung als Verdünnung im Fenster geblieben und der Test hätte auch bei einem gefüllten Fenster grün sein können). Test: „hinweg: fehlerfenster unberuehrt“ (geschärft).
- **AC-15:** Nachschärfung 2 (Mitschnitt des Hinweg-Tests): GIVEN der `after`-Block in `oauth-interaction.test.ts` WHEN er so umgebaut wird, dass jede mitgeschnittene Zeile gegen die **feste Ereignisliste** geprüft wird (`oauth interaction refused`, `oauth interaction store failed`, `oauth server error`, `oauth error`, `oauth return refused`, `oauth return store failed` sowie die festen Zeilen von `main.ts`, die der Test auslöst), statt gegen das Muster „Zeit plus beliebige Kleinbuchstaben“ THEN fällt eine Zeile mit einem anderen Text (z. B. einem Fehlertext in Kleinbuchstaben) durch, und der bestehende Prüfschritt auf Werte bleibt erhalten. Test: `after`-Block in `oauth-interaction.test.ts`; die Wirkung belegt ein Gegenbeispiel im Testfile (Zeile mit nicht erlaubtem Kleinbuchstabentext wird vom Prüfer abgelehnt).
- **AC-16:** Der Test AC-16 von 2a wird ersetzt: GIVEN der Test „rueckweg: finish ist noch nicht behandelt und verbraucht nichts“ (behauptet das Gegenteil des neuen Verhaltens: `finish` mit und ohne Cookie → 400, Ticket unverbraucht) WHEN dieser Schnitt gebaut wird THEN ist er **gestrichen** und durch die Tests AC-1 bis AC-12 ersetzt (die Fälle „ohne Cookie“ und „mit Cookie“ stehen jetzt in AC-3 bzw. AC-1); die Streichung steht ausdrücklich im Changelog. Test: der Ersatz ist „finish: …“ aus AC-1 bis AC-12; es bleibt kein Test mit dem alten Namen.
- **AC-17:** Gesamtlauf: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf; `oauth-provider.test.ts`, `main.test.ts`, `auth.test.ts`, `apple-client.test.ts` laufen unverändert grün; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Dateiliste (fünf Dateien) und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Test: Gesamtlauf `./server/scripts/test-local.sh` und CI `server.yml`; Dateiliste in `/60-validate`.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/oauth-interaction.ts` | MODIFY | Pfadweiche (`<uid>` / `<uid>/finish` / sonst 400), Abschluss `finishLogin` mit `redeemTicket`, `ticketQuery`; Hinweg in `startLogin` verschoben, ≈ +55 |
| `server/src/oauth-return.ts` | MODIFY | `Ticket` und `TICKET_MODEL` exportiert, Kommentar nachgezogen, ≈ +4/−3 |
| `server/test/oauth-return.test.ts` | MODIFY | Test AC-16 aus 2a ersetzt durch AC-1 bis AC-12 („finish: …“), ≈ +230/−14 |
| `server/test/oauth-interaction.test.ts` | MODIFY | Nachschärfungen 1 und 2 (AC-14, AC-15), ≈ +12/−6 |
| `CLAUDE.md` | MODIFY | `server/`-Abschnitt: Zeilen zu `oauth-interaction.ts` und `oauth-return.ts` (finish gebaut), ≈ +2/−2 |

### Estimated Changes

- **Files: 5** (Code: `oauth-interaction.ts`, `oauth-return.ts`; Tests: `oauth-return.test.ts`, `oauth-interaction.test.ts`; Doku: `CLAUDE.md`). Innerhalb des Limits von 4 bis 5.
- **Code ≈ 60 LoC, Tests ≈ 240 LoC, Doku ≈ 4 LoC, insgesamt ≈ 325 LoC** (Zeilen hinzugefügt, geändert und gelöscht). Das liegt **über dem Limit von ±250 LoC**. Warum angenommen: Die Last liegt in den Gegenproben zur Login-CSRF-Sicherung (ohne Cookie, fremdes Cookie, Ticket einer anderen Interaktion, Replay, Ablauf, Form, Pfad, Methode, Prompt, gelöschtes Konto, Speicherfehler). Sie sind der **Beleg der Sicherheitsgrenze** („wer im Browser als welches Konto angemeldet wird“) und lassen sich weder kürzen noch in einen späteren Schnitt verschieben, ohne dass der Abschluss unbelegt ausgeliefert würde. Henning hat die Überschreitung am 2026-11-06 ausdrücklich freigegeben („Ja, als ein Schritt“). Präzedenz: 2a lag bei ≈ 720 LoC statt geschätzter 320 (Code 1,6×, Tests 2,5×); deshalb ist die Schätzung hier ehrlich auf ≈ 325 gesetzt, mit der Erwartung, dass die Tests eher darüber liegen. **Meldeschwelle beim Bauen:** wächst die Summe über 420 LoC, wird das vor dem Weiterbauen gemeldet.
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Migration, kein `generate`, keine neue Abhängigkeit.
- Doku als Teil des Schnitts: `CLAUDE.md` (`server/`-Abschnitt) bei `src/oauth-interaction.ts` (Abschluss `finish` gebaut: Pfadweiche, Cookie + Ticket + Pfad-`uid`, `interactionFinished`, `remember: false`) und bei `src/oauth-return.ts` („finish itself … S4b-2b“ streichen, `Ticket`/`TICKET_MODEL` exportiert).
- Seiteneffekte nach außen: keine. Der Dienst ist nicht erreichbar (nginx bis S6); ohne `APPLE_WEB_CLIENT_ID` und OAuth-Schlüssel ändert sich kein Verhalten; auch mit Abschluss bekommt Claude weder Code noch Token, weil die Zustimmung (S5) fehlt.

## Risiken

- **Login-CSRF (Kernrisiko):** Wird eine der drei Bindungen (Pfad-`uid`, Cookie-`uid`, Ticket-`uid`) oder die Einmaligkeit des Tickets nicht geprüft, könnte ein Angreifer einem fremden Browser seine Anmeldung unterschieben. Gegenmittel: feste Reihenfolge, Einlösen erst nach allen Vergleichen, Gegenproben AC-3 bis AC-8 mit „Ticket bleibt unverbraucht“.
- **Reist das Lax-Cookie zu `finish`?** Nach RFC 6265bis gehen `SameSite=Lax`-Cookies bei einer top-level-Navigation mit sicherer Methode auch seitenübergreifend mit; der Rückweg ist ein seitenübergreifender POST (Cookie fehlt dort, daher das Ticket), die 303 erzeugt daraus einen top-level-GET auf `finish`. Quellen: [RFC 6265bis](https://httpwg.org/http-extensions/draft-ietf-httpbis-rfc6265bis.html); Fallberichte scheitern am POST-Schritt, nicht am anschließenden GET ([Discourse](https://meta.discourse.org/t/sign-in-with-apple/122790/40?tl=en), [Apple-Forum](https://developer.apple.com/forums/thread/133037), [Ash](https://elixirforum.com/t/ash-authentication-sign-in-with-apple-post-callback-missing/72697)). **Für Safari/WebKit gibt es keinen eigenen Beleg.** Die Tests (Node-`fetch`) beweisen die Server-Logik, nicht das Browserverhalten. Der Nachweis in Safari und Chrome mit echter Apple-Anmeldung gehört in S6. Zeigt er, dass ein Browser das Cookie zurückhält, ist die Alternative in „Alternativen“ der Weg (nur `oauth-return.ts`, keine ADR).
- **Konto in Millisekunden zwischen Einlösen und Sitzung gelöscht:** `deleteAccount` räumt das Ticket vor `finish` mit ab (AC-9, 400). Fällt die Löschung genau zwischen `consume` und das Schreiben der Sitzung durch die Bibliothek, schreibt diese eine Sitzung mit einer Konto-ID, die es nicht mehr gibt: Fremdschlüsselfehler im Aussteller, 500. Das ist ein Fenster von Millisekunden, wird **bewusst nicht abgefangen** (kein AC erzwingt es) und ist kein Datenleck: `mountIssuer` protokolliert Bibliotheksfehler nur als `oauth server error`/`oauth error`, das Fehlerobjekt (dessen Detail die Konto-ID nennt) erreicht weder Protokoll noch Antwort.
- **Werte im Protokoll oder in der Antwort:** Fehlerobjekte der Datenbank (Konto-ID im Detail), Ticket, `uid`, Cookie: AC-10, AC-12; der Mitschnitt erlaubt nur feste Ereignisse.
- **Fehlerfenster:** Ein Fehler im Abschluss darf kein 5xx sein, sonst zieht `/health` auf 503 (Dienst ist im Monitor kritisch). Ablehnungen sind 400/405, Erfolg und Fehler-Ticket enden in 303 (AC-11). Ein Fehler **innerhalb** der Bibliothek (siehe oben) wäre ein 500 und zählt.
- **Befunde F001 und F002 aus 2a bleiben offen** (beide LOW, im Rückweg): F001 (Datenbankfehler im `consume` des `state` als `refused` statt `store failed`) und F002 (Rest nach 413 ohne Zeitgrenze gelesen). Sie liegen in `oauth-return.ts`, ändern keine Sicherheitsgrenze (Antwort in beiden Fällen identisch bzw. kein Wert betroffen) und würden den Schnitt über die Freigabe hinaus vergrößern; der neue Abschluss wiederholt F001 nicht (Schritt 8). Sie werden in einem eigenen kleinen Schnitt oder beim Anfassen der Datei behoben.
- **Datenschutz:** keine neuen Daten; gelesen werden Ticket (Hash in `oauth_records`, 60 s) und Cookie; gespeichert wird allein das Ergebnis in der Interaktion und die Sitzung des Ausstellers (transient). Datenschutztext unberührt.

## Test Plan

### Automated Tests (TDD RED)

RED: `appleInteraction` kennt den Pfad `<uid>/finish` nicht (er endet in der festen 400), `Ticket` und `TICKET_MODEL` werden nicht exportiert; alle Tests „finish: …“ schlagen fehl (400 statt 303), „finish: fehlerfenster zaehlt weder 400 noch 303“ schlägt an der 303-Erwartung fehl. Die Schärfung in AC-14 ist rot gegen einen Dienst, dessen Fenster nicht unberührt ist (Gegenprobe im Test), AC-15 rot gegen ein Muster, das beliebigen Kleinbuchstabentext durchlässt.

| Testname | AC |
|---|---|
| „finish: erfolg legt sitzung des kontos an und endet bei der zustimmung“ | AC-1 |
| „finish: fehler-tickets enden als oauth-fehler beim client ohne beschreibung“ | AC-2 |
| „finish: ohne cookie und mit fremdem cookie 400 und ticket bleibt“ | AC-3 |
| „finish: ticket einer anderen interaktion 400 und ticket bleibt“ | AC-4 |
| „finish: replay abgelaufen unbekannt und fremdes modell 400“ | AC-5 |
| „finish: ticket genau einmal und nicht leer“ | AC-6 |
| „finish: ticket in falscher form wird abgelehnt und nicht verbraucht“ | AC-7 |
| „finish: anderer pfadrest falsche methode und anderer prompt 400“ | AC-8 |
| „finish: geloeschtes konto raeumt das ticket ab und ergibt 400“ | AC-9 |
| „finish: speicherfehler 400 store failed ohne werte“ | AC-10 |
| „finish: fehlerfenster zaehlt weder 400 noch 303“ | AC-11 |
| „finish: protokoll nur feste ereignisse ohne werte“ | AC-12 |
| bestehende Hinweg- und Rückweg-Tests, unverändert | AC-13 |
| „hinweg: fehlerfenster unberuehrt“ (geschärft) | AC-14 |
| `after`-Block in `oauth-interaction.test.ts` (Mitschnitt gegen feste Ereignisliste) | AC-15 |
| Streichung „rueckweg: finish ist noch nicht behandelt und verbraucht nichts“ | AC-16 |
| `./server/scripts/test-local.sh`, `/60-validate` (Dateiliste per `git diff`) | AC-17 |

- [ ] Test 1 (AC-1, AC-2): GIVEN Durchlauf bis zur 303 des Rückwegs WHEN `finish` und Weiterlaufen THEN Sitzung des Kontos und feste 501 der Zustimmung bzw. OAuth-Fehler ohne Beschreibung am `redirect_uri` des Clients mit dessen `state`.
- [ ] Test 2 (AC-3, AC-4): GIVEN zwei Durchläufe WHEN ohne Cookie, mit fremdem Cookie, mit Ticket der anderen Interaktion THEN 400, beide Tickets unverbraucht und danach einlösbar.
- [ ] Test 3 (AC-5, AC-6, AC-7): GIVEN Replay, Ablauf, unbekannt, `state` als Ticket, fehlendes, leeres und doppeltes `ticket`, Ticket in falscher Form WHEN `finish` THEN 400 und nichts verbraucht (außer beim ersten gültigen Abruf).
- [ ] Test 4 (AC-8, AC-9, AC-10): GIVEN anderer Pfadrest, falsche Methode, Prompt `consent`, gelöschtes Konto, Speicherfehler WHEN `finish` THEN 400/405 ohne Werte, `store failed` bei Speicherfehlern.
- [ ] Test 5 (AC-11, AC-12): GIVEN die Fälle aus AC-1 bis AC-10 WHEN Fehlerfenster und Protokoll geprüft werden THEN `/health` 200 (und 503 bei der 5xx-Gegenprobe) und nur feste Ereignisse.
- [ ] Test 6 (AC-13 bis AC-17): GIVEN Altbestand, geschärfte Hinweg-Tests, gestrichener Test, Gesamtlauf WHEN `./server/scripts/test-local.sh` THEN alles grün, keine neue Abhängigkeit, keine Migration.

**Keine UI-Tests:** keine Oberfläche, kein sichtbarer Ablauf.

## Alternativen

| Weg | Was | Spricht dafür | Spricht dagegen | Gekippt würde |
|---|---|---|---|---|
| **A (gewählt): `finish` mit Cookie + Ticket + Pfad-`uid`, Einlösen zuletzt** | Abschluss als eigener Pfadrest der Interaction, `interactionFinished` mit `remember: false` | bindet den Abschluss an denselben Browser, keine neue Cookie-Sorte, keine Migration, ein falscher Aufruf verbrennt nichts | zusätzlicher Pfad und eine Reihe Gegenproben | — |
| B Abschluss ohne Ticket direkt im Rückweg (`POST`) | `interactionFinished` bzw. Konto-Zuordnung schon im Rückweg | ein Schritt weniger | der seitenübergreifende POST trägt das Lax-Cookie nicht, der Abschluss wäre nicht an den Browser gebunden: Login-CSRF | die Bindung an den Browser als Sicherheitsannahme von S4b (bereits in 2a verworfen) |
| C `remember: true` | Sitzung des Browsers beim Aussteller bleibt über das Browserende hinaus; eine zweite Verbindung aus claude.ai fragt Apple nicht erneut | weniger Apple-Anmeldungen | im Ablauf „einmal verbinden“ kein Nutzen; dauerhafte Sitzung auf fremden Rechnern ein Risiko; Claudes Zugang hält das Refresh-Token ohnehin | die Wahl `remember: false`; ein Ein-Zeilen-Wechsel im Aufruf, falls Henning später „bleib angemeldet“ will |
| D Zwischenseite statt 303 im Rückweg | der Rückweg antwortet mit einer kleinen Seite, die selbst auf `finish` weiterleitet (die Navigation startet dann auf der eigenen Seite, also same-site) | wirkt, falls ein Browser das Lax-Cookie nach der 303 zurückhält | HTML-Antwort, Skript- oder Meta-Refresh-Weg; nach heutigem Stand unnötig | nur `oauth-return.ts`, keine ADR; **wird erst gebaut, wenn der Echtbrowser-Nachweis in S6 es zeigt** |
| E Nachschärfungen 1 und 2 abtrennen | `oauth-interaction.test.ts` in einem eigenen Schnitt | kleinerer Schnitt | spart nur ≈ 18 LoC; dieselbe Testwelt (Mitschnitt, Fenster) wird zweimal angefasst; die Gegenproben selbst lassen sich ohnehin nicht abtrennen (sie belegen die Sicherheitsgrenze) | die Entscheidung „als ein Schritt“ (Henning, 2026-11-06) |
| F Bei anderem Prompt als `login` auf die 501 zurückfallen (wie im Hinweg) | `finish` im Prompt `consent` meldet die feste Absage | gleiches Verhalten wie im Hinweg | verschleiert einen Fehlaufruf als „Zustimmung kommt noch“; ein Ticket gehört zu einem Login | die Festlegung „nur Prompt `login`“ in Schritt 4 |

A bis C und D sind in der Analyse behandelt; B ist bereits in S4b verworfen und wird hier nicht neu verhandelt.

## Out of Scope / Folgeschnitte

- **Zustimmungsseite und Erlaubnisliste (S5):** `consent`-Prompt, Code und Token für Claude, nur Henning bis #625. Bis dahin endet der Ablauf an der festen 501.
- **Web-Token-Ablage (eigener Schnitt vor S6):** Ablage des Web-Refresh-Tokens je Konto und `client_id` (Migration 005), Widerruf beim Löschen, Entscheidung über sofortigen Widerruf.
- **Betrieb (S6):** Services ID im Apple-Konto, nginx `/oauth/*`, `APPLE_WEB_CLIENT_ID` und OAuth-Schlüssel in Compose (Repo `henemm-infra`), Echtbrowser-Nachweis Safari und Chrome.
- **F001 und F002 aus 2a** (Rückweg, LOW): nicht in diesem Schnitt, Begründung unter „Risiken“.

## Abnahme

Kein Pfad der Geräteliste berührt. (Nur `server/`, keine App, kein `project.yml`.) Die Abnahme endet nach den Tests: `./server/scripts/test-local.sh` (typecheck + `node --test` gegen ein Wegwerf-Postgres) grün und die CI `server.yml` auf dem PR grün. Ein Simulator-Durchlauf entfällt, weil es reiner Dienstcode ohne Oberfläche ist und der Dienst von außen noch nicht erreichbar ist; der Abschluss wird in den Tests Ende-zu-Ende vom CIMD-Client über `/oauth/auth`, Hinweg, Rückweg (nur Apple ist `fakeApple`) und `finish` bis zur Sitzung des Kontos und zur festen 501 der Zustimmung durchgespielt (echter Aussteller, echte Datenbank). Stufe 3 entfällt.

## Definition of Done

- [ ] AC-1 bis AC-17 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `server.yml` grün
- [ ] Der Test „rueckweg: finish ist noch nicht behandelt und verbraucht nichts“ ist gestrichen und ersetzt (AC-16)
- [ ] `CLAUDE.md` (`server/`-Abschnitt) aktualisiert: `oauth-interaction.ts` (Pfadweiche, Abschluss `finish`, Cookie + Ticket + Pfad-`uid`, `remember: false`) und `oauth-return.ts` (Hinweis „finish S4b-2b“ ersetzt, `Ticket`/`TICKET_MODEL` exportiert)
- [ ] #621 kommentiert (Stand Schnitt 4b-2b; Folge: S5 Zustimmung, Web-Token-Ablage vor S6, S6 mit Echtbrowser-Nachweis; F001/F002 offen), Board-Karte aktuell

## Changelog

- 2026-11-06: Initial spec created (Schnitt 4b-2b)
- 2026-11-06: **Ersetzt** den Test „rueckweg: finish ist noch nicht behandelt und verbraucht nichts“ (AC-16 aus `feat-621-schnitt-4b2a-rueckweg`, `oauth-return.test.ts`): Er behauptet das Gegenteil des neuen Verhaltens (`finish` mit und ohne Cookie → 400, Ticket unverbraucht). Seine Fälle gehen in „finish: ohne cookie und mit fremdem cookie 400 und ticket bleibt“ (AC-3) und „finish: erfolg legt sitzung des kontos an und endet bei der zustimmung“ (AC-1) auf. Die Spec von 2a bleibt als Stand von 2a unverändert.
