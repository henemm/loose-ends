# Context: fix-978-s5-kurzer-klick (#978 Schnitt v5)

## Request Summary
Die Wiederöffnungstests des Mac-Menüleistenpanels sollen kurz klicken wie ein Mensch, die Haltedauer (Maus runter → hoch)
aus dem Panel-Protokoll messen und nur dann, wenn das Prüfwerkzeug zu lange gehalten hat, genau einmal wiederholen;
sonst hart rot. DoD von #978: Test baut den Nutzerweg nach, drei aufeinanderfolgende Läufe des Mac-Galerie-Jobs grün.

## Vorgeschichte (belegt)
- S2 (PR #992): Panel-Protokoll `MenuBarPanel` (key/resign/hide/close, Stapel, CGEvent-Felder, für 3 s nach `key` lokaler
  und globaler Maus-Monitor), Wiederholungs-Workflow `mac-panel-repeat.yml`, Auswerter `scripts/mac_panel_repeat_summary.py`.
- S3 v1–v3 widerlegt: Warten auf Ruhe der vordersten App, Klick über vorderste App, Klick über deren Menüleiste — der Fall
  trat trotzdem auf (Befunde `docs/artifacts/fix-978-s3-wiederoeffnen-warten/befund-*.md`).
- S3 v4 (PR #994, 33a102b): Halteprobe `testHoldDurationProbe`, Lauf 45602877961: `click(forDuration: 1.0)` 20/20 zu,
  `click(forDuration: 0.1)` 0/20 zu. Ursache: langes Halten auf dem Statusobjekt schließt das Panel (Systemverhalten wie
  bei Menüs, StableBar #904: ≥ 700 ms). Fälle bei `click()`: key→Maus hoch 0,71/0,90/0,93 s; Erfolge ≤ 0,36 s.
- Testläufer-Monitor (`HoldMonitor`, globaler NSEvent-Monitor) sah 0/40 XCTest-Klicks → Haltedauer nicht im Läufer messbar.
- Beim kurzen Klick steht im Panel-Protokoll **kein** Maus-hoch (das Ereignis bleibt beim Statusobjekt); der Auswerter paarte
  dann fälschlich mit späterem Maus-hoch (11–13 s).

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsUITests/MacGalleryTests.swift` | `openPanel` (Z. ~313, `statusItem.click()`), `testMenuBarReopensAfterReturnWithOneClick`, `testMenuBarReopensAfterOpenAppWithOneClick` (Z. ~470), Kontrollarm, `testHoldDurationProbe`/`holdClick`/`HoldMonitor` (Z. ~505–585), `coordinateClick`, `waitForFrontmostSettled`, `frontmostRootClick` (v3, Z. ~643), `assertSymbolOpensPanelWithOneClick` (Z. ~670) — Hauptort des Umbaus |
| `LooseEnds/Mac/MenuBarCapture.swift` | Panel-Protokoll (`panelLogger`, Kategorie `MenuBarPanel`), `startMonitors` (Z. ~201: lokal+global, 3 s ab `key`), `logMonitored` (Typ, Fenster, Zeitstempel). Einzige Quelle der Haltedauer, die XCTest-Klicks sieht |
| `scripts/mac_panel_repeat_summary.py` | Auswerter: `parse_panel_log`, `key_to_mouse_up` (Paarung im 15-s-Fenster → Fehlpaarung beim kurzen Klick), `how_of`/`_HOW` (menubar-root/fallback-*), Arme |
| `scripts/test_mac_panel_repeat_summary.py`, `scripts/test_mac_reopen_settle.py`, `scripts/test_menubar_panel_log.py` | Skripttests, die Quelltext von MacGalleryTests/MenuBarCapture prüfen (v2/v3-Erwartungen, müssen mitwandern) |
| `.github/workflows/ci.yml` | Job „Mac Gallery (macOS)“ (Z. ~576, 60 min, `-only-testing:LooseEndsUITests/MacGalleryTests`), Protokoll-Schritt `log show … MenuBarPanel` → Artefakt `MacGalleryPanelLog` (Z. ~733) |
| `.github/workflows/mac-panel-repeat.yml` | Wiederholungsläufe je Arm, Eingaben `iterationen`, `sandbox`, `kontrollarm`, `halteprobe`; `log show` nach dem Lauf |
| `LooseEndsUITests/MacUITestSupport.swift` | `macLaunch`, `macElement`, `macMainWindow`, `macShot` |
| `docs/specs/fix-978-s3-wiederoeffnen-warten.md` | Spec v4 (Halteprobe), Regeln, Abweichungen |

## Existing Patterns
- Klickwege mit `how`-Text im Anhang `mac-gallery-<label>-click` (Zeitpunkt, vorderste App, Klickdauer, Ergebnis) — der
  Auswerter zählt daraus je Arm.
- Diagnosearme nur mit Umgebungsvariable (`LE_PANEL_CONTROL_ARM`, `LE_PANEL_HOLD_PROBE`), sonst `XCTSkip`; im Pflichtjob nie.
- Zustand an den Test: bisher nur über Accessibility (Elemente, Kennungen) und Startargumente (`--ui-testing…`); die App
  schreibt unter Tests nichts, was der Läufer liest.

## Dependencies
- Upstream: XCUITest-Klicksynthese (`click()`, `click(forDuration:thenDragTo:)`, `XCUICoordinate`), Statusobjekt-Host des
  Systems, `NSEvent`-Monitore der App, `log show` im CI-Job.
- Downstream: geschützter Check „Mac Gallery (macOS)“, `mac-panel-repeat.yml`-Auswertung, Skripttests.

## Existing Specs
- `docs/specs/fix-978-s3-wiederoeffnen-warten.md` (v4), `docs/specs/fix-978-s2-panel-ernte.md`, `docs/specs/fix-978-panel-schliesst.md`

## Risks & Considerations
- Kernfrage für die Analyse: Wie erfährt der Test die Haltedauer **während des Laufs**, um über der Schwelle zu wiederholen?
  Der Läufer sieht die Klicks nicht; `log show`/`OSLogStore` aus dem Läufer ist fraglich (Sandbox/Rechte des UI-Test-Läufers
  auf macOS, recherchieren). Möglich: die App legt den gemessenen Wert unter `--ui-testing` per Accessibility offen
  (App-Code, Kategorie Diagnose) — oder gar keine Wiederholung nötig, wenn `click(forDuration: 0.1)` die Haltedauer
  zuverlässig kurz hält (Probe: 0/20 zu, 0,036–0,137 s).
- Beim kurzen Klick fehlt Maus-hoch im Protokoll → „kein Maus-hoch in 3 s“ muss als „kurz“ gelten, nicht als „unbekannt“.
- Der v3-Klickweg (`frontmostRootClick`, harte Rückfall-Regel) liegt auf main; ein Umbau muss ihn sauber ablösen samt Skripttests.
- Galerie-Job dauert 33–41 min bei 60-min-Grenze; drei grüne Läufe = drei Reruns.
- Haltedauer-Schwelle: StableBar ≥ 700 ms, eigene Fälle ≥ 0,71 s, Erfolge ≤ 0,36 s → Schwelle irgendwo 0,4–0,7 s, begründen.
- Scoping: App-Code höchstens die Offenlegung der Haltedauer; Test-/Skriptcode zählt nicht zum LoC-Limit.
