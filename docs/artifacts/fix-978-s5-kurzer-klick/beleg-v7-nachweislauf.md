# #978 S5 v7 – Beleg Nachweislauf (DoD-Zeile 3)

- Lauf: 45676450151 (`mac-panel-repeat.yml`, `iterationen=40`, Kontrollarm an), Commit 72e7dff, Zweig `fix/978-s5-kurzer-klick`,
  2026-11-25 18:59–19:50 UTC (19:59–20:50 Uhr MEZ)
- Testergebnis: 120 Tests ausgeführt, 0 Fehler (3057 s)
- Zusammenfassung: Artefakt `MacPanelRepeatSummary` (`scripts/mac_panel_repeat_summary.py`)

## Zähler

| Arm | Nenner | Panel zu | Rate | Wiederholungen | Klickweg |
|---|---|---|---|---|---|
| return | 40 | 0 | 0,0 % | 0 | short-click 40 |
| open-app | 40 | 0 | 0,0 % | 0 | short-click 40 |
| control | 40 | 0 | 0,0 % | 0 | xcuicoordinate 40 |

Soll-Nenner 40 je Arm, keine Abweichung. Kein Panel-zu-Fall, also auch keiner unter 0,4 s und kein zweiter Fehlschlag:
Abbruchregel (b) greift nicht. Die Haltedauer je Klick (Spalte „key → Maus hoch“ aus dem Protokoll) liegt im
Open-App-Arm zwischen 0,026 und 0,135 s oder „kurz (kein Maus-hoch)“, weit unter der Schwelle 0,4 s.

## Anhänge geöffnet (DoD-Zeile 5)

- open-app (`testMenuBarReopensAfterOpenAppWithOneClick`): `how: user: short click 0.1 s`, `first click`, `hold: not read (panel open)`, darunter der Elementbaum mit dem offenen Panel (Dialog).
- return (`testMenuBarReopensAfterReturnWithOneClick`): `how: user: short click 0.1 s`, `first click`, `hold: not read (panel open)`.
- control (`testMenuBarReopensAfterReturnWithControlClick`): `how: control: XCUICoordinate click, no right to post events`, `first click`, `hold: not read (panel open)`.

Eine Wiederholung kam in keinem Arm vor; ein Anhang mit Wiederholung existiert deshalb nicht.
Die gelesene Haltedauer für lange Klicks ist in der Halteprobe belegt (`beleg-v7-halteprobe.md`, Lauf 45672549713).
