---
entity_id: feat-932-schnitt-1-app
type: feature
created: 2026-11-15
updated: 2026-11-15
status: draft
workflow: feat-932-claude-felder
---

# Spec: Claude setzt Titel und Angaben, Schnitt 1 (App, #932)

## Approval

- [ ] Approved

## GitHub Issue

#932 (Epic #612). Schnitt 1 von 3; das Issue bleibt offen (PR mit `Refs #932`, nie `Closes #932`), weil Schnitt 2, Schnitt 3 und der claude.ai-Durchlauf aus der Definition of Done von #932 offen bleiben.
Analyse: `docs/context/feat-932-claude-felder.md`. Vorgänger: #622 (Aufträge hinterlassen Revisionen mit Grund „Claude“, Zeile „Zuletzt von Claude“).

## Purpose

Claude soll beim Erfassen und danach den Titel und die Angaben einer Aufgabe setzen können (Fälligkeit, Wichtigkeit, Dringlichkeit, Dauer, Energie, Tags, Projekt, beim Erfassen auch die Notiz), statt nur Rohtext abzulegen. Dieser Schnitt baut die Gegenstelle auf dem Gerät: der `OrderExecutor` versteht ein Objekt `fields` und die neue Art `update`, prüft alles vor dem ersten Schreiben und schreibt jede Änderung als Nutzerrevision mit Grund „Claude“; der Modelltitel ersetzt einen Titel, den Claude beim Erfassen gesetzt hat, nicht mehr. Ohne den Dienst (S2/S3) schickt nichts solche Aufträge, der Schnitt ist unschädlich und zuerst im Testbau, bevor der Dienst ausgerollt wird.

**Regeln vor Modell:** reine Datenlogik (Prüfen, Namen abgleichen, Revisionen schreiben), keine Sprachaufgabe; der Satz „Ohne Modell geht es nicht, weil …“ entfällt, es kommt kein Modellaufruf hinzu.

## Nicht in diesem Schnitt

