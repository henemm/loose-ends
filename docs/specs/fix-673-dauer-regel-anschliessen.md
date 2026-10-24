---
entity_id: fix-673-dauer-regel-anschliessen
type: bugfix
created: 2026-10-24
updated: 2026-10-24
status: draft
version: "1.0"
---

# Spec: Dauer-Regel im Produktpfad anschließen (#673)

Grundlage: Issue #673, Entscheidung Henning 2026-10-24 (Tech Lead entscheidet: anschließen, nicht löschen),
Kontext und Analyse in `docs/context/fix-673-duration-rule.md`, Reproduktion in
`docs/artifacts/fix-673-duration-rule/simulator-run.txt`.

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine — Die Regel `DurationRule` (#441) ist beschlossen, hier wird sie nur angeschlossen; ADR-5 (Erkennung) und die Regel „Regeln vor Modell“ bleiben unverändert.

- [ ] Approved

## Source

- **File:** `Shared/Enrichment/EnrichmentCoordinator.swift`
- **Identifier:** `EnrichmentCoordinator.applyRules`, neu `applyDurationRule(to:mode:)`

## Purpose

`DurationRule` (#441) erkennt ausdrücklich genannte Längen („20 Minuten“, „eine halbe Stunde“, „2 hours“),
wird aber nirgends aufgerufen (`grep -rn DurationRule Shared LooseEnds`: nur Regeldatei und Tests).
Ein Erfassungstext mit „20 Minuten“ setzt deshalb nie eine Dauer; im Detail steht nur „+ Duration“.
Bisher funktioniert hat das nie: #441 lieferte nur die Regel und ihre Tests. Reproduziert im Simulator am
2026-10-24 (Erfassen, Detail): Wichtig, Dringend und Datum kommen aus demselben Text an, die Dauer nicht.

## Acceptance Criteria

- **AC-1:** Ein Erfassungstext mit genannter Länge setzt beim ersten Regellauf die Dauer des Eimers, den
  `DurationRule.match(in:)` liefert („Steuerbescheid prüfen 20 Minuten“ → „30 min“). Das Feld steht danach
  mit Herkunft `rule` und Konfidenz 1.0; es gibt genau eine `Revision` des Feldes `duration` mit Autor `rule`
  und der Begründung der Regel.
- **AC-2:** Ein Wert, den der Nutzer gesetzt oder geleert hat (`userHasTouched`), wird im ersten Lauf nicht
  überschrieben; es entsteht keine Revision. Trifft die Regel dann trotzdem, zählt das Feld als „von der Regel
  getroffen“ und bleibt vom Modell unberührt.
- **AC-3:** „Neu analysieren“ ersetzt einen Regelwert oder Modellwert durch den Regeltreffer, einen
  Nutzerwert nie (`EnrichmentWriter.mayWrite`, wie bei Wichtig und Dringend).
- **AC-4:** Reihenfolge wie bei den Kontexten (#232): Hat die Erkennung (früherer gleicher Rohtext, Nutzerwert,
  #136) die Dauer schon getroffen, läuft `DurationRule` nicht. Die Erkennung schlägt die Wortregel.
- **AC-5:** Ein Regeltreffer hält das Modell von der Dauer fern (`matched` enthält `.duration`, #34):
  das Modell überschreibt den Regelwert weder im ersten Lauf noch bei „Neu analysieren“. Ohne Regeltreffer
  bleibt das Verhalten des Modells unverändert.
- **AC-6:** Unteraufgaben bekommen die Dauer-Regel nicht (#565: nur Fälligkeit und Etikett-Wort).
- **AC-7:** Bestand ohne Nachlauf: Aufgaben, bei denen der Regelschritt schon lief (`rulesAppliedAt` gesetzt),
  bekommen die Dauer nur über „Neu analysieren“.
- **AC-8:** Kein Treffer (kein genannter Wert, oder „in 2 Stunden“ als Zeitpunkt) lässt das Feld leer und
  erzeugt keine Revision.
- **AC-9:** Simulator-Durchlauf als Nutzer: Erfassen „Steuerbescheid prüfen 20 Minuten“, Detail öffnen —
  die Zeile `field_duration` zeigt „30 min“ mit dem Uhr-Zeichen `fieldGlyph_duration` (#344). Vor dem Fix
  fehlte das Zeichen (Beleg: `simulator-run.txt`).

## Regeln vor dem Modell

Die Regel ist der Weg; das Modell wird für dieses Feld nicht vorgeschlagen (Konfidenz 1.0, nur was der Nutzer
ausdrücklich sagt). Wo kein Treffer ist, bleibt es beim bisherigen Modellverhalten. Alternativen: (B) Regel und
Tests entfernen, Dauer nur Modell/Nutzer — verworfen: Modell fehlt ohne Apple Intelligence, bei Dauer nie
gemessen, würde #441 kippen. (C) Regelwert nur als Vorschlag im Detail („30 min übernehmen?“) — verworfen für
jetzt: weicht vom Muster aller Regelfelder ab, mehr Oberfläche; eigenes Ticket, falls die Aufrundung stört.

## Nicht-Scope

- Aufrundung in den nächsten Eimer (20 Min → „30 min“): Entscheidung aus #441.
- Nachlauf über den Bestand (AC-7).
- Dauer für Unteraufgaben (AC-6).
- Änderungen an `DurationRule` selbst, am Modell oder am Schema (keine neuen Felder, kein CloudKit-Eingriff).

## Scope

- `Shared/Enrichment/EnrichmentCoordinator.swift`: `applyDurationRule(to:mode:)` nach Muster `applyImportanceRule`
  (~25 Zeilen), Aufruf in `applyRules` nach der Erkennung, nur wenn `.duration` nicht in `matched`.
- `LooseEndsTests/DurationRuleCoordinatorTests.swift` (neu): Koordinatortests zu AC-1 bis AC-8 mit
  `StubEnricher` und In-Memory-Speicher (Container im Test am Leben halten).
- `LooseEndsUITests/FieldsSmokeTests.swift`: `testSignsStandInTheRowAndBehindTheValuesInTheDetail` prüft zusätzlich
  `field_duration` mit `fieldGlyph_duration`; der Kommentar darüber („the capture text sets no duration“) wird berichtigt.

3 Dateien, ca. +35 Zeilen Produktcode, +90 Zeilen Tests.

## Abnahme

Stufe 1: Unit-Tests (`sim-unit`) und UI-Smoke grün. Stufe 2: Simulator-Durchlauf nach AC-9 mit `test-proof`.
Stufe 3: Pflicht, weil `Shared/Enrichment/EnrichmentCoordinator.swift` auf der Geräteliste steht — über TestFlight
nach dem Merge, nichts auf Hennings Geräten ohne sein „jetzt ist ein Test möglich“. Zu prüfen auch: Die
Kalender-Rückfrage (`CalendarAskSheet`) liest `duration` und ist mit einer Regeldauer vorbefüllt; das ist gewollt.

## Dependencies

| Entity | Zweck |
|--------|-------|
| `DurationRule` | liefert Eimer, Konfidenz, Begründung |
| `EnrichmentWriter.mayWrite` / `userHasTouched` | entscheidet, ob geschrieben werden darf |
| `RecognitionRule` | setzt `.duration` vorher aus früherem Nutzerwert (AC-4) |
| `Revision`, `FieldSource` | Revision mit Autor `rule`, Herkunft `rule` |

## Definition of Done

- [ ] AC-1 bis AC-9 erfüllt
- [ ] Koordinatortests grün, alle Unit-Tests grün (`sim-unit`)
- [ ] UI-Smoke `FieldsSmokeTests` grün, Simulator-Beleg per `test-proof`
- [ ] Stufe 3 über TestFlight (Geräteliste) nach dem Merge
- [ ] #673 geschlossen, Board auf Done

## Test Plan

Unit (`DurationRuleCoordinatorTests`): erster Lauf setzt Dauer + Revision (AC-1); Nutzerwert bleibt (AC-2);
„Neu analysieren“ ersetzt Regel-/Modellwert, nie Nutzerwert (AC-3); Erkennung schlägt Regel (AC-4); Modell
überschreibt Regeltreffer nicht, erster Lauf und Neu analysieren (AC-5); Unteraufgabe ohne Dauer (AC-6);
Bestand ohne Nachlauf (AC-7); kein Treffer / „in 2 Stunden“ (AC-8). UI: `FieldsSmokeTests` (AC-9).

## Changelog

- 2026-10-24: Initial (#673)
