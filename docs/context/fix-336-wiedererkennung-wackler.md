# Context: fix-336-wiedererkennung-wackler

## Request Summary
`RecognitionWalkthroughTests.testWordEqualRecaptureTakesOverDurationAndContext` war in der CI einmal rot
(Lauf 38155552783, Versuch 1, Stand 8d33b90), die Wiederholung grün. Ziel aus #336/#172: Ursache aus dem
`.xcresult` belegen, Test beim ersten Versuch grün, drei CI-Läufe in Folge grün.

## Befund aus den Ergebnisbündeln (beide Versuche heruntergeladen und verglichen)

| | Rot (Versuch 1) | Grün (Versuch 2) |
|---|---|---|
| Tipp auf `topRow` | `taskRow_C009DDC6… Button`, richtige Zeile | richtige Zeile |
| Detailansicht | laut Bildschirmaufnahme ab t≈31 s offen, „Zaun streichen“, bis zum Abbruch | offen |
| `Find the "detailRawTextMarker"` | 9,2 s (…:00,72 → …:09,88), Schnappschuss leer (nur App-Wurzel, `children` leer) | 0,28 s |
| Watchdog der App | `Main thread blocked for 9.0 s` (17:05:00,8–17:05:09,8) | nur der Start-Hänger 5,3 s |
| App-CPU (`host-load.log`) | 115 % um 17:04:51, 75 % um 17:05:12 | bis 82 % |
| Speicher | frei 45–46 %, swapouts 0 | frei 45–46 %, swapouts 324 |

- `waitForLabel` (Test, Zeile 130) nutzt eine `XCTNSPredicateExpectation` mit 10 s. Die erste Auswertung
  hing 9,2 s an der blockierten App, eine zweite fand vor Fristende nicht mehr statt.
- Die drei Vermutungen aus dem Ticket sind widerlegt (falsche Fläche, Zeile nicht oben, langsames Öffnen).
- **Lauf-weites Muster, nicht detailspezifisch:** Hänger ≥ 3 s, die mehr als 5 s nach einem App-Start
  beginnen: rot 12+ (29,1 s · 20,7 s · 10,1 s · 9,6 s · 9,0 s · 8,0 s …, in verschiedenen Tests),
  grün 4 (höchstens 7,3 s). Insgesamt 103 bzw. 72 Watchdog-Meldungen.
- In den roten Fenstern liegt `LooseEnds` selbst bei ~100–115 % CPU (ein Kern), Speicher ohne Druck.
  Anders als in #228 (Speichermangel, Poster-Sturm) ist hier kein Speichertief zu sehen.
- Hang-Berichte (spindump) sammelt die CI nur bei „Timed out while evaluating UI query“ oder fehlender
  Prozess-ID (`ci.yml` ~Zeile 233); dieser Fehler war eine gewöhnliche Zusicherung, also kein Stack.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | `topRow` (79), `waitForLabel` (130, 10 s), Fehlerstelle 167 |
| `LooseEnds/Views/TaskDetailView.swift` | Marker `detailRawTextMarker` (Hintergrund-Element, 65–71), `.onAppear` → `markSeen` + `save` (204–207, 430) |
| `LooseEnds/Views/TaskRow.swift` | Kennung `taskRow_*` (88) |
| `LooseEnds/App/MainThreadWatchdog.swift` | Watchdog nur unter `--ui-testing` (#228) |
| `.github/workflows/ci.yml` | `host-load.log`, `watchdog.log`, Hang-Sammlung nur bei UI-Query-Timeout (175–270) |
| `LooseEndsUITests/CaptureSmokeTests.swift`, `DesignGalleryTests.swift` | nutzen denselben Marker |

## Existing Patterns
- Warten über `waitForExistence`/`XCTNSPredicateExpectation` mit 2–10 s, keine gemeinsame Wartehilfe für
  „App hängt kurz“.
- CI-Diagnose aus #228/#243/#255/#260/#262: Watchdog, Lastprobe alle 20 s, Speicherwerte, Poster-Dienste
  vor den Tests abgeschaltet. #228 ist seit 2026-10-08 geschlossen (10 grüne Läufe).
- #172: UI-Tests sollen beim ersten Versuch grün sein, die CI-Wiederholung ist entfernt.

## Dependencies
- Upstream: XCTest-Schnappschüsse werden im Hauptthread der App beantwortet; SwiftData-`save` in `markSeen`.
- Downstream: Jede Änderung an Wartezeiten der UI-Tests wirkt nur auf die CI-Laufzeit, nicht aufs Produkt.

## Existing Specs
- Keine eigene Spec für die Detailansicht-Wartelogik; #228 (Kommentare) ist die Vorgeschichte.

## Risks & Considerations
- Nur den Test großzügiger warten zu lassen verdeckt einen möglichen echten Hänger der App.
- Ob die App beim Öffnen der Detailansicht selbst Hauptthread-Arbeit macht, ist **nicht belegt**: der
  grüne Lauf zeigt dort keinen Hänger, der rote hängt in vielen Tests. Das muss die Analyse lokal
  nachstellen (Simulator unter CPU-Last, Watchdog, Time Profiler beim Öffnen der Detailansicht).
- Gerät ist nicht betroffen: kein Pfad der Geräteliste.
