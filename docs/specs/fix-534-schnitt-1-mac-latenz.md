---
entity_id: fix-534-schnitt-1-mac-latenz
type: bugfix
created: 2026-10-21
updated: 2026-10-21
status: draft
workflow: fix-534-modell-timeout
---

# Spec: Modell-Latenz messen, Schnitt 1 — Mac (#534)

## Approval

- [ ] Approved

## GitHub Issue

#534 (Epic #563). Schnitt 1 von 2; das Issue bleibt offen.

## Purpose

Epic #563 „Modellaufruf robust“. Das Limit von 30 s je Modellaufruf (`EnrichmentCoordinator`, #530) ist geschätzt. Dieser Schnitt misst die
Latenz kalt und warm auf dem Mac und schreibt den Bericht mit einer **Empfehlung** für das Limit. Die Zahl im Produkt ändert **Schnitt 2**
(iPhone-Messung, Stufe 3).

`.seconds(30)` steht an genau einer Stelle (`EnrichmentCoordinator.init`) ohne Messbeleg. `RealModelTests` prüft nur `took < 30 s` und sammelt keine
Zahlen; das xcresult trägt keine Zahlenreihen. Die Labor-App schreibt die Dauer je Aufruf schon (`MeasurementResult.seconds`, Gerät in
`Conditions.device`), ist also für das iPhone ohne Änderung nutzbar (Schnitt 2). „Kalt“ heißt hier prozess-kalt: erster Aufruf nach Prozessstart
(`FoundationModelsEnricher` baut je Aufruf eine neue Session, kein `prewarm()`). Ob das Betriebssystem das Modell zusätzlich neu laden muss,
lässt sich im Test nicht erzwingen; der Bericht sagt das.

