# Validation Report: feat-480-s2-startseite-tasten (#480 Schnitt 2)

Stand: a521248 (auf origin/main 760f1f6), 2026-10-23

## Test Results
- Unit (`./scripts/sim.sh sim-unit`, iPhone-Simulator): 900 bestanden, 0 fehlgeschlagen. Nicht gemessen:
  SelfConsistencyReportTests (Messdatei `selfconsistency-run.json` fehlt), Latenzschutz #274 (de_DE im Simulator nicht installiert).
  Beides ohne Bezug zu diesem Schnitt. Datei: `sim-unit-output.txt`.
- Simulator-Beleg (`test-proof StartScreenInteractionTests`, iPhone 17 / iOS 27.0, HEAD a521248): 20 gesamt, 20 bestanden,
  0 übersprungen (`simulator-run.txt`, drei Bilder geöffnet: Startseite, „Alle offen“, Parken — unverändert).
- CI 39916257254 (b5a9fdd): Mac Gallery 13/13, MacDetailClickTests 10/10, MacKeyboardTests 18/18; iOS UI Smoke 73 ausgeführt,
  6 übersprungen (DueNotificationTapTests ×3, PlaceNotificationTapTests ×3, brauchen LOOSEENDS_PUSH), 0 fehlgeschlagen.
- CI auf a521248 (nach dem Aufsetzen auf main): siehe PR #626.

## Spec Compliance
- Acceptance Criteria: 14/14 erfüllt (Adversary 2 Runden VERIFIED, Spec-Abgleich).
- AC-10: Fotos `mac-keyboard-start-selection-light/-dark.png` (CI 39916257254) geöffnet: Aufgabe 2 gewählt in Akzent-Tönung,
  Aufgabe 4 mit grauem Hover, hell und dunkel.
- AC-9 Randfall aus dem Spec-Abgleich (Zeile 6/7 gewählt, nach Rückkehr zugeklappt): die gespeicherte Auswahl ist dann nicht
  in den sichtbaren Zeilen; `RowKeyAction.resolve` behandelt sie wie keine Auswahl (Pfeil beginnt oben, Leertaste/Rücktaste
  tun nichts). Kein Fehlverhalten.
- AC-11: iOS-Zweig der Jetzt-Zeile wörtlich wie Basis; neue Parameter `onWritingFocus`/`expanded` haben iOS-neutrale
  Standardwerte; iPad-Bilder vorher/nachher gleich bis auf die Uhr.

## Regression Check
- Status: Keine Regressionen.

## Scope Check
- Code-Dateien: 6 (5 Produkt + 1 Test), alle in der Spec genannt.
- LoC: Produkt +180/−8, Tests +310/−1. Überschreitung der 250 vom PO freigegeben (Auswahl „So lassen“).
- project.yml / xcodeproj unverändert, keine Tmp-Datei.

### Result: PASS
