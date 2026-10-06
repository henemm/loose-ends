# Adversary Dialog — ci-178-xcode27
Spec: docs/specs/tooling/fix-178-ci-xcode27.md (inkl. Nachtrag 2026-10-06, Änderung 5, AC-15, AC-16)
Datum: 2026-10-06

## Checkliste

- [x] AC-2 Abbruch mit ::error::Expected Xcode 27.0 und Exit 1 bei anderer Version (Quelltext der Action, Test 5, Attrappe)
- [x] AC-3 Keine Absenkung: grep -rnE "sed -i|26\.0|macos-26" .github und grep -rn "project.yml" .github ohne Treffer (adversary-test-output.txt)
- [x] AC-4 (Quelltext) Strenge Simulatorwahl iPhone 17 / iOS-27-0, sonst ::error:: + Geräteliste, kein Rückfall
- [x] AC-5 (Quelltext) Diagnoseschritt mit Version, Laufzeiten, Gerät, Modellverfügbarkeit, bricht nie ab
- [x] AC-6 Check-Namen unverändert (Quelltext, Test)
- [x] AC-7 (Quelltext) Deployment-Ziel 27.0, kein Schritt ändert die Projektdatei
- [x] AC-11 Compiler-Schalter entfernt: grep ohne Treffer, #if/#endif balanciert, unit-green.txt
- [x] AC-12 CLAUDE.md-CI-Abschnitt nachgezogen (Test grün)
- [x] AC-13 Abnahmestufe: Diff nur in erlaubter Dateimenge, kein Pfad der Geräteliste (LooseEnds/Speech, Persistence, project.yml, Info.plist unberührt)
- [x] AC-15 (lokal belegbarer Teil) -collect-test-diagnostics never steht am xcodebuild test-without-building; Option existiert in Xcode 27 (xcodebuild -help: on-failure|never); Quelltext-Test grün
- [x] AC-16 (lokal belegbarer Teil) Startargument -speechServerRecognitionAllowed <false/> gesetzt; Gegenprobe: wird als echter Bool false gelesen (NO bleibt String, as? Bool = nil); lokaler UI-Lauf grün (ui-cancel-local.txt)
- [x] Testlauf scripts/test_ci_xcode27.py: 13/13 grün (adversary-test-output.txt)

## Abnahme im PR-Lauf (NICHT belegt — Pflicht in Phase 7/8 vor dem Merge)

Diese Punkte setzen einen hochgeladenen Stand voraus. Sie sind bewusst nicht abgehakt und bleiben
Abnahmekriterien der Spec, die `/60-validate` mit Lauf-ID belegt. Ohne sie wird nicht gemergt.

- offen: AC-8 Alle drei CI-Jobs grün ohne Wiederholung
- offen: AC-9 speech-stress per workflow_dispatch (Iterations 3) grün
- offen: AC-10 Zeiten gegen Ausgangswerte in der PR-Beschreibung
- offen: AC-14 Ausliefern nach dem Merge (Phase 8)
- offen: AC-15 speech-stress im PR-Lauf: jeder Durchlauf unter 300 s (summary.txt), kein „Timed out after 600.0 seconds“ in run-*.log
- offen: AC-16 speech-stress im PR-Lauf mit 10 Durchläufen: alle grün, in keinem Protokoll „Recognize speech via Apple?“ und kein „Computed hit point {-1, -1}“
- offen: echte Protokollzeilen zu AC-1, AC-4, AC-5, AC-6, AC-7, AC-11

## Dialog

### Runde 1
**Adversary:** Ursachenanalyse nachgeprüft statt übernommen. summary.txt aus Lauf 37415827670: 712/703/680 s je Durchlauf, der Test selbst 53,8/61,3/46,4 s; alle drei Protokolle enthalten „Failure collecting diagnostics from simulator: Timed out after 600.0 seconds“ — die 600 s sind belegt und gehören nicht zum Test. run-1.log: bei t=41,03 s „Computed hit point {-1, -1} after scrolling to visible“ direkt nach dem Systemdialog-Handling; run-2.log: bei t=40,5 s steht der Alert „Recognize speech via Apple?“ in der Hierarchie, in Lauf 2 ging der Test trotzdem grün, also echter Wettlauf, kein Dauerfehler. Die Analyse trägt. `xcodebuild -help` (Xcode 27): „-collect-test-diagnostics on-failure|never“ — Option existiert, steht in speech-stress.yml:83 als Argument von test-without-building (vor CODE_SIGNING_ALLOWED, kein Build-Setting), Quelltext-Test prüft das. Gegenprobe selbst gebaut (swiftc, UserDefaults.object(forKey:) as? Bool): `<false/>` ergibt __NSCFBoolean, as? Bool = false; `NO` ergibt NSTaggedPointerString, as? Bool = nil (die Spec-Behauptung stimmt); `<true/>` = true; ohne Argument nil. SpeechCapture.swift:200 liest genau so. Andere Leser des Schlüssels: grep über LooseEnds, Shared, Watch, Widgets, Share, Tests: nur SpeechCapture.swift:23/200/206; kein @AppStorage, kein bool(forKey:) — nichts reagiert anders auf <false/>. Schwächt es den Test? recognitionFailed (SpeechCapture.swift:142) wird erst NACH engine.start() und Erkennungsstart (Z. 116–134) erreicht; Mikrofon, Tap und Engine laufen unverändert, nur der Endzustand ist .unavailable (Z. 160) statt .needsServerConsent (Z. 163). Das Abbrechen-Blatt (captureCancelButton) steht in beiden Zuständen. Der Absturz-Pfad aus #184 (Abbrechen nach frischer Berechtigung, laufende Engine) bleibt erhalten. Lücke: Der Zustimmungsdialog-Pfad (needsServerConsent) wird in LooseEndsUITests/ und LooseEndsTests/ von keinem Test geprüft (grep ohne Treffer) — er war vorher auch nicht deterministisch geprüft, nur zufällig durchlaufen. Kein Rückschritt, aber ein Befund (F002).
**Implementierer:** Ursache und Wert bestätigt, Gegenprobe deckt sich. Der Dialog-Pfad war nie Zweck dieses Tests; ein eigener Test dafür wäre ein eigenes Ticket (Zustand vorgeben, Dialog erwarten, Antwort tippen). Keine Codeänderung.

