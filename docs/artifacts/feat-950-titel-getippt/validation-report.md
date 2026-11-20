# Validation Report: feat-950-titel-getippt (2026-11-20)

## Test Results
- Unit-Suite (`./scripts/sim.sh unit`): grün, Exit 0; XCTest-Bündel u. a. 100/100, keine Fehler.
- `test-proof InboxDrawerSmokeTests`: 2/2 bestanden, 0 übersprungen (`ui-drawer-proof.txt`).
- `test-proof CaptureSmokeTests`: 29/29 bestanden, 0 übersprungen (`simulator-run.txt`, Kopf e7eb07a, Hashes nach F001).
  Erster Lauf brach nach 12 grünen Tests ab, weil der App-Bau während des Laufs aus DerivedData gelöscht wurde
  („Cannot launch simulated executable: no file found“, Platte 9,6 GB frei, alle anderen LooseEnds-DerivedData-Ordner
  ebenfalls weg); zweiter Lauf auf demselben Stand vollständig grün.

## Beleg angesehen
- `950-sheet-getippt` (CaptureSmokeTests/testTypedCaptureKeepsItsWordingAsTitle): Detailansicht zeigt als Titel
  „Angebot für die Gartenhütte bei Müller einholen“, unverändert wie getippt; Hinweis „Not sorted yet“ (Modell unter
  `--ui-testing` aus), keine Tags gesetzt.

## Spec Compliance
- Alle Punkte aus Scope, Implementation Details und Test Plan (Tests 1–8, beide Smoke-Tests) erfüllt.
- Hinweis aus der Prüfung: „Gartenhütte“ könnte über den Wortanfang „Garten“ den Kontext Garten treffen; der Satz der
  Spec sollte kontextfrei sein. Im Beleg ist kein Tag gesetzt, der Titel-Assert ist davon unabhängig. Kein Fix.

## Regression Check
- Keine Regressionen.

## Scope Check
- 8 Dateien (5 Produktiv und Doku, 3 Test) wie in der Spec, +207/-7 LoC (Limit 250). Nichts außerhalb der Spec.

## Result: PASS
