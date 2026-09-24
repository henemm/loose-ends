# Adversary Dialog — #102 Freistehende Uhrzeit für Wiederholungsregeln

Geprüft gegen docs/specs/enrichment/rule-102-repeat-time.md und den Implementierungshinweis in
docs/context/102-repeat-time.md ("Implementierungshinweis aus TDD RED"). AC-2/AC-3 wurden gegen die
tatsächliche Implementierung (RepeatRule.timeGuess/RepeatRule.selecting) bewertet, nicht gegen das
illustrative Inline-Snippet der freigegebenen Spec — wie im Auftrag vorgegeben.

## Runde 1 — Erstprüfung gegen die Checkliste

Annahme: die Implementierung ist defekt, bis das Gegenteil mit Code und Testlauf bewiesen ist.

AC-1 timeGuess erkennt/verwirft kontextfrei

Shared/Models/RepeatRule.swift:45-48:
    static func timeGuess(from rawText: String) -> (hour: Int, minute: Int)? {
        TimeExpressionParser().time(in: rawText)
    }
Reiner Pass-Through, kein eigener Kontext-Check (isRepetition wird nicht befragt — "kontextfrei" im
Sinn der Spec bestätigt). Getestet in LooseEndsTests/RepeatRuleTests.swift:16-26: Treffer-Fall
("Jeden Tag um 7 Uhr die Tabletten nehmen" -> (7, 0)) und Nicht-Treffer-Fall ("Wöchentlich den Müll
rausbringen" -> nil). Beide grün im Testlauf (siehe unten).

Nachgebohrt: Was passiert bei hour == 0 (Mitternacht)? Optional Int unterscheidet 0 sauber von nil
— kein Bool'sches "truthy"-Problem, weder in timeGuess noch in selecting (if let guess =
timeGuess(...) prüft auf Optional, nicht auf Wahrheitswert). Kein eigener Testfall dafür vorhanden,
aber die Codepfad-Analyse schließt einen Bug hier aus — als Confirmation gewertet, nicht als
blinder Fleck.

AC-2 Prefill nur beim Neuanlegen

Shared/Models/RepeatRule.swift:50-64 (selecting) und Aufrufstelle
LooseEnds/Views/FieldEditorView.swift:168 (applyRepeat(RepeatRule.selecting(frequency, existing:
rule, rawText: task.rawText))). Bei existing == nil wird eine neue Regel erzeugt und
timeGuess(from: rawText) befüllt hour/minute, sofern ein Treffer vorliegt. Test:
LooseEndsTests/RepeatEditTests.swift:61-74 (firstFrequencyPickPrefillsTime) — Aufgabe mit Rohtext
"Jeden Tag um 7 Uhr die Tabletten nehmen", task.repeatRule vorher nil, nach RevisionService.set
über den selecting-Aufruf: task.repeatRule?.hour == 7, task.repeatRule?.minute == 0. Grün.

AC-3 Kein erneuter Prefill bei bestehender Regel

Gleiche Funktion, existing != nil-Zweig: next = existing, timeGuess wird nicht aufgerufen. Test:
LooseEndsTests/RepeatEditTests.swift:78-98 (changingFrequencyKeepsStoredTime) — bestehende Regel
mit hour: 7, minute: 0, Frequenzwechsel auf .weekly, danach unverändert hour == 7, minute == 0.
Grün.

Nachgebohrt: Die AC nennt vier Änderungsarten — "Frequenz, Intervall, Wochentage oder Basis". Der
Test deckt nur den Frequenzwechsel ab. Intervall/Wochentage/Basis laufen laut
FieldEditorView.swift:180-197 gar nicht über selecting, sondern kopieren rule direkt (var next =
rule; next.interval = ...) — timeGuess wird für diese drei Pfade strukturell nie aufgerufen,
unabhängig vom Testfall. Das deckt die AC vollständig ab, auch ohne dedizierten Test je
Änderungsart — siehe Runde 2 für die Detailprüfung dieser drei Pfade.

