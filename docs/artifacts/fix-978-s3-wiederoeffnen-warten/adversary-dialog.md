# Adversary Dialog — fix-978-s3-wiederoeffnen-warten
Spec: docs/specs/fix-978-s3-wiederoeffnen-warten.md
Datum: 2026-11-24 12:42

## Checkliste
- [x] **AC-1:** Given `LooseEndsUITests/MacGalleryTests.swift` / When der Diff geprüft wird / Then enthalten die Wiederöffnungstests kein `XCTExpectFailure` und kein `continueAfterFailure = true` mehr. Belegt durch Diff und `grep` auf beide Wörter in der Datei.
- [x] **AC-2:** Given `assertSymbolOpensPanelWithOneClick` / When der Diff geprüft wird / Then ist die Reihenfolge Symbol existiert, ruhig warten (`waitForFrontmostSettled`: vorderste App seit 1 s unverändert, Abfrage alle 0,1 s, Obergrenze 10 s, danach trotzdem klicken und den Ablauf im Anhang vermerken), genau ein Klick, Panel binnen 10 s, nach 3 s noch vorhanden, Anhang, harte Assertions; es gibt keinen zweiten Klick und keine Wiederholung. Belegt durch Diff.
- [x] **AC-3:** Given die Arme Return, ⌘W und Kontrollarm / When der Diff geprüft wird / Then gehen alle drei durch `assertSymbolOpensPanelWithOneClick` mit derselben Wartehilfe; der Kontrollarm bleibt mit `XCTSkip` ohne `LE_PANEL_CONTROL_ARM` geschützt. Belegt durch Diff.
- [x] **AC-4:** Given der Klickanhang `mac-gallery-<label>-click` / When er geschrieben wird / Then behält er `click:`, `how:` und als letzte Zeile `… panel open|not open` (open = offen und nach 3 s noch offen), die Verlauf-Zeilen der vordersten App stehen davor, und `scripts/test_mac_panel_repeat_summary.py` ist ohne Änderung am Skript grün. Belegt durch die Skript-Tests und einen geöffneten Anhang.
- [ ] **AC-5:** Given der Pflicht-Check „Mac Gallery (macOS)“ / When er auf dem PR-Zweig dreimal nacheinander läuft / Then ist er jedes Mal beim ersten Versuch grün, ohne `XCTExpectFailure`. Belegt durch drei Läufe, deren Ergebnisbündel geöffnet und beschrieben sind. (offen: braucht CI-Lauf auf dem PR-Zweig)
- [ ] **AC-6:** Given `mac-panel-repeat.yml` auf dem PR-Zweig mit mindestens 40 Iterationen und Kontrollarm / When er endet / Then nennt `MacPanelRepeatSummary` je Arm Nenner ≥ 40 und Zähler 0 (keine Abweichung vom Soll-Nenner). Belegt durch das Artefakt, geöffnet und beschrieben. (offen: braucht CI-Lauf auf dem PR-Zweig)
- [x] **AC-7:** Given der Diff / When er geprüft wird / Then berührt er nur `LooseEndsUITests/MacGalleryTests.swift` (App-Code 0 LoC; `MenuBarCapture.swift`, `mac-panel-repeat.yml`, `mac_panel_repeat_summary.py` unverändert), und der Build der UI-Test-Bundles ist grün. Belegt durch `git diff --stat` und den Bau.

## Dialog

### Runde 1
**Adversary:** Angriff auf Reihenfolge, Einzelklick, Haltezeit, Anhangformat, Skriptlesbarkeit.
- AC-1: `grep XCTExpectFailure|continueAfterFailure` liefert nur Zeile 17 (`continueAfterFailure = false` in setUp, vorbestehend, nicht `= true`). Der Open-App-Arm ruft die Hilfe direkt (Zeile 476).
- AC-2: Reihenfolge in `assertSymbolOpensPanelWithOneClick`: waitForExistence Symbol (10 s) -> `waitForFrontmostSettled()` -> ein Klick (`click` oder `statusItem.click()`, if/else, nie beide) -> `waitForExistence(10)` -> bei Erscheinen 3 s Run-Loop-Haltezeit -> `.exists` -> Anhang -> `XCTAssertTrue`. Kein zweiter Klick, keine Schleife.
- Run-Loop statt Thread.sleep: die Hilfe dreht `RunLoop.current.run(until:)` 0,1 s je Abfrage, damit AppKit die Workspace-Benachrichtigungen zustellt; Thread.sleep wuerde frontmostApplication einfrieren. Dasselbe gilt fuer die 3-s-Haltezeit. Kein Thread.sleep in der Hilfe.
- Timeout der Hilfe: nach 10 s `timeout after 10 s` im Verlauf, Test klickt trotzdem (Obergrenze greift, Schleife endet garantiert).
- AC-3: Arme Return (457), Open-App (476), Kontrollarm (498, mit `click: Self.coordinateClick`) nutzen dieselbe Funktion; Kontrollarm-XCTSkip bei fehlendem `LE_PANEL_CONTROL_ARM` unveraendert (486-488).
- AC-4: Der Anhang endet mit `after: ... panel open|not open`, davor `click:`, `how:`, Verlauf, `app.debugDescription` (mehrzeilig, steht vor der letzten Zeile). Skript liest `^click:`, `^how:` und `panel (open|not open)\s*$` mit re.M; Verlaufzeilen (`front ...`, `settled after`) enden nicht darauf. Skript unveraendert (git status), Skripttests: 29 OK (adversary-test-output.txt).
- AC-7: git diff --stat: nur MacGalleryTests.swift als Code (+58/-18 inkl. 2 Doku-Dateien); LooseEnds/, .github, scripts unveraendert; Bau: 1x TEST BUILD SUCCEEDED, Log (12:40) juenger als die Quelldatei (12:36).
**Implementierer:** (nicht beteiligt, Kontextisolation)

