---
entity_id: fix-395-kalibrierung-haengt
type: bugfix
created: 2026-10-18
updated: 2026-10-18
status: draft
workflow: fix-395-kalibrierung-haengt
---

# Spec: #395 — Lokaler Unit-Lauf hängt nicht mehr in FocusBloxCalibrationTests

## Approval

- [ ] Approved

## Purpose

Ziel (Issue #395): Ein lokaler Unit-Lauf endet immer, mit oder ohne Korpus. Definition of Done des Tickets: Modellmessungen
laufen im normalen Unit-Lauf nicht mehr; `./scripts/sim.sh sim-unit` mit Korpus endet grün; der Kalibrierungsbericht
bleibt unverändert (#147). Henning hat am 2026-10-18 Variante A freigegeben: die Suite wird entfernt. Es ändert sich kein
Produktcode und nichts Sichtbares in der App.

Ursache (belegt, Details und Belege in `docs/context/fix-395-kalibrierung-haengt.md` und
`docs/artifacts/fix-395-kalibrierung-haengt/repro/`):

- **Der Hänger vom 13.10. ist nicht reproduzierbar.** Drei Läufe am 2026-10-18 (Suite allein, voller Unit-Lauf, zwei
  Simulatoren gleichzeitig) zeigten keinen Stillstand. Wahrscheinliche Auslöser damals: mehrere Sitzungen gleichzeitig am
  Modell (vor der Sperre aus #341) oder ein Simulator-/Modellzustand; beides unbewiesen. Dass `LanguageModelSession.respond()`
  im Simulator manchmal weder zurückkehrt noch wirft, ist als Fallbericht belegt (Apple-Forum 796414).
- **Reproduziert ist ein anderer Fehler, der die DoD trifft:** Jeder lokale Unit-Lauf mit Korpus überschreibt den
  eingecheckten Gerätebericht `docs/reference/focusblox-calibration-report.md` mit Simulatorzahlen. Drei Läufe, drei
  Werte der Dauer-Trefferquote: 61 %, 64 %, 71 %. Der Gerätebericht (#23, iPhone) steht bei 51 %. `CalibrationGate` fängt
  nur Läufe mit ≥ 50 % Modellfehlern; ein funktionierendes Simulatormodell kommt durch.
- **Die Suite ist teuer:** 60 echte Modellaufrufe, 185 bis 187 s im Normalfall, 575 s bei Last. Jeder Modellfehler wird
  gezählt, ein Hänger nicht.

Kernargument (trägt ohne den Hänger): Die Suite kann nur im Simulator oder auf dem Mac laufen, denn Xcode-Testläufe auf
Hennings Geräten sind verboten und Modellmessungen am Gerät gehören in die Labor-App. Sie misst dort ein anderes Modell als
das, dessen Bericht sie überschreibt. Sie kann auf dieser Plattform nichts Gültiges messen. Das Ergebnis der Kalibrierung
steht in `docs/project/06-annahmen-und-experimente.md`.

## Source

- **File:** `LooseEndsTests/FocusBloxCalibrationTests.swift`
- **Identifier:** `FocusBloxCalibrationTests` (Gatter `@Suite(.enabled(if: MeasurementData.exists(focusBloxCorpusURL), …))`, Aufruf `FoundationModelsEnricher().enrich` in der Schleife über 60 Stichproben, Zeile 71 ff.), `CalibrationGate`, `CalibrationGateTests`
- **Weitere:** `scripts/measurement_status.py` (`GATES`), `scripts/test_measurement_status.py`, `LooseEndsTests/MeasurementFieldScopeTests.swift`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LooseEndsTests/MeasurementData.swift` | code | Findet den Korpus im Worktree und im Hauptordner; bleibt unverändert, die übrigen Berichts-Suiten nutzen es weiter |
| `scripts/measurement_status.py` | script | Statuszeile nach jedem `sim.sh unit` und in der CI-Zusammenfassung; `ci.yml:66` ruft es ohne feste Zahl |
| `LooseEndsTests/SelfConsistencyReportTests.swift`, `Measurement/SelfConsistency.swift` | code | Nennen die Suite nur in einem Kommentar |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | code | Das gerufene Modell; Geräteliste, wird nicht angefasst |
| `docs/reference/focusblox-calibration-report.md` | doc | Eingecheckter Gerätebericht aus #23; bleibt byte-gleich |
| #147, #133 | spec | „Nur echte Messungen schreiben“; wird mit der Entfernung vollständig eingelöst |
| #341 | spec | Unit-Lauf im Simulator, Sperre; nennt #395 als nicht enthalten |

Geprüft per grep: Außer `FocusBloxCalibrationTests.swift` instanziiert keine Datei in `LooseEndsTests/`, `Measurement/` oder
`scripts/` den `FoundationModelsEnricher`; die übrigen Berichts-Suiten rufen kein Modell.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsTests/FocusBloxCalibrationTests.swift` | DELETE | Suite, `CalibrationGate` und `CalibrationGateTests` (nur hier benutzt) |
| `LooseEndsTests/MeasurementFieldScopeTests.swift` | MODIFY | Test `focusBloxCalibrationDropsImportanceUrgency` (Zeilen 18–23), der den Quelltext der gelöschten Datei liest, entfällt; `selfConsistencyReportDropsImportanceUrgency` bleibt |
| `scripts/measurement_status.py` | MODIFY | `"FocusBloxCalibrationTests"` aus `GATES` (Zeile 22) |
| `scripts/test_measurement_status.py` | MODIFY | 5 wird 4 (Zeilen 36, 49, 53); Zeile 54 prüft eine andere Suite; neuer Test „keine Unit-Suite ruft das Modell“ |
| `LooseEndsTests/SelfConsistencyReportTests.swift` | MODIFY | Nur Kommentar (Zeile 9) |
| `Measurement/SelfConsistency.swift` | MODIFY | Nur Kommentar (Zeile 65) |
| `docs/project/02-datenmodell-und-ansichten.md` | MODIFY | Zeile 342: „Suite entfernt (#395), Bericht ist der Gerätestand aus #23“ |
| `docs/reference/funktionsuebersicht.md` | MODIFY | Zeile 19: Verweis auf die Suite ersetzt durch „Suite entfernt (#395)“ |

`docs/reference/focusblox-calibration-report.md` bleibt unverändert.

### Estimated Changes

- Files: 8 (1 DELETE, 7 MODIFY; vier Codedateien, zwei Kommentarzeilen, zwei Doku-Zeilen)
- LoC: ca. +10/−165
- Überschreitung der Dateigrenze (4–5) ist von Henning am 2026-10-18 freigegeben, weil der Schnitt fast nur aus Löschung besteht.
- Keine neuen Abhängigkeiten, Berechtigungen, AppStorage-Schlüssel oder Audiodateien.

## Definition of Done

- [ ] Suite entfernt, keine Verweise mehr (AC-1)
- [ ] Skripttests grün, 4 Messstrecken (AC-2, AC-3, AC-4)
- [ ] Voller Unit-Lauf mit Korpus grün, Bericht unverändert (AC-5, AC-6)
- [ ] Übrige Tests in `MeasurementFieldScopeTests` grün (AC-7)
- [ ] Doku nennt die Entfernung (AC-8)
- [ ] Kein Produktcode, keine Geräteliste (AC-9)

## Implementation Details

### Variante A — Suite entfernen (gewählt)

1. `LooseEndsTests/FocusBloxCalibrationTests.swift` löschen. Darin liegt auch `CalibrationGateTests` (ohne Korpus, läuft in
   der CI). Sie entfallen mit, weil `CalibrationGate` nur in dieser Datei benutzt wird und mit der Suite keinen Zweck mehr hat.
2. `MeasurementFieldScopeTests.swift`: den Test in den Zeilen 18–23 entfernen; der Kopfkommentar der Struct wird auf die
   verbleibende Datei angepasst, falls er die gelöschte nennt.
3. `scripts/measurement_status.py`: Eintrag aus `GATES` entfernen. Danach gibt es vier Messstrecken
   (`ContextWordLearningReportTests`, `RecognitionRuleCorpusTests`, `RuleLeaveOneOutReportTests`, `SelfConsistencyReportTests`).
4. `scripts/test_measurement_status.py`: Zahlen 5 auf 4; die Markdown-Zeilen-Prüfung (Zeile 54) wechselt auf eine
   verbliebene Suite; neuer Test `test_no_unit_suite_calls_the_model`: durchsucht `LooseEndsTests/*.swift` nach
   `FoundationModelsEnricher(` und erwartet keinen Treffer. Er schützt davor, dass eine Modellmessung unbemerkt
   in den Unit-Lauf zurückkehrt.
5. Kommentarzeilen in `SelfConsistencyReportTests.swift:9` und `Measurement/SelfConsistency.swift:65` nennen die gelöschte
   Suite nicht mehr (z. B. „die entfernte Kalibrierungssuite, #395“ oder Satz ohne Namen).
6. Doku-Zeilen in `02-datenmodell-und-ansichten.md:342` und `funktionsuebersicht.md:19`: „Suite entfernt (#395), Bericht ist
   der Gerätestand aus #23“.

### Alternativen (Henning will sie sehen)

- **B — Einschalter `TEST_RUNNER_LOOSEENDS_MODEL_MEASURE=1`, Status „ausgeschaltet“ in `measurement_status.py`** (+~60 LoC,
  4 Dateien). Abgelehnt: Im Normallauf wäre der Hänger weg, aber wer den Schalter setzt, überschreibt den Gerätebericht weiter
  mit Simulatorzahlen; das Instrument braucht einen eigenen Schutz und bleibt ein Werkzeug, das falsche Zahlen schreiben
  kann. Kippt keine ADR, löst aber #147 nur halb.
- **C — `.timeLimit(.minutes(10))` an der Suite** (+1 Zeile). Abgelehnt: Swift Testing bricht per Task-Gruppe kooperativ ab
  und wartet auf alle Kinder; ein Modellaufruf, der nie zurückkehrt (0 % CPU), hält den Prozess weiter. Das Limit gilt nur
  minutenweise (Mindestwert 1 Minute). Der Bericht würde weiter überschrieben. Löst die DoD nicht.
- **D — Kalibrierung in die Labor-App verlegen** (großer Umbau). Abgelehnt für diesen Schnitt: Nur sinnvoll, wenn wieder
  kalibriert werden soll; dann als eigenes Ticket. Die Labor-App misst heute Selbstkonsistenz, nicht Kalibrierung.

Gekippt wird keine ADR. Der Preis von A: Eine Wiederholung der Kalibrierung ist nur über die Git-Historie oder eine neue
Labor-App-Messung möglich.

## Test Plan

### Automated Tests (TDD RED)

Rot vor der Umsetzung:

- [ ] `scripts/test_measurement_status.py` erwartet 4 Messstrecken („4 von 4 übersprungen“, „alle 4 liefen mit Daten“,
  „**4 von 4 Messstrecken übersprungen**“) — rot, solange `GATES` fünf Einträge hat.
- [ ] `test_no_unit_suite_calls_the_model` (neu in `scripts/test_measurement_status.py`) — rot, solange
  `FocusBloxCalibrationTests.swift` den `FoundationModelsEnricher()` instanziiert (einziger Treffer, Zeile 71).
- [ ] `test_every_gate_is_listed_and_nothing_else` (bestehende Klasse `RegistryMatchesSwiftTests`) — bleibt grün; sie belegt, dass `GATES` und
  die Swift-Gatter nach der Löschung übereinstimmen.

Grün nach der Umsetzung, ohne Änderung: alle übrigen Tests von `LooseEndsTests`, darunter `MeasurementFieldScopeTests`
(`selfConsistencyReportDropsImportanceUrgency` und weitere).

Befehle:

```
python3 scripts/test_measurement_status.py
python3 -m unittest discover -s scripts -p 'test_*.py'
```

## Acceptance Criteria

- **AC-1:** Given der Stand nach der Umsetzung, When `test ! -e LooseEndsTests/FocusBloxCalibrationTests.swift` und `grep -rn "FocusBloxCalibrationTests\|CalibrationGate" LooseEndsTests Measurement scripts` laufen, Then existiert die Datei nicht mehr und der grep ist leer (Treffer nur in Doku-Zeilen, die die Entfernung nennen, nicht in diesen drei Ordnern).
- **AC-2:** Given der Stand nach der Umsetzung, When `python3 scripts/test_measurement_status.py` läuft, Then ist es grün und die Messstrecken-Liste in `GATES` hat genau vier Einträge ohne `FocusBloxCalibrationTests`.
- **AC-3:** Given der Stand nach der Umsetzung, When `grep -rln "FoundationModelsEnricher(" LooseEndsTests Measurement` läuft, Then ist die Ausgabe leer; der Skripttest `test_no_unit_suite_calls_the_model` prüft dasselbe und ist grün.
- **AC-4:** Given ein voller Lauf `./scripts/sim.sh sim-unit` mit Korpus (`focusblox-corpus.json` liegt im Hauptordner `/Users/hem/Developer/loose-ends/docs/reference/`, `MeasurementData` findet ihn), When der Lauf endet, Then ist das Ergebnis grün, und die Statuszeile von `measurement_status.py` am Ende nennt vier Messstrecken und keine Kalibrierung.
- **AC-5:** Given derselbe Lauf, When danach `git diff --exit-code docs/reference/focusblox-calibration-report.md` läuft, Then ist der Exit-Code 0 (Bericht byte-gleich, #147 eingelöst).
- **AC-6:** Given derselbe Lauf, When die Laufzeit mit den 187 s bis 218 s der Nachstellung verglichen wird, Then enthält das Protokoll keinen Test aus der gelöschten Suite und keinen Modellaufruf (`grep -c "FocusBloxCalibration" <Protokoll>` ergibt 0).
- **AC-7:** Given der Stand nach der Umsetzung, When `./scripts/sim.sh sim-unit MeasurementFieldScopeTests` läuft, Then sind die verbliebenen Tests dieser Suite grün und der Test `focusBloxCalibrationDropsImportanceUrgency` existiert nicht mehr.
- **AC-8:** Given der Stand nach der Umsetzung, When `grep -n "Suite entfernt (#395)" docs/project/02-datenmodell-und-ansichten.md docs/reference/funktionsuebersicht.md` läuft, Then liefert er je Datei einen Treffer, und keine der beiden Dateien verweist mehr auf `FocusBloxCalibrationTests.swift` als vorhandene Datei.
- **AC-9:** Given `git diff --name-only main...HEAD`, When die Liste mit der Geräteliste aus `CLAUDE.md` verglichen wird, Then enthält sie nur die acht Dateien aus „Affected Files“ (Löschung eingeschlossen), keinen Pfad der Geräteliste, keine `Info.plist`, kein `project.yml`, keinen Produktcode unter `Shared/` oder `LooseEnds/`.

## Abnahme

- **Stufe 1 — Tests:** Skripttests (`python3 -m unittest discover -s scripts -p 'test_*.py'`) und voller Unit-Lauf
  `./scripts/sim.sh sim-unit` mit Korpus, jeweils mit Protokoll unter `docs/artifacts/fix-395-kalibrierung-haengt/`.
- **Stufe 2 — Simulator-Ablauf:** entfällt sinnvoll, weil die App unverändert bleibt und keine Oberfläche betroffen ist.
  Stattdessen gilt der volle `sim-unit`-Lauf als Beleg (AC-4 bis AC-6).
- **Stufe 3:** Kein Pfad der Geräteliste berührt.

## Side-Effects

- Keine `Info.plist`-Änderung, keine neuen Berechtigungen, keine AppStorage-Schlüssel, keine Audiodateien.
- Kein Produktcode; geändert werden nur `LooseEndsTests/`, `Measurement/` (ein Kommentar), `scripts/` und zwei Doku-Zeilen.
- Der Unit-Lauf wird auf Rechnern mit Korpus um etwa drei Minuten kürzer.

## Nicht im Schnitt

- Randbefund #543: `RuleLeaveOneOutReportTests` schreibt bei jedem Lauf das Messdatum neu in
  `docs/reference/retrieval-leave-one-out-rules.md` (nur die Datumszeile).
- Restdateien aus #341 (`docs/artifacts/fix-341-testlaeufe-verlaesslich/`, nicht versioniert) gehören nicht in diesen Schnitt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Testwerkzeug, keine Architekturentscheidung; keine bestehende ADR wird gekippt, und #147 („nur echte Messungen schreiben“) wird eingelöst.

## Changelog

- 2026-10-18: Spec erstellt (Variante A, Alternativen B bis D, von Henning freigegeben).
