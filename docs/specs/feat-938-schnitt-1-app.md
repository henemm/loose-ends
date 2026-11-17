---
entity_id: feat-938-schnitt-1-app
type: feature
created: 2026-11-17
updated: 2026-11-17
status: draft
workflow: feat-938-wiederholung-claude
---

# Spec: Wiederholung und Link in Claude-Aufträgen, Schnitt 1 (App, #938)

## Approval

- [ ] Approved

## GitHub Issue

#938 (Epic #612). Schnitt 1 von 3; das Issue bleibt offen (PR mit `Refs #938`, nie `Closes #938`), weil Schnitt 2 (Dienst), Schnitt 3 (Übertragung der Liste „Family“) und der claude.ai-Durchlauf aus der Definition of Done von #938 offen bleiben.
Analyse: `docs/context/feat-938-wiederholung-claude.md`. Vorgänger: #932 (`fields` in Aufträgen, jede Änderung eine Nutzerrevision mit Grund „Claude“).

## Purpose

Claude soll beim Erfassen und danach eine Wiederholung (täglich, wöchentlich, monatlich, jährlich, mit Rhythmus und Wochentagen) setzen können, und beim Erfassen einen Link, damit die wiederkehrenden Aufgaben der Erinnerungsliste „Family“ über Claude in die App kommen. Dieser Schnitt baut die Gegenstelle auf dem Gerät: der `OrderExecutor` versteht `fields.repeat` und `fields.link`, prüft vor dem ersten Schreiben und schreibt die Wiederholung als `RepeatRule` mit Anker und einer Nutzerrevision mit Grund „Claude“. Ohne den Dienst (S2) schickt nichts solche Aufträge; der Schnitt ist unschädlich und kommt zuerst in den Testbau.

**Regeln vor Modell:** reine Datenlogik (Prüfen, Regel bauen, Revision schreiben), kein Modellaufruf; der Satz „Ohne Modell geht es nicht, weil …“ entfällt.

## Nicht in diesem Schnitt

- **Schnitt 2 (Dienst):** Form von `repeat`/`link` in `server/src/orders.ts`, zod-Schema und Werkzeugbeschreibungen in `server/src/mcp.ts`, Anleitung, Servertests. Der Dienst (`server/`) bleibt unverändert; bis S2 verwirft er `repeat` und `link` als unbekannte Schlüssel.
- **Schnitt 3 (Übertragung):** Liste „Family“ lesen und übertragen, claude.ai-Durchlauf.
- **Wiederholung entfernen** (bräuchte `null` als eigene Form): Folge-Issue bei Bedarf.
- Keine Abschrift Version 2: die Abschrift kennt keine Wiederholung und bleibt Version 1, unverändert.
- Keine Oberfläche, kein Modell- oder CloudKit-Schema-Wechsel: `repeatRule` ist ein `BYTES`-Feld mit JSON (`cloudkit/schema.ckdb`), `sourceURL` und alle `RevisedField`-Fälle existieren.
- Kein „n-ter Wochentag“ (z. B. „jedes Jahr am 2. Samstag im Februar“): PO-Entscheidung 2026-11-17, jährlich zum Datum, Claude nennt die Abweichung (S3).

## Reihenfolge der Auslieferung

App (dieser Schnitt) per TestFlight zuerst, Dienst (S2) erst ausrollen, wenn dieser Bau auf Hennings Geräten läuft. Grund: Swift-`Codable` ignoriert unbekannte Schlüssel. Eine alte App würde ein `capture` mit `fields.repeat` als Aufgabe ohne Wiederholung anlegen und `done` melden; die Wiederholung ginge still verloren (bei `update` mit weiteren Feldern ebenso, bei `repeat` allein wäre `fields` für sie leer und der Auftrag `invalid`). Die Reihenfolge löst das Problem, nicht der Code.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Auftragsweg (ADR-21, Weg B) und „Revisions, not undo“ tragen das unverändert: ein weiteres Feld im selben Objekt `fields`, Version 1, ohne Schemawechsel; „Repeat without series“ (ADR-7) bleibt: eine Regel an der Aufgabe, `anchor` aus #552.

