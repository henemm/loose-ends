# Adversary Dialog — feat-621-s4b-2b-finish
Spec: docs/specs/feat-621-schnitt-4b2b-finish.md
Datum: 2026-11-06 19:10

## Checkliste
- [x] **AC-1:** Erfolg bis zur Sitzung: GIVEN ein vollständiger Durchlauf bis zur 303 des Rückwegs mit Ticket `{ uid, accountId }` WHEN `finish` aufgerufen wird THEN Status 303, `location` ist genau `/oauth/auth/<uid>` (die `uid` der Interaktion), der Körper ist leer, das Cookie `_interaction_resume` trägt der Browser seit `/oauth/auth`; das Ticket ist verbraucht (`consumed_at` gesetzt). WHEN danach weitergelaufen wird THEN legt der Aussteller eine Sitzung an: genau eine Zeile in `oauth_records` mit Modell `Session` und `account_id` = das Konto aus dem Rückweg; die Antwort ist 303 auf eine neue Interaktion (`/oauth/interaction/<neue uid>`) mit Prompt `consent`, und deren Abruf (mit dem neuen Cookie) endet bei der festen 501 der Zustimmung (S5); es gibt noch keinen Code und kein Token (`AuthorizationCode`, `AccessToken`, `RefreshToken`: keine Zeile). Test: „finish: erfolg legt sitzung des kontos an und endet bei der zustimmung“.
- [x] **AC-2:** Fehler-Tickets enden beim Client: GIVEN je ein Durchlauf, dessen Ticket `{ uid, error: "access_denied" }` (Apple-Fehler im Rückweg) bzw. `{ uid, error: "temporarily_unavailable" }` (Apple nicht erreichbar) trägt, Client = CIMD-Client `https://claude.ai/...` mit `redirect_uri` und `state` des Clients WHEN `finish` und danach das Weiterlaufen THEN antwortet `finish` mit 303 auf `/oauth/auth/<uid>`, das Weiterlaufen mit 303 auf den `redirect_uri` des Clients mit `error=access_denied` bzw. `error=temporarily_unavailable` und dem `state` des Clients; die `location` enthält **kein** `error_description` und keinen `code`; es gibt keine Sitzung mit `account_id` und keine Zeile `AuthorizationCode`; das Ticket ist verbraucht. Test: „finish: fehler-tickets enden als oauth-fehler beim client ohne beschreibung“.
- [x] **AC-3:** Ohne Cookie und mit fremdem Cookie scheitert es, ohne das Ticket zu verbrennen: GIVEN zwei Durchläufe A und B bis zur 303 des Rückwegs WHEN `finish` von A (a) ohne Cookie, (b) mit dem Cookie von B, (c) mit einem erfundenen Cookie-Wert aufgerufen wird THEN jeweils 400 mit Körper genau `bad request`, `content-type: text/plain; charset=utf-8`, `cache-control: no-store`, ohne `location`; das Ticket von A ist unverbraucht (`consumed_at` leer), es entsteht keine Sitzung, die Interaktion von A und B ist unverändert (kein `result`); danach gelingt `finish` von A mit dem **richtigen** Cookie wie in AC-1. Test: „finish: ohne cookie und mit fremdem cookie 400 und ticket bleibt“.
- [x] **AC-4:** Ein Ticket einer anderen Interaktion scheitert, auch mit dem eigenen Cookie: GIVEN zwei Durchläufe A und B bis zur 303 des Rückwegs, B mit anderem Konto WHEN `finish` mit dem Cookie von A, aber dem **Ticket von B** aufgerufen wird (Pfad-`uid` und Cookie von A) THEN 400 `bad request`, keine Sitzung, die Interaktion von A bekommt kein `result`; das Ticket von B **und** das von A sind unverbraucht, beide gelingen danach mit den jeweils richtigen Cookies. Gleiches mit dem Pfad von B und dem Cookie von A (Pfad-`uid` ≠ Cookie-`uid`) → 400, nichts verbraucht. Test: „finish: ticket einer anderen interaktion 400 und ticket bleibt“.
- [x] **AC-5:** Replay, Ablauf, unbekannt, fremdes Modell: GIVEN ein Durchlauf bis zur 303 des Rückwegs WHEN (a) `finish` zweimal nacheinander mit dem Cookie aufgerufen wird, (b) die Uhr um mehr als 60 s hinter die Ausgabe vorgestellt wird (Ticket abgelaufen, Interaktion noch gültig), (c) ein nie ausgegebenes Ticket (32 Zufallsbytes base64url) benutzt wird, (d) als `ticket` der `state` aus dem Hinweg (Zeile `AppleLogin`) benutzt wird THEN (a) das erste gelingt (303), das zweite ist 400 `bad request` ohne zweite Sitzung, (b) bis (d) jeweils 400 `bad request`, kein Eintrag in `Session`, `result` der Interaktion unverändert; die Zeile `AppleLogin` aus (d) bleibt unverbraucht. Test: „finish: replay abgelaufen unbekannt und fremdes modell 400“.
- [x] **AC-6:** Das Feld `ticket` genau einmal und nicht leer: GIVEN ein gültiger Durchlauf WHEN `finish` aufgerufen wird (a) ohne `ticket`, (b) mit `ticket=` (leer), (c) mit zwei `ticket`-Werten (beide gültig bzw. einer gültig, einer erfunden), (d) mit einem gültigen `ticket` und weiteren Parametern THEN (a) bis (c) jeweils 400 `bad request`, das Ticket bleibt unverbraucht; (d) gelingt wie AC-1 (weitere Parameter sind ohne Wirkung). Test: „finish: ticket genau einmal und nicht leer“.
- [x] **AC-7:** Falsche Form des Tickets lässt sich nicht einlösen: GIVEN direkt mit `new PgAdapter(pool, "AppleTicket", now)` geschriebene Zeilen für die `uid` einer laufenden Interaktion, deren Payload (a) keine `uid` trägt, (b) `uid` und weder `accountId` noch `error`, (c) `accountId` und `error` zugleich, (d) `error: "server_error"`, (e) `accountId` als Zahl, (f) leere Strings trägt WHEN `finish` mit dem Cookie und dem jeweiligen Ticket aufgerufen wird THEN jeweils 400 `bad request`, die Zeile ist unverbraucht, keine Sitzung, kein `result`. Test: „finish: ticket in falscher form wird abgelehnt und nicht verbraucht“.
- [x] **AC-8:** Pfad, Methode und Prompt: GIVEN ein gültiger Durchlauf WHEN `finish` aufgerufen wird mit dem Pfad (a) `/oauth/interaction/<uid>/finishx`, (b) `/oauth/interaction/<uid>/finish/x`, (c) `/oauth/interaction/<uid>/x`, (d) `/oauth/interaction/<uid>/` (mit Schrägstrich), (e) `/oauth/interaction/<uid>/finish/` THEN jeweils 400 `bad request` ohne Verbrauch des Tickets; GIVEN POST, PUT, DELETE auf den richtigen Pfad THEN jeweils 405 mit `allow: GET`, leerer Körper, Ticket unverbraucht; GIVEN ein Ticket für die **neue** Interaktion mit Prompt `consent` (aus AC-1, Ticket per `PgAdapter` für deren `uid` geschrieben) WHEN `finish` mit deren Cookie THEN 400 `bad request` (kein Rückfall auf die 501) und das Ticket ist unverbraucht. Gegenprobe: Der Hinweg auf `/oauth/interaction/<uid>` antwortet unverändert mit 303 zu Apple. Test: „finish: anderer pfadrest falsche methode und anderer prompt 400“.
- [x] **AC-9:** Konto gelöscht, bevor `finish` kommt: GIVEN ein Durchlauf bis zur 303 des Rückwegs mit Ticket `{ uid, accountId }` WHEN danach `deleteAccount` für dieses Konto läuft und dann `finish` aufgerufen wird THEN ist das Ticket mit abgeräumt (Kaskade), `finish` antwortet 400 `bad request`, es entsteht keine Sitzung und kein Eintrag mit der Konto-ID. Test: „finish: geloeschtes konto raeumt das ticket ab und ergibt 400“.
- [x] **AC-10:** Speicherfehler ergeben 400 und nie 5xx: GIVEN ein Pool-Ersatz, dessen `query` (a) beim Lesen der Zeile `AppleTicket`, (b) beim Einlösen (`UPDATE … consumed_at`) mit einem Fehler scheitert, dessen Text eine Konto-ID und das Ticket nennt, (c) die Interaktion zwischen Ticket-Einlösung und `interactionFinished` löscht, sodass die Bibliothek wirft (Aufbau wie der Pool-Ersatz im Hinweg-Test AC-8) WHEN `finish` aufgerufen wird THEN jeweils 400 `bad request` ohne `location`, Protokoll genau `oauth interaction store failed` (nicht `refused`), weder Konto-ID noch Ticket noch Fehlertext in Antwort oder Protokoll; in (a) und (b) ist das Ticket unverbraucht bzw. bleibt der Zustand der Datenbank konsistent (kein halber Zustand: keine Sitzung). Test: „finish: speicherfehler 400 store failed ohne werte“.
- [x] **AC-11:** Das Fehlerfenster bleibt unberührt: GIVEN ein Dienst mit injizierter Uhr, die Vorbereitung (Anmeldungen, Hinwege, Rückwege) läuft zuerst, danach wird die Uhr um mehr als 5 min vorgestellt und neue Tickets werden geschrieben WHEN ≥ 25 abgelehnte `finish`-Anfragen (400, 405) und mindestens 5 erfolgreiche (303) in 5 min beantwortet werden THEN antwortet `/health` mit 200; Gegenprobe: dieselbe Anzahl Anfragen, bei der ein Ersatz-Handler über `interaction` mit 500 antwortet (Aufbau wie `ret` in 2a AC-18), lässt `/health` auf 503 stehen (5xx zählt). Test: „finish: fehlerfenster zaehlt weder 400 noch 303“.
- [x] **AC-12:** Keine Werte im Protokoll: GIVEN alle Fälle aus AC-1 bis AC-11 WHEN `console.log`, `console.error`, `process.stdout` und `process.stderr` mitgeschnitten werden THEN besteht jede Zeile aus genau einem der festen Ereignisnamen `oauth interaction refused`, `oauth interaction store failed`, `oauth return refused`, `oauth return store failed` oder einem bestehenden festen Ereignis aus `main.ts` (`oauth server error`, `oauth error`); `refused` kommt in den Ablehnungsfällen und `store failed` in AC-10 vor; keine Zeile enthält Ticket, `uid`, Konto-ID, `sub`, Cookie-Wert, Web-ID, Apple-Adresse oder Fehlertext. Test: „finish: protokoll nur feste ereignisse ohne werte“.
- [x] **AC-13:** Der Hinweg bleibt unverändert: GIVEN die bestehenden Hinweg-Tests in `oauth-interaction.test.ts` (ohne die Nachschärfungen aus AC-14 und AC-15) und die Rückweg-Tests AC-1 bis AC-15 und AC-17 bis AC-19 aus 2a WHEN der gesamte Lauf geführt wird THEN sind alle grün. Test: bestehende Tests, unverändert.
- [x] **AC-14:** Nachschärfung 1 (Fehlerfenster des Hinweges): GIVEN der Test „hinweg: fehlerfenster unberuehrt“ WHEN er so umgebaut wird, dass die Uhr **nach** den vorbereitenden `begin()`-Anfragen um mehr als 5 min vorgestellt wird, bevor die 400er gezählt werden THEN stehen im Fenster nur noch die gezählten 400er und die 501er des Zustimmungsweges (die 501 zählt nicht), und die Gegenprobe belegt, dass der Test **rot würde**, wenn das Fenster nicht unberührt wäre: GIVEN dieselbe Anzahl 400er-Anfragen, aber dazu ≥ 25 Anfragen, die mit 500 enden, THEN antwortet `/health` mit 503 (ohne die Vorstellung der Uhr wären die 303 und die 400er der Vorbereitung als Verdünnung im Fenster geblieben und der Test hätte auch bei einem gefüllten Fenster grün sein können). Test: „hinweg: fehlerfenster unberuehrt“ (geschärft).
- [x] **AC-15:** Nachschärfung 2 (Mitschnitt des Hinweg-Tests): GIVEN der `after`-Block in `oauth-interaction.test.ts` WHEN er so umgebaut wird, dass jede mitgeschnittene Zeile gegen die **feste Ereignisliste** geprüft wird (`oauth interaction refused`, `oauth interaction store failed`, `oauth server error`, `oauth error`, `oauth return refused`, `oauth return store failed` sowie die festen Zeilen von `main.ts`, die der Test auslöst), statt gegen das Muster „Zeit plus beliebige Kleinbuchstaben“ THEN fällt eine Zeile mit einem anderen Text (z. B. einem Fehlertext in Kleinbuchstaben) durch, und der bestehende Prüfschritt auf Werte bleibt erhalten. Test: `after`-Block in `oauth-interaction.test.ts`; die Wirkung belegt ein Gegenbeispiel im Testfile (Zeile mit nicht erlaubtem Kleinbuchstabentext wird vom Prüfer abgelehnt).
- [x] **AC-16:** Der Test AC-16 von 2a wird ersetzt: GIVEN der Test „rueckweg: finish ist noch nicht behandelt und verbraucht nichts“ (behauptet das Gegenteil des neuen Verhaltens: `finish` mit und ohne Cookie → 400, Ticket unverbraucht) WHEN dieser Schnitt gebaut wird THEN ist er **gestrichen** und durch die Tests AC-1 bis AC-12 ersetzt (die Fälle „ohne Cookie“ und „mit Cookie“ stehen jetzt in AC-3 bzw. AC-1); die Streichung steht ausdrücklich im Changelog. Test: der Ersatz ist „finish: …“ aus AC-1 bis AC-12; es bleibt kein Test mit dem alten Namen.
- [x] **AC-17:** Gesamtlauf: GIVEN der fertige Schnitt WHEN `./server/scripts/test-local.sh` (typecheck + alle Tests) läuft THEN ist er grün und räumt auf; `oauth-provider.test.ts`, `main.test.ts`, `auth.test.ts`, `apple-client.test.ts` laufen unverändert grün; es gibt keinen neuen Eintrag in `server/package.json` und keine neue Migration. Dateiliste (fünf Dateien) und Funktionslänge (jede Funktion höchstens 50 Zeilen) belegt `/60-validate` per `git diff --name-only origin/main -- server`, **nicht** als Test (ein Diff-Test gegen `main` bricht in der CI und nach dem Merge). Test: Gesamtlauf `./server/scripts/test-local.sh` und CI `server.yml`; Dateiliste in `/60-validate`.

