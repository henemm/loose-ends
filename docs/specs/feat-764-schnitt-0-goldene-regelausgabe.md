---
entity_id: feat-764-schnitt-0-goldene-regelausgabe
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-764-schnitt-0-goldene-regelausgabe
---

# Spec: #764 Schnitt 0 — Goldene Regelausgabe über alle Korpora

Epic #750. Modell: Haiku. Kein Produktcode außer einer Zeile in `scripts/sim.sh`.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750 („komplett autonom, ohne mein Zutun“). Keine Rückfrage.

## Purpose

Schnitt 1–4 (#751–#754) ziehen jedes Regelwort aus sieben Dateien nach `Shared/Language/`. Die vorhandenen
Korpus-Abnahmen sind Schwellen (`DateParserCorpusTests`: Datum ≥ 95 % exakt, 0 erfunden; Uhrzeit ≥ 95 %), keine
Gleichheit: ein verlorenes Wort, das drei Sätze kostet, bliebe unter der Schwelle unsichtbar. Darum friert dieser
Schnitt **vor** dem ersten Umzug die Ausgabe jeder Regel über jeden Korpussatz als Datei ein. Jeder spätere Schnitt
muss sie byte-gleich lassen.

Ohne Modell geht es nicht: nicht relevant, kein Modell beteiligt.

## Source

- `LooseEndsTests/DateParserCorpusTests.swift` — Muster für Korpuslauf mit festem Bezugstag (`CorpusTests.reference`, `CorpusTests.calendar`).
- `Measurement/Corpus.swift` `Corpus.load()` (319 Einträge, `Entry.id`, `.lang`, `.text`); `Measurement/ConventionCorpus.swift` `load()` (10 Muster);
  Textform-Korpus wie `LooseEndsTests/TextFormRuleReportTests.swift` ihn lädt (40 Inhalte, Formen `typed`, `dictated`, `english` plus Mail-Formen).
- Regel-Einstiege: `DateExpressionParser(calendar:).date(in:reference:)`, `TimeExpressionParser().time(in:)`,
  `DurationRule.match(in:)`, `ImportanceUrgencyRule.matchImportance(in:)`/`matchUrgency(in:)`, `PlaceWordRule.slot(in:)`,
  `ContextWordRule.match(in:available:)`, `TitleRule.title(from:reference:calendar:)`.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `LooseEndsTests/Fixtures/` | Ordner | nimmt `rule-golden.json` auf |
| `scripts/sim.sh` `run_xcodebuild()` | module | reicht `LOOSEENDS_UPDATE_GOLDEN` als `TEST_RUNNER_LOOSEENDS_UPDATE_GOLDEN` durch (Muster Z. 418, 445) |

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsTests/RuleGoldenTests.swift | NEW | ein Test, berechnet die Tabelle und vergleicht mit der Fixture |
| LooseEndsTests/Fixtures/rule-golden.json | NEW | die eingefrorene Ausgabe, aus dem Stand vor #751 |
| scripts/sim.sh | MODIFY | eine Zeile: Variable durchreichen |
| scripts/test_sim_run_xcodebuild.py | MODIFY | ein Test: Variable kommt als `TEST_RUNNER_…` an |

LoC: Test ≈ 140, sim.sh +1, Skripttest +8. Produktcode 0.

## Implementation Details

1. Sätze einsammeln: `Corpus.load()` (ID = `entry.id`), Textform (ID = `<content>.<form>`), Konvention (ID = `conv.<patternID>`).
   Reihenfolge egal, die Ausgabe wird nach ID sortiert.
2. Je Satz eine Zeile mit festen Schlüsseln, alle Werte Strings, `nil` = `"–"`:
   `date` (`yyyy-MM-dd` im Kalender `CorpusTests.calendar`, Bezugstag `CorpusTests.reference`), `time` (`HH:mm`),
   `duration` (`DurationBucket.rawValue`), `importance`, `urgency` (`rawValue`), `place` (`SavedPlaces.Slot` rawValue),
   `contexts` (Namen mit `, ` verbunden; `available` = die sechs englischen Schlüssel aus `TaskContext.defaultNameKeys`
   plus `"Telefon", "Haus", "Garten", "Besorgung", "Unterwegs"`), `title` (`TitleRule.title`, Bezugstag wie oben).
3. JSON mit `JSONEncoder` und `.sortedKeys`, `.prettyPrinted`; Fixture-Pfad aus `#filePath` → `Fixtures/rule-golden.json`.
4. Vergleich als Text. Bei Abweichung: `#expect` schlägt fehl mit den ersten 20 Zeilen `<id>: <feld> war <alt> → ist <neu>`.
5. `ProcessInfo.processInfo.environment["LOOSEENDS_UPDATE_GOLDEN"] == "1"`: Fixture schreiben, danach **absichtlich**
   fehlschlagen mit „Fixture neu geschrieben, Diff prüfen und den Schalter entfernen“.
6. Anzahl der Zeilen im Test fest (`#expect(rows.count == N)`, N beim Erzeugen eintragen), damit ein stillschweigend
   kleinerer Korpus auffällt.

Keine Schwelle, keine Toleranz: Gleichheit.

## Test Plan

- [ ] `RuleGoldenTests.matchesFixture`: GIVEN Fixture aus dem aktuellen Stand WHEN Lauf THEN grün.
- [ ] Manuell im PR belegt: GIVEN `"tomorrow"` lokal aus `relativeDays` gestrichen WHEN Lauf THEN rot, Meldung nennt mindestens eine Satz-ID mit `date war … → ist –`.
- [ ] `scripts/test_sim_run_xcodebuild.py::test_update_golden_is_passed_through`: GIVEN `LOOSEENDS_UPDATE_GOLDEN=1` WHEN `test` THEN Umgebung der Attrappe enthält `TEST_RUNNER_LOOSEENDS_UPDATE_GOLDEN=1`; ohne Variable nicht.

## Acceptance Criteria

- **AC-1:** Fixture eingecheckt, Test grün in der CI (`unit`-Job) und lokal (`./scripts/sim.sh sim-unit RuleGoldenTests`).
- **AC-2:** Ein gestrichenes Wort macht den Test rot mit Satz-IDs (Logauszug im PR).
- **AC-3:** `LOOSEENDS_UPDATE_GOLDEN=1` schreibt die Datei neu und lässt den Lauf rot enden.
- **AC-4:** Diff berührt nur die vier Dateien oben.

## Definition of Done

- [ ] AC-1 bis AC-4 belegt im PR (Testlauf-Log, Logauszug des roten Laufs, Diff).
- [ ] PR-Titel `test: goldene Regelausgabe über alle Korpora (Closes #764)`; Merge nach grüner CI; Board Done.
- [ ] Abschlussbericht enthält den Satz „Kein Pfad der Geräteliste berührt.“

## Architektur-Entscheidung (ADR)

- keine; Testinfrastruktur.

## Changelog

- 2026-10-30: Spec erstellt (Cloud-Sitzung, Plan #750).
