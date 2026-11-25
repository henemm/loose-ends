# Adversary Dialog — fix-978-s5-kurzer-klick
Spec: docs/specs/fix-978-s5-kurzer-klick.md
Datum: 2026-11-25 18:42

## Checkliste
- [x] **AC-1:** Given `scripts/test_mac_reopen_settle.py` und `scripts/test_mac_panel_repeat_summary.py` / When `python3 -m unittest` beide lokal fährt / Then sind alle Tests grün, darunter die neuen Quelltextprüfungen für Helfer, App und Retry-Pfad, und die v6-Tests des Auswerters bestehen unverändert. Belegt durch den Testlauf.
- [x] **AC-2:** Given `LooseEndsUITests/MacPanelHold.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then liest der Helfer `value` am Statusobjekt, kennt das Format `round=<n>` mit `pending` und `short`, wartet höchstens 4 s auf eine neue, nicht ausstehende Runde, liefert `.seconds`, `.short` oder `.unknown` mit Grund und enthält weder `OSLogStore` noch `import OSLog`. Belegt durch den Testlauf und den Diff.
- [x] **AC-3:** Given `LooseEnds/Mac/MenuBarCapture.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then setzt `MenuBarPanelLog` den Wert nur unter `ModelContainerFactory.isUITesting`, per `setAccessibilityValue` am Button des Fensters der Klasse `NSStatusBarWindow`, setzt bei `key` `round=<n> pending`, danach die Sekunden beim ersten Maus-hoch (Typ 2, lokal oder global) innerhalb der 3-s-Monitorrunde und `short` bei Rundenende ohne Maus-hoch; die Protokollzeilen sind unverändert. Belegt durch den Testlauf und den Diff.
- [x] **AC-4:** Given `LooseEndsUITests/MacGalleryTests.swift` / When `test_mac_reopen_settle.py` den Quelltext prüft / Then liest jeder Klickweg (`openPanel`, `assertSymbolOpensPanelWithOneClick`, `holdClick`) die Runde vor dem Klick, es gibt genau einen Retry-Pfad mit Schwelle `0.4`, höchstens eine Wiederholung, keinen Retry ohne gelesene Sekunden (unter 0,4 s, „short“ und „unknown“ sind hart rot mit Haltedauer oder Grund in der Meldung), der Klick bleibt `shortClick` mit `click(forDuration: 0.1`, Kontrollarm und Halteprobe bleiben hinter Umgebungsvariable und `XCTSkip`. Belegt durch den Testlauf.
- [x] **AC-5:** Given der Stand dieses Nachtrags / When App und UI-Test-Bundle für macOS übersetzt werden (`./scripts/sim.sh mac-build` bzw. die Build-Prüfung) / Then übersetzen beide ohne Fehler. Belegt durch die Prüfausgabe.
- [x] **AC-6:** Given der Diff gegen den Commit c800f7b / When `git diff --stat` geprüft wird / Then sind es genau die vier Dateien `LooseEnds/Mac/MenuBarCapture.swift`, `LooseEndsUITests/MacPanelHold.swift`, `LooseEndsUITests/MacGalleryTests.swift` und `scripts/test_mac_reopen_settle.py` plus Dokumentation (`docs/`), der App-Code liegt nur in `LooseEnds/Mac/MenuBarCapture.swift` bei höchstens 250 LoC und ist nur unter `isUITesting` wirksam; `project.yml`, `Info.plist`, Entitlements, `ci.yml`, `mac-panel-repeat.yml` und Gate-Konfiguration sind unverändert. Belegt durch `git diff --stat` und den Quelltext.

## Dialog

