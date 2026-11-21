---
entity_id: fix-972-fields-smoke-flaky
type: bugfix
created: 2026-11-21
updated: 2026-11-21
status: draft
workflow: fix-972-fields-smoke-flaky
---

# Spec: FieldsSmokeTests im CI beim ersten Versuch grün (#972)

## Approval

- [ ] Approved

## Purpose

Zwei Tests in `FieldsSmokeTests` scheitern im CI gelegentlich, obwohl die App richtig arbeitet: Der eine wartet nur 5 s auf eine Zeilenbeschriftung, und eine einzelne Abfrage kostete auf dem ausgelasteten Simulator 4,2 s. Der andere nimmt an, dass der Kalendertag während des Laufs gleich bleibt, und scheitert über Mitternacht UTC. Beides sind Zeitannahmen des Tests; nur Testcode ändert sich, kein App-Code, kein Pfad der Geräteliste.

Analyse mit Belegen (Aktivitätsprotokoll, Bildschirmaufnahme, Zeitstempel): `docs/context/fix-972-fields-smoke-flaky.md`, Abschnitt „Analysis“.

## Source

- **File:** `LooseEndsUITests/FieldsSmokeTests.swift`
- **Identifier:** `choose(_:in:app:)`, `testLowAndMediumShowNoSignInTheRowButTheLadderInTheDetail`, `testCalendarWaitsForADate`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| XCUITest-Abfrage-Engine (`waitForNonExistence`, `XCTNSPredicateExpectation`) | framework | Wartebedingungen im Test |
| `LooseEnds/Views/EditorPage.swift` (`LevelLadder`, id `levelOption_<raw>`) | module | Option, die getippt und danach als verschwunden erwartet wird |
| `LooseEnds/Views/TaskDetailView.swift` (`fieldRow`, id `field_<field>`) | module | Zeile, deren Beschriftung gelesen wird |
| CI-Job „UI Smoke (iOS Simulator)“ (#939, sechs Teile) | ci | Umgebung, in der die Tests wackeln |

## Scope

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsUITests/FieldsSmokeTests.swift | MODIFY | `choose`: Option per id halten, tippen, auf ihr Verschwinden warten (15 s), dann Zeilenbeschriftung mit 15 s; Kalendertest: Tag vor der Erfassung merken, „Today“ erwarten, wenn der Tag beim Lesen gewechselt hat, sonst „Tomorrow“ |

### Estimated Changes
- Files: 1 (nur Testcode)
- LoC: +15/-5, App-LoC 0

## Implementation Details

- `choose`: `option = app.buttons["levelOption_<raw>"]` (`Medium` wird `medium`, `Low` wird `low`), tippen, dann `XCTAssertTrue(option.waitForNonExistence(timeout: 15))` (der Editor ist zurückgegangen), danach das bestehende Label-Prädikat auf der Zeile mit 15 s statt 5 s. Das Warten auf das Verschwinden trennt in der Fehlermeldung „Tippen nicht angekommen“ von „Beschriftung spät“.
- Kalender: vor der Erfassung `let day = Calendar.current.startOfDay(for: Date())`; nach dem Lesen der Zeile ist das erwartete Wort „Today“, wenn `startOfDay(for: Date())` ungleich `day` ist, sonst „Tomorrow“. Test-Prozess und Simulator teilen die Rechneruhr, der Vergleich trägt.
- Die übrigen 17 `XCTNSPredicateExpectation`-Stellen in sechs anderen Klassen bleiben bewusst unverändert (kein Mitnehmen nebenbei); wackelt eine, wird sie ein eigenes Ticket.

### Alternativen (verworfen)
- Fester Testtakt per Startargument `--ui-testing-now`: macht alle Datumstests stundenunabhängig, berührt aber App-Code an mehreren Stellen (Bezugstag des Parsers, `isDateInToday` in Views, `NewDateRule`) für ein Zeitfenster von einer Sekunde pro Tag; unverhältnismäßig, eigenes Ticket, falls weitere Datumstests wackeln.
- Nur Timeout erhöhen: behebt das Symptom, aber ein verlorener Tipp erschiene als 15-s-Fehler „Beschriftung“ mit falscher Erklärung.
- Wiederholung fehlgeschlagener Tests im CI: in #172 bewusst entfernt, Ziel ist „beim ersten Versuch grün“.

## Test Plan

### Automated Tests (TDD RED)
- [ ] Test 1: GIVEN ein Simulator unter Last (Abfrage dauert über 5 s) WHEN `testLowAndMediumShowNoSignInTheRowButTheLadderInTheDetail` Medium, Low (Wichtigkeit) und Low (Dringlichkeit) wählt THEN verschwindet der Editor innerhalb von 15 s und die Zeile zeigt den gewählten Wert.
- [ ] Test 2: GIVEN eine Aufgabe „Steuerbescheid morgen prüfen“ WHEN die Erfassung vor und das Lesen der Zeile nach Mitternacht liegen THEN erwartet `testCalendarWaitsForADate` „Today“, ohne Mitternachtswechsel „Tomorrow“.
- [ ] Test 3: GIVEN die geänderten Tests WHEN `./scripts/sim.sh test-proof FieldsSmokeTests` zehnmal hintereinander läuft THEN sind alle zehn Läufe grün.

## Acceptance Criteria

- **AC-1:** `choose(_:in:app:)` tippt die Option über die id `levelOption_<raw>`, wartet mit `waitForNonExistence(timeout: 15)` auf das Schließen des Editors und prüft danach die Zeilenbeschriftung mit 15 s Budget; kein 5-s-`XCTWaiter` mehr in diesem Helfer.
- **AC-2:** `testCalendarWaitsForADate` merkt den Kalendertag vor der Erfassung und erwartet nach dem Lesen „Today“ bei Tageswechsel, sonst „Tomorrow“.
- **AC-3:** `./scripts/sim.sh test-proof FieldsSmokeTests` ist zehnmal hintereinander grün, mit registriertem Simulator-Beleg.
- **AC-4:** Der Diff berührt nur `LooseEndsUITests/FieldsSmokeTests.swift` und keine App-Datei (App-LoC 0).

## Definition of Done (außerhalb der ACs)

- [ ] Fünf grüne `main`-Läufe von „UI Smoke (iOS Simulator)“ nach dem Merge (Beobachtung im CI, kein Workflow-AC); bis dahin bleibt #972 offen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Nur Wartebedingungen und eine Tageserwartung im Testcode ändern sich; keine Struktur-, Daten- oder Schnittstellenentscheidung.

## Changelog

- 2026-11-21: Initial spec created
