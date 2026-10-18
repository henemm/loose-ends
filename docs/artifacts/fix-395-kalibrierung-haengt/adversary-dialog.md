# Adversary Dialog — fix-395-kalibrierung-haengt
Spec: docs/specs/tooling/fix-395-kalibrierung-haengt.md
Datum: 2026-10-18 19:35

## Checkliste
- [x] **AC-1:** Given der Stand nach der Umsetzung, When `test ! -e LooseEndsTests/FocusBloxCalibrationTests.swift` und `grep -rn "FocusBloxCalibrationTests\|CalibrationGate" LooseEndsTests Measurement scripts` laufen, Then existiert die Datei nicht mehr und der grep ist leer (Treffer nur in Doku-Zeilen, die die Entfernung nennen, nicht in diesen drei Ordnern).
- [x] **AC-2:** Given der Stand nach der Umsetzung, When `python3 scripts/test_measurement_status.py` läuft, Then ist es grün und die Messstrecken-Liste in `GATES` hat genau vier Einträge ohne `FocusBloxCalibrationTests`.
- [x] **AC-3:** Given der Stand nach der Umsetzung (auf `main` mit #531), When `grep -rlnE "FoundationModelsEnricher\s*\(" LooseEndsTests Measurement` läuft, Then nennt er nur Dateien, deren Suite am Schalter `.enabled(if: RealModel.isRequested` hängt (heute nur `LooseEndsTests/RealModelTests.swift`, aus #531, läuft nur mit `./scripts/sim.sh real-model`); der Skripttest `test_no_unit_suite_calls_the_model` prüft dasselbe rekursiv über beide Ordner, ist grün und schlägt bei einem Modellaufruf ohne diesen Schalter an.
- [x] **AC-4:** Given ein voller Lauf `./scripts/sim.sh sim-unit` mit Korpus (`focusblox-corpus.json` liegt im Hauptordner `/Users/hem/Developer/loose-ends/docs/reference/`, `MeasurementData` findet ihn), When der Lauf endet, Then ist das Ergebnis grün, und die Statuszeile von `measurement_status.py` am Ende nennt vier Messstrecken und keine Kalibrierung.
- [x] **AC-5:** Given derselbe Lauf, When danach `git diff --exit-code docs/reference/focusblox-calibration-report.md` läuft, Then ist der Exit-Code 0 (Bericht byte-gleich, #147 eingelöst).
- [x] **AC-6:** Given derselbe Lauf, When die Laufzeit mit den 187 s bis 218 s der Nachstellung verglichen wird, Then enthält das Protokoll keinen Test aus der gelöschten Suite und keinen Modellaufruf (`grep -c "FocusBloxCalibration" <Protokoll>` ergibt 0).
- [x] **AC-7:** Given der Stand nach der Umsetzung, When `./scripts/sim.sh sim-unit MeasurementFieldScopeTests` läuft, Then sind die verbliebenen Tests dieser Suite grün und der Test `focusBloxCalibrationDropsImportanceUrgency` existiert nicht mehr.
- [x] **AC-8:** Given der Stand nach der Umsetzung, When `grep -n "Suite entfernt (#395)" docs/project/02-datenmodell-und-ansichten.md docs/reference/funktionsuebersicht.md` läuft, Then liefert er je Datei einen Treffer, und keine der beiden Dateien verweist mehr auf `FocusBloxCalibrationTests.swift` als vorhandene Datei.
- [x] **AC-9:** Given `git diff --name-only main...HEAD`, When die Liste mit der Geräteliste aus `CLAUDE.md` verglichen wird, Then enthält sie nur die acht Dateien aus „Affected Files“ (Löschung eingeschlossen), keinen Pfad der Geräteliste, keine `Info.plist`, kein `project.yml`, keinen Produktcode unter `Shared/` oder `LooseEnds/`.

## Dialog

### Runde 1
**Adversary:** AC-1: Datei fehlt (ls: No such file); grep nach Suite/CalibrationGate in LooseEndsTests, Measurement, scripts leer. AC-2: scripts/test_measurement_status.py -> 9 Tests OK; GATES hat focusblox-corpus.json mit 4 Suiten (ContextWordLearning, RecognitionRule, RuleLeaveOneOut, SelfConsistency) plus selfconsistency-run.json mit SelfConsistencyReportTests (dieselbe vierte Suite), ohne Kalibrierung. AC-3: grep -rln "FoundationModelsEnricher(" LooseEndsTests Measurement leer. Wirksamkeit des Skripttests geprüft: temporäre Datei LooseEndsTests/ZzAdversaryProbe.swift mit FoundationModelsEnricher() -> Test schlägt an (FAILED failures=1, callers=['ZzAdversaryProbe.swift']); Datei danach entfernt. AC-4: eigener Volllauf sim.sh sim-unit (Exit 0, Test Succeeded, 810 Haken, 0 Fehlschläge); Korpus gefunden: ContextWordLearningReportTests (3,7 s), RecognitionRuleCorpusTests (0,6 s), RuleLeaveOneOutReportTests (4,0 s) liefen mit Daten; Statuszeile "Messstrecken: 1 von 4 übersprungen ... SelfConsistencyReportTests – fehlt: selfconsistency-run.json" (4 Messstrecken, keine Kalibrierung). AC-5: git diff --exit-code auf den Bericht nach dem Lauf: Exit 0. AC-6: grep -c FocusBloxCalibration im Protokoll = 0; Lauf dauerte ca. 45 s (18:22:51 bis 18:23:37) statt 187-218 s. AC-7: MeasurementFieldScopeTests im eigenen Volllauf bestanden (Zeilen 432-435), Protokoll des Implementierers ac7-measurement-field-scope.txt zeigt die Suite einzeln bestanden; der Testname focusBloxCalibrationDropsImportanceUrgency kommt in LooseEndsTests nicht mehr vor. AC-8: je ein Treffer (02-datenmodell:342, funktionsuebersicht:19). AC-9: staged plus RED-Commit (main...HEAD) ergibt genau acht Spec-Dateien (Kalibrierungs-Suite, FieldScopeTests, SelfConsistencyReportTests, SelfConsistency.swift, 02-datenmodell, funktionsuebersicht, measurement_status.py, test_measurement_status.py) plus Protokolle/Spec/Context/Briefing; kein Shared/, LooseEnds/, project.yml, Info.plist gestaged (LooseEnds/Info.plist ist nur unstaged, generiert).
**Implementierer:** (nicht beteiligt)

### Runde 2
**Adversary:** Kanten. Repo-weiter grep nach FocusBloxCalibration|CalibrationGate außerhalb von docs/artifacts, specs, context, briefings, .git, .claude: leer. .github/: nur ci.yml:66 ruft measurement_status.py --markdown ohne feste Zahl; keine Nennung der Suite oder von fünf Messstrecken. Kopfkommentar von MeasurementFieldScopeTests nennt die gelöschte Datei nicht und ist stimmig. Kommentare in SelfConsistencyReportTests:9 und Measurement/SelfConsistency.swift:65 nennen "the removed calibration suite (#395)". Skripttest-Reichweite: das Glob TESTS.glob("*.swift") deckt nur die oberste Ebene von LooseEndsTests; Probe in LooseEndsTests/Zz/P.swift und Measurement/ZzP.swift wurde NICHT erkannt (Test OK) -> Lücke gegenüber AC-3-Wortlaut, siehe F001. Aktuell gibt es keine Unterordner mit Swift-Dateien, daher kein aktueller Verstoß. Aufräumen: Probedateien entfernt; Nebenwirkung #543 zurückgesetzt.
**Implementierer:** (nicht beteiligt)

### Runde 3
**Adversary:** F001-Nachbesserung geprüft. Diff des gestagten Skripttests: Wächter nutzt jetzt rglob über LooseEndsTests und Measurement mit Regex FoundationModelsEnricher\s*\(. Eigene Proben, jeweils Test FAILED und Datei danach entfernt: (a) LooseEndsTests/Zz/P.swift (Unterordner) erkannt, (b) LooseEndsTests/ZzSp.swift mit "FoundationModelsEnricher ()" erkannt, (c) Measurement/ZzP.swift erkannt. Ohne Proben: grep mit \s* in beiden Ordnern leer, `python3 -m unittest discover -s scripts -p 'test_*.py'` OK. Statusliste (ohne fix-341) vor und nach den Proben identisch.
**Implementierer:** (nicht beteiligt)

### Runde 4
**Adversary:** Neuer Stand nach Rebase auf origin/main mit #531 (RealModelTests). Spec-Änderung AC-3/Changelog gelesen. AC-9 neu: staged (Calibration-Suite gelöscht, FieldScopeTests, SelfConsistencyReportTests, SelfConsistency.swift, 02-datenmodell, funktionsuebersicht, measurement_status.py, test_measurement_status.py = die acht Dateien) plus origin/main...HEAD (RED-Commit: test_measurement_status.py, Spec, Context, Briefing, Artefakte unter fix-395); zusätzlich staged: Protokolle, f001-probe.txt, Spec-Changelog. Kein Pfad der Geräteliste, keine Info.plist (nur unstaged generiert), kein project.yml, kein Shared/ oder LooseEnds/. AC-1: Datei fehlt, grep in LooseEndsTests/Measurement/scripts leer. AC-2: Skripttests OK, GATES vier Suiten. AC-3 neu: grep -rnE "FoundationModelsEnricher\s*\(" LooseEndsTests Measurement nennt nur LooseEndsTests/RealModelTests.swift (Zeilen 20, 52, 68); Suite ist per @Suite(.enabled(if: RealModel.isRequested ...)) abgeschaltet (Zeile 34-36). Proben: (a) ZzA.swift mit Aufruf ohne Schalter -> Test FAILED; (b) Schalterzeile nur als Kommentar + Aufruf -> Test OK (Umgehung möglich, F002); (c) Datei mit Schalter-Suite plus zweite Datei mit Aufruf -> FAILED (Ausnahme gilt je Datei). Probedateien entfernt. AC-4/5/6: eigener Volllauf sim-unit: Exit 0, Test Succeeded, 837 Tests, 832 bestanden, 0 fehlgeschlagen, 5 übersprungen (laut xcresult: RealModelTests Suite Skipped, SelfConsistencyReportTests Gatter ohne selfconsistency-run.json); RealModelGateTests gelaufen und bestanden (Protokoll Zeile 648-651); Korpus gefunden (ContextWordLearningReportTests 4,0 s mit Daten); Statuszeile "1 von 4 übersprungen"; grep -c FocusBloxCalibration = 0; Bericht focusblox-calibration-report.md unverändert (Exit 0). AC-7: MeasurementFieldScopeTests im Volllauf grün, Testname entfernt. AC-8 unverändert je ein Treffer. Aufräumen: retrieval-leave-one-out-rules.md zurückgesetzt, context-word-learning.md gelöscht.
**Implementierer:** (nicht beteiligt)

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_measurement_status.py:88
  Description: test_no_unit_suite_calls_the_model durchsucht nur LooseEndsTests/*.swift (nicht rekursiv) und nicht Measurement/. Eine Datei in einem Unterordner oder in Measurement/ mit dem Aufruf wird nicht erkannt (per Probe belegt). Auch ein Aufruf mit Leerzeichen vor der Klammer entginge dem Muster.
  Spec requirement: AC-3 — der Wächter soll dasselbe prüfen wie das grep über LooseEndsTests Measurement; Implementation Details Punkt 4 nennt allerdings nur LooseEndsTests/*.swift.
  Conflict: Der Schutz ist schmaler als das AC-3-grep; die Spec ist hier deckungsgleich mit der Umsetzung, daher nur Härtungslücke, kein Spec-Verstoß.
  Remediation: rglob über LooseEndsTests und Measurement verwenden und Regex FoundationModelsEnricher\s*\(.
  Status: BEHOBEN (Runde 3) — rglob über beide Ordner plus Regex umgesetzt und mit drei Proben bestätigt.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: scripts/test_measurement_status.py:90
  Description: Die Schalter-Ausnahme prüft nur, ob der Text `.enabled(if: RealModel.isRequested` irgendwo in der Datei steht, nicht ob er Code und nicht Kommentar ist und nicht ob er an der Suite hängt, die das Modell ruft. Probe: Datei mit Schalterzeile nur im Kommentar plus Aufruf wird nicht gemeldet (Test OK).
  Spec requirement: AC-3 — Dateien, deren Suite am Schalter hängt; der Test schlägt bei einem Modellaufruf ohne diesen Schalter an.
  Conflict: Absichtliche Umgehung möglich; versehentlich kaum (wer einen Aufruf schreibt, tippt den Schalter nicht zufällig als Kommentar). Kein echtes Risiko, der Wächter schützt vor Versehen, nicht vor Absicht.
  Remediation: Optional Kommentarzeilen vor der Suche entfernen oder `@Suite(` und Schalter gemeinsam verlangen.
  Status: OFFEN, akzeptiert als LOW

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/measurement_status.py:19
  Evidence: Datei nicht vorhanden; grep nach Suite/CalibrationGate in LooseEndsTests, Measurement, scripts leer.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: scripts/test_measurement_status.py:53
  Evidence: Skripttest 9 Tests OK; GATES ohne Kalibrierung, vier verschiedene Suiten.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: scripts/test_measurement_status.py:87
  Evidence: grep nennt nur das per Schalter abgeschaltete RealModelTests.swift (#531); Wächter rekursiv, schlägt bei Aufruf ohne Schalter nachweislich an (Proben Runde 3 und 4; Umgehung durch Kommentar siehe F002).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/measurement_status.py:19
  Evidence: Eigener sim-unit-Lauf Exit 0, Test Succeeded, 837 Tests/832 bestanden/0 fehlgeschlagen/5 übersprungen (RealModelTests, SelfConsistencyReportTests-Gatter), RealModelGateTests gelaufen, Korpus gefunden, Statuszeile "1 von 4 übersprungen". Protokoll docs/artifacts/fix-395-kalibrierung-haengt/adversary-test-output.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/reference/focusblox-calibration-report.md:1
  Evidence: git diff --exit-code auf den Bericht nach dem Volllauf: Exit 0.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/measurement_status.py:22
  Evidence: grep -c FocusBloxCalibration im Protokoll = 0; Laufzeit ca. 45 s statt 187-218 s.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEndsTests/MeasurementFieldScopeTests.swift:18
  Evidence: Suite MeasurementFieldScopeTests bestanden im eigenen Volllauf und im Implementierer-Protokoll; der entfernte Testname kommt nicht mehr vor.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: docs/project/02-datenmodell-und-ansichten.md:342
  Evidence: Je ein Treffer in 02-datenmodell:342 und funktionsuebersicht.md:19; keine Verweise auf die Datei als vorhanden.
  Status: CONFIRMED

Confirmation:
  AC: AC-9
  Code reference: LooseEndsTests/SelfConsistencyReportTests.swift:9
  Evidence: Staged plus origin/main...HEAD ergibt exakt die acht Spec-Dateien (u. a. Measurement/SelfConsistency.swift:65, docs/reference/funktionsuebersicht.md:19) plus Protokolle/Spec/Context/Briefing; kein Geräte-Pfad, keine Info.plist, kein project.yml, kein Shared/ oder LooseEnds/.
  Status: CONFIRMED

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
Tests: sim-unit voll auf Stand mit #531: 837 Tests, 832 bestanden, 0 fehlgeschlagen, 5 übersprungen (RealModelTests-Suite abgeschaltet, SelfConsistencyReportTests-Gatter ohne Datendatei; einzeln benannt); RealModelGateTests gelaufen; Skripttests OK
Edge cases: Wächter rekursiv und mit Leerzeichen-Regex wirksam; F001 behoben; F002 (Schalter-Kommentar-Umgehung) LOW, akzeptiert
Regressions: None found
Checklist: 9/9 points proven (4 Runden)

## Geprüfte Dateien

- sha256:6c22e2ff54d91059597133d815d9de8d5ac0a07615c7e4415e674fc6447bbc0e  LooseEndsTests/MeasurementFieldScopeTests.swift
- sha256:aea0a462b74f4d890a5ecf9e02cb2ff9b160c9ddea614a0278f9b9e76837e60f  LooseEndsTests/SelfConsistencyReportTests.swift
- sha256:b8db33709801714bc14e299f1312e53c888692c2609f4f366f5454a732041635  docs/project/02-datenmodell-und-ansichten.md
- sha256:a9bf0f28624de000889184a7c13b843aea72b0ff7ce4cf279eff2ee445429ccd  docs/reference/focusblox-calibration-report.md
- sha256:73feb7671a6f456e39cb772e4aa41ecdff2332b3889cd9f3c013ae80057a56b1  scripts/measurement_status.py
- sha256:7a9c78631fa539cc9f4e4c346fe02cc6462e4ce9fad5defabc510445e9a21a41  scripts/test_measurement_status.py

## Prüfbasis

- base: e59468c2f6d12f317a4f76b1a9ccd784e8c828bc
- blob:60b7187b9668eb95ec77edf8bb889e280fbf8421  LooseEndsTests/MeasurementFieldScopeTests.swift
- blob:31919f715364c7fbabaa2deea0af74f8c3fc984c  LooseEndsTests/SelfConsistencyReportTests.swift
- blob:1cf0e835a30411a8e3affa6891f6e1520ee0ccdd  docs/project/02-datenmodell-und-ansichten.md
- blob:5df20a285f08e9749c8f261a8e6f4fdec3186e7c  docs/reference/focusblox-calibration-report.md
- blob:1d67632ca5c22e5093808834b49f71afc9dbf84b  scripts/measurement_status.py
- blob:618ad38fad6f312eeb6fe49da1a0c5cc8666b94e  scripts/test_measurement_status.py