### Runde 2
**Adversary:** Zweiter Angriff auf Randfaelle.
- Swift 6: Hilfe und Pruefer sind `@MainActor`, `NSWorkspace.shared` nur dort gelesen, keine Sendable-Capture; Bau gruen.
- `after:` enthaelt nun auch 3 s Haltezeit; das Skript wertet nur `click:` (Klickzeit) und den Zustand, nicht die Dauer: unkritisch.
- Return-Arm: die Haltezeit beginnt erst nach dem Klick; der legitime Schliess-Vorgang (Return) liegt davor und ist durch den `exists == false`-Wait abgeschlossen. Zwischen Klick und Pruefung wird nichts getippt/aktiviert, ein legitimes Schliessen ist nicht zu erwarten.
- Ruhephase beginnt beim ersten Abfragewert (changedAt = Start), nicht beim wahren letzten Wechsel; mindestens 1 s Wartezeit bleibt, ein Wechsel in dieser Zeit setzt die Uhr zurueck: wie spezifiziert.
- Schwaeche (informativ, kein Defekt): Ein Timeout der Hilfe wird vom Skript nicht gesondert gezaehlt (Known Limitation der Spec).
- Nicht belegbar in Phase 6: AC-5 und AC-6 (offen: braucht CI-Lauf auf dem PR-Zweig). Kein Beleg erfunden. Ob die 3-s-Haltezeit und die Wartehilfe in der CI wirklich zuverlaessig sind, zeigt erst der Lauf.
**Implementierer:** (nicht beteiligt)

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/MacGalleryTests.swift:476
  Evidence: Open-App-Arm ohne XCTExpectFailure/continueAfterFailure = true, Hilfe direkt gerufen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/MacGalleryTests.swift:557
  Evidence: Reihenfolge Symbol, Settle, ein Klick, 10 s Panel, 3 s Halten, Anhang, Assertion; kein Retry. Wartehilfe Zeile 528 mit Run-Loop, 0,1 s, 1 s ruhig, 10 s Limit.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/MacGalleryTests.swift:498
  Evidence: Kontrollarm nutzt dieselbe Funktion, XCTSkip-Schutz Zeile 486-488.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/test_mac_reopen_settle.py:114
  Evidence: Test `after_line_is_last_and_history_before_it` plus NewFormatSummaryTests (Zeile 126ff) gruen; Skript unveraendert.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEndsUITests/MacGalleryTests.swift:1
  Evidence: Nur diese Codedatei geaendert (import AppKit), Bau erfolgreich, andere Dateien unveraendert.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS

Alle in Phase 6 belegbaren ACs (AC-1 bis AC-4, AC-7) PROVEN, keine Defekte gefunden. AC-5 und AC-6 offen: braucht CI-Lauf auf dem PR-Zweig.
Tests: 29 bestanden, 0 fehlgeschlagen, 0 uebersprungen (Skripttests); UI-Test-Bundles bauen (TEST BUILD SUCCEEDED).

## Geprüfte Dateien

- sha256:7ee4cc38064487a8c2c9fece81e05ecb17b3fcbc3d224b26f78f2d461342d338  LooseEndsUITests/MacGalleryTests.swift
- sha256:e2fc49fe1a93f33c6bd40a4525627d48271189c854d059a6884a00f8815caa0c  scripts/test_mac_reopen_settle.py

## Prüfbasis

- base: 688d1074e6c34f7c1062b76c9774687b1dc07992
- blob:68ee50ea0a8dd8155174a723c15ca9fd045b9d87  LooseEndsUITests/MacGalleryTests.swift
- blob:89d2636efdcadd86d8e07ec1105b8c9e8eeccc77  scripts/test_mac_reopen_settle.py