## Dialog

### Runde 1
**Adversary:** Gesamtlauf `./server/scripts/test-local.sh` (Ausgabe: docs/artifacts/feat-621-s4b-2b-finish/adversary-test-output.txt): 336 Tests, 336 pass, 0 fail, 0 skipped. Alle zwölf Tests "finish: ..." und "hinweg: fehlerfenster unberuehrt" erscheinen grün. Angriffe auf den Code:
- Cookie-uid vs. Pfad-uid vs. Ticket-uid: `detailsFor` vergleicht `details.uid === uid` (Pfad); `redeemTicket` vergleicht `form.uid !== uid` mit der Cookie-uid vor `consume`. Reihenfolge Methode, Cookie/Pfad/Prompt, Ticketfeld, find, Form, uid, consume. Kein Verbrennen durch fremde Anfragen.
- Doppel-Einlösung parallel: `find` und `consume` sind getrennt, aber `consume` ist ein einzelnes `UPDATE ... WHERE consumed_at IS NULL ... RETURNING 1`; der Verlierer wirft "oauth record not consumable", wird als `refused` (400) behandelt, erreicht `interactionFinished` nie. Höchstens eine Sitzung. Es gibt dafür keinen eigenen Parallel-Test (F001, LOW).
- Pfadzerlegung `pathParts`: `<uid>/`, `<uid>/finishx`, `<uid>/finish/`, `<uid>/finish/x` ergeben null oder falsche Teile und damit 400; durch Test AC-8 belegt.
- Ticketform: `ticketForm` verlangt genau `accountId,uid` oder `error,uid`, nichtleere Strings, bekannte Fehlerwerte; `jti` wird abgezogen, `consumed` vorher geprüft.
- Logs: nur die Konstanten REFUSED und STORE_FAILED; die catch-Blöcke geben das Fehlerobjekt nie weiter. 5xx: alle catch-Pfade enden mit 400; ein Wurf innerhalb `interactionFinished` nach gesendeten Headern lässt `headersSent` prüfen.
- Funktionslänge: längste Funktion `finishLogin` 25 Zeilen, `finishReturn` 23, alle unter 50.
- AC-1-Korrektur: in node_modules/oidc-provider 9.13.3 setzt nur `lib/actions/authorization/interactions.js:144` (cookieName('resume')) das Cookie; `lib/provider.js` `interactionFinished` schreibt nur Status 303, `Location`, `Content-Length: 0`, `interactionResult` speichert nur `interaction.result`. Behauptung bestätigt, keine Lücke (Resume-Route liest das Cookie bei `/oauth/auth/:uid`).
**Implementierer:** Keine Gegenrede nötig; Befunde unten.

