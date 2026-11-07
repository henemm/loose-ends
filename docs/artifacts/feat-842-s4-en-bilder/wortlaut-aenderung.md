# #842 S4a — Wortlaut-Änderung nach dem ersten englischen Lauf

- Datum: 2026-11-07
- Befund: Erster Lauf `LOOSEENDS_UI_LANG=en ./scripts/sim.sh store-screenshots` (iPhone 17) brach in `photographStart` ab:
  „Jetzt should show at least two rows“ (1 < 2). Unter „Now“ standen nur „Check the tax notice“ und, nach dem
  Erledigen von „Water the flowers“, keine zweite Zeile; „Call Anna about Sunday today“ fehlte.
- Ursache: `DateExpressionParser.expression(in:)` nimmt die **früheste** Zeitangabe im Satz. Deutsch „Anna **heute**
  wegen Sonntag anrufen“ → heute; Englisch „Call Anna about **Sunday** today“ → Sunday (2026-11-08), also nicht „Now“.
- Spec-Vorgabe (Implementation Details 5, Risiko c): Abweichung im Aufbau → Satz nach Rücksprache ändern, nicht Bild.
- Entscheidung Henning (AskUserQuestion, 2026-11-07): **„Call Anna today about Sunday“** statt „Call Anna about Sunday today“.
  Die übrigen vier Sätze bleiben wie freigegeben. AC-9 gilt für diesen Satz mit dem neuen Wortlaut.

## Wichtigkeit bei „Check the tax notice“ (2026-11-07)

- Befund: Englische Bilder 01/03/04 zeigen „!!!“ und im Detail „Importance High“; die deutschen (auch der Vergleichslauf
  von heute) bei „Steuerbescheid prüfen“ nicht. Ursache: `EnglishPack` „official“ enthält `tax` (ganzes Wort), `GermanPack`
  nur `steuer`/`steuererklärung`; das Kompositum „Steuerbescheid“ trifft nicht. Annahme der Spec (Punkt 5, „amtlich, beide
  gleich“) war falsch.
- Entscheidung Henning (AskUserQuestion, 2026-11-07): **so lassen** — „Check the tax notice today“ bleibt, das Bild zeigt das
  echte Verhalten. Die deutsche Lücke wird ein eigenes Ticket.
- Satz des Tages („Today two things due.“ / „Heute zwei Dinge fällig.“): tagesabhängig, nicht sprachabhängig — der deutsche
  Vergleichslauf von heute zeigt denselben Satz.

## Umfang über der Grenze (2026-11-07)

- Stand: 6 Dateien, +242/−36 = 278 LoC (Schätzung der Spec ca. 150, Grenze ±250, 4–5 Dateien).
- Zuwachs aus den echten Läufen: iPad-Kennung `startNowRow_` seit #827, Druck als Tippen öffnet das Detail, iPad-Taste
  „Hide keyboard“, Datum der iPad-Statusleiste in der Systemsprache des Simulators → `store_set_lang`/`store_restore_lang`
  in `sim.sh` samt `StoreSimulatorLanguageTests` in `scripts/test_sim_run_xcodebuild.py` (6. Datei).
- Entscheidung Henning (AskUserQuestion, 2026-11-07): **Überhang annehmen**, kein Teilen.
