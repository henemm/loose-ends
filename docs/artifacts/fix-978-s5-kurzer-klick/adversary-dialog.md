# Adversary Dialog — fix-978-s5-kurzer-klick
Spec: docs/specs/fix-978-s5-kurzer-klick.md
Datum: 2026-11-25 19:01

## Checkliste
- [x] **AC-1:** Given `scripts/test_mac_reopen_settle.py` und `scripts/test_mac_panel_repeat_summary.py` / When `python3 -m unittest` beide lokal fährt / Then sind alle Tests grün, darunter die neuen Quelltextprüfungen für Helfer, App und Retry-Pfad, und die v6-Tests des Auswerters bestehen unverändert. Belegt durch den Testlauf.
- [x] **AC-2:** Given `LooseEndsUITests/MacPanelHold.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then liest der Helfer `value` am Statusobjekt, kennt das Format `round=<n>` mit `pending` und `short`, wartet höchstens 4 s auf eine neue, nicht ausstehende Runde, liefert `.seconds`, `.short` oder `.unknown` mit Grund und enthält weder `OSLogStore` noch `import OSLog`. Belegt durch den Testlauf und den Diff.
- [x] **AC-3:** Given `LooseEnds/Mac/MenuBarCapture.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then setzt `MenuBarPanelLog` den Wert nur unter `ModelContainerFactory.isUITesting`, per `setAccessibilityValue` am Button des Fensters der Klasse `NSStatusBarWindow`, setzt bei `key` `round=<n> pending`, danach die Sekunden beim ersten Maus-hoch (Typ 2, lokal oder global) innerhalb der 3-s-Monitorrunde und `short` bei Rundenende ohne Maus-hoch; die Protokollzeilen sind unverändert. Belegt durch den Testlauf und den Diff.
- [x] **AC-4:** Given `LooseEndsUITests/MacGalleryTests.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then liest jeder Klickweg (`openPanel`, `assertSymbolOpensPanelWithOneClick`, `holdClick`) die Runde vor dem Klick, es gibt genau einen Retry-Pfad mit Schwelle `0.4`, höchstens eine Wiederholung, keinen Retry ohne gelesene Sekunden (unter 0,4 s, „short“ und „unknown“ sind hart rot mit Haltedauer oder Grund in der Meldung), der Klick bleibt `shortClick` mit `click(forDuration: 0.1`, Kontrollarm und Halteprobe bleiben hinter Umgebungsvariable und `XCTSkip`. Belegt durch den Testlauf.
- [x] **AC-5:** Given der Stand dieses Nachtrags / When App und UI-Test-Bundle für macOS übersetzt werden (`./scripts/sim.sh mac-build` bzw. die Build-Prüfung) / Then übersetzen beide ohne Fehler. Belegt durch die Prüfausgabe.
- [x] **AC-6:** Given der Diff gegen den Commit c800f7b / When `git diff --stat` geprüft wird / Then sind es genau die vier Dateien `LooseEnds/Mac/MenuBarCapture.swift`, `LooseEndsUITests/MacPanelHold.swift`, `LooseEndsUITests/MacGalleryTests.swift` und `scripts/test_mac_reopen_settle.py` plus Dokumentation (`docs/`), der App-Code liegt nur in `LooseEnds/Mac/MenuBarCapture.swift` bei höchstens 250 LoC und ist nur unter `isUITesting` wirksam; `project.yml`, `Info.plist`, Entitlements, `ci.yml`, `mac-panel-repeat.yml` und Gate-Konfiguration sind unverändert. Belegt durch `git diff --stat` und den Quelltext.

## Dialog

### Runde 1
**Adversary:** F001 aus v7-r1 (assumeIsolated im Monitor-Handler) behoben? Beweis: grep assumeIsolated in MenuBarCapture.swift. Die Handler (Zeilen 208-226) rufen nur `ModelContainerFactory.isUITesting` (static var, ProcessInfo-Argumente, kein Aktorzustand), lesen `event.timestamp` und springen per `DispatchQueue.main.async`; `assumeIsolated` steht nur im main-Block selbst (sicher, Hauptqueue). Produktpfad: numstat gegen c800f7b = 41 Zeilen hinzugefuegt, 0 geloescht; ausserhalb von --ui-testing wirken nur `roundStart` und `shownRound` (zwei Variablen), `showHold` kehrt per guard sofort zurueck.
Zeitbasis: NSEvent.timestamp = Sekunden seit Systemstart, ProcessInfo.systemUptime = Sekunden seit Systemstart (beide mach_absolute_time-basiert, ohne Schlaf): gleiche Basis. Ein Hop aendert die Haltedauer nicht, weil die Zeit am Ereignis haengt, nicht an der Ausfuehrung.
Rundenzuordnung: `round` wird im Handler erfasst; `mouseUp` ignoriert bei `monitorRound != round` und bei `shownRound == round`. Das 3-s-Ende setzt `short` nur wenn `shownRound != round` und setzt dabei shownRound; ein spaeter Hop gehoert dann zur gleichen Runde und wird verworfen (short wird nicht ueberschrieben). Umgekehrt: Hop vor dem 3-s-Block (FIFO auf der Hauptqueue) schreibt Sekunden, das Ende ueberschreibt nicht. Ein neues `key` erhoeht monitorRound, alte Hops fallen heraus.
Swift 6: Uebersetzung in build-check-v7.txt (Datei 19:00 nach letzter Quelltextaenderung 18:52; 0 error, 0 warning, BUILD SUCCEEDED und TEST BUILD SUCCEEDED).
**Implementierer:** Belege aus dem Quelltext; Testlauf siehe adversary-test-output.txt: 84 Tests, OK.

### Runde 2
**Adversary:** Zweiter, schaerferer Blick. AC-2: MacPanelHold.read (MacPanelHold.swift:40) wartet maximal `wait` = 4 s, nimmt nur Runden > before und nicht pending, liefert `.seconds/.short/.unknown(reason)`; kein OSLog. AC-4: alle drei Klickwege lesen `MacPanelHold.round(of:)` vor dem Klick (MacGalleryTests.swift:318, :549, :693); ein Retry-Pfad `retryAfterLongHold` (:649) mit `retryHold = 0.4` (:636), `guard case .seconds ... held >= retryHold` erzwingt: kein Retry ohne gelesene Sekunden, hoechstens ein zweiter Klick; Klick `click(forDuration: 0.1` (:630); Kontrollarm (:501) und Halteprobe (:524) hinter XCTSkip. AC-6: project.yml und CI-Verzeichnis ohne Diff; App-Code nur MenuBarCapture.swift +41/-0; der Rest sind zwei UI-Test-Dateien, das Testskript und docs/. AC-3: `showHold` hat guard auf isUITesting, der Handlerzweig ebenfalls; `logMonitored` unveraendert, keine geloeschte Zeile.
Offener Punkt (laut Spec bewusst kein AC): ob XCUITest `statusItems.firstMatch.value` liest, klaert die CI-Halteprobe.
**Implementierer:** keine weiteren Einwaende.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Findings und Confirmations

Confirmation:
  AC: AC-1
  Code reference: scripts/test_mac_reopen_settle.py:1
  Evidence: unittest beider Module: 84 Tests, OK (adversary-test-output.txt)
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/MacPanelHold.swift:40
  Evidence: read(_:after:) wartet <= 4 s, Reading seconds/short/unknown mit Grund, kein OSLog
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:208
  Evidence: Handler nur unter isUITesting, timestamp erfasst, async-Hop, Wert per setAccessibilityValue am NSStatusBarWindow-Button; pending bei key, short bei Rundenende; F001 behoben, kein assumeIsolated im Handler
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/MacGalleryTests.swift:649
  Evidence: ein Retry-Pfad, Schwelle 0.4 (:636), Runde vor Klick in drei Wegen, shortClick 0.1 s, XCTSkip fuer Kontrollarm/Halteprobe
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: docs/artifacts/fix-978-s5-kurzer-klick/build-check-v7.txt:1
  Evidence: BUILD SUCCEEDED und TEST BUILD SUCCEEDED, 0 error, nach der letzten Quelltextaenderung
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:112
  Evidence: App-Code nur MenuBarCapture.swift +41/-0, project.yml und CI unveraendert
  Status: CONFIRMED

## Verdict
VERDICT: VERIFIED
Alle sechs ACs bewiesen, F001 behoben, 84 Tests gruen, Build-Beleg ok.

## Geprüfte Dateien

- sha256:08d4b3f5d2e77d87b0b884e726cac0efc0e43461165ff35efaa790f25321ddb5  LooseEnds/Mac/MenuBarCapture.swift
- sha256:1b78ba91f77363342ccfd4a151fba7f51dc96dd06b63139fe83106d0b74385a5  LooseEndsUITests/MacGalleryTests.swift
- sha256:be63313c540a81f3d8a28000022038048861f42ce509482af18709548500c2a6  LooseEndsUITests/MacPanelHold.swift
- sha256:01c2edc434b1eb9e9f11b3b0f0a32a7088b6c9942cb8bd4476797f9eb84e2357  docs/artifacts/fix-978-s5-kurzer-klick/build-check-v7.txt
- sha256:9959c99b055233a087b0dec04a094e9e3019631bc1a7e543c580724765df06e5  scripts/test_mac_reopen_settle.py

## Prüfbasis

- base: 33a102b76c8c000e05549636f4c9010a0e9916be
- blob:cfa52fc5006f861bb547612df442136da958cabc  LooseEnds/Mac/MenuBarCapture.swift
- blob:dd45e19272b3b7aef9c02903cd554e373a76e058  LooseEndsUITests/MacGalleryTests.swift
- blob:8fc3ef89cc1af8a186170445cb27cad9cb391931  LooseEndsUITests/MacPanelHold.swift
- blob:f12c64e3a30c8c754338680a2ad9bc437757d140  docs/artifacts/fix-978-s5-kurzer-klick/build-check-v7.txt
- blob:a05bc0f712fb92afaa8f98a453064d0303a00dd8  scripts/test_mac_reopen_settle.py