### Runde 1
**Adversary:** Beweise je AC. AC-1: `python3 -m unittest scripts.test_mac_reopen_settle scripts.test_mac_panel_repeat_summary -v` -> 84 Tests OK (docs/artifacts/fix-978-s5-kurzer-klick/adversary-test-output.txt). AC-2: kein OSLog in MacPanelHold.swift (grep leer), `wait = 4`, parse `round=<n> <state>`, `.seconds/.short/.unknown(Grund)`. AC-3: showHold guardet `ModelContainerFactory.isUITesting`, setzt per `setAccessibilityValue` am NSStatusBarButton des `NSStatusBarWindow`; `pending` in startMonitors, Sekunden in mouseUp (lokal + global), `short` nach 3 s; Protokollzeilen im Diff unveraendert. AC-4: Retry nur in `retryAfterLongHold`, Schwelle 0.4, nur bei `.seconds`, `click(forDuration: 0.1`, Kontrollarm/Halteprobe hinter Env + XCTSkip, `before` vor dem Klick in openPanel (Z.316), holdClick (Z.548), assertSymbol... (Z.693). AC-5: build-check-v7.txt "TEST BUILD SUCCEEDED", 0 Fehler. AC-6: `git diff --stat c800f7b` = die vier Dateien plus docs/, App +33 LoC, keine project.yml/Info.plist/Entitlements/.github.
Angriff Thread: addGlobalMonitorForEvents dokumentiert keinen Thread; in der Praxis laeuft der Handler auf dem Main-Thread (Main-Runloop), aber `MainActor.assumeIsolated` kaeme bei Abweichung zu einem Precondition-Absturz. Das steht jetzt auch im Produktpfad (startMonitors laeuft bei jedem `key`, nicht nur unter --ui-testing): `if event.type == .leftMouseUp { assumeIsolated {...} }` wird vor dem isUITesting-Guard ausgefuehrt (MenuBarCapture.swift:212, 219). Zuvor waren die Handler nonisolated ohne assumeIsolated. Zusaetzlich rechnet mouseUp im Produkt String(format:) pro Maus-hoch (shownRound wird dort nie gesetzt), harmlos.
Angriff Test: Falscher Retry durch alte Runde? `read(after: before)` verlangt round > before und nicht pending; Runde wird vor dem Klick gelesen; alte Runde mit Maus-hoch nach neuem key wird durch `monitorRound == round` verworfen. Rundenwechsel/doppeltes Maus-hoch: `shownRound != round`-Guard, stopMonitors bei neuem key. Wert vor der ersten Runde: round(of:) = 0, Wert nil -> .unknown, kein Retry. Rundenende nach Wert: `short` wird nur gesetzt, wenn shownRound != round. Rest-Risiko: ob `statusItems.firstMatch.value` den Accessibility-Wert des NSStatusBarButton tatsaechlich liefert, ist lokal nicht pruefbar (Mac-UI-Tests nur CI); Fehlschlag fuehrt zu `.unknown` und hartem Rot, nie zu falschem Retry.
**Implementierer:** Handler-Thread: Apple nennt keinen Thread, Praxis Main-Runloop; das Risiko bleibt als Finding F001 offen (Abhilfe: Guard `ModelContainerFactory.isUITesting` vor assumeIsolated oder `DispatchQueue.main.async`).

### Runde 2
**Adversary:** Zweite Pruefung der Randfaelle: Klick ohne key (Panel nicht ausgeloest) -> Runde bleibt `before`, nach 4 s `.unknown("no finished round ...")`, kein Retry (Z.47-50). Rundenende 3 s nach key vs. Wartefenster 4 s ab Klickende: reicht, weil der Klick 0.1 s dauert und key vor dem Klickende bzw. kurz danach liegt. Zweiter Retry unmoeglich: `retryAfterLongHold` klickt hoechstens einmal und gibt zurueck. Produkt ohne --ui-testing: showHold kehrt vor jeder Wirkung zurueck, roundStart/shownRound sind die zwei Variablen; Zusatzwirkung nur der oben genannte assumeIsolated-Aufruf und String(format:). Build-Beleg gelesen: 0 "error:", TEST BUILD SUCCEEDED. Alle sechs ACs mit Beleg; das Thread-Risiko ist kein AC-Bruch, aber ein Produkt-Absturzpfad ohne Not.
**Implementierer:** Bestaetigt F001; Spezifikation fordert "nur unter isUITesting wirksam" (AC-6), der assumeIsolated-Aufruf ist im Produkt wirksam. 

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:219
  Description: Der globale Monitor-Handler ruft MainActor.assumeIsolated ohne vorherigen isUITesting-Guard auf (ebenso lokal Z.212); Produktpfad.
  Spec requirement: AC-6 — App-Code nur unter isUITesting wirksam
  Conflict: Liefert Apple den Handler nicht auf dem Main-Thread, stuerzt die Produkt-App beim Maus-hoch in der 3-s-Runde ab; Apple dokumentiert den Thread nicht.
  Remediation: `guard ModelContainerFactory.isUITesting` vor assumeIsolated pruefen (nonisolated lesbar) oder Hop per DispatchQueue.main.async.