### Runde 2
**Adversary:** Frühe-Einigkeit-Skepsis: Ich habe Runde 1 nicht auf Zustimmung beendet, sondern die Gegenstellen gesucht. (a) -collect-test-diagnostics never entfernt bei Fehlschlag die Sysdiagnose; was bleibt, ist der Export der Anhänge per xcresulttool (Schritt „Export crash reports“ nutzt xcresult und Log, nicht die Sysdiagnose) — Verlust nur der Simulator-Sysdiagnose, die ohnehin nie ankam (Timeout 600 s). (b) Die Option gilt nur für speech-stress; ci.yml (UI Smoke) bleibt unberührt, dort zeigte sich die Wartezeit laut Spec nicht. (c) Das Argument liegt in der Argument-Domain, wird nicht dauerhaft gespeichert und gilt bei jedem Start, auch nach `simctl privacy reset`; die Zustimmung wird nie geschrieben (Schreibstelle nur SpeechCapture.swift:206 über den Dialog). (d) Offener Rest-Wettlauf: allowSystemAlerts im Test tippt weiter auf Systemdialoge; der Befund „Alert“ in Lauf 1 war der App-Dialog, nicht das System. Ob nach der Änderung kein weiterer Wettlauf bleibt, zeigt nur der 10er-Lauf — deshalb AC-16 offen. (e) Die zwei neuen Python-Tests prüfen nur Quelltextstellen (assertIn); sie belegen Konfiguration, nicht Wirkung. Die Wirkung ist ausdrücklich nur im PR-Lauf belegbar und so ausgewiesen, nicht abgehakt. (f) Python-Suite 13/13 selbst ausgeführt (adversary-test-output.txt); die zwei neuen Fälle waren laut test-red-output-nachtrag.txt vorher rot. (g) Alle seit Basis geänderten Codedateien gelesen und unten per Code reference gedeckt.
**Implementierer:** Keine weitere Nachbesserung. Offen bleiben ausschließlich die PR-Lauf-Belege (AC-8, 9, 10, 14, 15, 16 und echte Protokollzeilen); der 10er-Lauf entscheidet über AC-16.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: .github/workflows/speech-stress.yml:83
  Description: -collect-test-diagnostics never schaltet die Sysdiagnose auch bei echtem Fehlschlag ab; für Fehlersuche bleiben nur Log, xcresult-Anhänge und Absturzberichte.
  Spec requirement: AC-15 — keine Diagnose-Wartezeit.
  Conflict: Verlust von Diagnosedaten bei Fehlschlag; die Sysdiagnose kam in Lauf 37415827670 ohnehin nicht an (Timeout 600 s). Kein Verstoß.
  Remediation: Keine. Status: akzeptiert.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Speech/SpeechCapture.swift:163
  Description: Der Zweig .needsServerConsent und der Zustimmungsdialog (CaptureView.swift:34/116) werden von keinem UI- oder Unit-Test in LooseEndsUITests/ oder LooseEndsTests/ geprüft; der Abbrechen-Test hat ihn bisher nur zufällig durchlaufen und umgeht ihn jetzt bewusst.
  Spec requirement: AC-16 — Abbrechen-Test ohne Zustimmungsdialog.
  Conflict: Keine Regression (vorher ebenfalls nicht deterministisch geprüft), aber eine Prüflücke für #63.
  Remediation: Eigenes Folgeticket: Test mit vorgegebenem Zustand und Dialog-Erwartung (nicht in dieses Ticket, Scoping). Status: akzeptiert, im Abschlussbericht zu nennen.

## Bestätigungen

Confirmation:
  AC: AC-2, AC-3, AC-6, AC-7
  Code reference: .github/actions/select-xcode-27/action.yml:13
  Evidence: Vergleich der Zeile 1 von xcodebuild -version mit "Xcode 27.0"; sonst ::error::Expected Xcode 27.0, exit 1 (Z. 14–15); grep auf Absenkung ohne Treffer.
  Status: CONFIRMED

