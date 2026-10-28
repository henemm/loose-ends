---
entity_id: spike-71-schnitt-2a-laeufer-ablehnung
type: feature
created: 2026-10-28
updated: 2026-10-28
status: draft
workflow: feat-71-guardrail-iphone-spalte
---

# Spec: Guardrail-Rate messen, Schnitt 2a — Läufer zählt Ablehnungen (#71)

## Approval

- [ ] Approved

## GitHub Issue

#71 (Spike, Epic #370, Annahme B3). Schnitt 2a von 2b; das Issue bleibt offen (`Refs #71`, nie `Closes #71`).

## Purpose

Annahme B3 (`docs/project/06-annahmen-und-experimente.md`): Mehr als 1 % Verweigerung auf Alltagstext ist das Abbruchkriterium. Die Mac-Spalte steht (2/387 = 0,52 %, obere
Wilson-Grenze 1,86 %, PR #727). Weil diese Grenze über 1 % liegt und das iPhone die neuere Modellgeneration hat, braucht B3 die **iPhone-Spalte** (Schnitt 2). Schnitt 2 ist in zwei Teile geteilt:

- **2a (diese Spec, jetzt):** Messcode ohne Gerät. Kein Gerätelauf, kein `sim.sh`-Skript, kein Bericht, keine Rohdaten.
- **2b (eigene Spec):** Skript `lab-guardrail`, Ergebnis → Probe in `GuardrailReport`, Bericht, Rohdaten. Läuft erst nach Hennings wörtlichem „jetzt ist ein Test möglich“, gebündelt mit #88 Teil 2.

**Die Falle, die 2a löst:** `MeasurementRun.remaining()` zählt nur Erfolge als erledigt. Mit `--exit-when-done` (`pass(untilDone:)`) würde ein Satz, den das Modell ablehnt, endlos neu
gemessen. Zusätzlich löst jede Ablehnung im Läufer heute den Fehlerzähler und die 60-s-Pause aus, drei abgelehnte Sätze in Folge hielten den Lauf an. Eine Ablehnung ist hier aber das
Messergebnis, kein Fehlversuch.

**Ohne Modell geht es nicht, weil** die Frage lautet, ob das Modell ablehnt; Regeln lehnen nie ab, Nulllinie 0 % (Schnitt 1, `docs/reference/modell-guardrails.md`). Dieser Schnitt führt kein
Modell ein, er macht den bestehenden Läufer fähig, eine Ablehnung als Ergebnis zu behandeln.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Messcode der Labor-App, kein Produktpfad. Der Schalter ist ein Parameter mit Standard `false`; das Verhalten für #88 und die Latenzreihe #534 bleibt bytegleich.

## Source

**File:** `Measurement/MeasurementRun.swift` (Hauptdatei; übrige Dateien in der Tabelle)
**Identifier:** `MeasurementResult.countsAsMeasured(countRefusals:)`, `MeasurementRun.remaining/pass`, `MeasurementPacing.countsAsFailure`, `MeasurementProgress.done(in:countRefusals:)`, `Corpus.countRefusals(from:)`, `Corpus.url(fileName:)`

| Datei | Änderung |
|---|---|
| `Measurement/MeasurementRun.swift` | MODIFY: `MeasurementResult.wasRefused` (`errorKind` ist `guardrail` oder `refusal`) und `countsAsMeasured(countRefusals:)`; `remaining(from:runsPerEntry:countRefusals:)` und `pass(after:from:runsPerEntry:untilDone:countRefusals:)` mit `countRefusals: Bool = false`; `MeasurementPacing.countsAsFailure(_:countRefusals:)`; `MeasurementProgress.done(in:countRefusals:)` (Standard `false`) |
| `Measurement/Corpus.swift` | MODIFY: `countRefusals(from:flag: "--count-failures")`; `url(fileName:)` sucht dritte Stelle `Documents/` der App |
| `LooseEndsLab/MeasurementRunner.swift` | MODIFY: Init-Parameter `countRefusals` (Standard `false`), durchgereicht an `remaining`, `pass`, `done`; im Loop zählt eine Ablehnung nicht als Fehlversuch |
| `LooseEndsLab/LabApp.swift` | MODIFY: Argument lesen, an den Läufer geben |
| `LooseEndsTests/MeasurementRunTests.swift` | MODIFY: Tests (siehe Test Plan) |

Entscheidungen dieser Spec:

- Als **Ablehnung** gelten genau `MeasurementErrorKind.guardrail` und `.refusal` (das Modell hat Nein gesagt). `rateLimited`, `timeout`, `assetsUnavailable`, `contextWindow`, `decoding`,
  `unsupported`, `concurrent` und `andere` sagen nichts über den Text: Sie zählen nie als gemessen, bleiben offen für eine spätere Scheibe und behalten Pause und Dreifehler-Stopp.
- Der Fortschritt zählt mit Schalter Ergebnisse, die `countsAsMeasured` erfüllen, sonst endete der Balken nie bei 100 %. `done(in:)` ohne Parameter bleibt wie bisher.
- `Corpus.url`: Reihenfolge Bündel, Datei neben der Quelle, `Documents/`. Dort liegen die 287 persönlichen Sätze, per `devicectl` abgelegt (2b); sie gehen nie ins Bündel oder Repo.

Nicht in diesem Schnitt: `Shared/`, `FoundationModelsEnricher.swift`, `EnrichmentCoordinator.swift`, `project.yml`, `scripts/sim.sh`, `Measurement/GuardrailReport.swift`.

## Dependencies

| Abhängigkeit | Art |
|---|---|
| `MeasurementErrorKind` (`guardrail`, `refusal`, …) aus #536 | wiederverwendet, unverändert |
| Läufer (#65, #83, #534), `--exit-when-done`, `--runs` | erweitert, Standardverhalten unverändert |
| Schnitt 1 (`GuardrailReport`, Bericht, PR #727) | gemergt |
| Schnitt 2b (Skript, Auswertung, Bericht, Gerätelauf) | folgt, Stufe 3, erst nach Hennings Wort |

## Acceptance Criteria

- **AC-1:** `MeasurementRun.remaining(from:runsPerEntry:countRefusals:)` und `pass(after:from:runsPerEntry:untilDone:countRefusals:)` haben den Parameter `countRefusals: Bool = false`. Ohne ihn
  (Standard) bleibt ein Satz, dessen Ergebnis `guardrail` oder `refusal` trägt, offen, die Rückgabe ist identisch zu der vor der Änderung (Regressionsschutz für #88 und #534).
- **AC-2:** Mit `countRefusals: true` zählt ein Ergebnis als gemessen, wenn es erfolgreich ist oder `errorKind` `guardrail` oder `refusal` trägt. Ergebnisse mit `rateLimited`, `timeout`,
  `assetsUnavailable` oder `contextWindow` zählen nicht und der Satz bleibt in `remaining` offen.
- **AC-3:** Mit `countRefusals: true` und `untilDone: true` terminiert `pass` (kein Satz bleibt wegen einer Ablehnung dauerhaft offen): Eine Simulation über `MeasurementRun`-Ergebnisse, in der
  ein Satz immer abgelehnt wird, endet nach endlich vielen Pässen mit leerer Liste. Ohne Modell, ohne Gerät.
- **AC-4:** Bei `runsPerEntry: 2` zählt jeder abgelehnte Durchlauf einzeln: Nach einer Ablehnung (runIndex 0) bleibt der Satz mit `runIndex` 1 offen, nach zwei Ablehnungen ist er erledigt. Gemischte Folgen
  (Erfolg + Ablehnung) zählen beide.
- **AC-5:** `MeasurementPacing.countsAsFailure(_ result:countRefusals:)` liefert `false` für Erfolge, mit Schalter auch für `guardrail` und `refusal`, und `true` für alle übrigen Fehlerarten; ohne Schalter `true` für jeden
  Fehler. `MeasurementRunner.measureRemaining` benutzt sie: Eine Ablehnung setzt den Zähler `consecutiveFailures` auf 0, löst keine 60-s-Pause aus und zählt nicht zum Dreifehler-Stopp; echte Fehler behalten Pause und Stopp.
  Die Schwellen `giveUpAfterConsecutiveFailures` (3) und `waitAfterFailure` (60) bleiben unverändert.
- **AC-6:** `MeasurementProgress.done(in:countRefusals:)` zählt mit Schalter die Ergebnisse, die `countsAsMeasured` erfüllen; ohne Schalter ist `done(in:)` unverändert `run.succeeded.count`. Der Läufer
  nutzt den Wert für `done`, `progress` und das Ende-Log.
- **AC-7:** `Corpus.countRefusals(from:flag:)` liefert `true`, wenn `--count-failures` in den Argumenten steht, sonst `false`. `LabApp` liest das Argument und übergibt es an `MeasurementRunner(countRefusals:)`.
  Ohne Argument verhält sich die Labor-App wie bisher.
- **AC-8:** `Corpus.url(fileName:)` findet eine Datei `<fileName>.json` in `Documents/` der App als dritte Stelle. Liegt dieselbe Datei im Bündel, gewinnt das Bündel; die Datei neben der Quelle gewinnt vor `Documents/`.
  Das Verhalten für bestehende Korpora bleibt gleich. Fehlt die Datei überall, wirft `url` weiter `CocoaError(.fileNoSuchFile)`.
- **AC-9:** Der PR berührt genau diese fünf Dateien: `Measurement/MeasurementRun.swift`, `Measurement/Corpus.swift`, `LooseEndsLab/MeasurementRunner.swift`, `LooseEndsLab/LabApp.swift`,
  `LooseEndsTests/MeasurementRunTests.swift`. Insbesondere bleiben `Shared/`, `FoundationModelsEnricher.swift`, `EnrichmentCoordinator.swift`, `project.yml`, `scripts/sim.sh` und
  `Measurement/GuardrailReport.swift` unverändert (Dateiliste des PR). Es läuft nichts auf einem Gerät.

## Scope

**Affected Files:** fünf Dateien (vier Produktion/Messcode, eine Test). Schätzung ca. +60/−10 Produktion, ca. +120 Test, zusammen unter 250 LoC. Keine Permissions, keine AppStorage-Keys, kein
CloudKit-Schema, kein `project.yml`, kein Produktpfad. **Kein Pfad der Geräteliste berührt.**

**Schnitt 2b (eigene Spec, #71 bleibt bis dahin offen):** `lab-guardrail` in `scripts/sim.sh`, Korpusbau `guardrail-iphone.json` (Ids ohne Alltagswortlaut), Übernahme Ergebnis → Probe in `GuardrailReport`,
Bericht `docs/reference/modell-guardrails.md` (iPhone-Spalte), Rohdaten. Ein einziger Gerätedurchgang, gebündelt mit #88 Teil 2, nur nach Hennings wörtlichem „jetzt ist ein Test möglich“.

## Test Plan

**Zuordnung AC → Test** (alle in `LooseEndsTests/MeasurementRunTests.swift`, Funktionsnamen entstehen in TDD RED):

| AC | Test |
|---|---|
| AC-1 | (a) ohne Schalter bleibt ein abgelehnter Satz offen, `pass` unverändert |
| AC-2 | (b) mit Schalter zählen `guardrail`/`refusal`; `rateLimited`, `timeout`, `assetsUnavailable`, `contextWindow` bleiben offen |
| AC-3 | (c) Simulation `pass` mit `untilDone` + Schalter terminiert bei einem immer abgelehnten Satz |
| AC-4 | (d) 2 Durchläufe je Text, `runIndex` stimmt, jeder abgelehnte Durchlauf zählt einzeln |
| AC-5 | (e) `countsAsFailure` für Erfolg, Ablehnung, übrige Arten, mit und ohne Schalter |
| AC-6 | (f) `done(in:countRefusals:)` mit und ohne Schalter |
| AC-7 | (g) `Corpus.countRefusals(from:)` mit und ohne Flag; `LabApp`-Verdrahtung durch Dateiliste/Build |
| AC-8 | (h) `Corpus.url` findet Wegwerfdatei in `Documents/` (Test legt an und räumt auf), Bündel hat Vorrang |
| AC-9 | Dateiliste des PR |

RED: Die neuen Tests kompilieren nicht bzw. schlagen fehl, solange die Parameter und Funktionen fehlen. GREEN: alle grün. Lauf nur im Simulator: `./scripts/sim.sh sim-unit MeasurementRunTests`, nie auf dem
Mac-Host, nie auf einem Gerät. Simulator-Durchlauf: Die Änderung der Labor-App hat keine sichtbare Oberfläche; `./scripts/sim.sh build` baut, `sim-unit` ist grün. Ein Gerätelauf gehört ausdrücklich
**nicht** in diesen Schnitt (nichts auf Hennings Geräten ohne sein Wort).

## Alternativen

- **A. Auf der Mac-Zahl entscheiden:** verworfen. Obere Grenze 1,86 % liegt über der Schwelle 1 %, und das iPhone hat die neuere Modellgeneration. Gekippt würde die Annahme, dass Mac und iPhone getrennt zählen.
- **B. Nur die 100 heiklen Texte aufs iPhone:** Notlösung, falls die persönlichen Sätze nicht aufs Gerät sollen; ein Treffer wäre schon 1 %, die Schwelle trüge nicht.
- **C. Läufer ungeändert, abgelehnte Sätze von Hand ausschließen:** verworfen, Endlosschleife mit `--exit-when-done` und kein belastbarer Beleg.
- **D. Ablehnung im Läufer immer als gemessen zählen, ohne Schalter:** verworfen, würde #88 und die Latenzreihe #534 verändern. Der Schalter hält den Standard bytegleich.
- Gekippte ADR: keine.

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt, jedes durch Test oder Dateiliste belegt
- [ ] `MeasurementRunTests` grün; `./scripts/sim.sh sim-unit` grün; `./scripts/sim.sh build` baut
- [ ] Nichts auf einem Gerät gelaufen; Dateiliste des PR enthält nur die fünf Dateien
- [ ] PR mit `Refs #71`; #71 kommentiert (Stand 2a, Rest = 2b)

## Changelog

- 2026-10-28: Initial (Schnitt 2a von 2)
