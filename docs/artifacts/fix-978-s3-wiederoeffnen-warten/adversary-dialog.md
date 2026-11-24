# Adversary Dialog — fix-978-s3-wiederoeffnen-warten
Spec: docs/specs/fix-978-s3-wiederoeffnen-warten.md
Datum: 2026-11-24 14:29

## Checkliste
- [x] **AC-1:** Given `LooseEndsUITests/MacGalleryTests.swift` / When der Diff geprüft wird / Then enthalten die Wiederöffnungstests kein `XCTExpectFailure` und kein `continueAfterFailure = true` mehr. Belegt durch Diff und `grep` auf beide Wörter in der Datei.
- [x] **AC-2:** Given `assertSymbolOpensPanelWithOneClick` / When der Diff geprüft wird / Then ist die Reihenfolge Symbol existiert, ruhig warten (`waitForFrontmostSettled`: vorderste App seit 1 s unverändert, Abfrage alle 0,1 s, Obergrenze 10 s, danach trotzdem klicken und den Ablauf im Anhang vermerken), genau ein Klick, Panel binnen 10 s, nach 3 s noch vorhanden, Anhang, harte Assertions; es gibt keinen zweiten Klick und keine Wiederholung. Belegt durch Diff.
- [x] **AC-3:** Given die Arme Return, ⌘W und Kontrollarm / When der Diff geprüft wird / Then gehen alle drei durch `assertSymbolOpensPanelWithOneClick` mit derselben Wartehilfe; der Kontrollarm bleibt mit `XCTSkip` ohne `LE_PANEL_CONTROL_ARM` geschützt. Belegt durch Diff.
- [x] **AC-4:** Given der Klickanhang `mac-gallery-<label>-click` / When er geschrieben wird / Then behält er `click:`, `how:` und als letzte Zeile `… panel open|not open` (open = offen und nach 3 s noch offen), die Verlauf-Zeilen der vordersten App stehen davor, und `scripts/test_mac_panel_repeat_summary.py` ist ohne Änderung am Skript grün. Belegt durch die Skript-Tests und einen geöffneten Anhang.
- [ ] **AC-5:** Given der Pflicht-Check „Mac Gallery (macOS)“ / When er auf dem PR-Zweig dreimal nacheinander läuft / Then ist er jedes Mal beim ersten Versuch grün, ohne `XCTExpectFailure`. Belegt durch drei Läufe, deren Ergebnisbündel geöffnet und beschrieben sind.
- [x] **AC-6:** Given `mac-panel-repeat.yml` auf dem PR-Zweig mit mindestens 40 Iterationen und Kontrollarm / When er endet / Then nennt `MacPanelRepeatSummary` je Arm Nenner ≥ 40 und Zähler 0 (keine Abweichung vom Soll-Nenner). Belegt durch das Artefakt, geöffnet und beschrieben.
- [x] **AC-7:** Given der Diff / When er geprüft wird / Then berührt er nur `LooseEndsUITests/MacGalleryTests.swift` (App-Code 0 LoC; `MenuBarCapture.swift`, `mac-panel-repeat.yml`, `mac_panel_repeat_summary.py` unverändert), und der Build der UI-Test-Bundles ist grün. Belegt durch `git diff --stat` und den Bau.

## Dialog