### Runde 2
**Adversary:** Zweiter Angriff auf die Randfälle. (1) Eine consume-Race mit abgelaufenem Ticket zwischen find und consume: `NOT_EXPIRED` in consume, Folge refused 400. (2) Pfad ohne Präfix: `pathParts` gibt `{uid:"", finish:false}`, `startLogin` lehnt wegen uid-Vergleich ab. (3) `interactionFinished` wirft nach consume (Interaktion gelöscht): Ticket verbraucht, 400, `store failed`, keine Sitzung; vom Spec-AC-10(c) so gefordert, kein halber Zustand. (4) Fehler-Ticket: `{ error }` mit `mergeWithLastSubmission:false`, ergibt kein `error_description` (Test AC-2 grün). (5) Fallback ohne `webClientId` unverändert vor der Pfadprüfung. (6) Testdateien: oauth-return.test.ts Diff nur Cookie-Assertion korrigiert (negativ plus Vorbedingung, dass der Browser das Cookie aus /oauth/auth trägt), oauth-interaction.test.ts mit Nachschärfungen AC-14/15 bereits im RED-Commit, Tests grün. (7) package.json und migrations unverändert (Diff leer). Keine Verletzung gefunden; Early-Agreement-Skepsis: jeder AC wurde gegen Code UND Testname/Ergebnis geprüft, nicht nur gegen die Gesamtzahl.
**Implementierer:** Keine Gegenrede.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: server/src/oauth-interaction.ts:117
  Description: redeemTicket liest mit find, danach consume als getrenntes atomares UPDATE; die Einmaligkeit bei zwei gleichzeitigen finish-Aufrufen hängt allein an consume (rowCount) und dessen Auswertung NOT_CONSUMABLE.
  Spec requirement: AC-5 — Replay ergibt 400, keine zweite Sitzung
  Conflict: Kein Fehler im Code gefunden (SQL ist atomar), aber nur sequentielles Replay ist getestet, kein paralleler Test.
  Remediation: Optional Test mit Promise.all über zwei finish-Aufrufe; höchstens ein 303.

