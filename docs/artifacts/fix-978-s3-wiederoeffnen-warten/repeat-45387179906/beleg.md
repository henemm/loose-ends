# AC-6 Beleg: mac-panel-repeat.yml Lauf 45387179906 (Zweig fix/978-s3-wiederoeffnen-warten, 40 Iterationen, Kontrollarm an)

Ergebnis (`summary/mac-panel-repeat-summary.md`): return 40/0, open-app 40/0, control 40/0, Soll-Nenner 40, keine Abweichung, Fälle 0.

Geöffneter Klickanhang (Export aus `MacPanelRepeat.xcresult`, 120 Klickanhänge): Zeilen `click:`, `how:`, `frontmost before the click:`,
Verlauf (`front 0.00 s com.henning.looseends`, `settled after 1.04 s`), dann die Hierarchie, letzte Zeile `after: 9.90 s, panel open`.
Alle 120 Anhänge beenden die Wartehilfe mit `settled after …`, keiner mit `timeout after 10 s`. Der Kontrollarm klickte wie in S2 per
XCUICoordinate-Rückfall.
