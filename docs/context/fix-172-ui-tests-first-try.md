# Context: fix-172-ui-tests-first-try

## Request Summary
#172: UI-Tests in der CI beim ersten Versuch grün; `-retry-tests-on-failure` aus `ci.yml` entfernen.
Drei Teile: (1) `testCalendarSwitchStaysOn` wackelt, (2) `RecognitionWalkthroughTests` sucht über den
Titel, (3) Wiederholung entfernen. DoD siehe Issue (u. a. drei CI-Läufe ohne `##[error]`-Zeile).

## Related Files
| File | Relevance |
|------|-----------|
| `.github/workflows/ci.yml:130` | `-retry-tests-on-failure \` im Schritt „Run UI smoke tests“, einzige Fundstelle |
| `LooseEndsUITests/CaptureSmokeTests.swift:515-558` | `testCalendarSwitchStaysOn`; Zeile 541 ist die scheiternde Zusicherung |
| `LooseEndsUITests/CaptureSmokeTests.swift:119` | `waitForValue(_:of:timeout:)`, `XCTNSPredicateExpectation` auf `value == %@`, Standard 5 s |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift:55,131` | `row(containing:)` (Titel-Suche, `label CONTAINS`) und sein einziger Aufruf |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift:67` | `topRow(in:)`: bestehendes Muster ohne Titel (`taskRow_*` BEGINSWITH, oberste Zeile) |
| `LooseEnds/Views/TaskDetailView.swift:60-62` | `Toggle("Show in calendar", isOn: $task.showInCalendar)` mit Kennung `showInCalendarToggle`; Produktcode, soll unverändert bleiben |

## Existing Patterns
- #165 in `CaptureSmokeTests`: Zeile über `taskRow_*` finden, Inhalt über den unveränderlichen Rohtext
  (`detailRawText`) bestätigen, nie über den Titel. `RecognitionWalkthroughTests` hat das für die zweite
  Aufgabe schon (`topRow` + `detailRawText`), für die erste noch nicht.
- Warten über `XCTNSPredicateExpectation` + `XCTWaiter` (nicht `sleep`).

## Befunde (Recherche zuerst, danach Protokoll)
Recherche (Quellen):
- Apple-Forum „XCUITest fails because of accessibility not loading“: https://developer.apple.com/forums/thread/750438
  (zufällige Fehlschläge „accessibility not loaded“ auf Simulator und Gerät, 60-s-Wartezeit).
- Apple-Forum „Why is Toggle's value not changed in Xcode cloud?“: https://developer.apple.com/forums/thread/768716
  (Toggle-Wert bleibt in der Cloud „0“, SwiftUI wertet Ansicht nicht sofort neu aus).
- Apple-Forum „Error accessing UIDevice.shared.orientation“: https://developer.apple.com/forums/thread/711588
  (Fehlertext `Failed to get list of active applications: … kAXErrorServerNotFound`).

Beleg aus dem CI-Artefakt `UITestResults` von Lauf 36984712575 (`ui-smoke.log`, Iteration 1 von 3):
- 37,39 s → 52,54 s: „Wait for … to idle“ nach dem Tippen auf die Zeile dauert 15 s.
- 57,43 s: `Checking Expect predicate value == "0"` beginnt. Darauf folgt „Find the showInCalendarToggle Switch“,
  das bis 61,68 s dauert (4,25 s für ein einziges Auflösen des Elements). Die 5-s-Frist ist damit nach einer
  einzigen Auswertung verbraucht. Das erklärt den scheinbaren Widerspruch („wartet 5 s vergeblich, danach ist der
  Wert 0“): der Prädikat-Wartevorgang kommt nicht zum zweiten Auswerten, der spätere Direktzugriff liest `0`.
- Iteration 2 desselben Laufs besteht, ebenfalls mit sehr langsamen Schritten (Gesamt 85 s bis zur Notiz).
  Es ist also ein Zeitproblem des Runners, kein Fehler im Schalter.
- Die Läufe 36828990111 und 36826401134 sind nicht mehr auswertbar (Artefakte und Protokolle abgelaufen).
  Der Eintrag „Failed to get list of active applications“ passt zum Forenmuster (Accessibility-Dienst auf dem
  Runner nicht erreichbar) und ist von der Zeitüberschreitung getrennt zu behandeln.

Offen für `/20-analyse`: Zeitüberschreitung beheben (Frist am Slow-Runner ausrichten oder Auswertungsweg ändern),
und den Fall ohne Zeitbezug (Accessibility-Ausfall) bewerten. Reproduktion lokal erzwingen (z. B. Last auf dem
Simulator), denn die CI-Artefakte allein zeigen den Fehler, aber nicht den Schalter „Fehler an/aus“.

## Dependencies
- Upstream: `TaskDetailView` (Kennungen `showInCalendarToggle`, `detailRawText`), `ViewRules`-Sortierung (jüngste Aufgabe oben).
- Downstream: CI-Job „UI smoke tests“ (ci.yml), `./scripts/sim.sh test-proof` (lokaler Nachweis).

## Existing Specs
Keine passende unter `docs/specs/`. Verwandt: #165 (Erfassungs-UI-Tests), #145 (`test-proof`).

## Risks & Considerations
- Eine längere Frist verdeckt Langsamkeit nur, statt sie zu erklären. Alternative: das Element nur einmal
  auflösen und nicht wiederholt (gesamte Laufzeit pro Schritt messen).
- Die DoD verlangt drei CI-Läufe ohne Fehlversuch im Protokoll; ohne Wiederholung kann ein Lauf rot werden, bis die Ursache sicher beseitigt ist.
- Scoping: voraussichtlich 3 Dateien, <100 LoC; Produktcode bleibt unverändert.

## Analysis

### Type
Bugfix (Testcode und CI-Konfiguration; kein Produktcode)

### Root Cause (Teil 1, Kalenderschalter)
`waitForValue` benutzt `XCTNSPredicateExpectation` auf einem Element, das bei **jeder** Auswertung neu aufgelöst
wird. Auf dem langsamen CI-Runner dauert ein einziges Auflösen 4,25 s (Beleg Lauf 36984712575: 57,43 s → 61,68 s).
Die 5-s-Frist ist damit nach **einer** Auswertung verbraucht, der Wartevorgang endet mit Zeitüberschreitung, ohne
je ein zweites Mal gelesen zu haben. Der Direktzugriff in der Fehlermeldung liest danach `0` — den Wert, auf den
gewartet wurde. Das löst den scheinbaren Widerspruch. Der Schalter selbst ist in Ordnung.

Gleiche Schwachstelle, gefährlicher: Zeile 543–547. Läuft `waitForValue("1", timeout: 2)` am Runner in dieselbe
Zeitüberschreitung, obwohl das Tippen schon gewirkt hat, tippt der Ersatzweg per Koordinate ein zweites Mal und
schaltet wieder aus.

Nicht auswertbar: Lauf 36828990111 (`Failed to get list of active applications` = Accessibility-Dienst auf dem Runner,
Forenmuster, kein Testfehler) und 36826401134 (Artefakte abgelaufen). Ob diese beiden dieselbe Ursache haben, ist
nicht belegt.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/CaptureSmokeTests.swift` | MODIFY | `waitForValue`: Frist nach Zeit, nach Fristende genau ein letztes Lesen; Voraussetzung „0“ direkt lesen; Ersatz-Tippen nur, wenn der Wert nach dem letzten Lesen noch `0` ist |
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | MODIFY | Erste Aufgabe über `topRow` + `detailRawText` finden; `row(containing:)` entfällt |
| `.github/workflows/ci.yml` | MODIFY | Zeile `-retry-tests-on-failure \` entfernen |

### Scope Assessment
- Files: 3
- Estimated LoC: +30/-15
- Risk Level: LOW (Testcode; ein roter CI-Lauf ist der Preis, falls ein dritter Fehlerfall existiert)

### Technical Approach (Regelweg, kein Modell)
1. **Reproduzieren vor Fix:** Auflösezeit künstlich verlängern (CPU-Last durch mehrere Dauerläufer-Prozesse während
   `sim.sh test-proof CaptureSmokeTests/testCalendarSwitchStaysOn`), bis derselbe Fehler „Value was Optional(0)“
   erscheint. Das ist der Schalter an/aus; ohne ihn kein Fix.
2. Fix mit demselben Ablauf unter derselben Last grün zeigen.
3. Teil 2: Titelsuche durch `topRow` ersetzen; zusätzlich Rohtext der ersten Aufgabe nach dem Öffnen bestätigen
   (`detailRawText`), damit die fachliche Zusicherung gleich bleibt.
4. Wiederholung entfernen, drei CI-Läufe im Protokoll auf `##[error]` prüfen.