### Runde 1
**Adversary:** Frühere Dialoge übersahen den roten CI-Schritt „Script tests“ (`test_click_check_in_non_strict_expect_failure`). Ich habe die volle Skriptsuite wie in `ci.yml` (venv, pyyaml~=6.0, pillow~=12.0, `unittest discover -s scripts -p 'test_*.py' -v`) selbst gefahren: Ran 846 tests, OK (skipped=1; übersprungen ist `test_datenschutz_text.LiveTests.test_live_pages`, braucht `DATENSCHUTZ_LIVE=1`, unabhängig vom Ticket). Ausgabe: `adversary-test-output.txt`. 0 FAIL, 0 ERROR.
Andere Skripte mit Annahmen über `MacGalleryTests.swift`: `scripts/test_ci_xcode27.py` (`-only-testing`-Name, Quellenliste), `scripts/test_mac_panel_repeat_summary.py` (Anhangformat), `scripts/test_menubar_panel_log.py`, `scripts/test_mac_reopen_settle.py`. Alle grün; keine verletzte Annahme.
Der Fix in `test_menubar_panel_log.py`: Klasse `TestOpenAppArmIsHard` verlangt kein `XCTExpectFailure` und kein `continueAfterFailure = true` im ⌘W-Test und dass `assertSymbolOpensPanelWithOneClick` nach dem Aufbau steht. Die Prüfung ist nicht abgeschwächt, sondern auf den Sollstand umgekehrt (`assertNotIn("XCTExpectFailure")`); kehrt die Klammer zurück, wird sie rot (AC-1).
Swift: `MacGalleryTests.swift` enthält weder `XCTExpectFailure` noch `continueAfterFailure = true` (nur `= false` in setUp, Zeile 17). Reihenfolge in `assertSymbolOpensPanelWithOneClick`: Symbol 10 s, `waitForFrontmostSettled`, ein Klick, 10 s Panel, 3 s Halten, Anhang, `XCTAssertTrue(opened)`. Kein zweiter Klick. Alle drei Arme rufen dieselbe Funktion; Kontrollarm hat `XCTSkip` ohne `LE_PANEL_CONTROL_ARM`.
Angriffsversuche: (a) vorderste App wird nie ruhig: nach 10 s „timeout after 10 s“ und Klick trotzdem, wie spezifiziert. (b) `frontmostApplication` ohne RunLoop würde nie aktualisieren: die Schleife dreht `RunLoop.current.run(until:)` je 0,1 s. (c) Anhang-Vertrag: letzte Zeile `after: … s, panel open|not open` bleibt letzte, Verlauf davor; Skripttests grün. (d) „geht auf, geht zu“ zählt als „not open“ und lässt den Test hart scheitern.
**Implementierer:** Fix und Änderung belegt, siehe Bestätigungen.

### Runde 2
**Adversary:** Aktualitätsprüfung. Der Diff von `LooseEndsUITests/MacGalleryTests.swift` gegen Commit a24a607 ist leer: die Datei ist seit dem GREEN-Commit unverändert, der Bau-Beleg `mac-build-for-testing-summary.txt` gilt weiter. Der Diff-Vergleich Basis 688d107 gegen HEAD über `LooseEnds/`, `server/`, `.github/`, `scripts/mac_panel_repeat_summary.py` ist leer (AC-7: App-Code 0). Geändert sind Testcode, Doku-Artefakte, `scripts/test_mac_reopen_settle.py` (neu) und `scripts/test_menubar_panel_log.py` (Fix, noch nicht committet).
AC-6: `gh run view 45387179906` meldet headSha a24a607273bed04d2198cffda63d5ec25b8da3aa, conclusion success. `repeat-45387179906/summary/mac-panel-repeat-summary.md` geöffnet: return 40/0, open-app 40/0, control 40/0, Soll-Nenner 40, keine Abweichung, Fälle 0; Klickweg statusitem 40/40, Kontrollarm xcuicoordinate 40. `beleg.md`: 120 Klickanhänge, alle enden mit „settled after …“, kein Timeout, letzte Zeile „panel open“. Einwand: 0/40 beweist bei früherer Rate (1/420 bis 13 %) die Wirkung nur statistisch; die Spec fordert nicht mehr, AC-5 deckt den Pflicht-Job.
AC-5: offen. Lauf 45387184786: Gesamtlauf `queued`, Job „Mac Gallery (macOS)“ completed/success; das ist ein Lauf, nicht drei. Nicht als erfüllt gewertet.
Restrisiko, kein Defekt: Der Fix `scripts/test_menubar_panel_log.py` ist noch nicht committet; die CI sieht ihn erst mit dem Commit.
**Implementierer:** Keine Gegenrede.

## Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/MacGalleryTests.swift:467
  Evidence: Der ⌘W-Test enthält kein XCTExpectFailure und kein continueAfterFailure = true (grep); setUp setzt nur = false (Zeile 17). Der Fix scripts/test_menubar_panel_log.py:53 (TestOpenAppArmIsHard) hält das fest und läuft grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/MacGalleryTests.swift:557
  Evidence: Reihenfolge Symbol (10 s), waitForFrontmostSettled (Zeile 561; 0,1-s-Takt, 1 s ruhig, 10 s Grenze, 528-550), genau ein Klick (564), Panel 10 s (565), 3 s Halten (569), Anhang, XCTAssertTrue(opened) (584). Kein zweiter Klick. scripts/test_mac_reopen_settle.py prüft das statisch, grün.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/MacGalleryTests.swift:498
  Evidence: Return (457), ⌘W (476) und Kontrollarm (498) rufen alle assertSymbolOpensPanelWithOneClick; Kontrollarm wirft XCTSkip ohne LE_PANEL_CONTROL_ARM (486-487).
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: scripts/test_mac_reopen_settle.py:1
  Evidence: Anhang click:, how:, Verlauf, letzte Zeile after: … panel open|not open (MacGalleryTests.swift:573-580); test_mac_panel_repeat_summary.py in der vollen Suite grün, mac_panel_repeat_summary.py unverändert; geöffneter Anhang laut repeat-45387179906/beleg.md.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/test_menubar_panel_log.py:53
  Evidence: Lauf 45387179906 auf headSha a24a607 (success), MacGalleryTests.swift seither unverändert; Zusammenfassung 40/0 je Arm, Soll-Nenner 40, keine Abweichung.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: LooseEndsUITests/MacGalleryTests.swift:2
  Evidence: App-Code, mac-panel-repeat.yml und mac_panel_repeat_summary.py gegenüber Basis unverändert; Bau der UI-Test-Bundles durch mac-build-for-testing-summary.txt belegt, Datei seither unverändert.
  Status: CONFIRMED

AC-5: OFFEN (in dieser Phase nicht belegbar, nichts erfunden). Stand Lauf 45387184786: Job „Mac Gallery (macOS)“ completed/success, Gesamtlauf queued; nur ein Lauf.

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: VERIFIED

Tests: 846 passed, 0 failed, 1 übersprungen (test_datenschutz_text.LiveTests.test_live_pages, braucht DATENSCHUTZ_LIVE=1)
Edge cases: geprüft, keine gebrochen
Regressions: keine
Checklist: 6/7 bewiesen; AC-5 offen (drei grüne Pflicht-Läufe, in dieser Phase nicht belegbar)

## Geprüfte Dateien

- sha256:7ee4cc38064487a8c2c9fece81e05ecb17b3fcbc3d224b26f78f2d461342d338  LooseEndsUITests/MacGalleryTests.swift
- sha256:e2fc49fe1a93f33c6bd40a4525627d48271189c854d059a6884a00f8815caa0c  scripts/test_mac_reopen_settle.py
- sha256:36436ca038ad3c413edfd885c6621741c228a645fb0da7a45c1eb155c0b21388  scripts/test_menubar_panel_log.py

## Prüfbasis

- base: 688d1074e6c34f7c1062b76c9774687b1dc07992
- blob:68ee50ea0a8dd8155174a723c15ca9fd045b9d87  LooseEndsUITests/MacGalleryTests.swift
- blob:89d2636efdcadd86d8e07ec1105b8c9e8eeccc77  scripts/test_mac_reopen_settle.py
- blob:21747de747dc891779d8517c529e2b1dcf95a632  scripts/test_menubar_panel_log.py

## Geprüfte Dateien

- sha256:7ee4cc38064487a8c2c9fece81e05ecb17b3fcbc3d224b26f78f2d461342d338  LooseEndsUITests/MacGalleryTests.swift
- sha256:e2fc49fe1a93f33c6bd40a4525627d48271189c854d059a6884a00f8815caa0c  scripts/test_mac_reopen_settle.py
- sha256:36436ca038ad3c413edfd885c6621741c228a645fb0da7a45c1eb155c0b21388  scripts/test_menubar_panel_log.py

## Prüfbasis

- base: 688d1074e6c34f7c1062b76c9774687b1dc07992
- blob:68ee50ea0a8dd8155174a723c15ca9fd045b9d87  LooseEndsUITests/MacGalleryTests.swift
- blob:89d2636efdcadd86d8e07ec1105b8c9e8eeccc77  scripts/test_mac_reopen_settle.py
- blob:21747de747dc891779d8517c529e2b1dcf95a632  scripts/test_menubar_panel_log.py
