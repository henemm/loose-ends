# Adversary Dialog — fix-402-menueleiste-layout
Spec: docs/specs/fix-402-menueleiste-layout.md
Datum: 2026-10-13 21:47

## Checkliste
- [x] **AC-1:** Given kein hörbarer Pegel (nie über `SpeechDiagnosis.audibleLevel`) / When beliebig lange zugehört wird, Puffer kommen, kein Ergebnis / Then liefert `SpeechDiagnosis.hint` `nil` (Schweigen ist kein Problem). Belegt durch Unit-Test `silenceIsNoProblem` (zuerst rot).
- [x] **AC-2:** Given ein erster Pegel über `audibleLevel` / When `secondsAudible` die Schwelle `threshold` (6 s) erreicht (inklusive, 5,9 s noch nicht), Puffer da, kein Ergebnis / Then liefert `hint` Fall W; die Wartezeit zählt ab dem ersten Pegel, nicht ab Zuhörbeginn. Belegt durch Unit-Test `audibleLevelStartsTheClock`; `threshold` und `audibleLevel` stehen je an genau einer Stelle.
- [x] **AC-3:** Given Ergebnisse da und ein langsamer Start (`slowStart` 3 s) oder spätes erstes Ergebnis (`threshold` 6 s, inklusive) / When `showsReport` falsch ist (Produkt) / Then liefert `hint` `nil`; mit `showsReport` wahr (Prüfbau, `LaunchTimings.isProbeBuild`) liefert er den Bericht wie bisher. Belegt durch Unit-Test `reportOnlyInProbeBuild` und Code-Prüfung am Diff (`SpeechCapture` übergibt `isProbeBuild(bundleID:)`).
- [x] **AC-4:** Given macOS und Fall W / When die Erfassungsmaske die Diagnose zeigt / Then steht **eine** graue Zeile mit SF Symbol `exclamationmark.circle` (kein Emoji, kein Ersatzzeichen), `lineLimit(1)`, `.footnote`, `.secondary`, Text „Ton kommt an, aber kein Text erkannt“ (de) bzw. „Sound arrives, but no text recognized“ (en, beide im Zeichenkatalog), und die Einzelwerte (Modell, Mikrofon, Sprache, Puffer, Ergebnisse) stehen unverändert in `.help` und im Accessibility-Label. Belegt durch Code-Prüfung am Diff, den Test `shortTextIsOneLineWithoutFigures` und die Screenshots aus AC-7.
- [x] **AC-5:** Given iPhone und iPad / When die Diagnosezeile erscheint / Then sind Text, Umbruch und Optik unverändert (alle Optikänderungen unter `#if os(macOS)`); nur die Regeln aus AC-1 bis AC-3 gelten auch dort. Belegt durch den unveränderten, grünen UI-Test `SpeechDiagnosisLineTests` und Diff-Prüfung.
- [x] **AC-6:** Given `docs/reference/testflight.md` / When der Mac-Abschnitt gelesen wird / Then steht dort, dass in der TestFlight-App am Mac oben rechts „macOS“ gewählt werden muss, weil sonst die iOS-Fassung (Mac-Wrapper) ohne Menüleistensymbol installiert wird. Belegt durch Diff-Prüfung.
- [x] **AC-7:** Given der Mac-Prüfbau (`./scripts/sim.sh mac`, **nur** nach Hennings wörtlichem „jetzt ist ein Test möglich“) / When das Panel unter dem Menüleistensymbol geöffnet wird, mit und ohne Problemzeile (Problemzeile durch Ton ohne erkannten Text, z. B. mit deaktivierter Erkennung) / Then sind Text, Pegel, Knöpfe „Abbrechen/Fertig“ und die Fußzeile vollständig sichtbar, die Knöpfe überdecken die Fußzeile nie, das Panel ist mit und ohne Zeile gleich hoch, und im Alltag (Panel öffnen, 8 s schweigen) erscheint keine Diagnosezeile. Belegt durch Desktop-Screenshots in **hell und dunkel**, jeweils mit und ohne Problemzeile, die geöffnet und beschrieben werden (Ablage unter `docs/artifacts/402-menueleiste-layout/`). Kein automatisierter Test (siehe Risiken).
- [x] **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die sechs genannten Dateien (Teil A: fünf, Teil B: `testflight.md`), nicht `MenuBarCapture.swift`, `SettingsView.swift`, `Shared/`, `project.yml`, Entitlements oder `Info.plist`; kein `try?`, kein `print`; und alle bestehenden Tests sind grün.

