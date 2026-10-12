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

## Analysis

### Type
Bug (wackelnder UI-Test, kein Produktfehler)

### Root Cause (belegt)
XCTest lässt sich jeden Schnappschuss des Elementbaums von der App **auf ihrem Hauptthread** bauen. Auf dem
ausgelasteten CI-Rechner dauert das bis zu 29 s. Im roten Lauf hing die **erste und einzige** Auswertung von
`waitForLabel` (10 s Frist) 9,2 s und lieferte einen leeren Baum, für eine zweite Auswertung blieb keine Zeit.

Belege:
- Zuordnung aller Watchdog-Blockaden ≥ 3 s des roten Laufs zu den XCTest-Aktivitäten
  (`docs/artifacts/fix-336-wiedererkennung-wackler/correlate.py`, Ergebnisbündel a1): 31 von 31 beginnen entweder beim Einrichten der Testsitzung
  („Setting up automation session“, 5–8 s, jeder Test) oder 0,0–1,4 s nach einer Element-Abfrage
  („Checking existence of …“, „Find the …“). Fast immer ist es eine Abfrage über `.any` („captureTextField Any“,
  „Any (First Match)“, „calendarTargetRow Any“, „detailRawTextMarker Any“), einmal `Button (First Match)` (3,1 s).
  Ohne Test-Abfrage gibt es keine einzige Blockade.
- Fehlerstelle: Die Abfrage beginnt um :00,724, der Watchdog meldet die Blockade ab ≈ :00,8, die Antwort kommt um :09,877,
  das Ende der Blockade um :09,83. Vorher meldete XCTest „Wait for … to idle“ als erfüllt, die App war also ruhig.
- Lokal (iOS-27-Simulator, eigenes Gerät LE-336): App im Leerlauf mit `--ui-testing` 0 % CPU, Hauptthread
  ruht (`sample`). Testlauf ohne Zusatzlast grün, aber mit 9,2-s-Blockade beim Start. Unter Zusatzlast
  (8× `yes` auf 10 Kernen) blockierte der Hauptthread 35 s, 112 s und 370 s. Die Fehlerklasse ist damit
  lokal nachgestellt. Der rote Testausgang selbst ist es noch nicht: Der Mac war mit 7 Simulatoren anderer Sitzungen
  ausgelastet (≈ 1090 % CPU, Load 260), und die Läufe kamen nicht bis zum Ende.
- Recherche: Schnappschuss-Anfragen blockieren den Hauptthread der App, auf CI häufig bis zur 30-s-Grenze
  („Unable to perform work on main run loop, process main thread busy“): Apple Developer Forums
  https://origin-devforums.apple.com/forums/thread/741983, https://developer.apple.com/forums/thread/708993,
  https://developer.apple.com/forums/thread/133026

Widerlegt: falsche Fläche, Zeile nicht oben, App-Arbeit beim Öffnen der Detailansicht (`markSeen`/`save`):
Die Blockade beginnt erst mit der Abfrage, nicht mit dem Tipp.
Offen, aber für den Fix nicht nötig: warum der verspätete Schnappschuss leer war (vermutlich eine interne Frist der Bedienungshilfen).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/RecognitionWalkthroughTests.swift` | MODIFY | `waitForLabel`: Frist so, dass eine zweite Auswertung nach einem langsamen Schnappschuss sicher stattfindet (30 s, wie XCTests eigene Abfragegrenze). Begründender Kommentar mit Verweis auf #336 |

### Scope Assessment
- Files: 1
- Estimated LoC: +10/-3
- Risk Level: LOW (nur Testcode, kein Produktpfad, kein Pfad der Geräteliste)

### Technical Approach (Empfehlung)
Die Wartefrist von `waitForLabel` wird von 10 s auf 30 s angehoben. Die Zusicherungen bleiben unverändert, sie
prüfen weiter genau dieselbe Beschriftung. Ein echter App-Hänger bleibt sichtbar, aus zwei Gründen: Der Watchdog
protokolliert jede Blockade weiter in `watchdog.log`, und eine App, die nie den richtigen Wert zeigt, scheitert
nach 30 s genauso.

Alternativen:
1. **Schnappschüsse billiger machen:** `.any`-Abfragen durch typisierte ersetzen (`staticTexts`/`otherElements`)
   oder den Elementbaum der Detailansicht verkleinern. Die Wirkung ist unbelegt (auch `Button (First Match)`
   blockierte), und der Baum gehört zum Produkt. Deshalb eine Messung wert, aber nicht der erste Schritt.
2. **Alle UI-Tests gemeinsam härten** (eine gemeinsame Wartehilfe mit langer Frist für jede `.any`-Abfrage):
   Das gemeinsame Ziel „beim ersten Versuch grün“ (#172) spräche dafür. Es wären aber 6–8 Testdateien, also über
   den Limits. Diese Tests liefen trotz Blockaden von 20–29 s grün, weil `waitForExistence` nach einer späten
   Antwort noch einmal auswertet.
   → Eigenes Ticket, falls weitere Wackler auftauchen.
3. **Wiederholung in der CI:** würde die in #172 entfernte Wiederholung zurückbringen und eine ADR kippen. Abgelehnt.
4. **Größerer oder eigener CI-Rechner:** liegt außerhalb des Repos, mit Kosten und dem Vorschau-Image `xcode-27`.
   Nicht jetzt.

### Dependencies
Keine Produktabhängigkeiten. Die CI-Diagnose (Watchdog, `host-load.log`) bleibt unverändert und belegt künftige Fälle.

### Nachweis (für Spec/Validate)
- RED: nicht deterministisch erzwingbar. Ersatz ist der lokale Lauf unter Zusatzlast, vor und nach der Änderung,
  dazu die Zuordnung Blockade → Abfrage. Grüner Lauf ohne Last bleibt Pflicht.
- DoD #336: drei CI-Läufe in Folge grün.

### Open Questions
- keine (rein technisch, Tech-Lead-Entscheidung)

## RED-Stand (Phase 5, 2026-10-12)
- Wegwerf-Prüfung `docs/artifacts/fix-336-wiedererkennung-wackler/probe-wegwerf.swift.txt` (Klasse
  `WaitForLabelSlowSnapshotProbe`; `waitForLabel` dafür vorübergehend `internal` und `of: NSObject`): erste Auswertung
  hängt 9,2 s bzw. 29,1 s. 10 s → beide rot nach 1 Auswertung (`probe-rot-10s.txt`), 30 s → 29-s-Fall rot (`probe-gegenprobe-30s.txt`).
- GREEN in Phase 6: dieselbe Prüfung mit 60 s (Wegwerf, danach Datei wieder auf den Fix zurücksetzen), dann `load-nachher`
  über `loadrun.sh`-Ablauf (8× `yes`, `LOOSEENDS_SIM=LE-336`, `CLAUDE_SESSION_ID=fix336`) und `test-proof` ohne Last.
- Lauf unter Last vorher: grün, Blockaden 5,1 s / 9,9 s nach Testaktivität (`load-vorher/correlate-output.txt`).
