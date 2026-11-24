# #978 S3 — Befund: Mac Gallery rot in Versuch 3 (CI-Lauf 45387184786, Commit a24a607)

Stand 2026-11-24. AC-5 (drei grüne Galerie-Läufe) ist **nicht erfüllt**; der Ansatz von Schnitt 3 ist für diesen Fehlerweg widerlegt.

## Läufe
- Versuch 1 (Job 138421060283): grün.
- Versuch 2 (Job 138487582555): `cancelled`, Zeitlimit `timeout-minutes: 40` (`ci.yml:541`); alle Tests grün („Executed 18 tests, with 0 failures“), Job 40 min 32 s.
  Auch auf main liegt der Job bei 33–41 min (2026-11-21: 33 min, 2026-11-23: 38 min, 2026-11-24: 40,5 min): Zeitgrenze ist ein eigenes, vorbestehendes Problem.
- Versuch 3 (Job 138515652833): rot, `testMenuBarReopensAfterOpenAppWithOneClick`, „One click on the symbol opened no panel (reopen-open-app)“.
- Skripttests auf dem Zweig waren zusätzlich rot (`test_menubar_panel_log.py` verlangte noch `XCTExpectFailure`); im Arbeitsbaum behoben, noch nicht committet.

## Zeitachse Versuch 3 (UTC; App-PID 24959 durchgehend, kein Neustart)
| Zeit | Test | App-Protokoll (MenuBarPanel) |
|---|---|---|
| 20:11.5–12.6 | `waitForFrontmostSettled`: Finder, „settled after 1.05 s“ | Finder vorn seit 04.239 |
| 20:12.598 | Click StatusItem | – |
| 20:12.631 | XCTest selbst: „Open/Activate com.henning.looseends“ | 12.668 become-active |
| 20:12.694 | Synthesize event (bis 18.326, 5,6 s) | 13.095 Finder wieder aktiv |
| | | 13.150 panel key (`_beginExpandedInterfaceSession`) |
| | | 13.992 Maus hoch, **0,897 s nach key** |
| | | 14.030 resign, 14.093 hide (`_endExpandedInterfaceSession` ← `FBSScene handlePrivateActions`, vom System-Host) |
| 20:18.333–28.385 | `waitForExistence` findet kein Panel | – |

## Belegt
- Das Panel ging auf und wurde ~40 ms nach einem verspäteten Maus-hoch vom System-Host geschlossen, noch während `click()` lief. Die App hat es nicht selbst geschlossen.
- Abstand key → Maus hoch: Wiederholungslauf 45387179906 (231 Öffnungen) min 0,100 s, Median 0,137 s, p95 0,206 s, max 0,225 s, alle offen; Galerie-Versuch 1 0,202 s offen; Fehlfall 0,897 s.
- Den App-Wechsel löst XCTest **innerhalb** von `click()` aus (Activate der Ziel-App, die nicht vorn ist). `waitForFrontmostSettled` vor dem Klick kann ihn nicht verhindern; die 3-s-Haltezeit sieht den Fall nie, weil das Panel schon vor `waitForExistence` zu ist.

## Hypothese (gut gestützt, Apple-Quelle fehlt)
Ein Klick mit langem Drücken-Halten (≈ 0,9 s) wird vom Menüleisten-Host wie bei NSMenu als Drücken-Halten-Loslassen behandelt und schließt beim Loslassen.
Quellen: cocoa-dev „Keeping open menu after mouse up“ (2011, NSMenu); Apple Forums thread 836113 „Various menu bar NSStatusItem issues with macOS 27“ (nicht inhaltlich geprüft).

## Folgerung für den nächsten Ansatz (Spec-Nachbesserung)
- Ursache liegt im Testwerkzeug (synthetischer Klick mit Aktivierung und zeitweise langem Halten), nicht in der App: ein echter kurzer Klick blieb 231/231 offen.
- Kandidaten: Klick ohne XCTest-Aktivierung der Ziel-App und mit festem kurzem Abstand (z. B. CGEvent down/up direkt), oder Erkennung „ging auf und wieder zu während des Klicks“ über das Panel-Protokoll und Unterscheidung in der Meldung.
- Rohdaten (Scratchpad, flüchtig): Auszüge der Anhänge und Protokolle von Versuch 1 und 3.