AC-4 Codec-Round-Trip verlustfrei

Shared/Services/FieldCodec.swift:81-91: encode(_ rule:)/decodeRepeat sind generische
Codable-Pass-Throughs, unverändert seit vor #102 (Diff gegen HEAD auf dieser Datei ist leer).
Getestet in LooseEndsTests/RepeatRuleTests.swift:60-77: Round-Trip mit hour: 7, minute: 30 liefert
identische Werte; Round-Trip ohne gesetzte Zeit liefert nil/nil. Beide grün.

AC-5 Kein automatisches Fälligkeitsdatum aus Wiederholungstext (Regression)

Diff gegen HEAD auf Shared/Enrichment/DueDateRule.swift und Shared/Services/DateExpressionParser.swift
ist leer — beide Dateien sind seit dem letzten Commit vor #102 unverändert. Gepinnter Test
LooseEndsTests/DueDateRuleTests.swift:62-72 (timeWithoutDateYieldsNothing, AC-6 aus #95) lief im
vollen Suite-Durchlauf grün mit, siehe Testlauf unten.

Testlauf (vollständig, eigener Lauf, nicht nur der bereits vorhandene GREEN-Output des
Implementierers):

    ./scripts/sim.sh unit
    -> xcodebuild.log: "Test run with 172 tests in 39 suites passed after 1.334 seconds."
    -> 0 Vorkommen von Fehlschlag-Markern außerhalb erwarteter Stub-Failure-Logzeilen
    -> Suite "Regelschritt: Wiederholungs-Uhrzeit" passed after 0.003 seconds. (7 Tests)
    -> Suite "Repeat rule edits" passed after 0.029 seconds. (5 Tests, davon 2 neu für #102)

Vollständiger Log: docs/artifacts/102-repeat-time/adversary-unit-run.log. Ein zweiter, unabhängiger
GREEN-Lauf liegt bereits unter docs/artifacts/102-repeat-time/test-green-output.txt
(Implementierer) — beide Läufe stimmen in der Gesamtzahl 172/39 überein.

### Runde 1 Zwischenstand
- [x] AC-1: CONFIRMED
- [x] AC-2: CONFIRMED
- [x] AC-3: CONFIRMED (mit offenem Nachbohr-Punkt zu Intervall/Wochentage/Basis — siehe Runde 2)
- [x] AC-4: CONFIRMED
- [x] AC-5: CONFIRMED

Kein Finding in Runde 1. Bewusst nicht konvergiert — Runde 2 prüft gezielt Regressionsrisiken,
Grenzfälle und die in der Spec dokumentierte Abweichung (Code-Organisation).

## Runde 2 — Regressions- und Grenzfallprüfung

Scope-Treue der Abweichung (View-Closure -> reine Funktionen). Per Auftrag als bewusste,
dokumentierte Entscheidung zu bewerten, nicht als Abweichung. Geprüft: FieldEditorView.swift Diff
gegen HEAD ist rein additiv-ersetzend (4 Zeilen raus, 1 Zeile rein), keine sonstigen
Verhaltensänderungen im Picker. Die drei Folge-Controls (Stepper für Intervall, weekdayRow,
Basis-Picker, FieldEditorView.swift:180-197) mutieren weiterhin direkt eine Kopie von rule und
rufen applyRepeat — kein Aufruf von selecting oder timeGuess in diesen drei Pfaden. Das erfüllt
AC-3 strukturell für alle vier genannten Änderungsarten, auch ohne separaten Testfall je Feld:
hour/minute werden nie berührt, weil der Code sie nie anfasst (Kopie behält sie unverändert).
Bewertung: kein Finding — die Spec fordert Verhalten, nicht Testabdeckung je Einzelpfad, und der
Pass-Through-Charakter ist durch Lesen des Codes bewiesen, nicht nur behauptet.

Testabdeckung Namenskollision. LooseEndsTests/ModelTests.swift benennt die alte
RepeatRuleTests-Suite in RepeatRuleRollForwardTests um, weil RepeatRuleTests.swift (neu, #102)
denselben Namen für die neue Suite beansprucht. Ohne diese Umbenennung hätte der Build wegen
doppelter Typnamen im selben Modul nicht kompiliert. Der grüne Testlauf (172/39, Build erfolgreich)
belegt, dass die Kollision aufgelöst ist — keine Testfall-Körper wurden inhaltlich verändert (nur
Kommentar + Suite-/Typname), wie im Diff sichtbar.

FieldCodec-Downstream-Risiko. Gegenprobe: Gibt es einen zweiten Schreibpfad für hour/minute außer
RepeatRule.selecting, der FieldCodec.encode/decodeRepeat umgehen könnte? Durchsuchung von Shared/
und LooseEnds/ (ohne Tests) nach direkten .hour=/.minute=-Zuweisungen liefert nur die beiden
Zuweisungen in RepeatRule.selecting selbst — kein zweiter Schreibpfad, keine Inkonsistenzgefahr
zwischen Modell und Codec.

Rückwärtskompatibilität gespeicherter Regeln ohne die neuen Felder. decodeRepeat nutzt
JSONDecoder().decode(RepeatRule.self, from:); hour/minute sind Int? = nil mit Default —
synthetisiertes Decodable nutzt für optionale, defaultbehaftete Properties decodeIfPresent,
fehlende Schlüssel in altem JSON decodieren als nil. Explizit durch codecRoundTripWithoutTimeStaysNil
(RepeatRuleTests.swift:69-77) mit einer Regel ohne die neuen Felder bewiesen — grün.

Build- und Kompilationsbeleg. Der Testlauf selbst kompiliert LooseEnds, LooseEndsWatch,
LooseEndsWidgets, LooseEndsShare (Zieldiagramm mit 6 Targets laut xcodebuild-Log) — Shared/
kompiliert also weiterhin in Watch/Widgets/Share mit den neuen RepeatRule-Feldern, wie von der Spec
verlangt (kein #if canImport(FoundationModels), reines Foundation). Kein Kompilationsfehler im
gesamten Log.

Konsistenzprobe der beiden unabhängigen Testläufe. Mein eigener frischer Lauf
(docs/artifacts/102-repeat-time/adversary-unit-run.log, xcodebuild.log: "Test run with 172 tests in
39 suites passed") und der bereits vorhandene GREEN-Output des Implementierers
(docs/artifacts/102-repeat-time/test-green-output.txt) stimmen in Testzahl und Suitezahl exakt
überein — kein Hinweis auf Flakiness oder einen nicht reproduzierbaren Zustand.

### Kein Finding in Runde 2

Kein Finding erhoben — alle geprüften Grenzfälle (hour=0, Namenskollision, zweiter Schreibpfad,
Rückwärtskompatibilität, Build über alle Targets, Reproduzierbarkeit) bestätigen die
Spec-Konformität.

### Runde 2 Zwischenstand
- [x] AC-1: CONFIRMED (Grenzfall hour=0 durch Codeanalyse ausgeschlossen)
- [x] AC-2: CONFIRMED
- [x] AC-3: CONFIRMED (alle vier Änderungsarten strukturell geprüft, nicht nur der getestete Fall)
- [x] AC-4: CONFIRMED (Rückwärtskompatibilität zusätzlich bewiesen)
- [x] AC-5: CONFIRMED (kein zweiter Schreibpfad, kein Diff in den geschützten Dateien)

## Confirmations

Confirmation:
  AC: AC-1
  Code reference: Shared/Models/RepeatRule.swift:45-48
  Evidence: timeGuess ist ein reiner Pass-Through auf TimeExpressionParser().time(in:), ohne
    isRepetition-Prüfung — liefert (hour, minute) bei Treffer, nil sonst. Bestätigt durch
    LooseEndsTests/RepeatRuleTests.swift:16-26 (beide Fälle grün).
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Models/RepeatRule.swift:50-64
  Code reference: LooseEnds/Views/FieldEditorView.swift:168
  Evidence: selecting(_, existing: nil, ...) befüllt hour/minute aus timeGuess beim Neuanlegen.
    Bestätigt durch LooseEndsTests/RepeatEditTests.swift:61-74 (grün, task.repeatRule?.hour == 7).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Models/RepeatRule.swift:51-58
  Code reference: LooseEnds/Views/FieldEditorView.swift:180-197
  Evidence: selecting(_, existing: rule, ...) übernimmt next = existing ohne erneuten
    timeGuess-Aufruf; Intervall-/Wochentage-/Basis-Controls kopieren rule direkt und rufen
    selecting/timeGuess nie auf. Bestätigt durch LooseEndsTests/RepeatEditTests.swift:78-98 (grün).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Services/FieldCodec.swift:81-91
  Evidence: encode/decodeRepeat unverändert (kein Diff gegen HEAD), generischer
    Codable-Pass-Through. Bestätigt durch LooseEndsTests/RepeatRuleTests.swift:60-77
    (Round-Trip mit und ohne Uhrzeit, grün).
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Enrichment/DueDateRule.swift:1
  Code reference: Shared/Services/DateExpressionParser.swift:1
  Evidence: Diff gegen HEAD auf beiden Dateien ist leer (unverändert). Gepinnter Test
    LooseEndsTests/DueDateRuleTests.swift:62-72 (timeWithoutDateYieldsNothing) lief im vollen
    Suite-Durchlauf grün (172 Tests/39 Suites, xcodebuild.log).
  Status: CONFIRMED

## Testlauf-Belege

- docs/artifacts/102-repeat-time/adversary-unit-run.log — eigener, unabhängiger Lauf dieses
  Adversary-Agenten (./scripts/sim.sh unit)
- docs/artifacts/102-repeat-time/test-green-output.txt — vorhandener GREEN-Output des
  Implementierers, zum Abgleich herangezogen (übereinstimmende 172/39-Zahl)
- /Users/hem/Library/Developer/Xcode/DerivedData/LooseEnds-session-default/xcodebuild.log —
  Rohquelle für "Test run with 172 tests in 39 suites passed after 1.334 seconds."

VERDICT: VERIFIED

Die Implementierung hat der Gegenprüfung standgehalten.
Tests: 172 bestanden, 0 fehlgeschlagen (2 unabhängige Läufe, übereinstimmend)
Grenzfälle: hour=0, Namenskollision, zweiter Schreibpfad, Rückwärtskompatibilität, Build über alle
  6 Targets — alle geprüft, nichts gebrochen
Regressionen: keine — DueDateRule.swift und DateExpressionParser.swift ohne Diff, gepinnter Test
  timeWithoutDateYieldsNothing grün
Checkliste: 5/5 Punkte bewiesen (AC-1 bis AC-5)

## Geprüfte Dateien

- sha256:f43b2e0034ce2234d957602b33c10695f57055f67a8f73f199bc461b08e3a26c  LooseEnds/Views/FieldEditorView.swift
- sha256:f033d4c3e68947f08979947d529dd5944414f107233d1f61a3f82f2ab6b2285d  Shared/Enrichment/DueDateRule.swift
- sha256:148783c5fe9154e450d56400989c0b4f6de731675e6cdd309f49f0be2c22c1ef  Shared/Models/RepeatRule.swift
- sha256:746ef8219cafb6e1568ee5b42914f211cda33d0b683a602b8dba0c389383dd71  Shared/Services/DateExpressionParser.swift
- sha256:208552d64f79f138613af36a0385bb5301a9fca5f666a4428e6bd1d1436ccfc1  Shared/Services/FieldCodec.swift