## Source

**Files:** `Shared/Services/OrderExecutor.swift`, `LooseEndsTests/OrderExecutorRepeatTests.swift`, `docs/reference/claude-abschrift-vertrag.md`
**Identifier:** `OrderFields.repeat`, `OrderFields.link`, `OrderExecutor.write`

## Implementation Details

### Form von `fields.repeat` und `fields.link`

`OrderFields` bekommt `repeat: OrderRepeat?` (Swift-Schlüsselwort: Eigenschaft in Backticks, JSON-Schlüssel `repeat`) und `link: String?`. `OrderRepeat` (Codable, Equatable, Sendable): `frequency: String` (`daily|weekly|monthly|yearly`), `interval: Int?` (1…52, Standard 1), `weekdays: [Int]?` (1…7, 1 = Sonntag, nur bei `weekly`), `basis: String?` (`fromDueDate|fromCompletion`, Standard `fromDueDate`). Die Werte kommen als Text/Zahl und werden vom Executor geprüft, nicht vom Enum-Decoder, damit ein falscher Wert `invalid` mit `taskID` ist und kein unlesbarer Auftrag. `OrderFields.isEmpty` bleibt `self == OrderFields()`; `repeat` allein ist also ein gültiges `fields`.

### Prüfung vor dem ersten Schreiben (Formprüfung `invalid`, in `isWellFormed`)

Unbekannte `frequency` oder `basis`; `interval` außerhalb 1…52; `weekdays` bei einer anderen Frequenz als `weekly`, leer oder mit einem Wert außerhalb 1…7; `link` bei `update`; `link` ohne gültige URL oder mit einem anderen Schema als `http`/`https` oder ohne Host. Die Reihenfolge der Stufen bleibt wie in #932 (Form, Aufgabe, Namen, erwarteter Stand, ein `commit`).

### Erwarteter Stand bei `update`

Für `repeat` gilt nur `expectedStatus` (offen/geparkt): die Abschrift kennt keine Wiederholung, und es gibt keinen Vertrag Version 2. Das gilt wie bei Wichtigkeit und Dauer (letzter Schreiber gewinnt; Schutz ist das Ja des Nutzers laut Anleitung, S2). `matchesTranscript` bleibt unverändert.

### Schreiben der Wiederholung

In `write`, nach dem Fälligkeitsfeld (damit eine im selben Auftrag gesetzte Fälligkeit schon steht):

- **Regel bauen:** `RepeatRule(frequency:, interval: interval ?? 1, weekdays: sortiert und ohne Doppelte, basis: basis ?? .fromDueDate)`. Uhrzeit: setzt der Auftrag `dueDate` mit `dueHasTime == true`, sind `hour`/`minute` die Uhrzeit dieses Datums (im übergebenen Kalender); sonst keine. Ersetzt `update` eine vorhandene Regel ohne `dueDate` im Auftrag, bleiben deren `hour`/`minute` stehen.
- **Anker wie `FieldEditorView.applyRepeat`:** neue Regel (die Aufgabe hatte keine): `anchor` = die im selben Auftrag gesetzte oder vorhandene Fälligkeit; fehlt beides, `firstDueDate(now:calendar:)` der Regel, und diese Fälligkeit wird mitgesetzt (`set(.dueDate, …)` als eigene Revision, `dueHasTime = hour != nil`). Vorhandene Regel ersetzen (`update`): `anchor` bleibt, außer der Auftrag setzt `dueDate`, dann ist es dieses Datum.
- **Revision:** genau eine `.repeatRule`-Revision, Autor `.user`, Grund „Claude“, über `RevisionService.set(.repeatRule, to: FieldCodec.encode(rule), …)`; steht dieselbe Regel schon, entsteht keine Revision (`set` liefert nil), und der Anker bleibt.
- Die Funktion bleibt ≤ 50 LoC: Regelbau und Anker in zwei kleine private Funktionen (`makeRule`, `anchoredRule`).