### Alternativen
- **Frist einfach auf 30 s:** verdeckt die Langsamkeit, ändert aber nichts an „eine Auswertung verbraucht alles“. Verworfen.
- **Wiederholung behalten, aber sichtbar machen** (Schritt, der den Job warnt oder rot färbt, wenn ein Test erst im
  zweiten Versuch grün wurde): erhält Schutz gegen den Accessibility-Ausfall (Fälle 2/3), dessen Ursache nicht in
  unserer Hand liegt. Kippt die Vorgabe des Issues („Wiederholung entfernen“). Wird relevant, falls die drei
  CI-Läufe doch rot werden.
- **Anfangswert-Wait ganz streichen:** `showInCalendar` ist nicht modellabgeleitet, der Anfangswert immer `0`; eine
  Direktlesung genügt. Teil der Empfehlung.

### Dependencies
`TaskDetailView` (Kennungen unverändert), `ViewRules`-Sortierung (jüngste oben), CI-Job „UI smoke tests“,
`sim.sh test-proof`.

### Open Questions
- [ ] Für Henning keine (alles technisch). Offen für die Umsetzung: lässt sich der Fehler lokal mit CPU-Last
  erzwingen? Wenn nein: Wegwerf-Kopie mit künstlicher Verzögerung im Test als Reproduktionsnachweis.
- Keine sichtbare UI-Änderung, daher keine Entwurfsvorschau nötig.
