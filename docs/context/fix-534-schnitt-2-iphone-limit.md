# Context: #534 Schnitt 2 — Limit je Modellaufruf aus der iPhone-Messung

## Request Summary
Das Limit von 30 s je Modellaufruf (`EnrichmentCoordinator.init`, #530) soll aus Messwerten kommen. Schnitt 1 (PR #609) hat den Mac gemessen
(kalt Max 4,20 s, warm Max 4,67 s, `docs/reference/modell-latenz.md`). Schnitt 2 misst das iPhone 16 Pro über die Labor-App und setzt danach die Konstante.
Henning hat für diesen einen Durchgang „jetzt ist ein Test möglich“ geschrieben (2026-10-22).

## Related Files
| Datei | Relevanz |
|---|---|
| `Shared/Enrichment/EnrichmentCoordinator.swift:30` | `modelTimeout: Duration = .seconds(30)`, die einzige Stelle; Stufe 3 (Geräteliste) |
| `Shared/Enrichment/ModelDeadline.swift` | Rennen Aufruf gegen Timer |
| `LooseEndsLab/MeasurementRunner.swift` | Messschleife; `measure` schreibt `seconds` je Aufruf, `Conditions` (Gerät, Strom, Hitze, App-Zustand); nutzt `FoundationModelsEnricher` (Produktschema) |
| `LooseEndsLab/LabApp.swift` | Startargumente `--corpus <name>`, `--runs <n>`, `--measure`; Ergebnisdatei heißt fest `date-title` |
| `Measurement/MeasurementRun.swift` | `MeasurementResult` (`seconds`, `conditions`, `runIndex`), `events` (start/stop/scene), `remaining` (setzt fort) |
| `Measurement/Corpus.swift` | `corpusFileName(from:)`, `runsPerEntry(from:)` |
| `scripts/sim.sh` (`lab`, `lab-run`, `lab-fetch`) | Bau, Start mit Zeitgrenze, Abholen per devicectl; `lab-fetch` holt nur `date-title.json` (Name als Argument möglich) |
| `scripts/measurement-summary.py`, `scripts/latency_summary.py` | Kurzfassung bzw. Kennzahlen kalt/warm (Schnitt 1) |
| `LooseEndsTests/RealModelTests.swift` (`RealModel.notes`) | die sechs Notizen der Mac-Messung |
| `docs/reference/modell-latenz.md` | Bericht, bekommt den iPhone-Teil |

## Vorhandene iPhone-Daten (wichtig)
`Measurement/results/date-title.json` (2026-09-20, iPhone17,1 = iPhone 16 Pro, iOS 27.0): 319 erfolgreiche Aufrufe, Minimum 4,6 s, Median 8,7 s,
**Maximum 21,4 s**. Das Maximum liegt nur beim 1,4-fachen unter dem heutigen Limit von 30 s. Die Daten sind aber nicht übertragbar:
altes Schema (mit Datumsfeldern, die das Modell seit #95 nicht mehr liefert), Kalt und Warm nicht getrennt, Hitze „serious“ in 155 von 342 Zeilen,
Akku und Strom gemischt. Sie zeigen die Größenordnung (iPhone etwa dreimal langsamer als der Mac), ersetzen die neue Messung nicht.

## Existing Patterns
- Messung läuft in der Labor-App in Scheiben, nie als Xcode-Testlauf (Memory „Handy ist kein Prüfstand“); Rückkanal still per `devicectl`.
- `lab-run <sekunden>` startet die App mit `--measure`, beendet sie nach der Zeit, holt die Datei. Jeder Start ist ein neuer Prozess: der erste Aufruf danach ist prozess-kalt.
- Ein fertiger Lauf (`remaining` leer) startet nicht neu: eine neue Messung braucht einen anderen Dateinamen oder `--runs` höher.

## Dependencies
- Upstream: `FoundationModelsEnricher` (unverändert), Apple Intelligence auf dem iPhone, `devicectl`, signierter Bau (`signed_build`, Kennung `com.henning.looseends.lab`).
- Downstream: `EnrichmentCoordinator` (Konstante), Bericht, CLAUDE.md-Zeile zum Limit falls vorhanden.

## Existing Specs
- `docs/specs/fix-534-schnitt-1-mac-latenz.md` (Schnitt 1, Alternativen A bis D; dort entschieden: eine Grenze aus beiden Messungen, `prewarm()` eigenes Ticket)

## Risks & Considerations
- **Geräteregel:** Gerät nur im Durchgang, den Henning freigegeben hat; Bau und Installation erst, wenn alles bereitliegt; er wird zum Entsperren gerufen, wenn der Lauf startet.
- **Hitze:** Eine lange Reihe heizt das iPhone auf (alte Daten: „serious“). Das Limit muss auch dann tragen; die Messung soll Hitze mitschreiben (`Conditions.thermal`) und im Bericht getrennt zeigen.
- **Vergleichbarkeit mit dem Mac:** Gleiche sechs Notizen, gleiche Kontextwörter, gleiche Reihenfolge; der Lab-Aufruf übergibt heute ein leeres Wörterbuch.
- **Kalt/warm trennen:** aus Ereignisprotokoll (`start`) und `finishedAt`, nicht raten.
- **Scope:** Labor-Änderungen (Ergebnisname, Korpus, evtl. Wörterbuch) + Auswertung + Konstante + Bericht; nahe an 4 bis 5 Dateien.
- **Limit-Regel offen:** aus dem größeren der beiden Maxima mit Abstand; die Faktoren legt die Spec fest, der Wert aus den Daten.

## Analysis

### Type
Feature (Messung, Werkzeug und Bericht). Kein Fehler im Produkt.

### Befund
Die Labor-App misst `seconds` je Aufruf mit dem Produkt-Enricher schon. Es fehlt für die Latenzreihe: (1) eigener Ergebnisname je Start
(der alte Lauf `date-title` gilt als fertig und startet nicht neu), (2) das Wörterbuch der Mac-Messung (die Labor-App übergibt leer),
(3) Selbstbeendigung nach dem Satz, damit der nächste Prozess kalt startet, ohne Wartezeit bis zur Zeitgrenze, (4) die sechs Notizen als Korpus,
(5) ein Ablauf, der n Starts nacheinander fährt und holt, (6) Auswertung kalt/warm aus den Labor-Dateien.

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Measurement/Corpus.swift` | MODIFY | Startargumente `--result <name>`, `--context-words a,b,c`, `--exit-when-done` als reine Funktionen (testbar) |
| `LooseEndsLab/LabApp.swift`, `LooseEndsLab/MeasurementRunner.swift` | MODIFY | Argumente durchreichen: Ergebnisname, Wörterbuch in `EnrichmentInput`, `exit(0)` nach dem letzten Satz |
| `Measurement/latency-corpus.json` | CREATE | die sechs Notizen aus `RealModel.notes` (Daten) |
| `scripts/sim.sh` | MODIFY | `lab-latency <n>`: n Starts, je Start eine Ergebnisdatei, holt sie, fasst zusammen |
| `scripts/latency_summary.py` (+ Test) | MODIFY | liest zusätzlich das Labor-Format (erster Aufruf je Datei = kalt, Hitze/Strom mitgeführt) |
| `LooseEndsTests` (Argument-Funktionen) | MODIFY/CREATE | Test der drei Argument-Funktionen |
| `docs/reference/modell-latenz.md` | MODIFY | iPhone-Teil, Hitze getrennt |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | **nicht in diesem Schnitt** | Konstante folgt als Schnitt 3 |

### Scope Assessment
- Code- und Skriptdateien: Corpus.swift, LabApp.swift, MeasurementRunner.swift, sim.sh, latency_summary.py (5) plus Korpusdaten, zwei Tests, Bericht.
- Geschätzt +170 LoC ohne Bericht und Daten. Grenznah, deshalb wird die Konstante (Stufe 3) abgespalten.
- Risk Level: MEDIUM. Das Produkt bleibt unberührt (Labor-App hat keinen Weg in die Produkt-App), aber die Messung läuft auf Hennings iPhone.

### Technical Approach
- Kalt = erster Aufruf nach Prozessstart (jeder `devicectl process launch --terminate-existing` ist ein neuer Prozess), warm = die übrigen 11 des Starts.
  Gleiche Eingabe wie am Mac: sechs Notizen reihum (zweimal, zusammen 12 Aufrufe), Wörterbuch Computer/Telefon/Haus/Garten/Unterwegs/Besorgung, keine Beispiele.
- n = 10 Starts: 10 kalte, 110 warme Aufrufe. Bei etwa 9 s je Aufruf rund 20 Minuten bei entsperrtem iPhone; die Hitze wird mitgeschrieben (Conditions).
- Limit-Regel (für Schnitt 3, hier nur im Bericht vorgeschlagen): auf volle 5 s aufgerundet das Dreifache des größten gemessenen Werts beider Geräte, mindestens 15 s;
  liegt das Ergebnis über 60 s, geht die Frage an Henning zurück (dann ist das Modell für den Alltag zu langsam, nicht das Limit zu kurz).

### Alternativen
- **Zwei Grenzen (kalt/warm):** nur bei Faktor > 5 zwischen kalt und warm; der Bericht entscheidet mit Zahlen.
- **Alte Messreihe auswerten statt neu messen:** liegt vor (Max 21,4 s), aber altes Schema, kalt/warm nicht getrennt; würde ein Limit aus einem anderen Aufruf ableiten.
- **TestFlight-Lauf in der normalen App:** brächte keine Zahlen zurück.
- **`prewarm()`:** eigenes Ticket, braucht diese Messung als Vorher-Wert.
- **Mac statt iPhone als Maßstab:** verworfen; das Limit richtet sich nach dem langsameren Gerät.

### Dependencies
Upstream: `FoundationModelsEnricher`, Apple Intelligence auf dem iPhone, `devicectl`, signierter Bau. Downstream: Schnitt 3 (Konstante), Bericht.

### Open Questions
- [x] Wie viele Starts? 10 (entschieden, Begründung oben); Henning kann es in der Spec-Freigabe ändern.
- [ ] Ob das iPhone bei Betrieb am Strom oder am Akku gemessen wird, bestimmt Henning mit seinem Gerät; beides wird in `Conditions` festgehalten und getrennt gezeigt.