Confirmation:
AC: AC-1
Code reference: scripts/test_mac_reopen_settle.py:1
Evidence: 84 Tests OK.
Status: CONFIRMED

Confirmation:
AC: AC-2
Code reference: LooseEndsUITests/MacPanelHold.swift:37
Evidence: read(after:), wait 4 s, Reading mit Grund, kein OSLog.
Status: CONFIRMED

Confirmation:
AC: AC-3
Code reference: LooseEnds/Mac/MenuBarCapture.swift:251
Evidence: showHold nur unter isUITesting, setAccessibilityValue am NSStatusBarWindow-Button; pending/Sekunden/short wie spezifiziert.
Status: CONFIRMED

Confirmation:
AC: AC-4
Code reference: LooseEndsUITests/MacGalleryTests.swift:649
Evidence: ein Retry-Pfad, Schwelle 0.4, nur bei .seconds, Runde vor dem Klick in allen drei Wegen.
Status: CONFIRMED

Confirmation:
AC: AC-5
Code reference: LooseEndsUITests/MacGalleryTests.swift:316
Evidence: build-check-v7.txt TEST BUILD SUCCEEDED, 0 Fehler.
Status: CONFIRMED

Confirmation:
AC: AC-6
Code reference: LooseEnds/Mac/MenuBarCapture.swift:205
Evidence: git diff --stat c800f7b: vier Dateien plus docs, +33 LoC App, Konfiguration unveraendert.
Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict
VERDICT: AMBIGUOUS
Alle sechs ACs bewiesen (84 Tests gruen, Build-Beleg ok, Diff im Rahmen). Offen: F001 (MEDIUM), assumeIsolated im Produktpfad der Monitor-Handler ohne dokumentierte Thread-Zusage von Apple; und die lokal nicht pruefbare Annahme, dass der XCUI-Wert des Statusobjekts den Button-Wert liefert (CI-Beleg steht aus).

## Geprüfte Dateien

- sha256:84ef7aa9f265541361734b885dcf85fb19ed6693d888abc1d0b7eff0207d1b5a  LooseEnds/Mac/MenuBarCapture.swift
- sha256:1b78ba91f77363342ccfd4a151fba7f51dc96dd06b63139fe83106d0b74385a5  LooseEndsUITests/MacGalleryTests.swift
- sha256:be63313c540a81f3d8a28000022038048861f42ce509482af18709548500c2a6  LooseEndsUITests/MacPanelHold.swift
- sha256:9959c99b055233a087b0dec04a094e9e3019631bc1a7e543c580724765df06e5  scripts/test_mac_reopen_settle.py

## Prüfbasis

- base: 33a102b76c8c000e05549636f4c9010a0e9916be
- blob:b77da0d3d51a49cc27bfee26aa4424f453818acb  LooseEnds/Mac/MenuBarCapture.swift
- blob:dd45e19272b3b7aef9c02903cd554e373a76e058  LooseEndsUITests/MacGalleryTests.swift
- blob:8fc3ef89cc1af8a186170445cb27cad9cb391931  LooseEndsUITests/MacPanelHold.swift
- blob:a05bc0f712fb92afaa8f98a453064d0303a00dd8  scripts/test_mac_reopen_settle.py