## Dialog

### Runde 1
**Adversary:** Beweis je Punkt verlangt, Diff gelesen, Test-Output und Simulator-Beleg geöffnet.

- [x] AC-1 Schweigen: `hint` mit `secondsAudible == nil` liefert nil, weil `(secondsAudible.map { $0 >= threshold } ?? false)`.
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:46. Test `silenceIsNoProblem` (LooseEndsTests/SpeechDiagnosisTests.swift:173) grün in test-green-output.txt Zeile 814. RED zuvor in test-red-output.txt (Commit d166c43).
- [x] AC-2 Uhr ab erstem Pegel: `>=` inklusive (SpeechDiagnosis.swift:46), Test 5,9 nil / 6,0 Treffer (SpeechDiagnosisTests.swift:178-182) grün. `threshold` (SpeechDiagnosis.swift:23) und `audibleLevel` (SpeechDiagnosis.swift:28) je genau eine Definition (grep über LooseEnds, Shared, Tests: keine zweite). Pegelvergleich in SpeechCapture.swift:305 strikt `>`: Pegel exakt 0,1 startet die Uhr nicht; vertretbar, Spec nennt "über audibleLevel".
  Code reference: LooseEnds/Speech/SpeechCapture.swift:305
- [x] AC-3 Bericht nur im Prüfbau: `showsReport && results > 0 && ...` (SpeechDiagnosis.swift:47), SpeechCapture übergibt `LaunchTimings.isProbeBuild(bundleID: Bundle.main.bundleIdentifier)` (SpeechCapture.swift:319; Definition LaunchTimings.swift:134, Suffix `.probe`). Test `reportOnlyInProbeBuild` (SpeechDiagnosisTests.swift:191) grün; Standardwert `showsReport: Bool = false` ist sicher.
  Code reference: LooseEnds/Speech/SpeechDiagnosis.swift:47
- [x] AC-4 Mac-Zeile: `macDiagnosisLine` mit `Image(systemName: "exclamationmark.circle")`, `.footnote`, `.secondary`, `lineLimit(1)`, `.help(diagnosis?.text)`, Accessibility-Label `diagnosis?.text`, Kennung `speechDiagnosisLabel` bleibt; Platz immer reserviert (opacity 0 statt entfernt, Platzhaltertext " "). xcstrings: gültiges JSON (json.load), Schlüssel "Speech diagnosis short" mit de "Ton kommt an, aber kein Text erkannt" und en "Sound arrives, but no text recognized". Test `shortTextIsOneLineWithoutFigures` grün. Screenshot-Teil gehört zu AC-7 (offen).
  Code reference: LooseEnds/Views/CaptureView.swift:231
- [x] AC-5 iOS unverändert: Der `#else`-Zweig (CaptureView.swift:210-223) enthält den alten Block unverändert (Diff fügt nur `#if os(macOS)`/`#else`/`#endif` ein). UI-Test SpeechDiagnosisLineTests: 2 bestanden, 0 fehlgeschlagen, 0 übersprungen (simulator-run.txt); Screenshot geöffnet: graue, umbrechende Zeile "No text yet - model: installed . microphone: yes . speech: yes . buffers: 62 . results: 0" wie zuvor.
  Code reference: LooseEnds/Views/CaptureView.swift:210
- [x] AC-6 Doku: testflight.md-Diff zeigt neuen Satz im Absatz "Die Mac-App (#389)" mit "macOS" oben rechts, iOS-Fassung im Mac-Wrapper, kein Menüleistensymbol, #405.
  Code reference: docs/reference/testflight.md:225
- [x] AC-7 Mac-Prüfbau: BELEGT DURCH HENNINGS EIGENE BEOBACHTUNG (2026-10-14): „AC-7 ist belegt. Ich habe alles gesehen und getestet.“ Kein Beleg von Claude, keine Screenshots im Repo; Herkunft ist die Aussage des PO auf seinem Mac. Gilt auch für die Verdrahtung `firstAudibleAt`.
  Code reference: LooseEnds/Speech/SpeechCapture.swift:300
- [x] AC-8 Dateien: uncommittet Localizable.xcstrings, SpeechCapture.swift, SpeechDiagnosis.swift, CaptureView.swift, testflight.md; SpeechDiagnosisTests.swift im Commit d166c43. Keine Änderung an MenuBarCapture.swift, SettingsView.swift, Shared/, project.yml, Entitlements, Info.plist. Kein `try?`/`print(` in den drei Swift-Dateien. Unit-Lauf grün: kein Fehlerzeichen in test-green-output.txt, "Test Succeeded", SpeechDiagnosis-Suite 25 Tests grün. "Messstrecken: 1 von 5 übersprungen" betrifft Messberichte ohne Korpusdatei, nicht die Änderung.
  Code reference: LooseEnds/Resources/Localizable.xcstrings:284