## Confirmations

Confirmation:
  AC: AC-1, AC-2, AC-3, AC-4, AC-5, AC-6, AC-7, AC-8, AC-9, AC-10, AC-11, AC-12, AC-16
  Code reference: server/src/oauth-interaction.ts:119
  Evidence: finishLogin, redeemTicket, ticketForm, pathParts, ticketQuery implementieren Reihenfolge und Fehlerpfade; die zugehörigen Tests "finish: ..." sind im Gesamtlauf grün (adversary-test-output.txt); der alte Test ist ersetzt.
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: server/src/oauth-return.ts:20
  Evidence: TICKET_MODEL als einzige Quelle für Schreiber und Leser, Verhalten des Rückwegs unverändert (Rückweg-Tests grün).
  Status: CONFIRMED

Confirmation:
  AC: AC-1, AC-3
  Code reference: server/test/oauth-return.test.ts:521
  Evidence: assertFinished prüft 303 auf /oauth/auth/<uid>, leeren Körper, kein neues Resume-Cookie; Vorbedingung ab Zeile 555 prüft Cookie aus /oauth/auth. Bibliothek 9.13.3 selbst gelesen: bestätigt.
  Status: CONFIRMED

Confirmation:
  AC: AC-13, AC-14, AC-15, AC-17
  Code reference: server/test/oauth-interaction.test.ts:1
  Evidence: Hinweg- und Nachschärfungstests grün im Gesamtlauf (336 pass, 0 fail, 0 skipped), keine Änderung in package.json oder migrations, Funktionen höchstens 25 Zeilen.
  Status: CONFIRMED