- **Schnitt 2 (Dienst, Erfassen mit Feldern):** Form von `fields` in `server/src/orders.ts` und `transcripts.ts`, `capture_task` mit optionalen Feldern, Serverstests.
- **Schnitt 3 (Dienst, `update_task`):** Migration 009, Werkzeug mit erwartetem Stand aus der Abschrift, Anleitung (≤ 2048 Byte), Testbau mit `konto` an, Ausrollen, claude.ai-Durchlauf aus der DoD von #932.
- Der Dienst (`server/`) wird in diesem Schnitt **nicht** geändert. Der Vertrag sagt, dass der Dienst `fields` erst ab S2 und `update` erst ab S3 annimmt; bis dahin verwirft er beides (kein weiterer Schlüssel, unbekannte Art).
- Keine Abschrift Version 2: Wichtigkeit, Dringlichkeit, Dauer, Energie und Notiz bleiben außerhalb der Abschrift (Version 2 braucht die Datenschutzfreigabe #625). Die Abschrift bleibt Version 1, unverändert.
- Nicht setzbar: Knäuel, Perle, Anhänge, Kalender, Ort, Wiederholung, Teilaufgaben (die hat `addSubtask`). Fälligkeit entfernen bleibt `setDue`. Leeren sonst gibt es nicht (nur Tags per leerer Liste).

## Reihenfolge der Auslieferung

App (dieser Schnitt) im Testbau, dann Dienst S2/S3, dann Ausrollen. Grund: Swift-`Codable` ignoriert unbekannte Schlüssel. Eine App ohne diesen Schnitt würde ein `capture` mit `fields` als reinen Text erfassen und `done` melden; die Felder gingen still verloren. Eine unbekannte Art (`update`) lehnt eine alte App dagegen sauber ab (unlesbar → `rejected/invalid`). Aufträge führt heute nur Hennings Testbau aus (Konto-Gruppe nur mit `konto`).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — der Auftragsweg (ADR-21, Weg B) und „Revisions, not undo“ tragen das unverändert: neue Art und neues Objekt im selben Format, Version 1, ohne Schemawechsel (Revisionsfelder und `RevisedField`-Fälle existieren alle, kein CloudKit-Schema betroffen).

## Source

**Files:** `Shared/Services/OrderExecutor.swift`, `Shared/Enrichment/EnrichmentWriter.swift`, `LooseEndsTests/OrderExecutorTests.swift`, `LooseEndsTests/EnrichmentTests.swift`, `docs/reference/claude-abschrift-vertrag.md`
**Identifier:** `Order`, `OrderFields`, `OrderExecutor.update`, `EnrichmentWriter.apply`

## Implementation Details

### Auftrag: `fields`, drei erwartete Werte, Art `update`

`Order.Kind` bekommt `update`. `Order` bekommt `fields: OrderFields?` und die erwarteten Stände `expectedTitle: String?`, `expectedContexts: [String]?`, `expectedProject: String?` (bestehend bleiben `expectedStatus`, `expectedDueDate`). `OrderFields` (neue Codable-Struktur, alles optional, nur vorhandene Schlüssel werden geschrieben): `title`, `notes`, `dueDate` + `dueHasTime`, `importance`, `urgency`, `duration`, `energy`, `contexts`, `project`. Importance, Urgency und Duration kommen als `String` und werden vom Executor geprüft (nicht über den Enum-Decoder), damit ein falscher Wert als `invalid` mit `taskID` beantwortet wird und nicht als unlesbarer Auftrag ohne Aufgabe.

Der Dienst prüft nur die Form (S2/S3), die App die Bedeutung, wie bei jeder Art.

### Prüfung vor dem ersten Schreiben

Reihenfolge, jede Stufe vor jedem Schreiben: (1) reine Formprüfung → `invalid`; (2) Aufgabe suchen (`update`) → `missing`; (3) Namen auflösen → `invalid`; (4) erwarteter Stand → `stale`; (5) schreiben, ein `commit`.

Formprüfung (`invalid`): Version ≠ 1; `fields` fehlt oder ist leer (bei `update`); `notes` bei `update`; Titel nach Trimmen leer; `importance`/`urgency` nicht `low|medium|high`; `duration` nicht `minutes5|minutes15|minutes30|hour1|hours2plus`; `energy` außerhalb −3…3; `dueDate` ohne `dueHasTime` oder `dueHasTime` ohne `dueDate`; `update` mit `expectedStatus` ≠ offen/geparkt (`done`/`removed`); `capture` ohne `text` (wie bisher).

Namen (`invalid`): jeder Tag und das Projekt muss in den Katalogen der App vorhanden sein, abgeglichen mit `CatalogService.nameKey` (groß-/kleinschreibungs-, akzentunabhängig, #157). Mehrere Treffer → der Überlebende wie bei Siri (`CatalogService.survivesBefore`, Projekt `CatalogService.project(named:in:)`). Geschrieben wird der Name aus dem Katalog, nie Claudes Schreibweise (`FieldCodec.apply` gleicht Kontexte über den Namen ab). Es wird nie ein Tag oder Projekt angelegt.

Erwarteter Stand (`stale`, nur `update`): `expectedStatus` immer; für jedes geänderte Feld, das die Abschrift trägt, der Abschriftwert: `title` → `expectedTitle`, `dueDate` → `expectedDueDate`, `contexts` → `expectedContexts`, `project` → `expectedProject`. Die Konvention des Vertrags gilt: fehlt der Wert, hatte die Aufgabe keinen (kein Titel, keine Fälligkeit, keine Tags, kein Projekt). Titel exakt, Tags als Menge nach `nameKey`, Projekt nach `nameKey`, Datum in ganzen Sekunden. Wichtigkeit, Dringlichkeit, Dauer, Energie stehen nicht in der Abschrift: für sie gilt nur der Status (letzter Schreiber gewinnt, vorher das Ja des Nutzers laut Anleitung, S3). Ein Datum, das denselben Zeitpunkt träfe und nur `dueHasTime` änderte, ist `invalid` (#777, wie `setDue`).

### Schreiben

Je vorhandenem Feld `RevisionService.set(field, to:, contexts:, projects:, now:)`, danach `revision.reason = "Claude"` (Autor `.user`, wie `setDue`). Ein Feld, dessen Wert schon so steht, schreibt keine Revision (`set` liefert nil). Ein fehlendes Feld bleibt unberührt; eine leere Tag-Liste leert die Tags. Das Datum setzt wie `setDue` zusätzlich `dueHasTime` (ohne Uhrzeit Tagesbeginn). `capture` setzt die Felder nach `CaptureService.save` auf die neue Aufgabe und speichert noch einmal; der Rohtext bleibt unverändert (ADR-3), der Titel von Claude ersetzt den Regeltitel als Nutzerrevision (`titleSourceRaw = user`). Gemeinsamer Schreibpfad für `capture` und `update` (eine private Funktion, ≤ 50 LoC).

### Titelschutz im Modell (`EnrichmentWriter`)

`EnrichmentWriter.apply` schreibt den Modelltitel im Erstlauf bisher mit `may(.title, firstRun: true, …)` (Zeile 54) und damit ohne Nutzerschutz. Ein von Claude beim Erfassen gesetzter Titel würde sofort ersetzt. Änderung: `firstRun: !userHasTouched(.title, on: task)`. Folge für alle Aufgaben: hat der Nutzer (oder Claude) den Titel vor dem ersten Lauf berührt, bleibt er; Aufgaben ohne Nutzerrevision am Titel verhalten sich wie bisher (Bestandsverhalten, durch Test belegt).

Die übrigen Felder schützen die Regeln schon (Befund im Code, `Shared/Enrichment/EnrichmentCoordinator.swift`): Fälligkeit Zeile 360 `firstRun: task.dueDate == nil`; Wichtigkeit Zeile 437 `task.importance == nil`; Dringlichkeit Zeile 482 `task.urgency == nil` (ein gesetzter Wert ist nicht leer); Dauer Zeilen 464 und 558, Tags Zeilen 340 und 580, Projekt Zeile 387, Notiz Zeile 422 zusätzlich `!userHasTouched`; „Erneut analysieren“ (`mayWrite(.reanalysis)`) prüft überall `userHasTouched`. Energie schreibt keine Regel, Tags und Projekt schreibt das Modell nie (#215, #469). Der Test unten belegt das als Kette (Erfassen mit Feldern, dann Koordinator-Durchlauf).

### Vertrag (`docs/reference/claude-abschrift-vertrag.md`)

Der Abschnitt „Auftrag“ wird erweitert: siebte Art `update`; `fields` an `capture` und `update` mit den Schlüsseln und Wertemengen oben; `expectedTitle`, `expectedContexts`, `expectedProject`; Prüfreihenfolge; Gründe `invalid` (unbekannter Name oder Wert) und `stale` ergänzt; Hinweis „der Dienst nimmt `fields` ab Schnitt 2 und `update` ab Schnitt 3 an“; Version bleibt 1.

**Harte Randbedingung, wie die neuen Beispiele eingebaut werden:** Zwölf Server-Testdateien lesen den Vertrag mit `/```json\n([\s\S]*?)\n```/g` und verlangen genau drei Treffer (`schema`, `accounts`, `orders`, `app-routes`, `mcp`, `transcripts`, `devices` zählen mit `/```json\n/`); mehrere nehmen Block 1 bis 3 nach Position (Abschrift, Auftrag, Ergebnis). Der Swift-Test `LooseEndsTests/OrderExecutorTests.swift` (`orderFixture`, ab Zeile 539) und `TranscriptCodecTests` prüfen die Beispiele mit `document.contains(...)`. Deshalb: die drei bestehenden `json`-Blöcke bleiben Zeichen für Zeichen und an ihrer Stelle; die zwei neuen Beispiele (`capture` mit `fields`, `update`) stehen in Blöcken mit der Kennzeichnung ` ```jsonc ` (`jsonc` statt `json`, deshalb trifft `/```json\n/` sie nicht), jeweils hinter dem Auftragsbeispiel und unter 30 Zeilen. Sie stehen wörtlich auch im Swift-Test (`orderFieldsFixture`, `orderUpdateFixture` mit `document.contains`, beide Richtungen Dekodieren/Kodieren, `JSONEqual`). Die Serverstests prüfen sie in S2/S3 gegen den Vertrag; der Satz „Server liest die Beispiele“ im Kopf des Vertrags wird um „die drei ` ```json`-Blöcke; die ` ```jsonc`-Beispiele prüft der Swift-Test“ ergänzt. Eine Änderung an den Zählregeln der Server-Tests ist nicht Teil dieses Schnitts.

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `Shared/Services/RevisionService.swift` | bestehend, unverändert | `set` schreibt die Nutzerrevision; `isByClaude`/`lastClaudeChange` tragen die Zeile „Zuletzt von Claude“ (#622 S2) |
| `Shared/Services/FieldCodec.swift` | bestehend, unverändert | eine Kodierung je Feld (Tags als Namensliste, Energie als Zahl) |
| `Shared/Services/CatalogService.swift` | bestehend, unverändert | `nameKey`, `survivesBefore`, `project(named:in:)` (nur lesend) |
| `Shared/Services/CaptureService.swift` | bestehend, unverändert | `save(…, via: .claude)` setzt Rohtext und Regeltitel |
| `Shared/Services/TranscriptCodec.swift` | bestehend, unverändert | kodiert/dekodiert `Order` (sortierte Schlüssel, ISO 8601) |
| `LooseEnds/Claude/ClaudeSync.swift` | bestehend, unverändert | unlesbarer Auftrag → `rejected/invalid` (alte App bei neuer Art) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | bestehend, unverändert | Regeln, die die Claude-Werte schon schützen (Test belegt) |
| `server/` | unverändert | S2/S3 |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `Shared/Services/OrderExecutor.swift` | MODIFY | `Order.Kind.update`, `fields`, drei erwartete Werte, `OrderFields`, Prüfung, gemeinsamer Schreibpfad, `update` | +135/-5 |
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | Titel im Erstlauf nur ohne Nutzerrevision | +1/-1 |
| `LooseEndsTests/OrderExecutorTests.swift` | MODIFY | neue XCTest-Klasse `OrderExecutorFieldsTests` samt Vertragsfixtures | +185 |
| `LooseEndsTests/EnrichmentTests.swift` | MODIFY | Titelschutz und Kette Erfassen → Koordinator | +45 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | Abschnitt „Auftrag“, zwei `jsonc`-Beispiele | +50 |

### Estimated Changes

- Files: 5 (Produktcode 2, Tests 2, Vertrag 1; Obergrenze 4–5 eingehalten).
- LoC: etwa +416/-6 insgesamt. Produktcode und Vertrag allein: +186/-6, unter dem Limit von ±250.

**Überschreitung des Limits, klar benannt:** Mit den Tests liegt der Schnitt bei etwa 420 LoC und damit über ±250. Der Überhang stammt aus Sicherheitstests (jedes Feld, jede Ablehnung ohne Schreiben, Vertragsbeispiele), nicht aus Produktcode (Regel „Sicherheitstests zählen nicht gegen das Limit“, bisher z. B. #615 S2a angenommen). Weiter teilen (etwa `capture` mit Feldern und `update` in zwei Schnitte) würde den gemeinsamen Schreib- und Prüfpfad doppeln und Zwischenstände ohne Nutzen erzeugen. Annahme dieser Überschreitung ist beim PO einzuholen, bevor `/50-implement` beginnt.

## Test Plan

### Automated Tests (TDD RED)

XCTest in `LooseEndsTests/OrderExecutorTests.swift` als eigene Klasse `OrderExecutorFieldsTests: XCTestCase` neben der bestehenden Swift-Testing-Suite und `OrderExecutorRevisionTests` (das QA-Gate zählt nur XCTest); Helfer der Suite (`TestStore`, `run`, `insert`, `Snapshot`) werden genutzt. Der Titelschutz steht als XCTest-Klasse `EnrichmentTitleProtectionTests` in `LooseEndsTests/EnrichmentTests.swift`.

- [ ] Test 1: GIVEN die Vertragsbeispiele `capture` mit `fields` und `update` WHEN dekodiert, kodiert und im Vertragstext gesucht THEN gleich dem festen Beispiel in beiden Richtungen, und der Vertrag enthält sie wörtlich.
- [ ] Test 2: GIVEN `capture` mit allen Feldern (Titel, Notiz, Datum mit Uhrzeit, Wichtigkeit, Dringlichkeit, Dauer, Energie, zwei vorhandene Tags, Projekt) WHEN ausgeführt THEN ein Task mit Rohtext unverändert, `capturedVia == .claude`, allen Werten gesetzt und je Feld genau einer Nutzerrevision mit Grund „Claude“; `RevisionService.lastClaudeChange` liefert die jüngste.
- [ ] Test 3: GIVEN eine Aufgabe und je ein `update` mit einem einzigen Feld (Titel, Datum, Wichtigkeit, Dringlichkeit, Dauer, Energie, Tags, Projekt) WHEN ausgeführt THEN genau dieses Feld geändert, genau eine Revision (Autor `.user`, Grund „Claude“, alter und neuer Wert richtig), `isByClaude` wahr, alle anderen Felder gleich.
- [ ] Test 4: GIVEN ein `update` mit demselben Wert wie bisher und ein `update` ohne dieses Feld WHEN ausgeführt THEN `done` und keine Revision für das unveränderte oder fehlende Feld; eine leere Tag-Liste leert die Tags (eine Revision).
- [ ] Test 5: GIVEN Namen WHEN ein Tag oder das Projekt in anderer Groß-/Kleinschreibung oder mit Akzent geschrieben ist THEN die Aufgabe trägt den Katalogeintrag mit dessen Schreibweise, und es entsteht nie ein neuer Tag oder ein neues Projekt.
- [ ] Test 6: GIVEN unbekannter Tag, unbekanntes Projekt, falsche Wichtigkeit, Dauer, Dringlichkeit, Energie 4, leerer Titel, `notes` bei `update`, leeres `fields`, Datum ohne `dueHasTime`, `expectedStatus` `done`, und dasselbe bei `capture` WHEN ausgeführt THEN `rejected/invalid` (mit `taskID` bei `update`), und `Snapshot` (Aufgaben, Revisionen, Kataloge) bleibt gleich; ein abgelehntes `capture` legt keine Aufgabe an.
- [ ] Test 7: GIVEN eine Aufgabe, die sich seit der Abschrift verändert hat WHEN `update` mit altem Titel, alten Tags, altem Projekt, altem Datum oder altem Status THEN `rejected/stale` mit `taskID`, Store unverändert; fehlt der erwartete Wert und hat die Aufgabe inzwischen einen, ebenfalls `stale`.
- [ ] Test 8: GIVEN eine unbekannte `taskID` WHEN `update` THEN `rejected/missing` ohne `taskID`, Store unverändert; ein `update` ohne `taskID` ist `invalid`.
- [ ] Test 9: GIVEN `setDue`, `complete`, `setNext`, `park`, `addSubtask` und `capture` ohne `fields` WHEN ausgeführt THEN Verhalten und die bestehenden Tests unverändert (kein Rückschritt).
- [ ] Test 10: GIVEN ein `update` mit Datum, das denselben Zeitpunkt träfe und nur `dueHasTime` änderte WHEN ausgeführt THEN `invalid`, keine Änderung (#777).
- [ ] Test 11: GIVEN eine Aufgabe mit einer Nutzerrevision am Titel WHEN `EnrichmentWriter.apply` im Erstlauf einen Modelltitel liefert THEN der Titel bleibt; GIVEN keine Nutzerrevision THEN der Modelltitel wird wie bisher geschrieben.
- [ ] Test 12: GIVEN ein `capture` mit allen Feldern, dessen Rohtext Datums-, Wichtigkeits-, Dauer-, Tag- und Notizwörter enthält WHEN danach der Koordinator-Durchlauf (Regeln und Stub-Modell mit anderem Titel) und „Erneut analysieren“ laufen THEN jedes von Claude gesetzte Feld behält seinen Wert, und keine automatische Revision kommt an einem dieser Felder hinzu.

Server-Tests laufen unverändert grün (`./server/scripts/test-local.sh`); sie belegen, dass die drei `json`-Blöcke des Vertrags unverändert gelesen werden.

### Abnahme

Stufe 1: neue Tests rot vor, grün nach der Umsetzung; alle Unit-Tests grün (`./scripts/sim.sh sim-unit OrderExecutorFieldsTests`, `OrderExecutorTests`, `OrderExecutorRevisionTests`, `EnrichmentTitleProtectionTests`, dann der volle Lauf `./scripts/sim.sh unit`), `./server/scripts/test-local.sh` grün.

Stufe 2: Der Ablauf „Auftrag von Claude → Aufgabe in der App → Zeile ‚Zuletzt von Claude‘“ besteht seit #622 S2 als UI-Test `LooseEndsUITests/ClaudeChangeTests.swift` mit dem Startargument `--ui-testing-claude-change` (`LooseEnds/App/LooseEndsApp.swift`, führt einen echten Auftrag `setDue` über `OrderExecutor` auf eine Beispielaufgabe aus). Er läuft unverändert als Regressionsnachweis, weil dieser Schnitt den `OrderExecutor` berührt: `./scripts/sim.sh test-proof ClaudeChangeTests` mit registriertem Beleg (das ist der Beleg für `phase8_complete`). Ein neuer UI-Test oder ein neues Startargument wird bewusst nicht gebaut: es gibt keine neue Oberfläche, die Detailzeile liest nur `isByClaude`/`lastClaudeChange`, und Test 2/3 belegen genau diesen Zusammenhang für die neuen Felder in der Logik. Das Fixture führt `setDue` aus; die Felder beweist der Unit-Test, nicht der Durchlauf. Das wird im Abschlussbericht so benannt.

Stufe 3: Kein Pfad der Geräteliste berührt. Geprüft gegen die Tabelle in `CLAUDE.md`: `Shared/Services/OrderExecutor.swift`, `Shared/Enrichment/EnrichmentWriter.swift`, Tests und Vertrag stehen nicht darin; `FoundationModelsEnricher.swift` und `EnrichmentCoordinator.swift` werden nicht angefasst, `Shared/Persistence/`, `project.yml`, Entitlements und `Info.plist` ebenso nicht. Das Gerät kommt mit dem claude.ai-Durchlauf im Testbau in S3.

## Acceptance Criteria

- **AC-1:** Die Vertragsbeispiele `capture` mit `fields` und `update` dekodieren zu festen `Order`-Werten und kodieren in beiden Richtungen gleich; `docs/reference/claude-abschrift-vertrag.md` enthält sie wörtlich (Test 1, `OrderExecutorFieldsTests`).
- **AC-2:** Ein `capture` mit `fields` legt die Aufgabe mit unverändertem Rohtext an und setzt jedes vorhandene Feld als Nutzerrevision (Autor `.user`, Grund „Claude“), `RevisionService.lastClaudeChange` findet sie (Test 2).
- **AC-3:** Ein `update` setzt Titel, Fälligkeit (mit `dueHasTime`), Wichtigkeit, Dringlichkeit, Dauer, Energie, Tags und Projekt je als genau eine Nutzerrevision mit Grund „Claude“ und richtigem Alt- und Neuwert; andere Felder bleiben gleich (Test 3).
- **AC-4:** Ein fehlendes Feld bleibt unberührt, ein unveränderter Wert schreibt keine Revision, eine leere Tag-Liste leert die Tags (Test 4).
- **AC-5:** Tags und Projekt werden nur über `CatalogService.nameKey` aus vorhandenen Einträgen aufgelöst und in der Schreibweise des Katalogs gespeichert; es entsteht nie ein neuer Tag oder ein neues Projekt (Test 5).
- **AC-6:** Unbekannter Tag oder Projekt, ungültiger Enum-Wert, Energie außerhalb −3…3, leerer Titel, `notes` bei `update`, leeres `fields`, Datum ohne `dueHasTime` und ein `update` mit `expectedStatus` erledigt oder gelöscht werden als `invalid` abgelehnt, ohne jede Schreibung: Aufgaben, Revisionen und Kataloge sind unverändert, ein abgelehntes `capture` legt keine Aufgabe an (Test 6, Test 10).
- **AC-7:** Ein `update`, dessen erwarteter Status, Titel, Tags, Projekt oder Datum nicht mehr zum Gerät passt, wird als `stale` abgelehnt, eine unbekannte Aufgabe als `missing`; der Store bleibt unverändert (Test 7, Test 8).
- **AC-8:** Aufträge ohne `fields` (`capture`, `complete`, `setDue`, `setNext`, `park`, `addSubtask`) verhalten sich unverändert; die bestehenden Tests von `OrderExecutorTests` und `OrderExecutorRevisionTests` bleiben grün (Test 9).
- **AC-9:** Der Modelltitel ersetzt im Erstlauf keinen Titel, an dem eine Nutzerrevision hängt, und schreibt ihn weiter, wo keine hängt (Test 11, `EnrichmentTitleProtectionTests`).
- **AC-10:** Nach einem `capture` mit Feldern behalten Regeln, Stub-Modell und „Erneut analysieren“ jeden von Claude gesetzten Wert (Fälligkeit, Wichtigkeit, Dringlichkeit, Dauer, Tags, Projekt, Notiz, Titel) und legen keine automatische Revision an diesen Feldern an (Test 12).
- **AC-11:** Der Vertrag enthält weiter genau drei ` ```json`-Blöcke an derselben Stelle und mit gleichem Inhalt; die neuen Beispiele stehen in ` ```jsonc`-Blöcken; `./server/scripts/test-local.sh` bleibt grün und der Dienst (`server/`) ist unverändert.
- **AC-12:** Alle Unit-Tests sind grün, und `./scripts/sim.sh test-proof ClaudeChangeTests` ist grün mit registriertem Beleg.

## Definition of Done

- [ ] Neue Tests aus dem Test Plan rot vor der Umsetzung, grün danach; alle Unit-Tests und `./server/scripts/test-local.sh` grün
- [ ] `./scripts/sim.sh test-proof ClaudeChangeTests` grün, Beleg registriert
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“ und dem Hinweis, dass das Startargument-Fixture `setDue` fährt und die Felder der Unit-Test belegt
- [ ] Ausgeliefert per PR mit `Refs #932`, CI grün, gemergt; #932 bleibt offen (S2, S3, claude.ai-Durchlauf); Reihenfolge: dieser Schnitt im Testbau vor dem Ausrollen des Dienstes

## Alternativen

- **Regelweg statt Felder (Regeln vor Modell):** Claude schreibt die Angaben in den Erfassungstext („… 20 Minuten #Garten“), die vorhandenen Regeln leiten sie ab; kein neuer Vertrag. Verworfen: der Rohtext wäre nicht mehr Hennings Wortlaut (Anleitung #623: „mit seinem Wortlaut, unverändert“, ADR-3), Energie und Projekt haben keine sichere Regel, und ein Umbenennen oder Ändern danach geht so gar nicht (der Anlass von #932). Fiele: die Festlegung der Anleitung #623, dass Rohtext unverändert bleibt.
- **Je Feld ein eigenes Werkzeug/eine eigene Art** (`rename`, `setTags`, …, wie `setDue`): einfachere Einzelprüfung, aber neun Arten, neun Migrationseinträge und viele Aufrufe je Aufgabe. Verworfen zugunsten eines `update` mit Feldobjekt. Fiele: nichts, nur das Muster „eine Art je Änderung“ aus #622.
- **Abschrift Version 2 mit allen Feldern** (volle Stand-Prüfung auch für Dauer, Energie, Wichtigkeit, Dringlichkeit, Notiz): kippt die Festlegung des Vertrags „mehr Felder in der Abschrift = Version 2 + Datenschutzfreigabe (#625)“. Folgearbeit möglich, nicht hier. Fiele: diese Vertragsfestlegung und der Datenschutztext (`docs/reference/datenschutz-entwurf.md`, Konto-Teil).
- **Verworfen im Detail:** Unbekannte Schlüssel in einem alten App-Stand ablehnen statt neue Art — nicht nötig, weil `update` als neue Art von alten Ständen ohnehin abgelehnt wird; für `capture` mit `fields` löst die Auslieferungsreihenfolge das Problem.
- Keine ADR fällt.

## Risiken

- **`capture` speichert zweimal:** `CaptureService.save` speichert sofort, danach schreibt der Executor die Felder und speichert erneut. Scheitert das zweite Speichern, bleibt eine Aufgabe ohne Felder, der Auftrag bleibt unbeantwortet, und das Zurückholen nach 10 Minuten (at-least-once, Vertrag „Wege der App“, Punkt c) kann das `capture` doppelt erfassen; das entspricht der bestehenden, dokumentierten Schwäche von `capture`. Alles Prüfbare liegt vor dem ersten Speichern, ein Fehler ist daher nur ein Speicherfehler.
- **Letzter Schreiber gewinnt bei Wichtigkeit, Dringlichkeit, Dauer, Energie:** sie stehen nicht in der Abschrift. Schutz ist der erwartete Status und die Anleitung (S3: Änderung nur nach Hennings Ja). Abschrift Version 2 wäre die Alternative (siehe oben).
- **Tags/Projekt sind für Claude nur aus offenen Aufgaben sichtbar** (`list_contexts`/`list_projects`): einen vorhandenen, aber unbenutzten Tag kennt Claude nicht und schickt ihn daher nicht; schickt Claude ihn trotzdem, nimmt die App ihn an (er steht im Katalog). Ein Name, den die App nicht kennt, wird `invalid` (nie neu anlegen); wird in der Anleitung S3 gesagt.
- **Änderung des Titelschutzes wirkt für alle Aufgaben:** hat der Nutzer den Titel vor dem Erstlauf selbst geändert, schreibt das Modell nicht mehr darüber. Das ist die beabsichtigte Folge (Nutzerwert schlägt Modellwert, wie bei Dauer); Test 11 sichert den Bestand.
- **Server-Test-Kopplung des Vertrags:** durch `jsonc` statt `json` umgangen, nicht durch Änderung der Server-Tests. Ändert jemand die Kennzeichnung in ` ```json`, brechen mindestens zwölf Testdateien sofort (laut, nicht still).

## Changelog

- 2026-11-15: Erste Fassung (Schnitt 1, App); S2 und S3 (Dienst) bekommen eigene Teil-Specs.
