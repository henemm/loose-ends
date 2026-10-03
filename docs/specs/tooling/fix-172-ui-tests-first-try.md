---
entity_id: fix-172-ui-tests-first-try
type: bugfix
created: 2026-10-02
updated: 2026-10-02
status: draft
workflow: fix-172-ui-tests-first-try
---

# Spec: #172 — UI-Tests laufen in der CI beim ersten Versuch grün, Wiederholung entfällt

## Approval

- [ ] Approved

## Purpose

Der CI-Schritt „Run UI smoke tests" wiederholt fehlgeschlagene Tests automatisch
(`-retry-tests-on-failure`). Dadurch bleibt ein wackelnder Test unsichtbar, solange der zweite
Versuch besteht. #172 verlangt, dass die UI-Tests beim ersten Versuch grün sind und die
Wiederholung entfällt. Diese Spec beseitigt die zwei belegten Wackelstellen im Testcode und
entfernt danach die Wiederholung. Es ändert sich kein Produktcode und nichts Sichtbares in der App.

## Source

- **File:** `LooseEndsUITests/CaptureSmokeTests.swift`
- **Identifier:** `waitForValue(_:of:timeout:)` (Zeile 117–123), `testCalendarSwitchStaysOn` (Zeile 514–558)
- **File:** `LooseEndsUITests/RecognitionWalkthroughTests.swift`
- **Identifier:** `row(containing:in:)` (Zeile 54–59), einziger Aufruf Zeile 131; Muster `topRow(in:)` (Zeile 61–69)
- **File:** `.github/workflows/ci.yml`
- **Identifier:** Schritt „Run UI smoke tests", Zeile 130 `-retry-tests-on-failure \`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LooseEnds/Views/TaskDetailView.swift` (Kennungen `showInCalendarToggle`, `detailRawText`) | module | Unverändert; die Tests lesen diese Elemente |
| `ViewRules`-Sortierung (jüngste Aufgabe oben) | module | `topRow` setzt voraus, dass die jüngste Erfassung oben steht |
| CI-Job „UI smoke tests" (`ci.yml`) | tooling | Prüfstand für die drei Läufe ohne Fehlversuch |
| `./scripts/sim.sh test-proof <Klasse>` (#145) | tooling | Lokaler Nachweis je Testklasse mit maschinellem Simulator-Beleg |
| #165 (Erfassungs-UI-Tests) | spec | Muster: Zeile über `taskRow_*` finden, Inhalt über `detailRawText` bestätigen |

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/CaptureSmokeTests.swift` | MODIFY | `waitForValue` mit Frist nach Zeit und genau einem letzten Lesen nach Fristende; Anfangswert „0" direkt lesen; Ersatz-Tippen nur, wenn der Wert nach dem letzten Lesen noch „0" ist |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | MODIFY | Erste Aufgabe über `topRow` + `detailRawText` finden; `row(containing:in:)` entfällt |
| `.github/workflows/ci.yml` | MODIFY | Zeile `-retry-tests-on-failure \` entfernen |

### Estimated Changes

- Files: 3
- LoC: +30/-15
- Kein Produktcode. Keine neuen Abhängigkeiten, keine neuen Berechtigungen, keine AppStorage-Schlüssel, keine Audiodateien.

## Definition of Done

- [ ] Fehler „Value was Optional(0)" vor dem Fix lokal ausgelöst, Ursache mit Beleg benannt (AC-1)
- [ ] Derselbe Ablauf mit dem Fix grün (AC-2)
- [ ] `./scripts/sim.sh test-proof` für `CaptureSmokeTests` und `RecognitionWalkthroughTests` grün, lokal mit Modell (AC-5)
- [ ] `RecognitionWalkthroughTests` sucht keine Aufgabe mehr über den Titel, fachliche Zusicherung unverändert (AC-4)
- [ ] `-retry-tests-on-failure` ist aus `ci.yml` entfernt (AC-6)
- [ ] Drei CI-Läufe hintereinander ohne `##[error]`-Zeile, am Protokoll geprüft (AC-7)
- [ ] Kein Produktcode geändert (AC-8)

## Implementation Details

### Root Cause Teil 1 — Kalenderschalter (`testCalendarSwitchStaysOn`)

`waitForValue` benutzt `XCTNSPredicateExpectation` auf einem Element, das bei jeder Auswertung neu
aufgelöst wird. Beleg aus dem CI-Artefakt `ui-smoke.log` von Lauf 36984712575 (Iteration 1 von 3):
Ab 57,43 s läuft „Checking Expect predicate value == \"0\"", darauf „Find the showInCalendarToggle
Switch" bis 61,68 s — ein einziges Auflösen dauert 4,25 s. Die 5-s-Frist ist nach einer Auswertung
verbraucht, der Wartevorgang endet mit Zeitüberschreitung, ohne ein zweites Mal gelesen zu haben.
Der Direktzugriff in der Fehlermeldung liest danach „0", also genau den Wert, auf den gewartet
wurde. Das löst den scheinbaren Widerspruch. Der Schalter selbst ist in Ordnung; Iteration 2
desselben Laufs besteht, ebenfalls mit sehr langsamen Schritten. Es ist ein Zeitproblem des Runners.

Gefährlicher Zweitfall, Zeile 543–547: Läuft `waitForValue("1", timeout: 2)` am Runner in dieselbe
Zeitüberschreitung, obwohl das Tippen schon gewirkt hat, tippt der Ersatzweg per Koordinate ein
zweites Mal und schaltet den Schalter wieder aus.

### Fix Teil 1

1. `waitForValue`: Die Frist läuft nach Uhrzeit, nicht nach Anzahl der Auswertungen. Nach Fristende
   wird genau ein letztes Mal gelesen; dessen Ergebnis entscheidet. Eine einzelne langsame
   Auflösung kann damit die Prüfung nicht mehr verbrauchen, ohne gelesen zu haben.
2. Anfangswert „0": `showInCalendar` ist nicht modellabgeleitet, der Anfangswert ist immer „0".
   Eine Direktlesung ersetzt das Warten (Zeile 541).
3. Ersatz-Tippen (Zeile 543–546): nur, wenn der Wert nach dem letzten Lesen noch „0" ist. Steht
   dort „1", wird nicht erneut getippt.

### Fix Teil 2 — `RecognitionWalkthroughTests`

Die erste Aufgabe wird nicht mehr über `row(containing:)` (Titelsuche, `label CONTAINS`) gefunden,
sondern über `topRow(in:)`. Nach dem Öffnen bestätigt `detailRawText` den unveränderlichen Rohtext
„Rasen mähen". Die fachliche Zusicherung bleibt gleich, nur der Suchweg ist titelunabhängig, wie
er für die zweite Aufgabe schon gilt. Die Funktion `row(containing:in:)` hat danach keinen Aufrufer
mehr und wird gelöscht.

### Fix Teil 3 — CI

`-retry-tests-on-failure \` aus `ci.yml` (Zeile 130) entfernen. Das ist die einzige Fundstelle.
Dieser Schritt kommt zuletzt, nachdem Teil 1 und 2 lokal belegt sind.

### Vorgehen: Reproduktion zuerst (Hennings Regel)

1. Fehler vor dem Fix erzwingen: CPU-Last (mehrere Dauerläufer-Prozesse) während
   `./scripts/sim.sh test-proof CaptureSmokeTests/testCalendarSwitchStaysOn`, bis derselbe Fehler
   „Value was Optional(0)" erscheint. Gelingt das nicht: Wegwerf-Kopie mit künstlicher Verzögerung
   im Test (Auflösezeit über 5 s), Fehler dort auslösen.
2. Fix umsetzen, denselben Ablauf unter derselben Last wiederholen, grün zeigen.
3. Teil 2 und 3 danach, gesamte Klassen laufen lassen, dann drei CI-Läufe.

### Alternativen

- **Frist einfach auf 30 s:** Verdeckt die Langsamkeit, ändert aber nichts daran, dass eine
  Auswertung die ganze Frist verbrauchen kann. Verworfen.
- **Wiederholung behalten, aber sichtbar machen** (ein Schritt, der den Job warnt oder rot färbt,
  wenn ein Test erst im zweiten Versuch grün wurde): erhält den Schutz gegen Ausfälle, deren
  Ursache nicht in unserer Hand liegt (Accessibility-Dienst des Runners). Das kippt die Vorgabe des
  Issues „Wiederholung entfernen". Rückfall, falls die drei CI-Läufe rot werden.
- **Anfangswert-Wait streichen:** Teil der Empfehlung (Fix Teil 1, Punkt 2), weil der Wert immer „0" ist.

### Nicht belegt und offen

- Die Läufe 36828990111 (`Failed to get list of active applications`, passt zum Forenmuster
  „Accessibility-Dienst auf dem Runner nicht erreichbar") und 36826401134 sind nicht mehr
  auswertbar (Artefakte und Protokolle abgelaufen). Ob sie dieselbe Ursache haben wie Lauf
  36984712575, ist **unbelegt**. Dieser Fix beseitigt nachweislich nur die Zeitüberschreitung beim
  Auflösen.
- **Risiko:** Ohne Wiederholung kann ein CI-Lauf rot werden, falls es einen dritten Fehlerfall gibt
  (etwa den Accessibility-Ausfall). Das wäre dann ein neuer Befund mit eigener Analyse; der Rückfall
  ist die Alternative „Wiederholung sichtbar machen".

### Recherche (Quellen)

- Apple-Forum „XCUITest fails because of accessibility not loading": https://developer.apple.com/forums/thread/750438
- Apple-Forum „Why is Toggle's value not changed in Xcode cloud?": https://developer.apple.com/forums/thread/768716
- Apple-Forum „Error accessing UIDevice.shared.orientation" (`Failed to get list of active applications`): https://developer.apple.com/forums/thread/711588

## Test Plan

Kein Produktcode, daher keine neuen Unit-Tests. Die Änderung ist der Testcode selbst; nachgewiesen
wird mit Reproduktion vor und Läufen nach dem Fix.

### Automated Tests (TDD RED)

- [ ] Test 1 (RED, Reproduktion): GIVEN der unveränderte `waitForValue` und künstliche CPU-Last auf dem Simulator WHEN `./scripts/sim.sh test-proof CaptureSmokeTests/testCalendarSwitchStaysOn` läuft THEN scheitert der Test mit „Value was Optional(0)".
- [ ] Test 2 (GREEN): GIVEN der korrigierte `waitForValue` und dieselbe Last WHEN derselbe Test läuft THEN besteht er beim ersten Versuch.
- [ ] Test 3: GIVEN die Fristlogik mit letztem Lesen WHEN der Schalter nach Fristende bereits „1" zeigt (ausgelöst in der Wegwerf-Kopie aus „Vorgehen": das erste Lesen wird künstlich über die Frist hinaus verzögert, das letzte Lesen sieht „1") THEN tippt der Ersatzweg nicht erneut und der Schalter bleibt an.
- [ ] Test 4: GIVEN `RecognitionWalkthroughTests` mit `topRow` + `detailRawText` WHEN `./scripts/sim.sh test-proof RecognitionWalkthroughTests` läuft THEN bestätigt `detailRawText` „Rasen mähen" und die Zusicherung zu Dauer und Kontext der zweiten Aufgabe besteht unverändert.
- [ ] Test 5: GIVEN `ci.yml` ohne `-retry-tests-on-failure` WHEN der Schritt „Run UI smoke tests" dreimal hintereinander läuft THEN steht in keinem Protokoll eine `##[error]`-Zeile.

## Acceptance Criteria

- [ ] AC-1 Reproduktion: Der Fehler „Value was Optional(0)" ist vor dem Fix lokal unter CPU-Last (oder in einer Wegwerf-Kopie mit künstlicher Verzögerung) ausgelöst und die Ausgabe im Bericht zitiert.
- [ ] AC-2 Fix belegt: Derselbe Ablauf unter derselben Last ist mit dem Fix grün, die Ausgabe im Bericht zitiert.
- [ ] AC-3 `waitForValue` liest nach Fristende genau einmal und entscheidet danach; der Anfangswert „0" wird direkt gelesen; das Ersatz-Tippen läuft nur bei Wert „0" nach dem letzten Lesen.
- [ ] AC-4 `RecognitionWalkthroughTests` findet die erste Aufgabe über `topRow` und bestätigt sie über `detailRawText`; `row(containing:in:)` ist gelöscht.
- [ ] AC-5 `./scripts/sim.sh test-proof CaptureSmokeTests` und `./scripts/sim.sh test-proof RecognitionWalkthroughTests` sind lokal mit Modell grün (maschineller Beleg, Screenshots geöffnet und beschrieben).
- [ ] AC-6 `-retry-tests-on-failure` steht nicht mehr in `.github/workflows/ci.yml`.
- [ ] AC-7 Drei CI-Läufe hintereinander sind grün, und das Protokoll jedes Laufs enthält keine `##[error]`-Zeile (geprüft am Protokoll, nicht am Endstatus).
- [ ] AC-8 Kein Produktcode geändert: Das Diff berührt genau die drei Dateien aus dem Scope.
- [ ] AC-9 Geräteliste: Kein Pfad der Geräteliste berührt. Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau.
- [ ] AC-10 Ausliefern: Nach dem Merge ist `bash ~/.claude/scripts/loose-ends-sync-main.sh` gelaufen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — reine Korrektur von Testcode und CI-Konfiguration ohne Architekturwirkung; es wird keine bestehende Entscheidung gekippt oder neu getroffen.
- **Rationale:** Die Alternative „Wiederholung sichtbar machen" ist als Rückfall festgehalten. Wird sie nötig, ist das eine neue Entscheidung mit eigener Analyse.

## Changelog

- 2026-10-02: Initial spec created (Analyse in `docs/context/fix-172-ui-tests-first-try.md`).
