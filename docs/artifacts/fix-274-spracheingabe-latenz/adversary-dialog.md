# Adversary Dialog — fix-274-spracheingabe-latenz
Spec: docs/specs/fix-274-spracheingabe-latenz.md
Datum: 2026-10-09

Eigene Läufe (Prüfer): voller Mac-Unit-Lauf `./scripts/sim.sh unit` (xcresult "My Mac": 545 bestanden, 0 fehlgeschlagen, 1 übersprungen = SelfConsistencyReportTests, nicht #274; Suite "Speech latency (#274)" passed after 9.084 s), `./scripts/sim.sh sim-unit SpeechLatencyTests` (iPhone-17-Simulator), `./scripts/sim.sh build` (Build Succeeded). Ausgabe: /tmp/adversary_test_output.txt. Messberichte danach zurückgesetzt; der Arbeitsbaum zeigt nur die vier erwarteten Pfade (plus .claude/).

## Checkliste
- [x] AC-1 Option: Fabrik `makeTranscriber(locale:)` existiert, benutzt die Konstante `transcriberReportingOptions = [.volatileResults, .fastResults]`; `transcriber()` ruft nur die Fabrik. Bewertung der bekannten Abweichung unten (F001, LOW). Belege: LooseEnds/Speech/SpeechCapture.swift:187/191/195; Suche nach `SpeechTranscriber(` über LooseEnds, LooseEndsTests, Shared, LooseEndsWatch, LooseEndsWidgets, Measurement: genau ein Treffer (Zeile 195); Test makeTranscriberReportsFastResults bestanden (Mac und Simulator).
- [x] AC-2 Erstes Wort: eigener Mac-Lauf Suite grün (9,08 s); Lauf des Implementierers: 0,99 s nach Sprechbeginn (test-green-output.txt), Schwelle 3 s. Code: LooseEndsTests/SpeechLatencyTests.swift:29-31.
- [x] AC-3 Inhalt: finalTextContainsKeyWords bestanden; Endtext "Morgen um 10:00 Uhr den Zahnarzt anrufen und danach die Unterlagen für die Steuererklärung zusammensuchen und an Thomas schicken." enthält alle vier Kernwörter (test-green-output.txt).
- [x] AC-4 Rot dann grün: test-red-timing-output.txt: 8,07 s nach Sprechbeginn (>= 3 s), 2 Fehlschläge (Zeittest und Optionstest) mit `[.volatileResults]`; test-green-output.txt: 0,99 s, 545/0/1. Der RED-Wert ist 8,07 s statt der in der Spec genannten ca. 12 s, weil die Fixture nur 8,7 s lang ist; die Schwelle wird klar gerissen (F002, LOW).
- [x] AC-5 Überspringen: Simulator-Lauf, xcresult: "The first word arrives within 3 s of speech start" = Skipped, "Test cancelled: Sprache de_DE wird hier nicht unterstützt"; ebenso finalTextContainsKeyWords; Optionstest Passed; Gesamt 1 bestanden / 2 übersprungen / 0 fehlgeschlagen. Nicht grün gezählt. Hinweis: die xcbeautify-Konsole zeigt die Skips nicht, die Begründung steht nur im xcresult (F003, LOW).
- [x] AC-6 Nichts sonst: Diffstat 2 Dateien, +14/-4; der Diff ändert nur die Zeile der Erzeugung (SpeechCapture.swift:187) und fügt Konstante und Fabrik hinzu; Analyzer, Tap, Wandler, Rechte, Diagnosezeile, UI unberührt. project.yml unberührt; speech-de.m4a landet im Test-Bundle ("Copying speech-de.m4a" im Build). Fixture und Test selbst liegen im RED-Commit 136f924.
- [x] AC-7 Regression: Unit Mac-Host 545/0/1 und Simulator 495 Tests grün, Build grün, alle 11 UI-Klassen grün (30 Tests), Speech Stress 10x grün (stress 2–11; stress 1 Infrastruktur, siehe Runde 3). Beleg: docs/artifacts/fix-274-spracheingabe-latenz/ac7-regression.txt.
- [x] AC-8 Gerät (Teil vor dem Merge): Prüfbau auf Hennings iPhone 16 Pro nach seinem wörtlichen „jetzt ist ein Test möglich“; Henning: „ich habe die Wörter 21, 22, 23 gesprochen. Die 21 erschien, als ich 23 ausgesprochen habe. Keine graue Zeile“ (≈1,5–2 s, vorher 13–14 s). Der Teil nach dem Ausliefern (TestFlight, Alltag auf iPhone und iPad) ist laut Spec Schließbedingung von #274 und #279 A, nicht Merge-Bedingung; beide Tickets bleiben offen (Commit mit „Refs #274“, nicht „Closes“).

## Dialog

### Runde 1
**Adversary:** Ich unterstelle: die Option greift nicht, oder der Test beweist sie nicht.
- Die Fabrik ist die einzige Erzeugungsstelle. `transcriber()` (SpeechCapture.swift:182-188) behält die Locale-Suche samt Protokollzeile und ruft die Fabrik. Beide Aufrufer (`start()` Zeile 64, `load()` Zeile 148) gehen durch `transcriber()`.
- Die Abweichung: SDK-Schnittstelle bestätigt (macOS-SDK Speech.swiftinterface, arm64e-apple-macos: Zeile 357 `public var reportingOptions` liegt in `SpeechTranscriber.Preset`; die Klasse selbst (Zeile 346-348) hat nur den init). Der Test kann die Option also nicht am Objekt lesen. Die Konstante als einzige Quelle ist die beste lesbare Annäherung.
- Lücke: der Konstantentest beweist nicht, dass die Fabrik die Konstante benutzt. Ersetzt jemand in der Fabrik die Konstante durch ein Literal `[.volatileResults]`, bleibt der Optionstest in CI und Simulator grün. Dort fängt es nur der Mac-Zeittest, und der läuft nur, wo das Modell installiert ist (nicht CI/Simulator, AC-5). Der Schutz vor stillem Rückbau ist in CI also schwächer, als die Spec behauptet (F001).
Code reference: LooseEnds/Speech/SpeechCapture.swift
Code reference: LooseEndsTests/SpeechLatencyTests.swift

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Speech/SpeechCapture.swift:194
  Description: makeTranscriber(locale:) reicht transcriberReportingOptions an SpeechTranscriber.init; der Test prüft nur die Konstante (SpeechLatencyTests.swift:17-21), nicht den Weg von der Konstante zum Transcriber.
  Spec requirement: AC-1 — reportingOptions des Fabrik-Transcribers enthält beide Optionen
  Conflict: Ein Literal in der Fabrik würde den Optionstest nicht röten; nur der Mac-Zeittest (Modell nötig) würde es fangen. Das SDK 27 erlaubt kein Lesen am Objekt, also ist es nicht vollständig behebbar.
  Remediation: So annehmbar, die Abweichung ist durch das SDK erzwungen. Kein Merge-Blocker. AC-1 gilt im Sinn (Schutz vor stillem Rückbau der Konstante) als erfüllt, mit dieser benannten Restlücke.

**Implementierer:** Abweichung bewusst; der Zeittest auf dem Mac deckt den echten Weg.

### Runde 2
**Adversary:** Zeitmessung und Überspringen angreifen.
- Läuft die Zeitmessung über denselben Transcriber? Ja: Test ruft `SpeechCapture.makeTranscriber(locale:)` in measure() (SpeechLatencyTests.swift:65) und für den Modellstatus (Zeile 54). Der RED-Lauf mit der alten Option lieferte 8,07 s und rotete, der GREEN-Lauf 0,99 s; mein eigener Lauf ebenfalls grün. Die Konsolenzeile `[#274] first result` konnte ich im eigenen xcresult nicht nachlesen (print wird nicht erfasst), die Suite-Dauer 9,08 s passt jedoch zur Strecke (8,7 s Ton in Echtzeit).
- Flakiness: Schwelle 3 s gegen 0,99 s lässt Reserve; beide Zeittests teilen einen Lauf (`shared` Task), Suite `.serialized`. Zeitlimit 1 Minute (Spec nannte 30 s, F002).
- Test.cancel in `measuredRun()` bei fehlender Sprache oder Modell: im Simulator als Skipped mit Begründung belegt (AC-5). Der statische `shared` Task ist lazy und startet im Simulator nicht.
- Regression: keine andere Stelle nutzt die geänderte Funktion; `.fastResults` ändert den Endtext im Versuch nicht (AC-3). Das Risiko ungenauerer Zwischenstände bleibt eine Gerätefrage (AC-8).

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEndsTests/SpeechLatencyTests.swift:28
  Description: Zeitlimit des Tests ist 1 Minute, Fixture 8,7 s; RED-Messung 8,07 s statt ca. 12 s.
  Spec requirement: AC-4 / Spec "Zeitlimit 30 s", "ca. 10 s" Fixture
  Conflict: Kleine Abweichungen von den Spec-Zahlen; die Aussagekraft bleibt (8,07 s gegen 3 s Schwelle, 0,99 s gegen 3 s).
  Remediation: Keine Codeänderung nötig; Spec-Text bei Gelegenheit angleichen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/SpeechLatencyTests.swift:50
  Description: Das Überspringen (Test.cancel) steht nur im xcresult; die xcbeautify-Konsole von sim.sh zeigt nur die bestandene Optionsprüfung, nicht die zwei Skips.
  Spec requirement: AC-5 — als übersprungen mit Begründung gemeldet
  Conflict: Im xcresult erfüllt; wer nur die Konsole liest, sieht kein Skip (und auch kein Grün für den Zeittest).
  Remediation: Kein Blocker. Als CI-Beleg die xcresult-Zusammenfassung verwenden.

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Speech/SpeechCapture.swift:195
  Evidence: einzige Erzeugungsstelle, Optionen aus der Konstante [.volatileResults, .fastResults]
  Status: CONFIRMED

Confirmation:
  AC: AC-2, AC-3, AC-4, AC-5
  Code reference: LooseEndsTests/SpeechLatencyTests.swift
  Evidence: Mac-Lauf grün (Suite 9,08 s), RED 8,07 s / GREEN 0,99 s in den Artefakten, Simulator: 2 Tests Skipped mit Begründung "Sprache de_DE wird hier nicht unterstützt"
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Speech/SpeechCapture.swift:187
  Evidence: Diff +14/-4 in zwei Dateien, nur die Erzeugung des Transcribers geändert
  Status: CONFIRMED

**Implementierer:** keine Codeänderung erforderlich.

### Runde 3
**Adversary:** AC-7 und AC-8 waren offen. Ich unterstelle: der Stress-Lauf ist nicht 10x grün, und das Gerät zeigt die Verbesserung nicht.
- AC-7, Stress: 11 Läufe `CaptureCancelCrashTests` auf eigenem Simulator (iPhone 17 Pro, eigener DerivedData; ein erster Versuch auf „iPhone 17“ brach ab, weil eine Parallelsitzung denselben Simulator und Bauordner nutzte: „build database is locked“). Lauf 1 rc=65 nach 558 s mit `kAXErrorServerNotFound` beim Holen des Hauptfensters, direkt nach dem Kaltstart; kein Schritt der App wurde ausgeführt. Das ist das bekannte Muster aus #172, unabhängig vom Transcriber. Lauf 2–11 grün (je ca. 22–27 s). Ich akzeptiere 10/10 grün nur, weil der Fehlschlag vor jeder App-Interaktion lag; ein Fehlschlag im Ablauf selbst hätte gezählt.
- AC-7, UI: alle 11 übrigen Klassen aus LooseEndsUITests (vollständig gegen `grep XCTestCase` abgeglichen) grün, 30 Tests. SpeechListeningTests und SpeechDiagnosisLineTests decken die Erfassung ab.
- AC-7, Unit im Simulator: 495 Tests in 82 Suites grün (Henning, 2026-10-09: Tests im Simulator, nicht auf dem Mac).
- Nachlauf: xcodebuild hing nach dem Ergebnis an `simctl diagnose` (bis 19 Min); nach dem Ergebnis beendet, rc unverändert. Werkzeugfrage, nicht #274: Ticket #298.
- AC-8: Prüfbau (`./scripts/sim.sh device`, Kennung LE Prüfbau) auf dem iPhone 16 Pro nach Hennings wörtlicher Freigabe für diesen Durchgang. Beobachtung: erstes Wort nach ca. 1,5–2 s statt 13–14 s, keine graue Diagnosezeile. Das ist der Teil vor dem Merge. Henning ergänzte: die Oberfläche muss die Lücke bis zum ersten Wort überbrücken; das ist #279 B/C (Kommentar dort), kein Defekt dieses Fixes.
- Rest von AC-8 (TestFlight, Alltag iPhone und iPad) ist laut Spec Schließbedingung der Tickets; sie bleiben offen.
- Nach Runde 3 kam #296 (Diagnosezeiten, andere Stellen in SpeechCapture.swift) auf main. Die Änderung ließ sich konfliktfrei aufsetzen; auf dem neuen Stand erneut grün: Simulator-Unit 506 Tests, SpeechListening, SpeechDiagnosisLine, CaptureCancelCrash, CaptureSmoke (17). Dateihashes unten neu gestempelt.
Code reference: LooseEnds/Speech/SpeechCapture.swift

Confirmation:
  AC: AC-7
  Code reference: LooseEnds/Speech/SpeechCapture.swift:195
  Evidence: docs/artifacts/fix-274-spracheingabe-latenz/ac7-regression.txt — Stress 10/10 grün (2–11), 11 UI-Klassen/30 Tests grün, Simulator-Unit 495 grün
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Speech/SpeechCapture.swift:195
  Evidence: Gerätelauf iPhone 16 Pro, Hennings Beobachtung „Die 21 erschien, als ich 23 ausgesprochen habe. Keine graue Zeile“
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Eigene Prüfung des einzigen Feldes: `SpeechCapture.transcriberReportingOptions` wird nur an einer Stelle geschrieben (let-Konstante, SpeechCapture.swift:191). Bedingung davor: keine (statisch). Test für diesen Weg: makeTranscriberReportsFastResults (Konstante) und, wo das Modell installiert ist, firstWordArrivesWithinThreeSecondsOfSpeechStart (echter Weg durch die Fabrik).

## Offene Punkte
- Vor dem Merge: CI (UI Smoke, Speech Stress) nach dem Push grün.
- Nach dem Ausliefern: TestFlight-Fassung im Alltag auf iPhone und iPad bestätigt; erst dann #274 und #279 A schließen.

## Verdict: VERIFIED

## Geprüfte Dateien

- sha256:9c12216add899ed58d19b50bde3836a3d089beb1f4f0fc61e6ade2d9eec42ea6  LooseEnds/Speech/SpeechCapture.swift
- sha256:e1e1ad70d7c98f11ac224fdd382ca66bdeb3279351176077c8fe07b1eb5bd328  LooseEndsTests/SpeechLatencyTests.swift

## Prüfbasis

- base: 6a0853bacaebf9f52530d4fd3762cf640b13456e
- blob:3d1eed706f0fa09a6c1ea59d44ffc20172ff5d8c  LooseEnds/Speech/SpeechCapture.swift
- blob:243a14643842ccb4b5b8710f084cfced4d2cb467  LooseEndsTests/SpeechLatencyTests.swift
