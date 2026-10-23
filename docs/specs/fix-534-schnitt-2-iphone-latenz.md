---
entity_id: fix-534-schnitt-2-iphone-latenz
type: bugfix
created: 2026-10-22
updated: 2026-10-22
status: draft
workflow: fix-534-schnitt-2-iphone-limit
---

# Spec: Modell-Latenz messen, Schnitt 2 — iPhone (#534)

## Approval

- [ ] Approved

## GitHub Issue

#534 (Epic #563). Schnitt 2 von 3; das Issue bleibt offen. Schnitt 1 (Mac, PR #609) ist gemergt. Schnitt 3 setzt die Konstante.

## Purpose

Das Limit von 30 s je Modellaufruf (`EnrichmentCoordinator`, #530) richtet sich nach dem langsameren Gerät. Der Mac braucht höchstens 4,67 s
(`docs/reference/modell-latenz.md`). Das iPhone 16 Pro war in der alten Labor-Reihe vom 2026-09-20 etwa dreimal langsamer (Median 8,7 s, Maximum 21,4 s,
319 Aufrufe), aber mit altem Schema, ohne Trennung kalt/warm und bei oft heißem Gerät; daraus lässt sich kein Limit ableiten.

Dieser Schnitt macht die Labor-App fähig, dieselbe Reihe wie am Mac zu fahren (sechs Notizen, gleiches Kontextwörterbuch, jeder Start kalt), misst das
iPhone damit und ergänzt den Bericht. Die Zahl im Produkt ändert **Schnitt 3**, weil `EnrichmentCoordinator.swift` auf der Geräteliste steht (Stufe 3).

„Kalt“ heißt prozess-kalt: der erste Aufruf nach dem Start der Labor-App (`devicectl process launch --terminate-existing` = neuer Prozess; der Enricher
baut je Aufruf eine neue Session, kein `prewarm()`). Ob das Betriebssystem das Modell zusätzlich neu laden muss, lässt sich nicht erzwingen und wird so benannt.

**Ohne Modell geht es nicht, weil** die Titelverfeinerung Sprachverstehen braucht (Beleg: #202, `TitleRule` setzt den Titel beim Erfassen nur aus dem
bereinigten Rohtext; die Verfeinerung bleibt übrig). Dieses Ticket führt kein Modell ein, es vermisst den bestehenden Aufruf. Eine Regel-Spalte entfällt:
Für Latenz gibt es keine Regel, die das Modell ersetzt.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Messung und Werkzeug. Entschieden wird nichts am Produkt; der Bericht gibt nur eine Empfehlung für Schnitt 3.

## Source

| Datei | Änderung |
|---|---|
| `Measurement/Corpus.swift` | erweitert: drei neue reine Funktionen für Startargumente `--result`, `--context-words`, `--exit-when-done` |
| `LooseEndsLab/LabApp.swift`, `LooseEndsLab/MeasurementRunner.swift` | Argumente durchreichen: Ergebnisname, Wörterbuch in die Eingabe, Selbstbeendigung nach dem letzten Satz |
| `Measurement/latency-corpus.json` | NEU: die sechs Notizen aus `RealModel.notes` (Daten) |
| `scripts/sim.sh` | `lab-latency <n>`: n Starts nacheinander, je Start eine Ergebnisdatei, holt sie, fasst zusammen |
| `scripts/latency_summary.py` | liest zusätzlich das Labor-Format (erster Aufruf je Datei = kalt), zeigt Hitze getrennt |
| `scripts/test_latency_summary.py`, `LooseEndsTests/CorpusTests.swift` | Tests der Auswertung und der Argument-Funktionen |
| `docs/reference/modell-latenz.md` | iPhone-Teil; Rohdaten unter `docs/artifacts/534-modell-latenz/iphone/` (Beleg, kein Code) |

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `FoundationModelsEnricher`, `EnrichmentInput`, `MeasurementRun`, `MeasurementStore` | unverändert, wiederverwendet |
| `RealModel.notes` (`RealModelTests.swift`) | Vergleichswert für den Korpus, unverändert |
| `sim.sh`: `require_device`, `signed_build`, `cmd_lab`, `$DEVICECTL` | wiederverwendet, unverändert |
| `scripts/latency_summary.py` aus Schnitt 1 | erweitert, bisheriges Format bleibt lesbar |
| Schnitt 1 (PR #609), #530, #531 | gemergt |
| Schnitt 3 (Konstante im `EnrichmentCoordinator`, Stufe 3) | folgt |

## Acceptance Criteria

- **AC-1:** `Corpus` bekommt drei reine Funktionen: `resultName(from:)` (`--result <name>`, ohne Flag `date-title`), `contextWords(from:)`
  (`--context-words a,b,c`, ohne Flag leer) und `exitWhenDone(from:)` (`--exit-when-done`, ohne Flag `false`). Ohne alle drei Flags verhält sich die Labor-App
  wie bisher. `CorpusTests` prüft Flag mit Wert, Flag ohne Wert und fehlendes Flag.
- **AC-2:** Die Labor-App legt ihre Ergebnisse unter dem Namen aus `--result` ab, übergibt die Wörter aus `--context-words` als `contextVocabulary`
  und beendet sich mit `exit(0)`, nachdem der letzte Satz gespeichert ist, wenn `--exit-when-done` gesetzt ist. Ohne die Flags bleibt alles wie heute.
  Die Labor-App ist kein Pfad der Geräteliste und kein Teil der Produkt-App.
- **AC-3:** `Measurement/latency-corpus.json` enthält genau die sechs Notizen von `RealModel.notes` in derselben Reihenfolge (`id` `lat-01` … `lat-06`,
  `lang` `de` oder `en`). `CorpusTests` vergleicht die Texte mit `RealModel.notes`, damit Mac und iPhone dieselbe Eingabe haben.
- **AC-4:** `./scripts/sim.sh lab-latency <n>` baut die Labor-App einmal und installiert sie (nur `com.henning.looseends.lab`), startet dann n Prozesse
  nacheinander mit `--measure --corpus latency-corpus --runs 2 --result latency-NN --context-words Computer,Telefon,Haus,Garten,Unterwegs,Besorgung --exit-when-done`
  (je Start 12 Aufrufe: 1 kalter, 11 warme), holt jede Datei nach `docs/artifacts/534-modell-latenz/iphone/latency-NN.json` und fasst am Ende zusammen.
  Es bricht mit klarer Meldung ab, wenn das iPhone gesperrt ist, kein Gerät verbunden ist, ein Start nach 300 s nicht endet oder eine Datei fehlt.
  Es fasst keine andere App, kein iPad, keine Watch und nicht den Mac als Ziel an.
- **AC-5:** `scripts/latency_summary.py <ordner>` erkennt das Labor-Format (`latency-*.json` mit `results`): der erste Eintrag jeder Datei ist `kalt`, die übrigen `warm`;
  Einträge mit `error` zählen als Fehler und gehen nicht in Minimum/Median/p95/Maximum. Zusätzlich zeigt es je Gruppe das Maximum nach Hitze
  (`conditions.thermal`: normal, fair, serious, critical) und die Zahl der Aufrufe je Stromquelle. Das bisherige Mac-Format bleibt lesbar; leerer Ordner oder fehlende
  Gruppe: Meldung, Exit ≠ 0. `test_latency_summary.py` prüft das mit festen Beispielwerten.
- **AC-6:** Gemessen sind mindestens 10 Starts auf Hennings iPhone 16 Pro (10 kalte, 110 warme Aufrufe), und zwar erst nach seinem wörtlichen „jetzt ist ein Test möglich“
  (2026-10-22, gilt für diesen Durchgang). Der Bericht `docs/reference/modell-latenz.md` bekommt den iPhone-Teil: Gerät und System aus `Conditions`, Kennzahlen kalt/warm wie am Mac,
  Hitze und Stromquelle getrennt, Verhältnis Kalt-Maximum zu Warm-Maximum gegen die Schwelle Faktor 5 (Empfehlung zu „zwei Grenzen“), Vergleich Mac gegen iPhone,
  und den **Vorschlag** für Schnitt 3 nach der Regel „Dreifaches des größten gemessenen Werts beider Geräte, aufgerundet auf 5 s, mindestens 15 s; über 60 s geht die Frage an Henning zurück“.
  Der Bericht setzt keine Zahl im Produkt.
- **AC-7:** Alles unter `Shared/` (insbesondere `EnrichmentCoordinator.swift` und `FoundationModelsEnricher.swift`) und die Produkt-App `LooseEnds/` bleiben unverändert.
  Das Ticket #534 bleibt offen, kein `Closes #534`.
- **AC-8:** Auf dem iPhone läuft nur die Labor-App (`LE Labor`), nur in diesem einen Durchgang. Es wird nichts anderes installiert oder beendet, Hennings Alltags-App und der Prüfbau bleiben unberührt.
  Alles Vorbereitende (Bau, Installation) ist abgeschlossen, bevor Henning zum Entsperren gerufen wird; der Lauf beginnt mit derselben Nachricht.

## Scope

**Affected Files:** neun Dateien in der Tabelle „Source“ (Identifier: `Corpus.resultName`, `Corpus.contextWords`, `Corpus.exitWhenDone`, `cmd_lab_latency`),
davon fünf Code- und Skriptdateien (`Corpus.swift`, `LabApp.swift`, `MeasurementRunner.swift`, `sim.sh`, `latency_summary.py`), dazu Korpusdaten, zwei Tests und der Bericht.
Das liegt über der 4–5-Dateien-Grenze; ein weiterer Schnitt (nur Argumente oder nur Skript) hätte kein eigenes Ziel, und die Konstante ist schon abgespalten (Schnitt 3).
Geschätzt +170 LoC ohne Bericht und Rohdaten. Keine Permissions, keine AppStorage-Keys, kein CloudKit-Schema, kein Pfad der Geräteliste im Code.

**Gerätelauf:** Die Messung selbst ist Stufe 3 im Sinne von „nur das Gerät zeigt es“, aber nicht über die Pfadliste ausgelöst, sondern weil das iPhone der Messort ist.
Henning hat dafür „jetzt ist ein Test möglich“ geschrieben; die Regel „nie ungefragt auf seinen Geräten“ bleibt. Dauer rund 20 Minuten bei entsperrtem iPhone (10 Starts, je 12 Aufrufe, geschätzt 9 s je Aufruf);
das Gerät erwärmt sich, die Hitze wird mitgeschrieben.

**Schnitt 3 (eigener Workflow):** die Konstante im `EnrichmentCoordinator` mit Verweis auf den Bericht, Test, Abnahme Stufe 3 über TestFlight.

## Test Plan

RED: `CorpusTests` für die drei Funktionen und den Korpusvergleich schlägt fehl, solange sie fehlen; `test_latency_summary.py` für das Labor-Format schlägt fehl, solange `latency_summary.py` es nicht liest.
GREEN: `./scripts/sim.sh sim-unit` (Swift, Simulator) und `python3 scripts/test_latency_summary.py`. Die Labor-App baut beim Gerätebau (`lab`); ein zusätzlicher Simulatorbau des Labor-Ziels entfällt, weil das Ziel nur für das Gerät gebaut wird.
Nachweis für AC-4/6/8 ist der Gerätelauf selbst (Rohdaten im Repo, `lab-latency`-Protokoll). Simulator-Durchlauf der Produkt-App: kein sichtbarer Ablauf geändert; `sim.sh build` bleibt grün.

## Alternativen

- **Alte Reihe auswerten statt neu messen:** liegt vor, passt aber nicht zum heutigen Schema und trennt kalt/warm nicht; ein Limit daraus wäre ein Limit für einen anderen Aufruf.
- **Eine Grenze aus beiden Messungen (gewählt, Schnitt 3).** Kleinste Änderung.
- **Zwei Grenzen (kalt großzügig, warm eng):** lohnt nur bei Faktor > 5; der Bericht entscheidet mit Zahlen.
- **Messung in der normalen App über TestFlight:** liefert keine Zahlen zurück; verworfen.
- **Weniger Starts (5):** kürzer, aber nur 5 kalte Werte; das Maximum trägt die Grenze, deshalb 10.
- **`prewarm()` beim Start:** eigenes Ticket, braucht diese Messung als Vorher-Wert.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt
- [ ] `sim.sh sim-unit` grün, `test_latency_summary.py` grün, `sim.sh build` baut
- [ ] `sim.sh lab-latency 10` gelaufen, Rohdaten unter `docs/artifacts/534-modell-latenz/iphone/`, Bericht ergänzt
- [ ] #534 kommentiert (Stand Schnitt 2, Rest = Schnitt 3), Schnitt 3 als Abschnitt benannt

## Changelog

- 2026-10-22: Initial (Schnitt 2 von 3)
