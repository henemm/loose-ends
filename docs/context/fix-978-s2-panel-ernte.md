# Context: fix-978-s2-panel-ernte (#978 Schnitt 2)

## Request Summary
Die roten Läufe des Jobs „Mac Gallery (macOS)“ mit Panel-Protokoll (seit #981, 2026-11-23) auswerten und fehlende Fälle
selbst per Wiederholungsläufe herbeiführen, ohne Sammel-Stichtag (PO 2026-11-23). Ziel laut DoD: Ursache mit Beleg
(App oder Prüfwerkzeug), dann Fix bzw. Testumbau, Test wieder hart und dreimal hintereinander grün.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Mac/MenuBarCapture.swift` | `MenuBarPanelLog.record` (Z. 111) und `MacAppDelegate.observeWindows`/`observePanelHiding` (Z. 190–228): Zeilen `key`/`close`/`resign`/`hide` mit Fensterklasse, `NSApp.currentEvent`, vorderster App, Aktivierungsrichtlinie, Stack |
| `LooseEndsUITests/MacGalleryTests.swift` | `openPanel` (Z. 311), `testMenuBarReopensAfterReturnWithOneClick` (Z. 445, hart), `testMenuBarReopensAfterOpenAppWithOneClick` (Z. 466, `XCTExpectFailure` nicht strikt), `assertSymbolOpensPanelWithOneClick` (Z. 485, Anhang `…-click` mit Klickzeit) |
| `LooseEndsUITests/MacUITestSupport.swift` | `macOpenMainWindowIfNeeded` (Z. 38): zweites Fehlerbild „Menu bar panel shows no Open Loose Ends“ |
| `.github/workflows/ci.yml` | Job „Mac Gallery (macOS)“, Panel-Log per `log show` (Z. ~692), Artefakte `MacGalleryPanelLog`, `MacGalleryResults` (xcresult + Logs) |
| `docs/artifacts/fix-862-menubar-panel/`, `docs/artifacts/fix-978-panel-schliesst/` | frühere Zeitachsen, Panel-Logs aus S1 |

## Erste Befunde (2026-11-23, beim Sammeln)
- main-Lauf 45138541451 (4cc97f6), rot: `testMenuBarReopensAfterReturnWithOneClick`. Panel-Log, Prozess 23297:
  `key` 09:21:13 (öffnen), `resign`/`hide` 09:21:22 (Return, ev=10), Klick des Tests angefordert 09:21:24.239,
  `key` 09:21:24.562 (ev=13, front Finder, accessory), **`resign` 09:21:25.373 mit ev=21**, `hide` 09:21:25.440.
  XCTest meldet das synthetisierte Klickereignis erst 09:21:29.798 fertig (5,5 s), dann 10 s Warten, kein Panel.
  → Das Panel ging auf und **nach 0,8 s wieder zu**, mitten in der Klicksynthese. Die Deutung im Issue-Kommentar
  („fünf key ohne resign“) war falsch: das sind fünf verschiedene Prozesse (je ein Test, Ende per `terminate`).
- PR-Lauf 45070786960 (S1, abgebrochen), Prozess 27700 = `reopen-open-app`: `key` ev=13 → nach 1,0 s `resign` ev=21.
  Dasselbe Muster beim ersten Fehlerbild.
- `ev=21` ist kein öffentlicher `NSEventType` (SDK 27.2: 18 Rotate, 19/20 Gesten, 22 ScrollWheel); 21 fehlt in den Headern.
  Recherche (Apple-Doku, Foren) ergab keine Bedeutung. In grünen Wiederöffnungen folgt auf `key` ev=13 kein `resign`.

## Existing Patterns
- Belege werden nach `docs/artifacts/<workflow>/` übernommen (gefiltert, keine Nutzerdaten).
- Diagnose-Workflow `diag-862.yml` (Draft-PR #975) für gezielte Wiederholungen; Wiederholung des echten Jobs per
  `gh run rerun --job`.

## Dependencies
- Upstream: SwiftUI `MenuBarExtra(.window)`, AppKit-Aktivierung (accessory/regular), XCUITest-Klicksynthese.
- Downstream: Pflicht-Check „Mac Gallery (macOS)“ macht fremde PRs rot (#983).

## Risks & Considerations
- Seltenes Ereignis: Wiederholungen nötig; Runner-Minuten (macOS) teuer, je Lauf ~35 min.
- Ein Testumbau darf den Nutzerweg nicht verwässern (DoD: prüft den Nutzerweg).
- Event 21 könnte von XCTest (synthetisierte Ereignisse) stammen → Prüfwerkzeug; nicht belegt, bis mehr Fälle da sind.