### Runde 2
**Adversary:** Edge Cases gesucht.
- Reset von firstAudibleAt: in `stop()` (SpeechCapture.swift:137) und beim Start des Zuhörens neben `listeningSince` (SpeechCapture.swift:288). `updateDiagnosis` räumt bei `listeningSince == nil` die Diagnose ab; Neustart zeigt nichts. Kein Mangel.
- `noteLevel` ignoriert Pegel, solange `listeningSince == nil` (SpeechCapture.swift:305): Tap läuft schon vor Zeile 287, die ersten Millisekunden gehen verloren; vernachlässigbar. Verspätete Task-Pegel nach `stop()` werden verworfen.
- Pegelskala: Tap liefert `Waveform.level(of:)` (SpeechCapture.swift:382), 0...1; 0,1 passt. Wert nicht am Gerät gemessen (Spec-Risiko, in AC-7 zu bestätigen).
- Aufrufer: `SpeechDiagnosis.hint` nur in SpeechCapture und Tests; keine alte Signatur mehr (Build und Tests grün).

Findings: F001 LOW edge_case, Code reference LooseEnds/Speech/SpeechCapture.swift:305, Pegel vor `listeningSince` gehen verloren (vernachlässigbar). F002 MEDIUM spec_violation (Beweislücke), Code reference LooseEnds/Views/CaptureView.swift:231, AC-7 (Panelhöhe, 8 s Schweigen, Schwelle 0,1 am echten Mikrofon, hell/dunkel) unbewiesen und nicht automatisierbar; nach Hennings "jetzt ist ein Test möglich" mit `./scripts/sim.sh mac` nachholen.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

AC-1 bis AC-6 und AC-8 bewiesen (Adversary, Code und Tests); AC-7 (Mac-Prüfbau) belegt durch Hennings eigene Beobachtung (siehe Nachtrag 2), nicht durch einen Beleg von Claude.

## Geprüfte Dateien

- sha256:c02b518fc305caf06a36129a37f4cbed00f8e50cd77ada7282234b5e3b92dedd  LooseEnds/Resources/Localizable.xcstrings
- sha256:fe81a670b157d453c2ad0d7b2f8cc2caffaac08bcab83def42ec84b9a0191c1c  LooseEnds/Speech/SpeechCapture.swift
- sha256:d1439423dfffa01fbe7e2e9a9cdc8458edccd1f75466af6f91352150396e3bf7  LooseEnds/Speech/SpeechDiagnosis.swift
- sha256:785e0f5df14764493423f38e0b020587f05d950fd1ae66b97ba3d79627975beb  LooseEnds/Views/CaptureView.swift
- sha256:7b7b69df9ae2266e782faf40f2446c0c83499a90fcc5411f8f3d86d850ebabd0  docs/reference/testflight.md

## Prüfbasis

- base: b5fd0b501bff3de0729f47faa7eeebaa78506dbb
- blob:a7216a736860bda4f92540d69982757d2d6e5df0  LooseEnds/Resources/Localizable.xcstrings
- blob:1eef2335fa6a68751e4182cb375d4907cabe64ea  LooseEnds/Speech/SpeechCapture.swift
- blob:fde0a773abaa499ad6943f5841755bab2ae1d0ee  LooseEnds/Speech/SpeechDiagnosis.swift
- blob:832a5a08a843f9f4317f0039fb49446c840c3186  LooseEnds/Views/CaptureView.swift
- blob:f8b043009c45668b7a9a7abf5626231bb35f5079  docs/reference/testflight.md

### Nachtrag AC-7 (2026-10-14): nicht belegt, vom PO ausdrücklich zurückgestellt

Der Mac-Prüfbau lief mit Hennings Freigabe („jetzt ist ein Test möglich“), der Beleg kam nicht zustande:
- Mac war gesperrt (Sperrbildschirm), Aufnahme zunächst schwarz.
- Menüleistensymbol des Prüfbaus nicht sichtbar erreichbar (vermutlich Hidden Bar), Klick öffnete kein sichtbares Panel.
- Die Bitte, das Panel selbst zu öffnen und „offen“ zu schreiben, war nicht ausführbar: der Klick ins Terminal schließt das Panel.
- Ein Hintergrundskript (wartet aufs Panel, Ton, Aufnahme nur des Fensters) wurde von der Berechtigungsprüfung abgelehnt.
- Ganzbildaufnahmen enthielten fremde Inhalte und wurden gelöscht; es liegen keine Screenshots vor.

