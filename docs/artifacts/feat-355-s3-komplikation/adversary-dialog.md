# Adversary-Dialog feat-355-s3-komplikation (Schnitt 3a, Komplikation mit dem Knoten)

Spec: docs/specs/intents/feat-355-s3-komplikation.md. Geprüft wurde der unkommittete Stand im Worktree deep-strolling-quilt.
Geänderte Dateien: project.yml, .github/workflows/testflight.yml, LooseEndsTests/CaptureComplicationTests.swift, LooseEndsWatchWidgets/CaptureComplication.swift, LooseEndsWatchWidgets/LooseEndsWatchWidgetsBundle.swift, LooseEndsWatchWidgets/PrivacyInfo.xcprivacy, LooseEndsWatchWidgets/Info.plist.

Prüfer: implementation-validator (unabhängiger Agent). Protokoll wörtlich übernommen vom Orchestrator.

## Checkliste

- [x] **AC-1:** Ziel `LooseEndsWatchWidgets` (app-extension, watchOS, Kennung mit `$(BUNDLE_ID_SUFFIX)`, Extension-Point widgetkit, Version und Build wie die anderen Ziele, Quellen Ordner plus Thread.swift, Abhängigkeit in `LooseEndsWatch`) — Beleg: `git diff project.yml` zeigt genau diese Einträge. Die erzeugte Info.plist trägt `NSExtensionPointIdentifier` `com.apple.widgetkit-extension` sowie `CFBundleShortVersionString` und `CFBundleVersion` als `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)`. Die gebaute Appex zeigt 0.1.0 (1), die eingebettete Watch-App ebenso.
Code reference: project.yml:158
Code reference: LooseEndsWatchWidgets/Info.plist
- [x] **AC-2:** Keine Berechtigungen — Beleg: Das Ziel in `project.yml` hat weder `entitlements` noch Gruppe, iCloud oder Siri noch eine `Shared/`-Quelle. `test_entitlements_sync.py` selbst ausgeführt, 4 Tests OK. `codesign -d --entitlements -` auf der gebauten Appex liefert keine Berechtigungen (adhoc, linker-signed). Der Simulatorbau ist unsigniert (CODE_SIGNING_ALLOWED=NO); die Absicherung ist die Quelle in `project.yml`, das signierte Archiv prüft der TestFlight-Bau (Known Risk 1).
Code reference: project.yml:166
- [x] **AC-3:** Genau `accessoryCircular` und `accessoryCorner`, kein inline, kein rectangular — Beleg: `.supportedFamilies([.accessoryCircular, .accessoryCorner])` im Widget; `accessoryInline` und `accessoryRectangular` kommen nicht vor. Test 1 und 2 grün. Widget unter `#if os(watchOS)`, im Watch-Widget-Ziel gebaut; macOS-Übersetzung des Testziels `** TEST BUILD SUCCEEDED **`.
Code reference: LooseEndsWatchWidgets/CaptureComplication.swift:91
- [x] **AC-4:** Knoten gerendert in beiden Familien, Rand frei, Mindestfüllung, davor rot — Beleg: eigener Lauf `sim-unit CaptureComplicationTests` grün, xcresult listet vier Tests bestanden inkl. beider Argumente `.circular`/`.corner` des Füllungstests (4–40 %). `test-red-runtime-output.txt` zeigt 5 Zusicherungsfehler zur Laufzeit (`bright.share > 0`, `share >= 0.04`, Policy), kein Kompilierfehler. PNGs `complication-circular.png` (152×152) und `complication-corner.png` (160×80) auf Schwarz angesehen: weißer Knoten, geschlossene Schlaufe, zwei sich kreuzende Enden nach links und rechts, runde Enden, gleichmäßige Strichstärke, Abstand zum Rand.
Code reference: LooseEndsWatchWidgets/CaptureComplication.swift:35
Code reference: LooseEndsTests/CaptureComplicationTests.swift:77
- [x] **AC-5:** Statischer Provider — Beleg: `getTimeline` reicht `Timeline(entries: [ein Eintrag], policy: .never)` aus `timeline()` durch; Test prüft `entries.count == 1` und die Policy, grün.
Code reference: LooseEndsWatchWidgets/CaptureComplication.swift:13
- [x] **AC-6:** Datenschutzdatei und CI — Beleg: `LooseEndsWatchWidgets/PrivacyInfo.xcprivacy` unterscheidet sich von der Vorlage nur im leeren `NSPrivacyAccessedAPITypes`; liegt in der gebauten Appex. `testflight.yml` hat `check com.henning.looseends.watchkitapp.widgets watchos27.`; `test_ci_xcode27.py` selbst ausgeführt, 17 Tests OK. Archivlauf belegt erst der TestFlight-Bau.
Code reference: .github/workflows/testflight.yml:157
Code reference: LooseEndsWatchWidgets/PrivacyInfo.xcprivacy
- [x] **AC-7:** Bundle enthält die Appex — Beleg: `LooseEnds.app/Watch/LooseEndsWatch.app/PlugIns/LooseEndsWatchWidgets.appex` im iOS-Simulatorbau; plutil: Kennung `com.henning.looseends.watchkitapp.widgets`, Extension-Point `com.apple.widgetkit-extension`, `MinimumOSVersion` 27.0, `PrivacyInfo.xcprivacy` daneben. Screenshot `watch-erfassung-nach.png`: Erfassung mit „Ich höre zu“, „Fertig“, 0.1.0 (1), unverändert.
Code reference: LooseEndsWatchWidgets/LooseEndsWatchWidgetsBundle.swift:5
- [x] **AC-8:** Bestehendes bleibt grün — Beleg: `test-green-output.txt`, voller Lauf 589 Tests in 92 Suites, Exit 0, „Menu bar thread (#366)“ und „Thread from the logo curve (#180, step 3)“ bestanden. Selbst ausgeführt: `CaptureComplicationTests`, `test_entitlements_sync.py`, `test_ci_xcode27.py`. `Thread.swift` ohne Diff.
Code reference: LooseEndsTests/CaptureComplicationTests.swift:1
- [x] **AC-9:** Gerätepunkt (Stufe 3): Auf Hennings Watch wählbar, zeigt den Knoten, Antippen öffnet die Erfassung — in Runde 2 offen, in Runde 3 belegt durch Hennings Rückmeldung zu TestFlight-Build 57 (siehe Runde 3).

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert. Keine neuen Schreibstellen auf Modellfelder: Die Komplikation zeigt eine feste
Zeichnung, der Provider liest und schreibt nichts. Daher keine Einträge für „Bedingung davor“ oder „Test für diesen Weg“.

## Findings

Finding:
  ID: F001
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEndsWatchWidgets/CaptureComplication.swift:34
  Description: `CaptureComplicationView(face:)` mit eigenem `Face`-Enum statt `family: WidgetFamily` wie in der Spec.
  Conflict: Formal; begründet, weil `accessoryCorner` im iOS-Test nicht existiert. Wirkung gleich, der Widget-Body bildet die Familie auf `Face` ab.
  Remediation: Spec-Wortlaut nachziehen. Kein Codeumbau.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsTests/CaptureComplicationTests.swift:20
  Description: Testdatei nach Commit 59df664 in `Bright.init` geändert (lokale Konstanten vor der Nutzung), weil sie sonst nicht übersetzte.
  Conflict: Keiner. `git diff` zeigt nur fünf Zeilen in `init`, keine Zusicherung, Schwelle oder Argument verändert.
  Remediation: Im PR-Text erwähnen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsWatchWidgets/CaptureComplication.swift:39
  Description: Der Test sieht `AccessoryWidgetBackground` und `widgetLabel` nicht (iOS rendert sie nicht).
  Conflict: Von der Spec benannte Testbarkeitsgrenze.
  Remediation: Prüfpunkt für Hennings TestFlight-Lauf (Rundform mit Hintergrund, Ecke mit Beschriftung).

Finding:
  ID: F004
  Severity: LOW
  Category: anti_pattern
  Code reference: LooseEndsWatchWidgets/CaptureComplication.swift:13
  Description: Provider-Test ruft `timeline()` statt `getTimeline` und vergleicht die Policy über die Beschreibung.
  Conflict: Hinreichend, `getTimeline` reicht ohne Logik durch.
  Remediation: Optional.

Finding:
  ID: F005
  Severity: LOW
  Category: edge_case
  Code reference: project.yml:171
  Description: Signierter Zustand (cloud-managed Signing, neue App-ID) und `$(BUNDLE_ID_SUFFIX)` im Prüfbau nicht gebaut, folgt aber dem Muster der Nachbarziele.
  Conflict: Von der Spec benannte Restunsicherheit (Known Risks 1, 2).
  Remediation: TestFlight-Lauf abwarten; Rückfall laut Spec.

## Runden

### Runde 1

Behauptungen und Belege gesammelt: eigener Lauf `CaptureComplicationTests` (Exit 0, 4 Tests im xcresult inkl. beider Argumente), `test_entitlements_sync.py` 4 OK, `test_ci_xcode27.py` 17 OK, plutil auf die Appex (Kennung, Extension-Point, Minimum 27.0, Version 0.1.0 (1), PrivacyInfo), codesign ohne Berechtigungen, `git diff` der drei geänderten Dateien, Rot-Protokoll mit Zusicherungsfehlern, Grün-Protokoll 589/92, PNGs und Watch-Screenshot angesehen. AC-1 bis AC-8 zunächst belegt; zweite Runde mit Gegenproben.

### Runde 2

Gegenproben: `Thread.swift` importiert nur SwiftUI, kein Diff, Watch-Appex mit Binärdatei gebaut. `$(BUNDLE_ID_SUFFIX)` folgt dem Muster der Nachbarziele (F005). iOS-App bettet Watch-App samt Appex ein. Version wie die anderen Ziele. macOS-Übersetzung des Testziels erfolgreich; `#if os(watchOS)` um Widget und `widgetLabel` nötig und richtig; `@main` in eigener Datei. `ThreadShape` kommt im Testziel nur aus dem App-Modul. Rot-Lauf belegt, dass der Test bei leerer Hülle scheitert; Schwellen 0,04–0,4 passen zum sichtbaren Knoten. Referenzberichte zurückgesetzt. Findings F001–F005 alle LOW.

Verdict allein aus AC-1 bis AC-8: VERIFIED. AC-9 offen und hier nicht belegbar (Gerätepunkt über TestFlight).

Tests: CaptureComplicationTests 4/4, voller Lauf 589 bestanden, 0 fehlgeschlagen; Skripttests 4 und 17 bestanden. Regressionen: keine. Checklist: 8/9 belegt, AC-9 offen.

Verdict Runde 2 (überholt): AMBIGUOUS — gemergt mit Hennings getipptem `override` (PR #407, 0b96fc4), dann TestFlight-Build 57.

### Runde 3

AC-9 bewertet mit Hennings Gerätebefund zu Build 57. Eigene Prüfung: `LooseEndsWatch/WatchCaptureView.swift` hat `@State private var saved = false` (Zeile 9), setzt `saved = true` (Zeile 37), und keine Stelle setzt ihn zurück. `git log` der Datei zeigt nur 33ae74e (#390), 2b29436 und b7ae28a; der Schnitt hat sie nicht angefasst, das Verhalten stammt aus dem Walking Skeleton (#1).

- [x] **AC-9:** Gerätepunkt — Beleg: Hennings wörtliche Rückmeldung zu Build 57 auf seiner Watch: „ja, grundsätzlich funktioniert es.“ Komplikation wählbar, Knoten sichtbar, Antippen öffnet die Erfassung. Gestützt durch die Archivprüfung in Lauf 38523695048: `com.henning.looseends.watchkitapp.widgets | …PlugIns/LooseEndsWatchWidgets.appex | watchos27.0 | 27.0 | 0.1.0 (57) | OK`; cloud-managed Signing hat die neue App-ID angelegt (F005, Known Risks 1 und 2 belegt). Die Rückmeldung ist pauschal und wird nach „Bestätigung gilt“ als Beleg gewertet.
Code reference: LooseEndsWatch/WatchCaptureView.swift:9

Finding:
  ID: F006
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEndsWatch/WatchCaptureView.swift:37
  Description: `saved = true` wird nach dem Speichern nie zurückgesetzt; die Erfassung bleibt im Abschlusszustand, eine zweite Aufgabe geht nicht ohne Neustart der App (Hennings Befund zu Build 57).
  Spec requirement: Kein AC dieses Schnitts; die Spec lässt die Erfassung unverändert.
  Conflict: Kein Defekt dieses Schnitts, das Verhalten bestand seit #1. Die Komplikation macht es nur öfter sichtbar.
  Remediation: Eigenes Ticket (automatisch zurück zum leeren Feld nach kurzem „Gesichert“, Hennings Wahl 2026-10-14, mit UI-Test).

Bilanz: AC-1 bis AC-9 belegt, keine Regression, F006 außerhalb der Spec und als Folgearbeit erfasst.

VERDICT: VERIFIED

## Geprüfte Dateien

- sha256:22aa25dc7882bbb1def6fb7e4ae07708ab18faa48de071be82a35ea97ea4782b  .github/workflows/testflight.yml
- sha256:ec63d7355cf3ce226502a29244276f199c2763a60c858c909d5e67688e2a77fe  LooseEndsTests/CaptureComplicationTests.swift
- sha256:7873eb6987031015af36f6dacb3454582fa79b3de6dfc0d7de119057069092d4  LooseEndsWatchWidgets/CaptureComplication.swift
- sha256:43a6e963ebf4df7d01741c68405d162f69d75b1dd1b4fe4c05b8652a35e1777b  LooseEndsWatchWidgets/Info.plist
- sha256:905d8f4b4e592ee7253162141203118505314553a3c01bf39413ce4ab2ab1e84  LooseEndsWatchWidgets/LooseEndsWatchWidgetsBundle.swift
- sha256:521eb6ef8430773e5c010e1838fe9dd8fa5d62b7b76d1cea8d7d8daadcb144e2  LooseEndsWatchWidgets/PrivacyInfo.xcprivacy
- sha256:a6732b5088ce25a38cbdaa85036a33202061dd75ae9a0cefd6e54ee696f6c0d5  project.yml

## Prüfbasis

- base: 28777a71c41e38564cb2dd6ea01c59670e631de4
- blob:3770e0de7ff3170d0e5118b40998f1699fb7a120  .github/workflows/testflight.yml
- blob:5a846480e62beef6162936a33c46d7045fc8c920  LooseEndsTests/CaptureComplicationTests.swift
- blob:6b1f5afc33d1335d5756c9fb1da2d2d27f36cbdf  LooseEndsWatchWidgets/CaptureComplication.swift
- blob:6370abfccc8b4db0fd14a0a704a6b1ce3a9b23a0  LooseEndsWatchWidgets/Info.plist
- blob:550af69c1609713148f81ad5afaa507f9e9e2a60  LooseEndsWatchWidgets/LooseEndsWatchWidgetsBundle.swift
- blob:e08a130bce319577ff33577af8aa04e4ff1b87c2  LooseEndsWatchWidgets/PrivacyInfo.xcprivacy
- blob:76119e82712344c4366c697bf8a5f93e2d3c2264  project.yml

## Geprüfte Dateien

- sha256:22aa25dc7882bbb1def6fb7e4ae07708ab18faa48de071be82a35ea97ea4782b  .github/workflows/testflight.yml
- sha256:ec63d7355cf3ce226502a29244276f199c2763a60c858c909d5e67688e2a77fe  LooseEndsTests/CaptureComplicationTests.swift
- sha256:1cbfd61c3c747345903c59fc8eda15057c530e3a47852affb03341d307d3ecd8  LooseEndsWatch/WatchCaptureView.swift
- sha256:7873eb6987031015af36f6dacb3454582fa79b3de6dfc0d7de119057069092d4  LooseEndsWatchWidgets/CaptureComplication.swift
- sha256:43a6e963ebf4df7d01741c68405d162f69d75b1dd1b4fe4c05b8652a35e1777b  LooseEndsWatchWidgets/Info.plist
- sha256:905d8f4b4e592ee7253162141203118505314553a3c01bf39413ce4ab2ab1e84  LooseEndsWatchWidgets/LooseEndsWatchWidgetsBundle.swift
- sha256:521eb6ef8430773e5c010e1838fe9dd8fa5d62b7b76d1cea8d7d8daadcb144e2  LooseEndsWatchWidgets/PrivacyInfo.xcprivacy
- sha256:a6732b5088ce25a38cbdaa85036a33202061dd75ae9a0cefd6e54ee696f6c0d5  project.yml

## Prüfbasis

- base: 28777a71c41e38564cb2dd6ea01c59670e631de4
- blob:3770e0de7ff3170d0e5118b40998f1699fb7a120  .github/workflows/testflight.yml
- blob:5a846480e62beef6162936a33c46d7045fc8c920  LooseEndsTests/CaptureComplicationTests.swift
- blob:f3be68a344c2b6b49f3f1424a00f6841532e5bb5  LooseEndsWatch/WatchCaptureView.swift
- blob:6b1f5afc33d1335d5756c9fb1da2d2d27f36cbdf  LooseEndsWatchWidgets/CaptureComplication.swift
- blob:6370abfccc8b4db0fd14a0a704a6b1ce3a9b23a0  LooseEndsWatchWidgets/Info.plist
- blob:550af69c1609713148f81ad5afaa507f9e9e2a60  LooseEndsWatchWidgets/LooseEndsWatchWidgetsBundle.swift
- blob:e08a130bce319577ff33577af8aa04e4ff1b87c2  LooseEndsWatchWidgets/PrivacyInfo.xcprivacy
- blob:76119e82712344c4366c697bf8a5f93e2d3c2264  project.yml
