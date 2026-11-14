---
entity_id: feat-615-schnitt-4f-abnahme
type: feature
created: 2026-11-14
updated: 2026-11-14
status: draft
workflow: feat-615-s4f-abnahme
---

# Spec: Abnahme Konto und Anmeldung, Schnitt S4f (#615, Weg B)

## Approval

- [ ] Approved

## GitHub Issue

#615 (Epic #612). Schnitt S4f, der letzte: er liefert die zwei offenen Punkte der Definition of Done des Tickets. Das Issue bleibt bis Hennings Rückmeldung zum TestFlight-Lauf offen (`Refs #615`, nie `Closes #615`).
Analyse: `docs/context/feat-615-s4f-abnahme.md` (Abschnitt „Analysis“ und die PO-Entscheidung unter „Open Questions“, verbindlich).
Vorgänger: S4c-1 (Gruppe „Claude“, nur gegen Stellvertreter belegt), S4c-2a/b, S4d (Anmeldewege live offen), S4e (Datenschutz); Debug-Weg aus #795 S3b-2 (`docs/specs/feat-795-schnitt-3b2-debug-weg.md`).
Es sind **drei Code-/Testdateien**: `server/scripts/local-fixture.ts` (geändert), `LooseEndsUITests/AccountLocalServiceTests.swift` (neu), `scripts/sim.sh` (geändert). Belege unter `docs/artifacts/feat-615-s4f-abnahme/` zählen nicht zum Dateilimit.

## Für den PO

Für dich ändert sich in der App nichts. Dieser Schnitt belegt, dass Anmelden, Abmelden und Konto löschen wirklich funktionieren, und zwar so, dass ich es selbst beweisen kann: Abmelden und Löschen spiele ich im Simulator gegen einen echten, nur auf diesem Mac laufenden Dienst durch und zeige, dass danach nichts von dem Konto übrig ist. Du hast entschieden, dass dein echtes Konto nicht gelöscht wird. Das Anmelden mit deinem Apple-Konto kann nur dein Gerät zeigen: dafür bekommst du nach dem Merge eine TestFlight-Version, die du anmeldest, abmeldest und wieder anmeldest. Ehrlich dazu: dass der Dienst beim Löschen Apple benachrichtigt (Widerruf), ist lokal nicht auslösbar, weil es dort kein Apple gibt; dieser Aufruf ist nur über die Dienst-Tests mit einer Attrappe belegt, und das steht im Abschluss so.

## Purpose

Die Definition of Done von #615 verlangt: Anmelden, Abmelden und Konto löschen im Simulator gegen den lokalen Dienst belegt, danach keine Zeile des Kontos mehr, Apple-Widerruf ausgelöst, plus Stufe 3 über TestFlight. Bisher gibt es die Gruppe „Claude“ nur gegen den Stellvertreter-Transport (`AccountSettingsTests`, `--ui-testing`, kein Netz) und das Löschen nur per Aufruf gegen eine Wegwerf-Datenbank. Lehre aus #136: eine Attrappe beweist die Kette nicht. S4f spielt Abmelden und Löschen mit dem echten `ServiceClient` gegen den echten Dienstcode durch und liest danach die Datenbank, ohne Produktcode zu ändern.

### Befund (aus der Analyse, am Code geprüft)

- Lokal gibt es keine Apple-Anmeldung: `server/scripts/local-service.sh` entfernt alle `APPLE_*`, `/auth/apple` antwortet 503. „Angemeldet“ heißt lokal: Sitzung per Fixture plus Debug-Weg (`-LEDebugService`, `-LEDebugSession`, `AccountWiring.debugService`; Sitzung nur im Speicher, echter `ServiceClient`). Anmelden mit Apple belegt nur TestFlight.
- Abmelden (`AccountState.signOut` → `POST /auth/logout`) und Löschen (`AccountState.deleteAccount` → `POST /auth/delete`) laufen lokal echt.
- `deleteAccount` (`server/src/accounts.ts`) löscht in einer Transaktion `order_results`, `orders`, `transcripts` und die OAuth-Zeilen der Grants und das Konto in `accounts`; `sessions`, `apple_tokens`, `device_tokens` und `oauth_records` mit `account_id` folgen per `ON DELETE CASCADE` (Migrationen 002, 004, 008). `revokeAfterDelete` (`server/src/auth.ts`) ruft je `apple_tokens`-Zeile den Widerruf; ohne Zeile oder ohne Apple-Konfiguration schreibt es `apple revoke skipped` (über `logError` auf stderr des Dienstes).
- Ein Zählbefehl „Zeilen des Kontos“ fehlt im Fixture. Wichtig: jeder bestehende Unterbefehl ruft `findOrCreate(pool, "local-fixture")`; nach dem Löschen würde das das Konto neu anlegen und den Nachweis „keine Zeile mehr“ verfälschen. `rows` darf es darum nicht rufen.

