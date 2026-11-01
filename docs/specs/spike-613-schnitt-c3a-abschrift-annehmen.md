---
entity_id: spike-613-schnitt-c3a-abschrift-annehmen
type: feature
created: 2026-11-01
updated: 2026-11-01
status: draft
workflow: spike-613-c3-dienstkern
---

# Spec: Abschrift annehmen und `setDue` prüft den Status, Schnitt C3a (#613, Weg B „Fenster für Claude“)

## Approval

- [ ] Approved

## GitHub Issue

#613 (Spike, Epic #612). Schnitt C3a; das Issue bleibt offen (`Refs #613`, nie `Closes #613`).
Vorgänger: C1b (`docs/specs/spike-613-schnitt-c1b-schema.md`, PR #789), C1a (`docs/specs/spike-613-schnitt-c1a-server-geruest.md`, PR #785), Vertrag v1 (`docs/reference/claude-abschrift-vertrag.md`).
Analyse: `docs/context/spike-613-c3-dienstkern.md`. Folgeschnitt C3b (Aufträge annehmen, einem Gerät vergeben, Ergebnis annehmen) ist nicht Teil dieser Spec.

## Purpose

Der Dienst für Claude kennt bisher nur ein Schema (C1b). Dieser Schnitt baut den ersten Teil des Dienstkerns: die Abschrift annehmen.
Zwei Funktionen über `pg`, ohne HTTP, ohne Anmeldung (`account_id` ist ein übergebener Wert bis C6): `checkTranscript(doc)` prüft die Form der Abschrift und nennt bei einer Abweichung den Feldpfad;
`putTranscript(pool, account, doc)` speichert sie und überschreibt eine vorhandene Abschrift nur, wenn `generatedAt` neuer ist, atomar in einer einzigen Anweisung.
Damit ist auch der offene Pflichtpunkt F005 aus C1b erledigt: ein verschachtelter `rawText` oder eine Notiz (zum Beispiel unter `now`) wird beim Annehmen mit einer verständlichen Meldung abgewiesen, nicht erst von der Datenbank mit einem nackten SQLSTATE.
Die Datenbank bleibt die zweite Wand; ihre CHECKs aus Migration 001 ändern sich nicht.

Dazu der zweite Pflichtpunkt aus C2: `OrderExecutor.setDue` prüft heute den Status nicht und setzt die Fälligkeit auch an einer erledigten oder gelöschten Aufgabe.
Künftig lehnt es das als `stale` ab, wie `complete` es mit der Menge `completable` schon tut. Der Vertragsabsatz „Ebenso offen in Version 1“ wird entsprechend angepasst.

**Regeln vor Modell:** Alles ist Regel und Formprüfung (Typen, UUID-Muster, Schlüsselmengen, SQL-Vergleich); kein Sprachmodell beteiligt. Der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Keine neue Produktentscheidung: Weg B (iCloud bleibt der Abgleich, eigener Dienst nur für Abschrift und Auftragsweg) ist in #612 entschieden und wird mit ADR-21 in C8 festgehalten;
  die Datenschutzgrenze der Abschrift (#625) und der Grundsatz „der Dienst rechnet nichts nach“ stehen im Vertrag v1. Dieser Schnitt setzt sie im Dienst und im Ausführer um.

## Source

**Files:** `server/src/transcripts.ts` (neu), `Shared/Services/OrderExecutor.swift` (`setDue`)
**Identifier:** `checkTranscript`, `putTranscript`, `OrderExecutor.setDue`

### Server: `checkTranscript(doc: unknown): asserts doc is Transcript`

Wirft `Error` mit deutscher Meldung der Form `Abschrift ungültig: <Feldpfad>: <Grund>` (zum Beispiel `Abschrift ungültig: now.today[1]: keine UUID`), bei der ersten gefundenen Abweichung.
Erlaubt ist genau die Form des Vertrags (Abschnitt „Abschrift“) und der Ausgabe von `TranscriptCodec`:

- Wurzel: Objekt mit genau den Schlüsseln `version` (die Zahl 1), `generatedAt` (String mit Zeitzone `Z` oder `±hh:mm`, als Zeitpunkt lesbar), `nowCount` (ganze Zahl ≥ 0), `now`, `tasks`.
- `now`: Objekt mit `today`, `lined`, `waiting` (je Liste von UUID-Strings, Pflicht, darf leer sein) und optional `knaeuel` (UUID-String); sonst kein Schlüssel.
- `tasks`: Liste von Objekten mit den Schlüsseln `id` (UUID), `title` (String), `status` (`unprocessed`, `unverified`, `active`, `parked`), `dueHasTime` (Boolean), `isKnaeuel` (Boolean), `contexts` (Liste von Strings) als Pflicht;
  optional `dueDate` (String mit Zeitzone), `project` (String), `nextRank` (ganze Zahl ≥ 0); kein weiterer Schlüssel, insbesondere kein `rawText`, keine `note`.
- Datenschutzlinie (F005): taucht der Schlüssel `rawText` oder `note` irgendwo im Dokument auf, auch tief verschachtelt, nennt die Meldung seinen Pfad (`Abschrift ungültig: now.rawText: Rohtext und Notiz gehören nicht in die Abschrift`).
- UUIDs werden in Groß- und Kleinschreibung angenommen (der Vertrag führt Großbuchstaben, die Spalten der Datenbank rechnen auf Kleinbuchstaben um).
- Der Dienst rechnet nichts nach: ob `nowCount` zur Größe von `now` passt oder `now`-Kennungen in `tasks` stehen, wird nicht geprüft (das tut die App).

### Server: `putTranscript(pool, account, doc): Promise<"stored" | "older">`

1. `checkTranscript(doc)`; bei Abweichung wirft die Funktion und schreibt nichts.
2. Eine Anweisung: `INSERT INTO transcripts (account_id, doc, generated_at) VALUES ($1, $2::jsonb, $3) ON CONFLICT (account_id) DO UPDATE SET doc = excluded.doc, generated_at = excluded.generated_at, received_at = now() WHERE transcripts.generated_at < excluded.generated_at RETURNING account_id`.
3. Liefert `RETURNING` eine Zeile: `"stored"` (erste Abschrift oder neuere ersetzt die alte). Liefert es keine: `"older"` (ältere oder gleich alte Abschrift, die Zeile bleibt unverändert).

`generated_at` kommt aus `doc.generatedAt` (der CHECK von 001 bindet beide aneinander). Atomar heißt: zwei gleichzeitige Aufrufe über zwei Verbindungen können die neuere Abschrift nie durch die ältere ersetzen, ohne Sperre im Dienst.

### Swift: `OrderExecutor.setDue`

Nach `find`: `guard completable.contains(task.status) else { return refuse(order, .stale, task: id) }`, vor der Prüfung der Fälligkeit. Eine erledigte oder gelöschte Aufgabe bleibt unverändert, keine Revision.
Eine offene Aufgabe (`unprocessed`, `unverified`, `active`, `parked`) verhält sich wie bisher.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `server/migrations/001_claude_schema.sql` (C1b) | Tabelle `transcripts` (PK `account_id`, `generated_at`, CHECKs), **unverändert** |
| `server/test/db.ts` (`freshPool`), `server/src/migrate.ts` (`migrate`) | Testaufbau: eigenes Schema je Test, Migration auf den echten Ordner |
| Vertrag v1 `docs/reference/claude-abschrift-vertrag.md` | Quelle des Beispiels (Test liest die ```json-Blöcke zur Laufzeit, Muster aus `schema.test.ts`) |
| `Shared/Services/OrderExecutor.swift`, `LooseEndsTests/OrderExecutorTests.swift` | bestehende Menge `completable`, bestehende Hilfen des Tests |
| Postgres 18 (lokal Wegwerf-Instanz, CI `postgres:18`), `pg` 8.23.1, `node:test` | bestehend; **keine neuen Abhängigkeiten** |

## Abweichungstabelle der Formprüfung

Je Zeile ein eigener `t.test` in `server/test/transcripts.test.ts`: das Vertragsbeispiel, eine Änderung, Ablehnung mit deutscher Meldung, die den Feldpfad nennt, und danach ist `transcripts` leer.

| Zeile | Änderung am Vertragsbeispiel | Meldung nennt |
|---|---|---|
| Z1 | `version` fehlt; `version` ist `"1"`; `version` ist `2` | `version` |
| Z2 | `generatedAt` fehlt; `generatedAt` ohne Zeitzone (`2026-03-12T09:00:00`) | `generatedAt` |
| Z3 | `now` ist kein Objekt (`"now": []` und `"now": "x"`) | `now` |
| Z4 | fremder Schlüssel in `now` (`"extra": []`); Pflichtschlüssel `waiting` fehlt | `now.extra`; `now.waiting` |
| Z5 | `now.knaeuel` vorhanden, aber keine UUID (`"abc"`, `5`) | `now.knaeuel` |
| Z6 | `now.today`, `now.lined`, `now.waiting` keine Liste von UUIDs (je: kein Array; Element keine UUID) | `now.today[0]` o. Ä. |
| Z7 | `contexts` einer Aufgabe keine Liste von Strings (`"Computer"`; `[1]`) | `tasks[1].contexts` |
| Z8 | `title` kein String (`5`); `project` kein String (`false`) | `tasks[0].title`; `tasks[1].project` |
| Z9 | `rawText` oder `note` an einer Aufgabe; `rawText` verschachtelt in `now` und in `contexts`-Element-Objekt | der volle Pfad des Schlüssels |
| Z10 | fremder Schlüssel an der Wurzel (`revisions`); `nowCount` kein Zahlenwert ≥ 0 (`"3"`, `-1`, `1.5`) | `revisions`; `nowCount` |

## Acceptance Criteria

- **AC-1:** `checkTranscript` nimmt das Abschrift-Beispiel aus den ```json-Blöcken von `docs/reference/claude-abschrift-vertrag.md` an (gelesen zur Laufzeit, nicht abgeschrieben, erster von drei Blöcken wie in `schema.test.ts`) und wirft nicht; ebenso ein Beispiel mit kleingeschriebenen UUIDs und ohne `now.knaeuel`/`dueDate`/`project`/`nextRank`.
- **AC-2:** (Z1) Fehlt `version` oder ist sie `"1"` oder `2`, wirft `checkTranscript` eine Meldung, die `version` nennt; `putTranscript` schreibt nichts (`SELECT count(*) FROM transcripts` = 0).
- **AC-3:** (Z2) Fehlt `generatedAt` oder hat es keine Zeitzone (`2026-03-12T09:00:00`), wirft `checkTranscript` eine Meldung mit `generatedAt`; nichts in `transcripts`.
- **AC-4:** (Z3) Ist `now` kein Objekt (Liste `[]` oder String `"x"`), wirft `checkTranscript` eine Meldung mit `now`; nichts in `transcripts`.
- **AC-5:** (Z4) Ein fremder Schlüssel in `now` (`extra`) bzw. ein fehlendes `waiting` wird mit Meldung `now.extra` bzw. `now.waiting` abgewiesen; nichts in `transcripts`.
- **AC-6:** (Z5) Ist `now.knaeuel` vorhanden, aber keine UUID (`"abc"` oder die Zahl `5`), nennt die Meldung `now.knaeuel`; fehlt der Schlüssel ganz, wird die Abschrift angenommen.
- **AC-7:** (Z6) Ist `now.today`, `now.lined` oder `now.waiting` keine Liste oder enthält ein Element, das keine UUID ist, nennt die Meldung den Pfad (zum Beispiel `now.today[0]`); je Liste ein Fall im Test; nichts in `transcripts`.
- **AC-8:** (Z7) Ist `contexts` einer Aufgabe keine Liste von Strings (`"Computer"` oder `[1]`), nennt die Meldung `tasks[1].contexts`; nichts in `transcripts`.
- **AC-9:** (Z8) Ist `title` einer Aufgabe kein String (`5`) bzw. `project` kein String (`false`), nennt die Meldung `tasks[0].title` bzw. `tasks[1].project`; nichts in `transcripts`.
- **AC-10:** (Z9, F005) `rawText` oder `note` an einer Aufgabe, verschachtelt in `now` (`{"now": {…, "rawText": "…"}}`) oder tief in einer Struktur (Objekt als `contexts`-Element) wird abgewiesen; die Meldung enthält den vollen Pfad des Schlüssels; nichts in `transcripts`.
- **AC-11:** (Z10) Ein fremder Schlüssel an der Wurzel (`revisions`) bzw. ein `nowCount` von `"3"`, `-1` oder `1.5` wird mit Meldung `revisions` bzw. `nowCount` abgewiesen; nichts in `transcripts`.
- **AC-12:** `putTranscript(pool, "henning", doc)` für ein Konto ohne Zeile liefert `"stored"`; die Zeile hat `account_id = 'henning'`, `doc` gleich dem Dokument und `generated_at` gleich `doc.generatedAt`.
- **AC-13:** Eine Abschrift mit neuerem `generatedAt` für dasselbe Konto liefert `"stored"` und ersetzt `doc` und `generated_at`; es bleibt genau eine Zeile (`count(*)` = 1) und `received_at` ist nicht älter als vorher.
- **AC-14:** Eine Abschrift mit älterem `generatedAt` liefert `"older"`; eine mit gleichem `generatedAt` (anderer Inhalt, etwa anderer `nowCount`) ebenfalls; in beiden Fällen sind `doc`, `generated_at` und `received_at` der Zeile unverändert.
- **AC-15:** Zwei gleichzeitige Uploads über zwei Verbindungen (`Promise.all` mit zwei Pools desselben Schemas; je eine Abschrift mit älterem und neuerem `generatedAt`, im Test in beiden Aufrufreihenfolgen) enden immer mit der neueren Abschrift in der Zeile, dazu genau ein Ergebnis `"stored"` oder zwei, nie die ältere gespeichert nach der neueren.
- **AC-16:** Zwei verschiedene Konten (`henning`, `anna`) halten je eine Abschrift unabhängig voneinander; ein Upload für `anna` berührt die Zeile von `henning` nicht.
- **AC-17:** Der Dienst rechnet nichts nach: eine formgültige Abschrift, deren `nowCount` (7) nicht zur Größe von `now` und deren `now`-Kennungen nicht in `tasks` stehen, wird angenommen (`"stored"`).
- **AC-18:** `server/migrations/001_claude_schema.sql` bleibt unverändert (die Dateiliste des PR enthält keine Datei unter `server/migrations/`), und `server/test/schema.test.ts` bleibt ohne Änderung grün (die DB-CHECKs sind weiterhin die zweite Wand).
- **AC-19:** `OrderExecutor.setDue` an einer erledigten Aufgabe (`status = .done`) liefert `rejected/stale` mit `taskID`; `dueDate`, `dueHasTime` der Aufgabe sind unverändert und es gibt keine neue `Revision`. Belegt durch `LooseEndsTests/OrderExecutorTests.swift`, ein Fall (Fälligkeit gleich dem erwarteten Stand).
- **AC-20:** `OrderExecutor.setDue` an einer gelöschten Aufgabe (`status = .removed`) liefert `rejected/stale` mit `taskID`; Fälligkeit unverändert, keine neue `Revision`. Belegt durch einen eigenen Fall im selben Testbestand.
- **AC-21:** `OrderExecutor.setDue` an einer offenen Aufgabe (`active`, ebenso `parked`) mit passendem erwarteten Stand setzt die Fälligkeit wie bisher (`done`, Revision mit Grund „Claude“); die bestehenden `setDue`-Tests bleiben unverändert grün.
- **AC-22:** `docs/reference/claude-abschrift-vertrag.md` ist angepasst: Der Punkt „`setDue` prüft den Status nicht …“ unter „Ebenso offen in Version 1“ ist gestrichen und als Regel formuliert (ein erledigter oder gelöschter Stand ist `stale`, der Status zählt zum erwarteten Stand);
  ein Satz sagt, dass der Dienst die Abschrift nur annimmt, wenn ihre Form stimmt, und eine vorhandene nur durch eine mit neuerem `generatedAt` ersetzt. Die drei ```json-Blöcke bleiben unverändert (Anzahl und Inhalt), `schema.test.ts` bleibt grün.
- **AC-23:** `./server/scripts/test-local.sh` ist grün (Typprüfung `npm run typecheck` ohne Fehler, alle Tests gegen das Wegwerf-Postgres) und räumt auf; `./scripts/sim.sh sim-unit OrderExecutorTests` ist grün; der Workflow `server.yml` ist auf dem PR grün.
  Die Dateiliste des PR enthält außer den unter Scope genannten fünf nichts: kein `project.yml`, kein CloudKit-Schema, keine `CLAUDE.md`-Änderung.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `server/src/transcripts.ts` | CREATE | `checkTranscript` (Formprüfung, ggf. mit kleinen Hilfen je Teil der Form) und `putTranscript` (Upsert mit `WHERE … <`), ~100 Zeilen |
| `server/test/transcripts.test.ts` | CREATE | Vertragsbeispiel angenommen; je Zeile der Abweichungstabelle ein `t.test`; Upsert-Fälle; zwei Verbindungen; Abweichungsfälle als Tabelle, ~100 Zeilen |
| `Shared/Services/OrderExecutor.swift` | MODIFY | `setDue`: Statusprüfung gegen `completable`, +2 |
| `LooseEndsTests/OrderExecutorTests.swift` | MODIFY | erledigte und gelöschte Aufgabe → `stale`, ~+20 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Absatz „Ebenso offen in Version 1“ und Satz zur Annahme der Abschrift, ~+6/−5 |

### Estimated Changes

- Files: 5 (Grenze erreicht)
- LoC: ~+228/−5 = ~233 (100 + 100 + 2 + 20 + 6, Löschungen 5), unter 250; jede Funktion ≤ 50 Zeilen (die Formprüfung ist in Hilfsfunktionen je Teil der Form geteilt; Testfälle als Tabelle gebündelt)
- Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, keine Oberfläche, keine Änderung an `project.yml`; `./scripts/sim.sh generate` ist nicht nötig. Keine Audiodateien.
- Seiteneffekt außerhalb des Tickets: keiner. `setDue` ist noch von keinem Pfad der App aufgerufen (Aufträge fließen erst mit C5).

Bei Überschreitung von 250 Zeilen: stoppen und nachfragen.

## Test Plan

### Automated Tests (TDD RED)

RED: `server/test/transcripts.test.ts` und die zwei neuen Fälle in `OrderExecutorTests.swift` werden zuerst geschrieben. Ohne `server/src/transcripts.ts` schlägt der Import fehl; ohne die Statusprüfung liefert `setDue` an erledigter und gelöschter Aufgabe `done`.

- [ ] Test 1 (AC-1): GIVEN das Vertragsbeispiel WHEN `checkTranscript` läuft THEN wirft es nicht (auch kleingeschriebene UUIDs, ohne optionale Felder).
- [ ] Test 2 bis 11 (AC-2 bis AC-11): GIVEN das Vertragsbeispiel WHEN je Tabellenzeile eine Änderung gemacht und `putTranscript` aufgerufen wird THEN wirft es mit Meldung, die den Feldpfad enthält, und `transcripts` ist leer.
- [ ] Test 12 (AC-12): GIVEN ein Konto ohne Zeile WHEN `putTranscript` THEN `"stored"` und die Zeile steht da.
- [ ] Test 13 (AC-13): GIVEN eine Zeile WHEN eine neuere Abschrift kommt THEN `"stored"`, eine Zeile, Inhalt ersetzt.
- [ ] Test 14 (AC-14): GIVEN eine Zeile WHEN eine ältere und eine gleich alte Abschrift kommen THEN je `"older"`, Zeile unverändert.
- [ ] Test 15 (AC-15): GIVEN zwei Verbindungen WHEN zwei Uploads gleichzeitig laufen (beide Reihenfolgen) THEN steht am Ende die neuere.
- [ ] Test 16 (AC-16): GIVEN zwei Konten THEN je eine eigene Zeile, unabhängig.
- [ ] Test 17 (AC-17): GIVEN `nowCount` 7 bei kleinem `now` THEN angenommen.
- [ ] Test 18 (AC-18): Diff-Durchsicht: `server/migrations/` unberührt, `schema.test.ts` grün.
- [ ] Test 19 bis 21 (AC-19 bis AC-21): `OrderExecutorTests`: `setDue` an `.done` und `.removed` → `stale`, Fälligkeit und Revisionen unverändert; offene Aufgabe wie bisher.
- [ ] Test 22 (AC-22): Diff-Durchsicht des Vertrags, `schema.test.ts` liest weiter genau drei Blöcke.

Läufe: `./server/scripts/test-local.sh` (Gesamtkette des Servers), `./scripts/sim.sh sim-unit OrderExecutorTests` (Swift), danach der Workflow `server.yml` auf dem PR.

**Keine UI-Tests:** Der Schnitt ändert keine Oberfläche und keinen sichtbaren Ablauf; `setDue` wird von keinem Bedienweg aufgerufen.

## Alternativen

- **Formprüfung als SQL-CHECK in Migration 001** (jsonpath je Feld; 001 darf bis C7 noch geändert werden). Vorteil: eine Wand für jeden Weg in die Tabelle. Nachteil: verschachtelte jsonpath-Ausdrücke für `now` und die Feldtypen sind schwer lesbar,
  der Fehler kommt als SQLSTATE ohne Feldnamen. Verworfen. Gekippt würde keine ADR; berührt wäre nur die Festlegung aus C1b, dass die Datenbank die Datenschutzlinie hält und die Formprüfung des Dienstes in C3 liegt. Ein billiger Zusatz-CHECK (`now` ist ein Objekt) bliebe möglich.
- **HTTP schon in C3** mit `node:http`. Vorteil: früher von außen ansprechbar. Nachteil: ohne Anmeldung ein offener Endpunkt, und die Form hängt an C4/C6. Verworfen; gekippt würde die Festlegung der Analyse „Transport erst mit C4/C6“ (keine ADR).
- **Formprüfung mit Bibliothek** (zod, ajv): weniger Schreibaufwand, aber eine neue Abhängigkeit, die Freigabe braucht; der Vertrag hat wenige flache Felder. Verworfen (Regel „keine neuen Dependencies ohne Freigabe“).
- **Kein Dienstkern, MCP schreibt direkt in die Tabellen** (C4 mit eigenem SQL): spart eine Schicht, verteilt aber Prüfung und Überschreiblogik doppelt auf MCP und App-Endpunkte. Verworfen; gekippt würde die Annahme aus C1a, dass der Dienst eine Funktionsschicht über dem Schema hat (keine ADR).
- **Überschreiben ohne `WHERE`** (letzter Upload gewinnt): einfacher, aber ein verspäteter älterer Upload eines zweiten Geräts ersetzt dann die neuere Abschrift. Verworfen; der Vertrag und die Analyse verlangen „nur neuere überschreibt“.
- **`setDue` ohne Statusprüfung lassen und nur die App-Seite dokumentieren:** hätte die Lücke in Vertrag und Ausführer konserviert (Claude könnte an erledigten Aufgaben Fälligkeiten setzen). Verworfen; gekippt würde die bewusste Abweichung „Ebenso offen in Version 1“ im Vertrag.

## Nicht in diesem Schnitt / Folgeschnitte

- **C3b:** Aufträge annehmen (`checkOrder` mit `version` = 1 und Feldern je `kind`, `putOrder`), einen Auftrag genau einem Gerät vergeben (`FOR UPDATE SKIP LOCKED`), Ergebnis annehmen (nur für einen Auftrag, den dieses Gerät hält). Eigener Workflow, ~+230 LoC, 3 Dateien.
- Rückholung eines geholten Auftrags nach Absturz des Geräts (braucht Doppelerkennung über die Auftragskennung in der App, C5, und Rückholregel, C7); Advisory-Lock für `migrate` und `client.on("error")` (C7).
- C4 MCP-Werkzeuge (lesen die Abschrift), C5 A/B-Nachweis, C6 Anmeldung und Konto-Tabelle, C7 Betrieb auf Hetzner, C8 ADR-21.

## Abnahme

- Stufe 1: `./server/scripts/test-local.sh` grün (Typprüfung und alle Servertests gegen echtes Postgres) und `./scripts/sim.sh sim-unit OrderExecutorTests` grün; der Workflow `server.yml` grün auf dem PR.
- Stufe 2: Pflicht für den Abschluss. `./scripts/sim.sh test-proof CaptureSmokeTests` liefert den maschinellen Simulator-Beleg aus einem echten Lauf auf dem aktuellen Stand (Commit-Kennung und Zeitstempel passen), nie von Hand gesetzt.
  Der Beleg belegt, dass die App mit der geänderten `Shared/Services`-Datei weiter startet und erfasst; ein Bedienablauf für `setDue` existiert noch nicht, weil nichts in der App Aufträge ausführt.
- Stufe 3: entfällt. Kein Pfad der Geräteliste berührt.

## Definition of Done

- [ ] AC-1 bis AC-23 erfüllt
- [ ] `./server/scripts/test-local.sh` grün, `./scripts/sim.sh sim-unit OrderExecutorTests` grün, Workflow `server.yml` grün
- [ ] `test-proof CaptureSmokeTests`-Beleg für `phase8_complete` registriert
- [ ] #613 kommentiert (Stand C3a, Folgeschnitt C3b), Board-Karte aktuell

## Changelog

- 2026-11-01: Initial spec created (Schnitt C3a)