Confirmation:
  AC: AC-3, AC-4, AC-5, AC-6, AC-7
  Code reference: .github/workflows/ci.yml:20
  Evidence: Drei Jobs runs-on xcode-27 (Z. 20, 56, 78) mit der Action (Z. 24, 60, 82), strenger Pick-Schritt Z. 90, Namen unverändert.
  Status: CONFIRMED

Confirmation:
  AC: AC-4, AC-15
  Code reference: .github/workflows/speech-stress.yml:83
  Evidence: iOS-27-0-Auswahl Z. 44; -collect-test-diagnostics never am test-without-building (Z. 83) samt Kommentar Z. 75; Option laut xcodebuild -help vorhanden. Wirkung nur im PR-Lauf belegbar (offen).
  Status: CONFIRMED

Confirmation:
  AC: AC-16
  Code reference: LooseEndsUITests/CaptureCancelCrashTests.swift:37
  Evidence: launchArguments enthält "-speechServerRecognitionAllowed", "<false/>"; Gegenprobe: <false/> wird als Bool false gelesen (as? Bool), NO nicht; SpeechCapture.swift:200 liest per object(forKey:) as? Bool; Mikrofon/Engine laufen vor recognitionFailed weiter (Z. 116–134). Wirkung im 10er-Lauf offen.
  Status: CONFIRMED

Confirmation:
  AC: AC-11
  Code reference: Measurement/MeasurementRun.swift:211
  Evidence: Kein compiler(>=6.4) mehr, nur #if canImport(FoundationModels) && !os(watchOS) balanciert; unit-green.txt grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-12, AC-13, AC-15, AC-16
  Code reference: scripts/test_ci_xcode27.py:143
  Evidence: 13/13 grün (adversary-test-output.txt), darunter test_stress_runs_skip_the_600_second_diagnostics (Z. 143) und test_cancel_test_declines_server_recognition_up_front (Z. 148); RED-Beleg test-red-output-nachtrag.txt.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

Hinweis zum Feld `speechServerRecognitionAllowed`: Produktionscode schreibt es an genau einer Stelle (SpeechCapture.swift:206, `answerServerConsent`), und zwar nur nach Antwort im Zustimmungsdialog. Ein Test für genau diesen Weg gibt es nicht (siehe F002); der geänderte Test setzt den Wert stattdessen als Startargument.

## Verdict

VERDICT: VERIFIED — alles vor dem Push Belegbare ist belegt (Python-Suite 13/13, Ursachenanalyse aus den Rohprotokollen bestätigt, Option und Startwert per Gegenprobe geprüft, keine anderen Leser des Schlüssels, Testzweck bleibt erhalten); nur LOW-Findings. Die Wirkung von AC-15 und AC-16 sowie AC-8, 9, 10, 14 ist ausdrücklich nur im PR-Lauf belegbar und steht als offen im Protokoll.

## Geprüfte Dateien

- sha256:2464bd2f3a0b4502f5a351fdd7c2103b610b0b73318da2741412cf82c27e4d9f  .github/actions/select-xcode-27/action.yml
- sha256:dccd8a7e762bd78eb233c088fe0bf0d787707287149b0a0200911159be16b0bb  .github/workflows/ci.yml
- sha256:75ebaea8de7fc9c9a2ea5f120fe3bbdb7cf195f482a75365cad1da60b5fe4c1f  .github/workflows/speech-stress.yml
- sha256:e869f4df4a1476639f69d25a250b3ef5318557add028ece533492723c582490f  LooseEnds/Speech/SpeechCapture.swift
- sha256:b75b24d67107a76efa2b1bd81023bf300e18a2d7756e8c9f5db785278942e94f  LooseEndsUITests/CaptureCancelCrashTests.swift
- sha256:63d7b8e6d9f8f5faa9119d56cf6e8789b6aadb1c838a727dfae5a8ec12f8ec50  Measurement/MeasurementRun.swift
- sha256:20a133a776abbe93bcaf233c5eb596e38f201897390c83b3ca75727d74c7d1a6  scripts/test_ci_xcode27.py

## Prüfbasis

- base: 10207fd5e28f171729573379ed916b714d947a4a
- blob:a27cbc67317a136303d901cc15e45c116636f73b  .github/actions/select-xcode-27/action.yml
- blob:78c4727718603310aaeefcad97f8f1fa4a4cfed5  .github/workflows/ci.yml
- blob:735d3ad4821fc81d779f68a7905bfef1c967d23a  .github/workflows/speech-stress.yml
- blob:84135dbe78cb6dd58d64230b5e48700335f39eb4  LooseEnds/Speech/SpeechCapture.swift
- blob:80b2dbefaa5a72142014d2978ca42cb8051cd563  LooseEndsUITests/CaptureCancelCrashTests.swift
- blob:0ac2ef2625589a73e90e620450320b7f8d6ada3b  Measurement/MeasurementRun.swift
- blob:0e97e2ea1281e4d095b52073c233670cb4dda945  scripts/test_ci_xcode27.py