### Teil 1: Fixture-Erweiterung (`server/scripts/local-fixture.ts`)

Zwei neue Unterbefehle, **keine Änderung an `server/src/`**, gleiche Schutzregel wie bisher (`DATABASE_URL` nur mit Host `127.0.0.1` oder `localhost`, sonst Ausgang 1 vor dem ersten Datenbankzugriff). Meldungen enthalten nie einen Token oder ein Geheimnis.

- `rows`: **rein lesend, ruft `findOrCreate` nicht** (legt nie ein Konto an). Gibt je eine Zeile `<tabelle>=<anzahl>` aus, in dieser festen Reihenfolge: `accounts`, `sessions`, `transcripts`, `orders`, `order_results`, `apple_tokens`, `oauth_records`, `device_tokens`. Gezählt wird jede Tabelle ganz (`SELECT count(*)`): die Wegwerf-Datenbank enthält nur das Fixture-Konto, so ist „0 in jeder Tabelle“ gleich „keine Zeile des Kontos und keine Waise“. Die Tabellennamen stehen fest im Skript (keine Eingabe in SQL).
- `apple-token`: legt für das Fixture-Konto (`findOrCreate`) eine `apple_tokens`-Zeile an: `encryptToken` (`apple-vault.ts`) mit einem zufälligen 32-Byte-Schlüssel und einem festen Platzhaltertext als Klartext, `storeRefreshToken` mit `clientId` `local-fixture-client`. Gibt `apple_tokens=1` aus. Ein zweiter Aufruf ersetzt die Zeile (Primärschlüssel `account_id, client_id`), es bleibt eine. Der Schlüssel wird nicht gespeichert: die Zeile ist absichtlich nicht entschlüsselbar, der Dienst läuft lokal ohne Apple-Konfiguration und überspringt sie ohnehin. Zweck: das Löschen entfernt nachweislich auch diese Zeile.

Der Kopfkommentar der Datei nennt die zwei neuen Unterbefehle. Die Usage-Meldung bei unbekanntem Unterbefehl auch.

### Teil 2: UI-Test gegen den lokalen Dienst (`LooseEndsUITests/AccountLocalServiceTests.swift`)