### Schreiben des Links

Nur `capture`: nach `CaptureService.save` wird `task.sourceURL` auf die URL gesetzt (wie bei Share und Mail). Keine Revision (`sourceURL` ist kein `RevisedField`); der Rohtext bleibt unverändert (ADR-3). Weil `save` bereits gespeichert hat, schreibt der bestehende zweite `commit` den Link mit. Ein `capture`, das nur `link` trägt, ist ein gültiges `fields`.

### Vertrag (`docs/reference/claude-abschrift-vertrag.md`)

Der `fields`-Absatz wird um `repeat` und `link` erweitert (Schlüssel, Wertemengen, Prüfgründe, Anker-Regel, „bei `update` nur Status“, „Wiederholung entfernen gibt es nicht“, „Dienst nimmt `repeat`/`link` ab Schnitt 2 an“). Ein weiteres Beispiel (`capture` mit `repeat` und `link`, unter 30 Zeilen) steht in einem Block mit der Kennzeichnung ` ```jsonc ` und bleibt gültiges JSON (keine Kommentare darin), wie die #932-Beispiele; die drei ` ```json`-Blöcke bleiben Zeichen für Zeichen unverändert (zwölf Server-Testdateien lesen sie nach Position). Das Beispiel steht wörtlich im Swift-Test (`document.contains`, Dekodieren/Kodieren, `JSONEqual`).

## Dependencies

| Entität | Art | Zweck |
|---|---|---|
| `Shared/Models/RepeatRule.swift` | bestehend, unverändert | Regel, `anchor`, `firstDueDate`, `nextDueDate` |
| `Shared/Services/FieldCodec.swift` | bestehend, unverändert | `.repeatRule` als sortiertes JSON kodieren |
| `Shared/Services/RevisionService.swift` | bestehend, unverändert | `set` schreibt die Nutzerrevision; `isByClaude` trägt die Zeile „Zuletzt von Claude“ |
| `Shared/Services/CaptureService.swift` | bestehend, unverändert | `save` (Rohtext, Regeltitel); `sourceURL` wird danach gesetzt |
| `Shared/Services/TaskActions.swift` | bestehend, unverändert | Weiterrollen beim Erledigen (nur im Test gelesen) |
| `Shared/Services/SiriRepeatMapping.swift`, `LooseEnds/Views/FieldEditorView.swift` | bestehend, unverändert | Vorbild für Anker und Revision |
| `server/` | unverändert | S2 |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung | LoC |
|---|---|---|---|
| `Shared/Services/OrderExecutor.swift` | MODIFY | `OrderFields.repeat`/`link`, `OrderRepeat`, Formprüfung, Regelbau mit Anker, Link auf `sourceURL` | +75/-3 |
| `LooseEndsTests/OrderExecutorRepeatTests.swift` | CREATE | XCTest-Klasse `OrderExecutorRepeatTests`, Vertragsbeispiel, Family-Fälle | +230 |
| `docs/reference/claude-abschrift-vertrag.md` | MODIFY | `repeat`/`link`-Absatz, ein `jsonc`-Beispiel | +30 |

### Estimated Changes

- Files: 3 (Produktcode 1, Test 1, Vertrag 1; Obergrenze 4–5 eingehalten).
- LoC: etwa +335/-3 insgesamt; Produktcode und Vertrag allein +105/-3.

