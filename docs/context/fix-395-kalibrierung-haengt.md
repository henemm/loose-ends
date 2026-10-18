# Context: fix-395-kalibrierung-haengt

## Request Summary
Ein lokaler Unit-Lauf (`./scripts/sim.sh unit`, seit #341 immer im Simulator) muss immer enden, auch wenn der
FocusBlox-Korpus auf der Platte liegt. Heute bleibt er in `FocusBloxCalibrationTests` stehen (#395, Befund bei #355:
zweimal über 30 Min Stillstand bei 0 % CPU), weil die Suite das echte On-Device-Modell 60-mal ruft.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsTests/FocusBloxCalibrationTests.swift` | Die hängende Suite. Gatter `@Suite(.enabled(if: MeasurementData.exists(focusBloxCorpusURL), …))` (Zeile 28); ruft `FoundationModelsEnricher().enrich` in einer Schleife über 60 Stichproben (Zeile ~103), jeder Fehler wird gezählt, ein Hänger nicht. Schreibt `docs/reference/focusblox-calibration-report.md` nur, wenn `CalibrationGate.measured` stimmt (#147). Enthält außerdem `CalibrationGateTests` (ohne Korpus, läuft auch in CI) — die dürfen nicht mit abgeschaltet werden. |
| `LooseEndsTests/MeasurementData.swift` | Sucht den gitignorierten Korpus erst im Worktree, dann im Hauptordner (#135/#149). Deshalb trifft der Hänger **jeden** Worktree auf Hennings Mac: der Korpus liegt in `/Users/hem/Developer/loose-ends/docs/reference/focusblox-corpus.json` (vorhanden, 200 KB, 27.09.). Hier liegt `corpusMissing` als Vorbild für einen Skip-Kommentar. |
| `scripts/measurement_status.py` | Listet nach jedem `sim.sh unit` und in der CI-Zusammenfassung, welche Messstrecken liefen; `GATES` ordnet Suite → Datei. Kennt bisher nur „Datei fehlt" als Grund. Eine Suite, die zusätzlich an einem Schalter hängt, würde hier fälschlich als „gelaufen" gemeldet. |
| `scripts/test_measurement_status.py` | Prüft per Regex (`@Suite\((.*?)\)\s*\n\s*struct`, `MeasurementData\.exists\((\w+)\)`), dass `GATES` und die Swift-Gatter übereinstimmen. Eine Änderung am `@Suite`-Ausdruck muss diese Regex weiter erfüllen. |
| `scripts/sim.sh` (`cmd_unit` Z. 275, `cmd_sim_unit` Z. 403) | Startet `xcodebuild test … -only-testing:LooseEndsTests`; Umgebungsvariablen erreichen den Testprozess nur mit Präfix `TEST_RUNNER_` (Vorbild Z. 448: `TEST_RUNNER_LOOSEENDS_PUSH_FEED`). |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | Das gerufene Modell. Gehört zur Geräteliste (Stufe 3) — darf in diesem Ticket **nicht** geändert werden. |
| `LooseEnds/App/LooseEndsApp.swift:31` | Vorbild aus #228: unter `--ui-testing` nimmt die App `ModelOffEnricher`, das Modell ist in UI-Tests aus. Unit-Tests haben keinen solchen Schalter. |
| `LooseEndsLab/MeasurementRunner.swift`, `Measurement/MeasurementRun.swift` | Labor-App für Modellmessungen auf dem iPhone, in Scheiben mit Pausen, Fehlerklassen und Wiederaufnahme. Misst Selbstkonsistenz, **nicht** die Kalibrierung. |
| `docs/reference/focusblox-calibration-report.md` | Eingecheckter Bericht (Gerätelauf aus #23, „übersprungen: 1", noch mit importance-Tabelle). Muss unverändert bleiben (DoD). |
| `LooseEndsTests/MeasurementFieldScopeTests.swift:18` | Liest den Quelltext von `FocusBloxCalibrationTests.swift` (prüft, dass importance/urgency nicht ausgewertet werden). Umbenennen/Verschieben der Datei bricht diesen Test. |

## Existing Patterns
- Messsuiten werden per `.enabled(if:, Comment)` gegattert; der Kommentar erklärt im Log, warum nicht gemessen wurde (`MeasurementData.corpusMissing`).
- Ein Lauf, der nicht messen konnte, schreibt nichts (`CalibrationGate`, #133/#147).
- Modell aus in automatisierten Läufen: `ModelOffEnricher` unter `--ui-testing` (#228).
- Schalter von außen in den Testprozess: `TEST_RUNNER_<NAME>` in `sim.sh`.
- Modellmessungen auf dem Gerät gehören in die Labor-App, nie in einen Xcode-Testlauf (Memory „Handy ist kein Prüfstand").

## Dependencies
- Upstream: `FoundationModelsEnricher` (Apple FoundationModels, im iOS-27-Simulator seit #208 vorhanden), `MeasurementData`, Korpus-Datei.
- Downstream: `measurement_status.py` (Ausgabe nach jedem Unit-Lauf und in der CI-Zusammenfassung), `test_measurement_status.py`, `MeasurementFieldScopeTests`, `SelfConsistencyReportTests` (nennt die Suite nur im Kommentar).

## Existing Specs
- `docs/specs/tooling/fix-341-testlaeufe-verlaesslich.md` — Unit-Lauf nur im Simulator, Sperre, Bauordner; nennt #395 ausdrücklich als nicht enthalten.

## Risks & Considerations
- **Ein Zeitlimit hilft vermutlich nicht:** Swift Testings `.timeLimit` bricht die Aufgabe nur kooperativ ab; kehrt der Modellaufruf nie zurück (0 % CPU = Warten), läuft der Prozess weiter. Muss in der Analyse recherchiert und am nachgestellten Hänger gezeigt werden. Außerdem gilt `.timeLimit` minutenweise (Mindestwert 1 Minute).
- Noch nicht nachgestellt: Hängt der erste Aufruf oder erst ein späterer? Hängt er auch heute (Simulator/Modellstand vom 18.10.)? Das entscheidet zwischen „Modell im Simulator nie rufen" und „nach N Aufrufen".
- Ein Schalter, der die Messung abschaltet, darf `CalibrationGateTests` nicht treffen (zweite Suite in derselben Datei).
- `measurement_status.py` muss „ausgeschaltet" als Grund kennen, sonst meldet es die Messung als gelaufen.
- Der Bericht darf beim Nachstellen nicht überschrieben werden; nach jedem Messlauf `docs/reference/` zurücksetzen.
- Kein Pfad der Geräteliste soll berührt werden (nur `LooseEndsTests/`, `scripts/`).
- Im Arbeitsordner liegen nicht versionierte Restdateien aus #341 (`docs/artifacts/fix-341-…`); sie gehören nicht in diesen Schnitt.

## Analysis

### Type
Bug (Testwerkzeug, kein Produktcode)

### Nachstellung (2026-10-18, Belege in `docs/artifacts/fix-395-kalibrierung-haengt/repro/`)
| Lauf | Ergebnis | Kalibrier-Test | Bericht |
|---|---|---|---|
| Suite allein, iPhone 17 (`sim-unit FocusBloxCalibrationTests`) | grün | 185 s, 0 Modellfehler | **überschrieben**: Dauer-Trefferquote 61 % |
| Voller Unit-Lauf (`sim-unit`, 815 Tests, 218 s) | grün | 187 s | **überschrieben**: 64 % |
| Zwei Simulatoren gleichzeitig (Sperre umgangen) | iPhone 17e grün, iPhone 17 „signal kill“ | 575 s (3× langsamer, Minuten mit ~2 Anfragen) | **überschrieben**: 71 % |
Gerätebericht (#23, iPhone): 51 %. Der Abbruch im iPhone 17 kam von einer anderen Sitzung, die um 16:16:23 die App auf denselben
Simulator installierte (Simulator-Log `installcoordinationd` → `runningboardd` Beendigung) — Versuchsartefakt, kein Modellhänger.

**Der Hänger vom 13.10. ist nicht reproduzierbar** (3 Läufe, kein Stillstand). Wahrscheinliche Auslöser damals: mehrere Sitzungen
gleichzeitig am Modell (vor der Sperre aus #341) oder ein Simulator-/Modellzustand; beides unbewiesen.
**Reproduziert ist ein anderer, DoD-relevanter Fehler:** Jeder lokale Unit-Lauf mit Korpus überschreibt den eingecheckten
Gerätebericht mit Simulatorzahlen (drei Läufe, drei verschiedene Werte). `CalibrationGate` fängt nur Läufe mit ≥ 50 % Modellfehlern;
ein funktionierendes Simulatormodell kommt durch.

### Recherche
- Swift Testing `.timeLimit`: Mindestens 1 Minute, nur minutenweise. `withTimeLimit` startet den Test in einer `withThrowingTaskGroup`
  und bricht ihn bei Ablauf ab; eine Task-Gruppe wartet aber auf alle Kinder, also läuft ein Aufruf, der den Abbruch nicht beachtet,
  weiter ([TimeLimitTrait.swift](https://github.com/swiftlang/swift-testing/blob/main/Sources/Testing/Traits/TimeLimitTrait.swift),
  [Pitch Zeitgranularität](https://forums.swift.org/t/pitch-constrain-the-granularity-of-test-time-limit-durations/73146)).
- `LanguageModelSession.respond()` kehrt im Simulator manchmal weder zurück noch wirft (Apple-Forum
  [796414](https://developer.apple.com/forums/thread/796414), iOS 26 Beta 5) — passt zum Befund vom 13.10., nicht heute nachgestellt.

### Kernargument (trägt ohne den Hänger)
Die Suite kann nur im Simulator oder auf dem Mac laufen (Xcode-Testläufe auf Hennings Geräten sind verboten, Modellmessungen am
Gerät nur in der Labor-App). Sie misst dort ein anderes Modell als das, dessen Bericht sie überschreibt. Sie kann auf dieser
Plattform nichts Gültiges messen. Das Ergebnis der Kalibrierung steht in `docs/project/06-annahmen-und-experimente.md`.

### Varianten
| Variante | Hänger | Überschreiben | Aufwand | Preis |
|---|---|---|---|---|
| **A: Suite entfernen (Empfehlung)** | weg | weg | −~160 LoC, 4 Code-Dateien + 2 Kommentare + 2 Doku-Zeilen | Wiederholung der Kalibrierung nur über Verlauf oder Labor-App |
| B: Einschalter `TEST_RUNNER_LOOSEENDS_MODEL_MEASURE=1`, Status „ausgeschaltet“ | im Normallauf weg | bleibt beim Einschalten, bräuchte eigenen Schutz | +~60 LoC, 4 Dateien | Instrument, das weiter falsche Zahlen schreiben kann |
| C: `.timeLimit(.minutes(10))` | nicht sicher (kooperativer Abbruch) | bleibt | +1 Zeile | löst die DoD nicht |
| D: Kalibrierung in die Labor-App verlegen | – | – | großer Umbau | nur wenn wieder gemessen werden soll; eigenes Ticket bei Bedarf |
Gekippt wird keine ADR; #147 („nur echte Messungen schreiben“) wird damit vollständig eingelöst.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsTests/FocusBloxCalibrationTests.swift` | DELETE | Suite, `CalibrationGate`, `CalibrationGateTests` (nur hier benutzt) |
| `LooseEndsTests/MeasurementFieldScopeTests.swift` | MODIFY | Test, der den Quelltext der gelöschten Datei liest, entfällt (Z. 18–23) |
| `scripts/measurement_status.py` | MODIFY | `FocusBloxCalibrationTests` aus `GATES` |
| `scripts/test_measurement_status.py` | MODIFY | 5 → 4 (Z. 36, 49, 53), Z. 54 auf andere Suite umstellen |
| `LooseEndsTests/SelfConsistencyReportTests.swift:9`, `Measurement/SelfConsistency.swift:65` | MODIFY | nur Kommentar |
| `docs/project/02-datenmodell-und-ansichten.md:342`, `docs/reference/funktionsuebersicht.md:19` | MODIFY | „Suite entfernt (#395), Bericht ist der Gerätestand aus #23“ |
`docs/reference/focusblox-calibration-report.md` bleibt byte-gleich (DoD).

### Scope Assessment
- Files: 8 (4 Code, 2 Kommentarzeilen, 2 Doku-Zeilen) — über der 4–5-Dateien-Grenze, aber fast nur Löschung
- Estimated LoC: +~10 / −~165
- Risk Level: LOW — kein Produktcode, kein Pfad der Geräteliste

### Technical Approach
Variante A. Nachweis: `./scripts/sim.sh sim-unit` mit Korpus endet grün, `git diff --exit-code docs/reference/focusblox-calibration-report.md`
danach leer, `python3 scripts/test_measurement_status.py` grün, Statuszeile nennt 4 Messstrecken.

### Dependencies
CI ruft `measurement_status.py` ohne feste Zahl (`ci.yml:66`). Andere Berichts-Suiten rufen kein Modell (geprüft per grep).

### Randbefund (nicht in diesem Ticket)
`RuleLeaveOneOutReportTests` schreibt bei jedem Lauf das Messdatum neu in `docs/reference/retrieval-leave-one-out-rules.md`
(nur Datumszeile) — erzeugt unnötige Diffs. Eigenes Ticket #543.

### Open Questions
- [x] Henning (2026-10-18): Suite entfernen (A), 8 Dateien freigegeben (fast nur Löschung).