Henning (2026-10-14): „AC-7 schließen.“ Entscheidung des PO, kein Beweis. [Überholt durch Nachtrag 2 unten.] Unbelegt bleiben: Panelhöhe am Mac, Schwelle `audibleLevel` 0,1 am echten Mikrofon, Verdrahtung `firstAudibleAt`, Hell/Dunkel.

## Geprüfte Dateien

- sha256:c02b518fc305caf06a36129a37f4cbed00f8e50cd77ada7282234b5e3b92dedd  LooseEnds/Resources/Localizable.xcstrings
- sha256:fe81a670b157d453c2ad0d7b2f8cc2caffaac08bcab83def42ec84b9a0191c1c  LooseEnds/Speech/SpeechCapture.swift
- sha256:d1439423dfffa01fbe7e2e9a9cdc8458edccd1f75466af6f91352150396e3bf7  LooseEnds/Speech/SpeechDiagnosis.swift
- sha256:785e0f5df14764493423f38e0b020587f05d950fd1ae66b97ba3d79627975beb  LooseEnds/Views/CaptureView.swift
- sha256:7b7b69df9ae2266e782faf40f2446c0c83499a90fcc5411f8f3d86d850ebabd0  docs/reference/testflight.md

## Prüfbasis

- base: b5fd0b501bff3de0729f47faa7eeebaa78506dbb
- blob:a7216a736860bda4f92540d69982757d2d6e5df0  LooseEnds/Resources/Localizable.xcstrings
- blob:1eef2335fa6a68751e4182cb375d4907cabe64ea  LooseEnds/Speech/SpeechCapture.swift
- blob:fde0a773abaa499ad6943f5841755bab2ae1d0ee  LooseEnds/Speech/SpeechDiagnosis.swift
- blob:832a5a08a843f9f4317f0039fb49446c840c3186  LooseEnds/Views/CaptureView.swift
- blob:f8b043009c45668b7a9a7abf5626231bb35f5079  docs/reference/testflight.md

### Nachtrag 2 zu AC-7 (2026-10-14): Henning hat es selbst belegt

Henning (2026-10-14): „ICH SAGE: AC-7 IST BELEGT. ICH HABE ALLES GESEHEN UND GETESTET.“
AC-7 steht damit als erfüllt; Beweisquelle ist Hennings Sicht auf dem eigenen Mac, nicht ein Beleg von Claude. Es gibt keine Screenshots im Repo,
und Einzelheiten (Panelhöhe, Schwelle 0,1) hat er nicht genannt; sie werden hier nicht behauptet.

## Geprüfte Dateien

- sha256:c02b518fc305caf06a36129a37f4cbed00f8e50cd77ada7282234b5e3b92dedd  LooseEnds/Resources/Localizable.xcstrings
- sha256:fe81a670b157d453c2ad0d7b2f8cc2caffaac08bcab83def42ec84b9a0191c1c  LooseEnds/Speech/SpeechCapture.swift
- sha256:d1439423dfffa01fbe7e2e9a9cdc8458edccd1f75466af6f91352150396e3bf7  LooseEnds/Speech/SpeechDiagnosis.swift
- sha256:785e0f5df14764493423f38e0b020587f05d950fd1ae66b97ba3d79627975beb  LooseEnds/Views/CaptureView.swift
- sha256:5f0f99fff51001e57c4fd4c10d5b03f5b4d0c0dacc2f847253a00f761f2427ea  docs/reference/testflight.md

## Prüfbasis

- base: 28777a71c41e38564cb2dd6ea01c59670e631de4
- blob:a7216a736860bda4f92540d69982757d2d6e5df0  LooseEnds/Resources/Localizable.xcstrings
- blob:1eef2335fa6a68751e4182cb375d4907cabe64ea  LooseEnds/Speech/SpeechCapture.swift
- blob:fde0a773abaa499ad6943f5841755bab2ae1d0ee  LooseEnds/Speech/SpeechDiagnosis.swift
- blob:832a5a08a843f9f4317f0039fb49446c840c3186  LooseEnds/Views/CaptureView.swift
- blob:a147f38caa85f79ac75ba7f87bc7f6fe611b0e3c  docs/reference/testflight.md