**Überschreitung des Limits, klar benannt:** mit den Tests liegt der Schnitt über ±250 LoC. Der Überhang stammt aus Sicherheitstests (jede Ablehnung ohne Schreiben, Anker- und Uhrzeitfälle, Weiterrollen), nicht aus Produktcode (Regel „Sicherheitstests zählen nicht gegen das Limit“, angenommen zuletzt bei #932 S1). Weiter teilen würde den gemeinsamen Prüfpfad doppeln. Annahme ist beim PO einzuholen, bevor `/50-implement` beginnt.

## Test Plan

### Automated Tests (TDD RED)

XCTest in `LooseEndsTests/OrderExecutorRepeatTests.swift` als Klasse `OrderExecutorRepeatTests: XCTestCase` (das QA-Gate zählt nur XCTest); die Helfer von `OrderExecutorTests.swift` (`TestStore`, `run`, `insert`, `Snapshot`) werden genutzt oder knapp nachgebaut.

- [ ] Test 1 (`testContractExampleRepeatAndLinkRoundTrips`): GIVEN das `jsonc`-Beispiel `capture` mit `repeat` und `link` WHEN dekodiert, kodiert und im Vertragstext gesucht THEN gleich dem festen `Order`-Wert in beiden Richtungen, und der Vertrag enthält es wörtlich.
- [ ] Test 2 (`testCaptureWithRepeatCreatesRuleWithAnchorAndRevision`): GIVEN `capture` mit `dueDate` (mit Uhrzeit 07:30) und `repeat` weekly, Wochentage 2 und 4 WHEN ausgeführt THEN Rohtext unverändert, `repeatRule` mit Frequenz, Wochentagen, `hour` 7, `minute` 30, `anchor` = Fälligkeit, genau eine `.repeatRule`-Revision (Autor `.user`, Grund „Claude“), `RevisionService.lastClaudeChange` findet sie.
- [ ] Test 3 (`testCaptureWithRepeatWithoutDueDateSetsFirstDueDate`): GIVEN `capture` mit `repeat` und ohne `dueDate` WHEN ausgeführt THEN `dueDate` = `firstDueDate(now)` der Regel, `anchor` gleich, `dueHasTime` falsch (Regel ohne Uhrzeit), zwei Revisionen (Fälligkeit, Wiederholung) mit Grund „Claude“.
- [ ] Test 4 (`testRepeatTimeComesOnlyFromDueDateWithTime`): GIVEN `dueDate` ohne Uhrzeit und `repeat` WHEN ausgeführt THEN `hour`/`minute` nil; GIVEN `dueDate` mit Uhrzeit THEN gesetzt.
- [ ] Test 5 (`testUpdateReplacesRuleKeepsAnchorUnlessDueDateComes`): GIVEN eine Aufgabe mit Regel und `anchor` WHEN `update` nur mit `repeat` THEN neue Regel, `anchor` unverändert, alte Uhrzeit bleibt; WHEN `update` mit `repeat` und `dueDate` THEN `anchor` = neues Datum, Uhrzeit aus dem Datum.
- [ ] Test 6 (`testUpdateAddsRuleToTaskWithDueDateAnchorsOnIt`): GIVEN eine Aufgabe ohne Regel mit Fälligkeit WHEN `update` mit `repeat` THEN `anchor` = diese Fälligkeit, Fälligkeit unverändert, genau eine Revision.
- [ ] Test 7 (`testUpdateWithRepeatChecksOnlyStatus`): GIVEN eine Aufgabe, deren Titel, Tags und Datum sich seit der Abschrift geändert haben WHEN `update` nur mit `repeat` und passendem Status THEN `done`; GIVEN Status erledigt oder gelöscht THEN `invalid`; GIVEN unbekannte `taskID` THEN `missing`; Store bei Ablehnung unverändert.
- [ ] Test 8 (`testSameRuleWritesNoRevision`): GIVEN eine Aufgabe mit genau dieser Regel WHEN `update` mit demselben `repeat` THEN `done`, keine neue Revision, `anchor` unverändert.
- [ ] Test 9 (`testMalformedRepeatAndLinkAreInvalidWithoutWriting`): GIVEN unbekannte Frequenz, unbekannte Basis, `interval` 0 und 53, `weekdays` bei `daily`, `weekdays` leer, Wochentag 0 und 8, `link` ohne Schema, mit `ftp:`, ohne Host, und `link` bei `update`, jeweils bei `capture`/`update` WHEN ausgeführt THEN `rejected/invalid` (mit `taskID` bei `update`), `Snapshot` (Aufgaben, Revisionen, Kataloge) gleich, ein abgelehntes `capture` legt keine Aufgabe an.
- [ ] Test 10 (`testCaptureLinkSetsSourceURLWithoutRevision`): GIVEN `capture` mit `link` `https://…` und Titel WHEN ausgeführt THEN `sourceURL` gesetzt, Rohtext unverändert, keine Revision für den Link; GIVEN nur `link` als `fields` THEN `done`.
- [ ] Test 11 (`testFamilyRhythmsCaptureAsWeeklyInterval`): GIVEN die Fälle „alle 26 Wochen“ und „alle 52 Wochen“ mit Uhrzeit und Tag aus der Liste „Family“ WHEN `capture` mit `repeat` weekly, `interval` 26 bzw. 52 THEN Regel mit `interval` 26 bzw. 52, kein Wochentag; die tägliche Gewohnheit „abends“ als `daily` mit Uhrzeit; „jährlich zum Datum“ als `yearly`.
- [ ] Test 12 (`testCompletingRollsForwardFromAnchor`): GIVEN eine per Auftrag angelegte Regel (weekly, Intervall 26, `fromDueDate`) WHEN die Aufgabe erledigt wird (`TaskActions.complete`) THEN die Fälligkeit rollt um 26 Wochen weiter und `anchor` folgt (`CompletionRecord` je Zyklus).
- [ ] Test 13 (`testOrdersWithoutRepeatOrLinkBehaveAsBefore`): GIVEN `capture` mit `fields` ohne `repeat`/`link`, `update`, `setDue`, `complete` WHEN ausgeführt THEN `repeatRule` und `sourceURL` unberührt, bestehende Tests (`OrderExecutorTests`, `OrderExecutorFieldsTests`) grün.

### Abnahme

Stufe 1: neue Tests rot vor, grün nach der Umsetzung; `./scripts/sim.sh sim-unit OrderExecutorRepeatTests`, `OrderExecutorFieldsTests`, `OrderExecutorTests`, `OrderExecutorRevisionTests`, dann der volle Lauf `./scripts/sim.sh unit`; `./server/scripts/test-local.sh` grün (belegt, dass die drei `json`-Blöcke des Vertrags unverändert gelesen werden).

Stufe 2: der Ablauf „Auftrag von Claude → Aufgabe in der App → Zeile ‚Zuletzt von Claude‘“ besteht als UI-Test `LooseEndsUITests/ClaudeChangeTests.swift` mit `--ui-testing-claude-change`; er läuft unverändert als Regressionsnachweis, weil der `OrderExecutor` berührt wird: `./scripts/sim.sh test-proof ClaudeChangeTests` mit registriertem Beleg. Kein neuer UI-Test: es gibt keine neue Oberfläche, die Wiederholung zeigt die App wie bisher aus `repeatRule`; das Fixture fährt `setDue`, die Wiederholung beweist der Unit-Test. Das nennt der Abschlussbericht.

Stufe 3: Kein Pfad der Geräteliste berührt. Geprüft gegen die Tabelle in `CLAUDE.md`: `Shared/Services/OrderExecutor.swift`, Tests und Vertrag stehen nicht darin; `Shared/Persistence/`, `project.yml`, Entitlements, `Info.plist`, `FoundationModelsEnricher.swift` und `EnrichmentCoordinator.swift` bleiben unberührt. Der claude.ai-Durchlauf mit dem Testbau ist Gerätepunkt der Definition of Done von #938, nicht Acceptance Criterion.

## Acceptance Criteria

- **AC-1:** Das Vertragsbeispiel `capture` mit `repeat` und `link` dekodiert zu einem festen `Order`-Wert und kodiert in beiden Richtungen gleich; `docs/reference/claude-abschrift-vertrag.md` enthält es wörtlich in einem `jsonc`-Block (Test 1, `testContractExampleRepeatAndLinkRoundTrips`).
- **AC-2:** Ein `capture` mit `repeat` legt die Aufgabe mit unverändertem Rohtext und einer `RepeatRule` (Frequenz, Intervall, Wochentage, Basis, Standardwerte 1 und `fromDueDate`) an, mit `anchor` = Fälligkeit und genau einer `.repeatRule`-Revision (Autor `.user`, Grund „Claude“), die `lastClaudeChange` findet (Test 2, `testCaptureWithRepeatCreatesRuleWithAnchorAndRevision`).
- **AC-3:** Fehlt Fälligkeit bei einer neuen Regel, setzt der Auftrag `firstDueDate(now:)` als Fälligkeit (eigene Revision, Grund „Claude“) und als `anchor` (Test 3, `testCaptureWithRepeatWithoutDueDateSetsFirstDueDate`).
- **AC-4:** `hour`/`minute` der Regel stammen nur aus einem im Auftrag gesetzten `dueDate` mit `dueHasTime`; sonst bleiben sie leer (Test 4, `testRepeatTimeComesOnlyFromDueDateWithTime`).
- **AC-5:** Ein `update` mit `repeat` ersetzt die vorhandene Regel und behält `anchor` und Uhrzeit, außer `dueDate` kommt im selben Auftrag; bei einer Aufgabe ohne Regel ankert es auf der vorhandenen Fälligkeit (Test 5 `testUpdateReplacesRuleKeepsAnchorUnlessDueDateComes`, Test 6 `testUpdateAddsRuleToTaskWithDueDateAnchorsOnIt`).
- **AC-6:** Bei `update` mit `repeat` ist nur der Status erwarteter Zustand: Titel-, Tag- oder Datumsänderungen seit der Abschrift lassen es nicht `stale` werden; erledigt/gelöscht ist `invalid`, unbekannte Aufgabe `missing`, der Store bleibt bei Ablehnung unverändert (Test 7, `testUpdateWithRepeatChecksOnlyStatus`).
- **AC-7:** Dieselbe Regel noch einmal setzen schreibt keine Revision und lässt den Anker stehen (Test 8, `testSameRuleWritesNoRevision`).
- **AC-8:** Unbekannte Frequenz oder Basis, `interval` außerhalb 1…52, `weekdays` bei anderer Frequenz als `weekly`, leer oder außerhalb 1…7, ein `link` ohne http/https-URL mit Host und ein `link` bei `update` werden als `invalid` abgelehnt, ohne jede Schreibung; ein abgelehntes `capture` legt keine Aufgabe an (Test 9, `testMalformedRepeatAndLinkAreInvalidWithoutWriting`).
- **AC-9:** Ein `capture` mit `link` setzt `sourceURL` ohne Revision und ohne den Rohtext zu ändern; `link` allein ist ein gültiges `fields` (Test 10, `testCaptureLinkSetsSourceURLWithoutRevision`).
- **AC-10:** Die Rhythmen der Liste „Family“ (alle 26 und alle 52 Wochen, täglich mit Uhrzeit, jährlich zum Datum) lassen sich als Regel anlegen, und Erledigen rollt die Fälligkeit nach dem Anker weiter (Test 11 `testFamilyRhythmsCaptureAsWeeklyInterval`, Test 12 `testCompletingRollsForwardFromAnchor`).
- **AC-11:** Aufträge ohne `repeat`/`link` verhalten sich unverändert; `OrderExecutorTests`, `OrderExecutorRevisionTests` und `OrderExecutorFieldsTests` bleiben grün (Test 13, `testOrdersWithoutRepeatOrLinkBehaveAsBefore`).
- **AC-12:** Der Vertrag enthält weiter genau drei ` ```json`-Blöcke an derselben Stelle mit gleichem Inhalt, `./server/scripts/test-local.sh` bleibt grün und `server/` ist unverändert; alle Unit-Tests sind grün und `./scripts/sim.sh test-proof ClaudeChangeTests` ist grün mit registriertem Beleg (Test 1 und die Läufe der Abnahme).

## Definition of Done

- [ ] Neue Tests aus dem Test Plan rot vor der Umsetzung, grün danach; alle Unit-Tests und `./server/scripts/test-local.sh` grün
- [ ] `./scripts/sim.sh test-proof ClaudeChangeTests` grün, Beleg registriert
- [ ] Abschlussbericht mit dem Satz „Kein Pfad der Geräteliste berührt.“ und dem Hinweis, dass das Startargument-Fixture `setDue` fährt und die Wiederholung der Unit-Test belegt
- [ ] Ausgeliefert per PR mit `Refs #938`, CI grün, gemergt; #938 bleibt offen (S2, S3, claude.ai-Durchlauf); TestFlight-Bau mit diesem Schnitt vor dem Ausrollen des Dienstes

## Alternativen

- **Eigenes Werkzeug/eigene Art `set_repeat`** (wie `set_due`): einfachere Einzelprüfung. Verworfen: die Übertragung der Liste „Family“ braucht dann zwei Aufträge je Aufgabe, und der Anker stünde zwischen beiden falsch (die Fälligkeit des ersten Auftrags ist noch nicht gesetzt oder nicht sichtbar). Fiele: nichts, nur das Muster „Felder in `fields`“ aus #932.
- **Modellerweiterung „n-ter Wochentag“** (`RepeatRule.ordinal`, `nextDueDate`, Anzeige, Tests; CloudKit additiv, da JSON): würde „jedes Jahr am 2. Samstag im Februar“ abbilden. Verworfen: PO entschied 2026-11-17, jährlich zum Datum; Claude nennt die Abweichung. Fiele: ADR-7 „Repeat without series“ bliebe unberührt, nur die Festlegung, dass die Regel nur Intervall und Wochentage kennt.
- **Link als Zeile in der Notiz statt `sourceURL`:** ginge auch bei `update`. Verworfen: `sourceURL` ist das vorgesehene Feld (Detail „Source · Open the source“), kein Textsuchen nötig. Fiele: nichts.
- **Abschrift Version 2 mit Wiederholung** für eine volle Stale-Prüfung: kippt die Vertragsfestlegung „mehr Felder = Version 2 + Datenschutzfreigabe (#625)“; Folgearbeit möglich, nicht hier.
- Keine ADR fällt.

## Risiken

- **Auslieferungsreihenfolge** (oben): ein früher ausgerollter Dienst führt mit alter App zu stillem Verlust der Wiederholung. Schutz ist die Reihenfolge; der Dienst-Rollout (S2) wartet auf den TestFlight-Bau.
- **Letzter Schreiber gewinnt bei `update`:** `repeat` steht nicht in der Abschrift; Schutz sind der Status und das Ja des Nutzers laut Anleitung (S2).
- **Geteilte Liste:** Zuordnungen zu Personen aus „Family“ gehen verloren (Henning wird es in S3 vor der Übertragung gesagt).
- **`capture` speichert zweimal:** wie in #932; Link und Wiederholung hängen am zweiten `commit`, ein Fehler dort ist ein Speicherfehler mit der bekannten at-least-once-Schwäche des Vertrags.
- **`repeat` als Swift-Schlüsselwort:** Eigenschaft in Backticks, JSON-Schlüssel bleibt `repeat`; der Test 1 sichert die Kodierung.

## Changelog

- 2026-11-17: Erste Fassung (Schnitt 1, App); S2 (Dienst) bekommt eine eigene Teil-Spec.
- 2026-11-17 (RED): Test 1 vergleicht über den JSON-Hin- und Rückweg (`JSONEqual`, erneutes Dekodieren gleich) statt mit einem im Test gebauten `Order`-Wert, weil `OrderRepeat` vor der Umsetzung nicht existiert und der Testkörper sonst nicht übersetzt; Test 8 setzt erst eine andere Regel (eine Revision) und dann dieselbe noch einmal (keine weitere), damit er vor der Umsetzung rot ist.