## Verdict
VERDICT: VERIFIED
Tests: 336 passed, 0 failed, 0 übersprungen
Edge cases: All checked; nur F001 (LOW, fehlender Parallel-Test, Code selbst korrekt)
Regressions: None found
Checklist: 17/17 points proven

## Geprüfte Dateien

- sha256:202e4a7e594adebf34b6ceefdb6c275435ecbceb0aa56eeb0217ee939bf6cbde  server/src/oauth-interaction.ts
- sha256:47808abb36312c7f7717279450504c430ebae809778514fa456fc9b64be5e0f9  server/src/oauth-return.ts
- sha256:2440ab2c88c17ed1ccfc0c8fc8a784c5d870696117bac2f510c89fefc1cbbc2b  server/test/oauth-interaction.test.ts
- sha256:13d67576c1d284c57a4730d10c5b615dbd874a50ada4ae17b021ca2ad3d80a38  server/test/oauth-return.test.ts

## Prüfbasis

- base: 32934fef0c39e985f567384da892ed956a73ef8f
- blob:fe0c07766d2ccaef9e67221a2cf73cbcd58caa87  server/src/oauth-interaction.ts
- blob:73cab14927daeb116d2bec3b8a31aca21f48b505  server/src/oauth-return.ts
- blob:a5f2a953b8a7439f421a1b48b7172649cc9fd7db  server/test/oauth-interaction.test.ts
- blob:883c26d2aca2fd9c8609cf80d470657d1c34e11c  server/test/oauth-return.test.ts
