# Adversary Dialog — fix-978-s3-wiederoeffnen-warten
Spec: docs/specs/fix-978-s3-wiederoeffnen-warten.md
Datum: 2026-11-24 18:19

## Checkliste
- [x] **AC-1:** Given `assertSymbolOpensPanelWithOneClick` / When der Diff geprüft wird / Then läuft der Klick im Return- und im ⌘W-Arm über eine `XCUICoordinate`, deren Wurzel `XCUIApplication(bundleIdentifier:)` der nach `waitForFrontmostSettled` vordersten App ist, mit Offset gleich Mitte von `statusItem.frame` minus Ursprung des Wurzelrahmens; ist die vorderste App Loose Ends selbst oder nicht lesbar, klickt er wie bisher `statusItem.click()` und vermerkt das im Anhang. Belegt durch Diff und `scripts/test_mac_reopen_settle.py`.
- [x] **AC-2:** Given der Anhang `mac-gallery-<label>-click` / When er geschrieben wird / Then nennt `how:` `user: frontmost root <bundle id>` (oder den Rückfall), eine Zeile nennt die Dauer des Klicks in Sekunden, und die letzte Zeile bleibt `after: … s, panel open|not open`. Belegt durch Diff, Skript-Test und einen geöffneten Anhang.
- [x] **AC-3:** Given der ⌘W-Arm `testMenuBarReopensAfterOpenAppWithOneClick` / When der Diff geprüft wird / Then enthält er weder `XCTExpectFailure` noch `continueAfterFailure = true`, und die Haltezeit von 3 s bleibt. Belegt durch `grep` und `TestOpenAppArmIsHard`.
- [x] **AC-4:** Given der Kontrollarm `testMenuBarReopensAfterReturnWithControlClick` / When der Diff geprüft wird / Then ist er unverändert (weiter mit `LE_PANEL_CONTROL_ARM` und `XCTSkip` geschützt). Belegt durch Diff.
- [ ] **AC-5:** Given ein Wiederholungslauf `mac-panel-repeat.yml` auf dem PR-Zweig mit mindestens 100 Iterationen je Arm / When er endet / Then gibt es keinen Fehlschlag in beiden Nutzerarmen, im xcresult-Aktivitätsprotokoll des Klicks im ⌘W-Arm steht kein „Activate com.henning.looseends“, die Klickdauer ist kleiner als 1 s, und im Panel-Protokoll liegt der Abstand `panel key` → Maus hoch unter 0,3 s. Belegt durch die Artefakte, geöffnet und beschrieben.
- [ ] **AC-6:** Given der Pflicht-Check „Mac Gallery (macOS)“ / When er auf dem Stand dreimal läuft / Then ist er jedes Mal beim ersten Versuch grün; ein Abbruch durch das 40-min-Zeitlimit (#974) zählt nicht und wird neu gestartet. Belegt durch drei Läufe, Ergebnisbündel geöffnet.
- [x] **AC-7:** Given der Diff / When er geprüft wird / Then sind `scripts/test_menubar_panel_log.py` und `scripts/test_mac_reopen_settle.py` grün und der App-Code unverändert (0 LoC; `MenuBarCapture.swift`, `mac-panel-repeat.yml`, `mac_panel_repeat_summary.py` unberührt). Belegt durch Skriptlauf und `git diff --stat`.

## Dialog

### Runde 1
**Adversary:** Beweise je Punkt, nicht Behauptungen. Evidenz: `git diff` (MacGalleryTests.swift, test_mac_panel_repeat_summary.py), Typecheck mit swiftc (ohne Ausgabe, sauber), Skriptsuite `python3 -m unittest discover -s scripts -p 'test_*.py'` = 881 Tests, OK (skipped=1; Skip ist die Umgebungsprüfung in test_asc_crashes/test_evidence_config/test_next_ticket_hook/test_store_screenshots, nicht in den Prüf-Dateien), Output in `adversary-test-output.txt`. Direkt: test_mac_reopen_settle 16 OK, test_menubar_panel_log 12 OK, test_mac_panel_repeat_summary 29 OK. Keine UI-Tests, keine App-Starts.

Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/MacGalleryTests.swift:563
  Evidence: `frontmostRootClick` (Z. 558-570) nimmt `XCUIApplication(bundleIdentifier: id)` als Wurzel, Offset = (item.midX - rootFrame.minX, item.midY - rootFrame.minY), `root.coordinate(withNormalizedOffset: .zero).withOffset(offset).click()`. Beide Rechengrößen sind Bildschirmpunkte (XCUIElement.frame), die Wurzelkoordinate .zero liegt auf dem Wurzelrahmen-Ursprung: konsistent, kein Mischen von Normalisiert und Absolut. Rückfall auf `statusItem.click()` bei nil/"none"/Loose Ends (Z. 559-562) und bei leerem Rahmen (Z. 565-568), im `how` vermerkt. Genau ein Klick je Zweig (kein Schleifen, kein zweiter Klick; geprüft per Lesen und `FrontmostRootClickTests` in scripts/test_mac_reopen_settle.py:131). Beide Nutzerarme laufen über denselben Helfer (`click == nil`), der Kontrollarm übergibt `Self.coordinateClick`.

Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/MacGalleryTests.swift:605
  Evidence: Anhang enthält `how:` (`user: frontmost root <id>` / Rückfall), Zeile `click duration: %.3f s` (Z. 605) und als LETZTE Zeile `after: … panel open|not open` (Z. 606). Dauer wird direkt um den Klick gemessen (Z. 586-590). scripts/test_mac_reopen_settle.py:131 prüft Reihenfolge (duration vor letzter Zeile) am Quelltext; test_mac_panel_repeat_summary.py liest das Format (NewFormatSummaryTests) ohne Skriptänderung. Der Anhang selbst entsteht erst im CI-Lauf (siehe AC-5).

Confirmation:
  AC: AC-3
  Code reference: scripts/test_menubar_panel_log.py:53
  Evidence: `grep XCTExpectFailure|continueAfterFailure` in MacGalleryTests.swift findet nur `continueAfterFailure = false` (Z. 17, setUp); Funktionsrumpf von `testMenuBarReopensAfterOpenAppWithOneClick` (Z. 468) hat weder XCTExpectFailure noch `= true`; `TestOpenAppArmIsHard` grün. Haltezeit `holdSeconds = 3` (Z. 594) bleibt.

Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/MacGalleryTests.swift:486
  Evidence: Der Diff berührt den Kontrollarm nicht (Hunk nur im Kommentar von Z. 462 ff., in `frontmostRootClick` und im Helfer); `LE_PANEL_CONTROL_ARM`-Guard und `XCTSkip` (Z. 487-488) sowie `Self.coordinateClick` unverändert. Der Helfer ruft für ihn weiter `click(statusItem)`.

Confirmation:
  AC: AC-7
  Code reference: scripts/test_mac_reopen_settle.py:131
  Evidence: beide genannten Skripttests grün (16 und 12), volle Suite 881 OK. `git diff --stat HEAD -- LooseEnds .github scripts/mac_panel_repeat_summary.py` leer; gegen den Zweigpunkt (c885f7a) ändern sich in diesen Pfaden nur Tests/Skripttests, App-Code 0 LoC.

Bewertung der Abweichung (Datei unten, Z. 406):
  Code reference: scripts/test_mac_panel_repeat_summary.py:406
  Der alte Test verlangte `statusItem.click()` im Helferrumpf; das ist durch den Umbau (Aufruf wandert nach `frontmostRootClick`) zwingend. Der neue Test verlangt weiterhin `statusItem.click()` (jetzt im Rückfall-Helfer) und zusätzlich, dass der Nutzerarm-Helfer `frontmostRootClick(` aufruft, und streicht Kommentare vor dem Vergleich, sodass ein Kommentar den Test nicht mehr täuschen kann (vorher konnte er das). Keine Abschwächung, eher strenger; in der Spec als „nur ausgeführt“ geführt, ist aber real geändert: Dokumentationsabweichung, kein Defekt.

**Implementierer:** keine Gegenrede nötig; Befunde unten.

### Runde 2
**Adversary:** Gezielt Schwachstellen gesucht.
1. Frontmost-App wird zweimal gelesen (Z. 585 `waitForFrontmostSettled`, Z. 586 erneut). Nach einem `timeout after 10 s` oder einem Wechsel zwischen beiden Aufrufen kann die Wurzel eine andere App sein als die im Verlauf angezeigte. Der Anhang nennt die Wurzel in `how:`, daher auswertbar.
2. Unbelegt (nur CI beweisbar): ob `XCUICoordinate.click()` auf einer Nicht-Ziel-Wurzel (Finder) wirklich nichts aktiviert und ob `XCUIApplication(bundleIdentifier:).frame` bei Finder ohne Fenster nichtleer, aber sinnvoll ist (dann liegt der Klickpunkt außerhalb des Wurzelrahmens, XCTest könnte ablehnen). Rückfall nur bei leerem Rahmen. Das ist genau, was AC-5 prüft; Spec nennt Alternative D als Rückfall.
3. Frontmost-Bundle-ID einer App ohne Bundle (nil) → Rückfall mit `none`: korrekt abgedeckt.
4. Kein zweiter Klick, keine Wiederholung: bestätigt.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:586
  Description: `frontmost` wird nach `waitForFrontmostSettled()` neu gelesen statt aus dessen Ergebnis genommen.
  Spec requirement: AC-1 — Wurzel ist die nach `waitForFrontmostSettled` vorderste App
  Conflict: Rechnerisch erfüllt (zeitlich nach dem Warten), aber bei Timeout oder spätem Wechsel kann die Wurzel vom Anhangverlauf abweichen; `how:` nennt die tatsächliche Wurzel.
  Remediation: Optional ID aus der Warte-Funktion zurückgeben. Kein Blocker.

**Implementierer:** F001 akzeptiert als LOW, kein Blocker.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

Offen (nicht abgehakt, nichts erfunden): AC-5 (Wiederholungslauf >= 100/Arm, Aktivierung im xcresult, Klickdauer < 1 s, panel key -> Maus hoch < 0,3 s) und AC-6 (drei Läufe „Mac Gallery (macOS)“) brauchen CI auf dem gepushten Stand.

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  AC-5 und AC-6 sind lokal nicht beweisbar (CI-Läufe auf gepushtem Stand fehlen); sonst nichts defekt.
Proven points: 5/7 (AC-1, 2, 3, 4, 7)
Tests: 881 passed, 0 failed, 1 übersprungen (Umgebungs-Skip, keine der geprüften Dateien)
Edge cases: nur F001 (LOW)
Regressions: None found
Recommendation: AC-5/AC-6 nach Push per CI nachweisen; ob XCTest bei Fremdwurzel nichts aktiviert, zeigt erst AC-5.

## Geprüfte Dateien

- sha256:12b2ce6af38136b02c6a12c819b428db20b3abecdaba53d5ce1801cd2ab82031  LooseEndsUITests/MacGalleryTests.swift
- sha256:8d1ee628a91af35cf7e193335be721ebe50496f3b5ec799e0a9f75d9fa0b17d5  scripts/test_mac_panel_repeat_summary.py
- sha256:9fb26fb286c0fabb3f715fab5d3b2017672f2d5357f335727dee40133285d1a3  scripts/test_mac_reopen_settle.py
- sha256:36436ca038ad3c413edfd885c6621741c228a645fb0da7a45c1eb155c0b21388  scripts/test_menubar_panel_log.py

## Prüfbasis

- base: c885f7a0f78b21b748aac358f34d91923c0c02ba
- blob:3e938522dcebe42021fb461f297f8a34cfc3d88d  LooseEndsUITests/MacGalleryTests.swift
- blob:73dd9ade4f421c10a80dc9e042b81513ac4aa959  scripts/test_mac_panel_repeat_summary.py
- blob:f01b5540400ae800da4099c60345290085fd4d91  scripts/test_mac_reopen_settle.py
- blob:21747de747dc891779d8517c529e2b1dcf95a632  scripts/test_menubar_panel_log.py