Neue XCTest-Klasse `AccountLocalServiceTests`. Sie startet die App **ohne** `--ui-testing` (das würde den Stellvertreter wählen, AC-8 von #795 S3b-2) mit `-LEDebugService <url>`, `-LEDebugSession <token>`, `-onboardingDone YES`, `-AppleLanguages (en)`, `-AppleLocale en_US`. Adresse und Token kommen aus der Umgebung des Testläufers: `LOOSEENDS_DEBUG_SERVICE` und `LOOSEENDS_DEBUG_SESSION` (von `sim.sh` als `TEST_RUNNER_…` durchgereicht, Teil 3). Fehlt eine der beiden oder ist sie leer, endet **jeder** Test mit `XCTSkip` und einem benannten Grund („kein lokaler Dienst: LOOSEENDS_DEBUG_SERVICE und LOOSEENDS_DEBUG_SESSION fehlen“); so bleibt die Klasse in der CI grün und nennt ihre übersprungenen Tests einzeln. Auf dem Mac `XCTSkip` wie in `AccountSettingsTests`.

Zwei Tests, die **einzeln** per `test-proof AccountLocalServiceTests/<test>` laufen, jeweils mit einer frischen Sitzung des Fixture-Kontos (das Protokoll in Teil 4 legt fest, wann welche Sitzung entsteht):

- `testSignOutEndsOnlyThisSession`: öffnet die Einstellungen (Zahnrad `settingsButton`), findet `accountSignedInRow` (Status „verbunden“ kommt aus dem Debug-Weg, ohne Anmeldedialog), tippt `accountSignOutRow` (keine Rückfrage), erwartet `accountAppleButton` und den Einleitungssatz (`accountHint`), Screenshot vorher und nachher als Anhang.
- `testDeleteRemovesTheAccount`: wie oben bis zur Zeile, tippt `accountDeleteRow`, erwartet die Rückfrage „Delete account?“, bestätigt mit „Delete account“, erwartet das Verschwinden von `accountSignedInRow` und den Anmeldeknopf, Screenshot der Rückfrage und danach.

Die Hilfsfunktionen (Einstellungen öffnen, Zeile sichtbar scrollen, Anhang) werden **nicht** aus `AccountSettingsTests` geteilt (private dort), sondern in der neuen Datei knapp nachgebaut, damit `AccountSettingsTests` unberührt bleibt. Der Test prüft die Oberfläche; was im Dienst geschieht, liest nur das Fixture (`rows`) außerhalb des Tests.

### Teil 3: Durchreiche (`scripts/sim.sh`)

Im `run_xcodebuild`-Abschnitt für `test` (neben `LOOSEENDS_UI_LANG`) zwei Zeilen: sind `LOOSEENDS_DEBUG_SERVICE` und `LOOSEENDS_DEBUG_SESSION` gesetzt, werden sie als `TEST_RUNNER_LOOSEENDS_DEBUG_SERVICE` und `TEST_RUNNER_LOOSEENDS_DEBUG_SESSION` exportiert, sonst bleibt der Aufruf byte-gleich. Die Kommentarzeile und die Usage-Zeile von `test-proof` im Kopf nennen die Variablen und den Satz: nur gegen die Wegwerf-Datenbank von `local-service.sh`, nie ein Token des Live-Dienstes. `scripts/ui_smoke_shards.py` bleibt unberührt: die Klasse wird wie jede andere automatisch einem CI-Teil zugeteilt und überspringt dort ihre zwei Tests.

### Teil 4: Protokoll A (lokal, Belege unter `docs/artifacts/feat-615-s4f-abnahme/protokoll-a.md`)

Feste Befehlsfolge, in einer Bash mit `set -m` (siehe Selbsttest in der Spec von #795 S3b-2), Ausgaben wörtlich im Protokoll:

1. `server/scripts/local-service.sh` im Hintergrund, Ausgabe in eine Logdatei, `state.env` lesen (`SERVICE_URL`, `DATABASE_URL`, `SESSION_TOKEN`).
2. Zeilen füllen: `local-fixture.ts apple-token`, `local-fixture.ts order "Aufgabe aus Protokoll A"`, `POST $SERVICE_URL/app/device` mit der Sitzung (`X-Device`: UUID, Token hex gerade Länge 64 bis 200, `environment` `sandbox`). `LOOSEENDS_SIM_SIGN=1 ./scripts/sim.sh build`, App mit den Debug-Argumenten starten (`./scripts/sim.sh launch …`), warten bis `local-fixture.ts result <ID>` `outcome=done` zeigt (der Start holt den Auftrag und sendet die Abschrift), App beenden. `local-fixture.ts rows` **vorher**: `accounts`, `sessions`, `transcripts`, `orders`, `order_results`, `apple_tokens`, `device_tokens` je mindestens 1; `oauth_records` bleibt 0 (siehe Known Limitations).
3. Abmelden: `LOOSEENDS_DEBUG_SERVICE=$SERVICE_URL LOOSEENDS_DEBUG_SESSION=$SESSION_TOKEN ./scripts/sim.sh test-proof AccountLocalServiceTests/testSignOutEndsOnlyThisSession`; danach `rows`: `sessions` um genau 1 kleiner, alle anderen Zahlen unverändert, `accounts=1`.
4. Neue Sitzung: `local-fixture.ts session` (neuer Token). Löschen: `test-proof AccountLocalServiceTests/testDeleteRemovesTheAccount` mit dem neuen Token; danach `rows`: **alle acht Zahlen 0**. Im Log des Dienstes steht genau die Zeile `apple revoke skipped` (Zeitstempel davor), kein `apple revoke failed`.
5. Gegenprobe: ein erneuter Aufruf von `POST $SERVICE_URL/auth/delete` mit dem gelöschten Token antwortet 401 (die Sitzung ist weg), `rows` bleibt 0.
6. Aufräumen: Dienst per Signal beenden, kein Prozess, kein Temp-Ordner, kein offener Port.

Screenshots (Anhänge der Testläufe) werden geöffnet und beschrieben, bevor ein AC abgehakt wird.

### Teil 5: Protokoll B (TestFlight, Gerätepunkt, `protokoll-b.md`)

Siehe Definition of Done. Kein AC (das QA-Gate kennt keinen Aufschub, Gerätepunkte stehen nie als AC). Ablauf: nach dem Merge Lauf von `testflight.yml` mit `konto=true` und einem `what_to_test`-Text für Henning (Anmelden mit Apple in den Einstellungen unter „Claude“, Abmelden, wieder Anmelden; was er sehen muss). Der Bau wird nie einer Store-Version zugeordnet (`asc_store_version.py`). Konto löschen läuft dort **nicht** (PO-Entscheidung 2026-11-14). Claude liest anschließend nur lesend auf `rennwienix`, ob ein Konto und eine Sitzung bestehen (Zahlen, keine Inhalte), und hält das im Protokoll fest.

**Regeln vor Modell:** reine Verdrahtung und Nachweis ohne Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine; ADR-21 (Dienst für Claude, Weg B) bleibt unverändert und wird belegt. Keine neue Abhängigkeit, kein Schema, keine Berechtigung, keine `Info.plist`-Änderung.
- **Rationale:** Der Schnitt ändert keinen Produktpfad: ein lesender Fixture-Befehl, ein Testwerkzeug im Debug-Bau und eine Durchreiche von Umgebungsvariablen. Die Wahl der Nachweisart (kein Apple-Stellvertreter im Dienst, kein Live-Löschen) kippt keine ADR.

## Source

- **File:** `server/scripts/local-fixture.ts`
- **Identifier:** Unterbefehle `rows` und `apple-token` in `run`; `LooseEndsUITests/AccountLocalServiceTests.swift` mit `class AccountLocalServiceTests`
- **Benutzt (unverändert):** `encryptToken`, `storeRefreshToken` (`server/src/apple-vault.ts`), `findOrCreate`, `createSession` (`server/src/accounts.ts`), `AccountWiring.debugService`, `AccountState.signOut`, `AccountState.deleteAccount`, `AccountSection` (Bezeichner `accountSignedInRow`, `accountSignOutRow`, `accountDeleteRow`, `accountAppleButton`, `accountHint`)
- **Unberührt:** `server/src/`, `LooseEnds/`, `LooseEndsTests/`, `project.yml`, jede `Info.plist`, Entitlements, `AccountSettingsTests.swift`, `scripts/ui_smoke_shards.py`, `.github/workflows/`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/scripts/local-service.sh` und `local-fixture.ts` (#795 S3b-2), Node 26, Postgres 18 | bestehend, wie `test-local.sh` |
| Debug-Weg `AccountWiring.debugService` (`-LEDebugService`, `-LEDebugSession`, nur Debug-Bau, nur `http://localhost:<port>`) | bestehend, unverändert |
| `AccountState`, `ServiceClient`, `InMemorySessionStore`, `AccountSection` | bestehend, unverändert |
| Server `accounts.ts` (`deleteAccount`), `auth.ts` (`revokeAfterDelete`), `apple-vault.ts`, Migrationen 001 bis 008 | bestehend, unverändert; Tabellennamen aus den Migrationen übernommen |
| `scripts/sim.sh` (`test-proof`, `LOOSEENDS_SIM_SIGN=1`) | bestehend; Durchreiche neu |
| TestFlight-Eingabe `konto` (#615 S4c-2a), `asc_store_version.py` | bestehend, unverändert |
| Live-Dienst `loose-ends.henemm.com` auf `rennwienix` | nur lesend für Stufe 3 |
| Downstream | #621 (claude.ai-Verbindung am selben Konto), #795 (App-Sitzung), #625 (Store-Schalter) |

## Acceptance Criteria

Die ACs belegen Läufe gegen den lokalen Dienst und den Simulator; alle sind ohne Hennings Gerät erreichbar. Die Befehle und Ausgaben stehen wörtlich in `docs/artifacts/feat-615-s4f-abnahme/protokoll-a.md`. Gerätepunkte stehen in der Definition of Done.

- **AC-1:** `rows` zählt und legt nichts an: GIVEN eine frisch migrierte Wegwerf-Datenbank ohne Konto WHEN `local-fixture.ts rows` läuft THEN gibt es genau acht Zeilen `<tabelle>=0` in der Reihenfolge `accounts`, `sessions`, `transcripts`, `orders`, `order_results`, `apple_tokens`, `oauth_records`, `device_tokens`, und ein zweiter Aufruf zeigt dieselben Zahlen (es entsteht kein Konto).
- **AC-2:** Schutz und Stille: GIVEN `rows` oder `apple-token` WHEN `DATABASE_URL` fehlt oder `postgres://u@db.example:5432/x` ist THEN endet der Aufruf mit Ausgang 1 vor jedem Datenbankzugriff, und stderr enthält weder einen Token noch den Platzhaltertext (`grep -F`); ein unbekannter Unterbefehl endet mit Ausgang 1 und nennt `rows` und `apple-token` in der Usage-Meldung.
- **AC-3:** `apple-token` legt genau eine Zeile an: GIVEN der laufende lokale Dienst WHEN `apple-token` zweimal läuft THEN zeigt `rows` danach `apple_tokens=1` und `accounts=1`, und `psql`/Fixture-Ausgabe nennt keinen Klartext (der Platzhaltertext erscheint in keiner Ausgabe des Protokolls).
- **AC-4:** Ohne Umgebung übersprungen: GIVEN `LOOSEENDS_DEBUG_SERVICE` und `LOOSEENDS_DEBUG_SESSION` nicht gesetzt WHEN `./scripts/sim.sh test-proof AccountLocalServiceTests` läuft THEN sind beide Tests übersprungen (nicht rot), der Skip-Grund nennt die zwei Variablen, und das Protokoll benennt jeden übersprungenen Test einzeln.
- **AC-5:** Abmelden im Simulator gegen den echten Dienst: GIVEN der lokale Dienst mit gefüllten Zeilen (Teil 4, Schritt 2) und eine Sitzung S1 WHEN `testSignOutEndsOnlyThisSession` mit S1 läuft THEN ist der Test grün (Zeile „verbunden“ da, nach dem Tippen Anmeldeknopf und Einleitungssatz da, keine Rückfrage), und `rows` zeigt danach `sessions` um genau 1 kleiner als vorher, `accounts=1` und alle übrigen Zahlen unverändert.
- **AC-6:** Löschen im Simulator gegen den echten Dienst, keine Zeile mehr: GIVEN dieselbe Datenbank und eine neue Sitzung S2 (`local-fixture.ts session`) WHEN `testDeleteRemovesTheAccount` mit S2 läuft THEN ist der Test grün (Rückfrage „Delete account?“ erscheint, Bestätigung entfernt die Zeile „verbunden“, Anmeldeknopf kehrt zurück), und `rows` zeigt danach **alle acht Zahlen 0**; die Zahlen davor (Schritt 2) zeigen für `accounts`, `sessions`, `transcripts`, `orders`, `order_results`, `apple_tokens` und `device_tokens` mindestens 1.
- **AC-7:** Widerruf ausgelöst, ehrlich benannt: GIVEN der Lauf aus AC-6 THEN steht im Log des Dienstes zwischen Start und Ende des Löschens genau eine Zeile `apple revoke skipped` und keine Zeile `apple revoke failed`, und das Protokoll sagt wörtlich, dass lokal kein Apple erreichbar ist (der Widerruf wird versucht und übersprungen) und der Aufruf an Apple selbst nur durch die Server-Tests mit Attrappe belegt ist (`server/test/auth.test.ts`, `./server/scripts/test-local.sh` grün im Protokoll).
- **AC-8:** Gelöschte Sitzung ist tot: GIVEN der Lauf aus AC-6 WHEN `POST $SERVICE_URL/auth/delete` mit S2 aufgerufen wird THEN antwortet der Dienst 401, und `rows` bleibt bei allen acht Zahlen 0.
- **AC-9:** Durchreiche ändert nichts ohne die Variablen: GIVEN `scripts/sim.sh` WHEN `bash -n scripts/sim.sh` läuft und `grep -n 'LOOSEENDS_DEBUG_' scripts/sim.sh` gelesen wird THEN ist die Syntax sauber, die Variablen stehen nur im Zweig für `test` und exportieren nur, wenn beide gesetzt sind, und ein `./scripts/sim.sh test-proof AccountSettingsTests` ohne sie läuft wie bisher grün (8 von 8).
- **AC-10:** Kein Produktcode berührt, Server und App grün: GIVEN die Änderung WHEN `git diff --stat origin/main...HEAD -- server/src LooseEnds LooseEndsTests project.yml` läuft THEN ist die Ausgabe leer, `./server/scripts/test-local.sh` ist grün, und `./scripts/sim.sh unit` ist grün.
- **AC-11:** Aufräumen: GIVEN das Ende von Protokoll A WHEN der Dienst per Signal beendet wurde THEN gibt es keinen Prozess von Dienst oder Postgres dieses Laufs, keinen Temp-Ordner und keinen offenen Port, und kein Wert des Tokens steht im abgelegten Protokoll (`grep -F` mit `SESSION_TOKEN` und `DATABASE_URL`-Passwortteil, falls vorhanden, ohne Treffer).
- **AC-12:** Belege geöffnet: GIVEN die Screenshots der beiden Testläufe unter `docs/artifacts/feat-615-s4f-abnahme/` THEN ist jeder geöffnet und beschrieben (Einstellungen mit Gruppe „Claude“ und Zeile „verbunden“; Rückfrage „Delete account?“; Zustand danach mit Anmeldeknopf), und das Protokoll nennt je Bild, was darauf zu sehen ist.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/scripts/local-fixture.ts` | MODIFY | Unterbefehle `rows` (lesend, ohne `findOrCreate`) und `apple-token`; Kopfkommentar und Usage; ≈ +50 |
| `LooseEndsUITests/AccountLocalServiceTests.swift` | CREATE | zwei Tests, `XCTSkip` ohne Umgebung, Debug-Weg ohne `--ui-testing`; ≈ +100 |
| `scripts/sim.sh` | MODIFY | Durchreiche von `LOOSEENDS_DEBUG_SERVICE` und `LOOSEENDS_DEBUG_SESSION` an `test`; ≈ +5 |
| `docs/artifacts/feat-615-s4f-abnahme/` | CREATE | Protokoll A mit Ausgaben und Bildern, Protokoll B (TestFlight); Doku, zählt nicht zum Limit |
| `CLAUDE.md` | MODIFY | Doku, zählt nicht zum Limit: eine Zeile bei `local-fixture.ts` (`rows`, `apple-token`) und bei `test-proof` (die zwei Variablen) |

### Estimated Changes

- **Dateien: 3 Code-/Testdateien** (eine neu, zwei geändert), unter dem Limit von 4 bis 5.
- **LoC: ≈ +155** (Fixture ≈ 50, UI-Test ≈ 100, `sim.sh` ≈ 5), unter der Grenze von ±250. Keine Funktion über 50 Zeilen.
- Keine Permissions, keine `Info.plist`-Einträge, keine AppStorage-Keys, kein CloudKit-Schema, keine Audio-Dateien, keine neue Abhängigkeit, kein Produktverhalten. Eine neue Swift-Datei in `LooseEndsUITests/`: `generate` ist nach dem Stand zu fahren (Regel des Repos).
- **Seiteneffekte nach außen:** keine für Nutzer. Lokale Läufe sprechen nur mit `localhost` und einer Wegwerf-Datenbank; der TestFlight-Lauf nutzt die bestehende Eingabe `konto`.
- **Parallele Arbeit:** vor dem PR `origin/main` und offene PRs auf Berührung von `CLAUDE.md`, `scripts/sim.sh` und `LooseEndsUITests/` prüfen.

## Risiken

- **Neue Klasse in der CI:** `ui_smoke_shards.py` ordnet sie selbst einem Teil zu (Gewicht 2); die zwei Tests springen dort mit Skip. Skip-Zahlen werden einzeln benannt. Ein Test, der ohne Umgebung rot würde, wäre ein Fehler im `XCTSkip`-Zweig (AC-4).
- **`rows` darf kein Konto anlegen:** sonst zeigt der Nachweis nach dem Löschen eine Zeile. Darum bewusst ohne `findOrCreate`; AC-1 prüft es.
- **`--ui-testing` schlägt den Debug-Weg:** der neue Test setzt das Argument nie; sähe er den Stellvertreter, wäre „verbunden“ ohne Dienst trügerisch. Der Nachweis lebt von `rows` nach dem Lauf, nicht von der Oberfläche allein.
- **Token im Prozessaufruf und in der Umgebung:** nur gegen die Wegwerf-Datenbank; die Adressregel des Debug-Wegs schließt den Live-Dienst aus. Nie ein Token des Live-Dienstes.
- **Simulator-Dialog:** Mitteilungsdialog kann Bilder verdecken; `-onboardingDone YES` überspringt die Einführung, der Dialog wird im Protokoll benannt, falls er liegt.
- **Testsperre:** `test-proof` und `launch` holen `/tmp/loose-ends-testlauf.lock`; die Schritte laufen nacheinander.
- **Gerätestufe:** kein Pfad der Geräteliste berührt; Stufe 3 ist hier trotzdem Teil der Ticket-DoD (siehe unten).

## Test Plan

Kein neuer Unit-Test: es entsteht kein Produktcode. Der Test ist der UI-Test selbst plus die Datenbankprobe vorher und nachher (TDD-Reihenfolge: zuerst `rows` und die zwei UI-Tests schreiben, `test-proof` ohne Umgebung zeigt RED beziehungsweise Skip; dann Lauf gegen den lokalen Dienst).

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN frisch migrierte Wegwerf-Datenbank WHEN `local-fixture.ts rows` läuft THEN acht Zeilen mit 0, und ein zweiter Aufruf legt kein Konto an (AC-1).
- [ ] Test 2: GIVEN `DATABASE_URL` mit fremdem Host WHEN `rows` läuft THEN Ausgang 1, keine Ausgabe von Geheimnissen (AC-2).
- [ ] Test 3: GIVEN der lokale Dienst WHEN `apple-token` zweimal läuft THEN `apple_tokens=1` (AC-3).
- [ ] Test 4: GIVEN keine Umgebungsvariablen WHEN `test-proof AccountLocalServiceTests` läuft THEN beide Tests übersprungen mit benanntem Grund (AC-4).
- [ ] Test 5: GIVEN gefüllte Zeilen und Sitzung S1 WHEN `testSignOutEndsOnlyThisSession` läuft THEN grün, und `rows`: `sessions` minus 1, Rest gleich (AC-5).
- [ ] Test 6: GIVEN Sitzung S2 WHEN `testDeleteRemovesTheAccount` läuft THEN grün, und `rows`: alle acht Zahlen 0, Log `apple revoke skipped` (AC-6, AC-7).
- [ ] Test 7: GIVEN das gelöschte Konto WHEN `/auth/delete` mit S2 aufgerufen wird THEN 401 (AC-8).

| Test / Beleg | AC |
|---|---|
| Fixture-Aufrufe in `protokoll-a.md` | AC-1 bis AC-3 |
| `test-proof AccountLocalServiceTests` ohne Umgebung | AC-4 |
| `test-proof …/testSignOutEndsOnlyThisSession` und `rows` | AC-5 |
| `test-proof …/testDeleteRemovesTheAccount`, `rows`, Dienstlog | AC-6, AC-7 |
| `curl` auf `/auth/delete` | AC-8 |
| `bash -n`, `grep`, `test-proof AccountSettingsTests` | AC-9 |
| `git diff --stat`, `test-local.sh`, `sim.sh unit` | AC-10 |
| Aufräumprobe und `grep -F` im Protokoll | AC-11 |
| geöffnete Screenshots | AC-12 |

**Ehrlich zur Belegkraft:** die Läufe belegen Abmelden und Löschen gegen den echten Dienstcode und den echten `ServiceClient`, und dass nach dem Löschen in keiner der acht Tabellen eine Zeile bleibt. Sie belegen nicht die Anmeldung mit Apple (lokal nicht möglich), nicht den Aufruf an Apple beim Widerruf (nur gegen Attrappe in den Server-Tests) und nicht nginx. Das Anmelden belegt der TestFlight-Lauf; der echte Widerruf bleibt ohne Live-Beleg, weil das Konto nicht gelöscht wird (PO-Entscheidung).

## Alternativen

| Weg | Was | Dagegen | Gekippt würde |
|---|---|---|---|
| **A (gewählt): Abmelden und Löschen lokal im Simulator, Anmelden über TestFlight, Widerruf über Server-Tests** | siehe Purpose | belegt Apple selbst nicht; wird im Abschluss so benannt | nichts; keine ADR |
| **B Lokaler Apple-Stellvertreter im Dienst** | Umgebungsschalter lenkt Apple-Adressen auf einen lokalen Stub, Anmelden und Widerruf lokal „echt“ | neuer Produktcode nur für den Nachweis, belegt Apple trotzdem nicht; verworfen | nichts |
| **C Löschen live auf Hennings Konto** | echter Widerruf bei Apple, Zeilen per ssh gezählt | trifft sein einziges Konto samt claude.ai-Verbindung (OAuth-Zeilen); von Henning am 2026-11-14 abgelehnt | nichts |
| **D Zweites Apple-Konto als Testkonto** | Tür kurz über `ALLOWED_APPLE_SUBS` öffnen, Löschen live ohne sein Konto | braucht zweites Apple-Konto auf seinem Gerät und eine Änderung der Live-Konfiguration; verworfen | nichts |
| **E Zähler in `rows` je Konto statt je Tabelle** | nur Zeilen mit `account_id` | übersieht Waisen und braucht `findOrCreate`, das das Konto nach dem Löschen neu anlegte; verworfen | nichts |

Keine frühere Entscheidung (ADR) fällt bei einer Alternative.

## Out of Scope / Folgeschnitte

- Echter Widerruf bei Apple und Löschen auf dem Live-Dienst: bewusst nicht (PO-Entscheidung 2026-11-14).
- `oauth_records` mit Inhalt im lokalen Lauf: nicht angelegt (siehe Known Limitations).
- Merkposten F004 (Sicherungsfrist ab 2026-12-04): bleibt im Ticket, nicht Teil der DoD dieses Schnitts.
- #625 (Store-Schalter `LEAccountEnabled`), #795 S5.
- Änderungen an `server/src/`, `LooseEnds/`, `project.yml`, jeder `Info.plist`, `ui_smoke_shards.py`: keine.

## Abnahme

Kein Pfad der Geräteliste berührt (`server/scripts/`, `LooseEndsUITests/`, `scripts/` stehen nicht in der Liste); die Abnahme der Änderung endet nach Stufe 2: Stufe 1 sind Fixture-Aufrufe, `sim.sh unit` und `test-local.sh`, Stufe 2 der benutzte Durchlauf im Simulator mit Protokoll A und Bildern. **Zusätzlich verlangt die Definition of Done von #615 Stufe 3 über TestFlight** (Anmelden, Abmelden, wieder Anmelden, `konto=true`); sie steht darum unten als Gerätepunkt und nicht als AC. Nichts läuft auf Hennings Geräten ohne sein Wort; er bedient die TestFlight-App selbst.

## Definition of Done

- [ ] AC-1 bis AC-12 erfüllt, belegt im Protokoll A; UI-Tests vor dem Lauf geschrieben (Skip beziehungsweise RED belegt)
- [ ] `./scripts/sim.sh unit` grün, `./server/scripts/test-local.sh` grün, `test-proof AccountSettingsTests` weiter 8 von 8 grün, Build erfolgreich
- [ ] Protokoll A vollständig unter `docs/artifacts/feat-615-s4f-abnahme/` abgelegt, Screenshots geöffnet und beschrieben, kein Token im Protokoll
- [ ] Doku: `CLAUDE.md` (Fixture-Unterbefehle, Durchreiche an `test-proof`; Hotspot, vor dem PR gegen `origin/main` abgleichen)
- [ ] PR mit `Refs #615` (nicht `Closes`), CI grün, Merge durch Claude; Board-Karte aktuell, Memory geschrieben
- [ ] **Gerätepunkt (Stufe 3, TestFlight, nicht Teil der ACs):** nach dem Merge Lauf von `testflight.yml` mit `konto=true` und `what_to_test` (deutsch, für Henning: Einstellungen, Gruppe „Claude“, mit Apple anmelden, abmelden, wieder anmelden, was er sehen muss; kein Löschen). Alles gebaut und installierbar, bevor Henning gerufen wird; keine Buildnummer im Chat. Seine Rückmeldung schließt den Punkt; Claude liest danach nur lesend auf `rennwienix` (Konto und Sitzung vorhanden, keine Inhalte) und legt es in `protokoll-b.md` ab. Erst dann `#615` kommentieren und schließen, mit dem Satz, dass Löschen und „keine Zeile mehr“ im Simulator gegen den lokalen Dienst belegt sind, der Apple-Widerruf lokal übersprungen und nur über die Server-Tests mit Attrappe belegt ist.

## Known Limitations

- Anmelden mit Apple belegt nur TestFlight (Hennings Gerät); lokal gibt es kein Apple und keinen Identity-Token für die eigene Kennung.
- Der Apple-Widerruf wird lokal versucht und übersprungen (`apple revoke skipped`); der Aufruf an Apple ist nur durch die Server-Tests mit Attrappe belegt (`server/test/auth.test.ts`), live nie ausgelöst (kein Live-Löschen).
- `oauth_records` bleibt im lokalen Lauf bei 0 (kein OAuth-Aussteller lokal, keine Verbindung von claude.ai); das Löschen dieser Zeilen belegen die Server-Tests, nicht Protokoll A. Die Zahl 0 vorher und nachher ist darum kein Beleg für sie und wird im Protokoll so benannt.
- Die zwei UI-Tests laufen nur mit der Umgebung des lokalen Dienstes; in der CI sind sie übersprungen und werden dort einzeln als übersprungen benannt.
- `rows` zählt ganze Tabellen und taugt nur gegen die Wegwerf-Datenbank mit dem einen Fixture-Konto.

## Changelog

- 2026-11-14: Initial spec created (Schnitt S4f, Abnahme von #615; PO-Entscheidung kein Live-Löschen)