**Ohne Modell geht es nicht, weil** die Titelverfeinerung Sprachverstehen braucht (Beleg: #202, `TitleRule` setzt den Titel beim Erfassen
nur aus dem bereinigten Rohtext; die Verfeinerung ist das, was bleibt). Dieses Ticket führt kein Modell ein, es vermisst den bestehenden Aufruf.
Datum setzt die Regel (#95, 99,3 %), Kontexte setzt das Modell nie (#215). Eine Regel-Spalte entfällt: Für Latenz gibt es keine Regel, die das
Modell ersetzt. Der Bericht führt diese Einordnung mit den Verweisen.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Messung und Bericht. Der Bericht gibt zur Frage „zwei Grenzen“ nur eine Empfehlung für Schnitt 2; entschieden wird dort.

## Source

| Datei | Änderung |
|---|---|
| `LooseEndsTests/RealModelLatencyTests.swift` | NEU: Mess-Suite, gleiche Gates wie `RealModelTests`, schreibt Rohwerte als JSON |
| `LooseEndsTests/RealModelGateTests.swift` | Quelltext-Test erweitert um die neue Suite |
| `scripts/sim.sh` | `real-model-latency <n>`: n Prozesse nacheinander, sammelt die Rohdaten |
| `scripts/latency_summary.py` | NEU: n, Minimum, Median, p95, Maximum je Gruppe |
| `scripts/test_latency_summary.py` | NEU: Python-Test mit festen Beispielwerten |
| `docs/reference/modell-latenz.md` | NEU: Bericht; Rohdaten unter `docs/artifacts/534-modell-latenz/` (Beleg, kein Code) |

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `RealModel` (Gates, `notes`) in `RealModelTests.swift` | wiederverwendet, unverändert |
| `FoundationModelsEnricher`, `ModelDeadline`, `EnrichmentCoordinator` | gemessen bzw. unberührt |
| `scripts/sim.sh` Testsperre (`acquire_testlock`), `real_model_result.py` | wiederverwendet, unverändert |
| #530 (Limit), #531 (`real-model`), #535, #536 | gemergt |
| Schnitt 2 (iPhone, Labor-App, Konstante) | folgt, Stufe 3 |

## Acceptance Criteria

- **AC-1:** Neue Suite `RealModelLatencyTests` trägt dieselben Gates wie `RealModelTests` (`.enabled(if: RealModel.isRequested)`, `.serialized`,
  Verfügbarkeitsprüfung); ohne `LOOSEENDS_REAL_MODEL=1` wird sie übersprungen, nie rot. `RealModelGateTests` prüft das im Quelltext auch für
  die neue Suite.
- **AC-2:** Je Prozess: ein erster Aufruf (kalt) mit `RealModel.notes[0]`, danach 10 warme Aufrufe (die sechs Notizen reihum). Jede Probe wird
  mit `ContinuousClock` gemessen und als Zeile `{gruppe: "kalt"|"warm", note, sekunden, fehler?}` in eine JSON-Datei geschrieben, deren Pfad
  die Umgebungsvariable `LOOSEENDS_LATENCY_OUT` nennt. Ohne diese Variable schreibt die Suite nichts und bleibt trotzdem grün.
  Ein fehlgeschlagener Aufruf wird als Probe mit `fehler` festgehalten und bricht die Reihe nicht ab.
- **AC-3:** `./scripts/sim.sh real-model-latency <n>` baut einmal (`build-for-testing`), startet dann n Prozesse nacheinander
  (`test-without-building`, nur `RealModelLatencyTests`) und sammelt die n JSON-Dateien unter `docs/artifacts/534-modell-latenz/`.
  Es holt die Testsperre wie `real-model`, prüft macOS >= Target und Apple Silicon und bricht bei einer fehlenden Datei mit Meldung ab.
  Es fasst kein iPhone, iPad oder keine Watch an.
- **AC-4:** `scripts/latency_summary.py <ordner>` liest die Rohdaten und gibt je Gruppe n, Minimum, Median, p95 und Maximum aus, Fehlerproben
  getrennt gezählt. Fehlt eine Gruppe oder ist der Ordner leer: klare Meldung, Exit ≠ 0. `scripts/test_latency_summary.py` prüft das mit
  festen Beispielwerten.
- **AC-5:** Gemessen sind mindestens 15 Prozesse (15 kalte, 150 warme Proben). Der Bericht `docs/reference/modell-latenz.md` enthält: Gerät und
  System (`sw_vers`, Chip), Bau, Weg, Läufe; die Kennzahlen aus AC-4 getrennt kalt/warm; die Aussage „prozess-kalt, nicht system-kalt“;
  die Einordnung aus „Purpose“ (wofür das Modell noch gebraucht wird, mit Verweisen); eine **Empfehlung** zu Alternative B (zwei Grenzen) mit
  Zahlen (Kalt-Maximum gegen Warm-Maximum, Schwelle Faktor 5); den Vermerk, dass p95 bei n=15 nur beschreibt und das Maximum die Grenze trägt;
  den offenen Punkt „iPhone → Schnitt 2“. Der Bericht legt **keine** neue Zahl für das Produkt fest.
- **AC-6:** `EnrichmentCoordinator.swift` und alles unter `Shared/` bleiben unverändert (die Dateiliste des PR enthält dort nichts).

## Scope

**Affected Files:** fünf Code- und Skriptdateien plus Bericht (Tabelle „Source“; Identifier: `RealModelLatencyTests`, `cmd_real_model_latency`). Das liegt am oberen Rand der 4–5-Dateien-Grenze: Der Python-Test gehört zum
Auswerteskript, die Mess-Suite zum Quelltext-Test; ein Schnitt weiter hätte kein eigenes Ziel. Geschätzt +200 LoC ohne Bericht und Rohdaten.
Keine Permissions, keine AppStorage-Keys, kein Modell, kein CloudKit-Schema. Kein Pfad der Geräteliste berührt.

**Schnitt 2 (eigener Workflow):** iPhone-Messung über die Labor-App (Dauer je Aufruf liegt vor; kalt/warm aus Reihenfolge und `runIndex`, ggf. ein
Feld in `MeasurementRunner`), danach die Konstante in `EnrichmentCoordinator` mit Kommentar-Verweis. Stufe 3, erst nach Hennings wörtlichem
„jetzt ist ein Test möglich“. #534 bleibt bis dahin offen (kein `Closes #534` in Schnitt 1).

**Mac als Messort:** Der Lauf geschieht auf dem Entwicklungsrechner dieser Sitzung über den in CLAUDE.md vorgesehenen `real-model`-Weg
(Mac-Hosting des echten Modells, #531), nicht auf einem Gerät, das Henning als Testziel führt; „eigene Rechner-Ressourcen“ sind laut
globaler Regel nicht betroffen. Unit-Tests laufen weiter nur im Simulator.

## Test Plan

RED: `test_latency_summary.py` schlägt ohne Skript fehl; der Quelltext-Test in `RealModelGateTests` schlägt fehl, solange die Suite fehlt oder
ein Gate fehlt. Der Mess-Durchlauf `sim.sh real-model-latency 15` ist der Nachweis für AC-2/3/5 (Rohdaten im Repo); für diese ACs gibt es
keinen automatischen Test, nur den Lauf selbst: Die Suite ist hinter `LOOSEENDS_REAL_MODEL` gesperrt und läuft nie in der CI, ein Test der
Suite wäre selbst ein Modelllauf. Die Auswertelogik (Gruppen, Fehlerproben, Kennzahlen) deckt `test_latency_summary.py` mit festen Beispieldaten ab. Simulator-Durchlauf: kein sichtbarer Ablauf geändert; `sim.sh sim-unit` bleibt grün,
`sim.sh build` baut.

## Alternativen

- **Eine Grenze aus beiden Messungen (gewählt, in Schnitt 2).** Kleinste Änderung.
- **Zwei Grenzen (kalt großzügig, warm eng):** lohnt nur bei Faktor > 5; der Bericht empfiehlt mit Zahlen.
- **`prewarm()` beim Start:** ändert den Enricher, best effort laut Apple; eigenes Ticket, braucht diese Messung als Vorher-Wert.
- **Kein Limit:** nähme #530 zurück; verworfen.
- **Alles in einem Schnitt:** hinge am Gerätelauf, hielte den Mac-Teil auf und zöge `EnrichmentCoordinator` (Stufe 3) hinein.

## Definition of Done

- [ ] AC-1 bis AC-6 erfüllt
- [ ] `test_latency_summary.py` und `RealModelGateTests` grün; `sim.sh sim-unit` grün; `sim.sh build` baut
- [ ] `sim.sh real-model-latency 15` gelaufen, Rohdaten und Bericht im Repo
- [ ] #534 kommentiert (Stand Schnitt 1, Rest = Schnitt 2), Folgeticket/Abschnitt für Schnitt 2 benannt

## Changelog

- 2026-10-21: Initial (Schnitt 1 von 2)
