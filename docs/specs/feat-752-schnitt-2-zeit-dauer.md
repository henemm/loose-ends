---
entity_id: feat-752-schnitt-2-zeit-dauer
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-752-schnitt-2-zeit-dauer
---

# Spec: #752 Schnitt 2 — Zeit- und Dauer-Tabellen ins Sprachpaket

Epic #750. Nach #751. Modell: Haiku.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750.

## Purpose

Die Wörter aus `TimeExpressionParser` und `DurationRule` ziehen nach dem Muster von #751 in die Packs. Keine Logikänderung.

Ohne Modell geht es nicht: nicht relevant.

## Source

- `Shared/Services/TimeExpressionParser.swift`: `cues` (Z. 67: `um`, `auf`, `at`), `spelledHours` (123, Zusatz zu `numbers`: `null`, `dreizehn` … `dreiundzwanzig`),
  `hourUnits` (140), `minuteUnits` (141), `spokenOffsets` (143), Artikelprüfung Z. 132 (`ein`, `eine`, …, nur nach `um`), `uhr` (Z. 129), `am`/`pm` (Z. 164).
- `Shared/Enrichment/DurationRule.swift`: `phrases` (15), `minuteUnits` (23), `hourUnits` (24), `pointInTime` (27).

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| Shared/Language/LanguagePack.swift | MODIFY | Felder `timeCues`, `spelledHours`, `hourUnits`, `minuteUnits`, `spokenOffsets`, `clockWord`, `timeArticles`, `durationPhrases`, `pointInTime` + Sichten |
| Shared/Language/EnglishPack.swift, GermanPack.swift | MODIFY | Werte |
| Shared/Services/TimeExpressionParser.swift | MODIFY | liest Sichten |
| Shared/Enrichment/DurationRule.swift | MODIFY | liest Sichten |
| LooseEndsTests/Language/LanguagePackTests.swift | MODIFY | zwei Tests |

LoC ≈ +90 / −40.

## Implementation Details

- Deutsch: `timeCues` `um`, `auf`; `clockWord` `uhr`; `timeArticles` `ein`, `eine`, `einer`, `einem`, `einen`; `spelledHours` die
  deutschen Zusätze; `hourUnits` `stunde`, `stunden`, `std`, `h`; `minuteUnits` `minute`, `minuten`, `min`; `spokenOffsets` die
  sechs deutschen; `durationPhrases` die zehn deutschen; `pointInTime` `in`, `nach`.
- Englisch: `timeCues` `at`; `clockWord` leer (`""` nie matchen: Regel prüft `!isEmpty`); `timeArticles` leer; `hourUnits`
  `hour`, `hours`, `hrs`, `hr`, `h`; `minuteUnits` `minutes`, `mins`, `min`; `spokenOffsets` `half an hour`, `an hour`;
  `durationPhrases` die sieben englischen; `pointInTime` `in`, `after`. `am`/`pm` bleiben in der Regel (Ziffernkleber, kein Wort).
- Gleiche Wörter in beiden Packs mit gleichem Wert (`h`, `min`, `in`) sind erlaubt; die Sicht entfernt Duplikate.
- `durationPhrases` und `spokenOffsets`: Sicht sortiert **längste Phrase zuerst** (Wortzahl, dann Zeichen), damit
  „eine halbe stunde“ vor „eine stunde“ bleibt (Kommentar Z. 13 der Regel).

## Test Plan

- [ ] `LanguagePackTests.everyPackNamesUnits`: GIVEN jedes Pack THEN `hourUnits`, `minuteUnits`, `durationPhrases` nicht leer.
- [ ] `LanguagePackTests.durationPhrasesLongestFirst`: GIVEN Sicht `LanguagePacks.durationPhrases` THEN Wortzahl nicht aufsteigend.
- [ ] Bestand grün: `RuleGoldenTests`, `TimeExpressionParserTests`, `DurationRuleTests`, `DurationRuleCoordinatorTests`, `DateParserCorpusTests.times`, `TextFormRuleReportTests`.

## Acceptance Criteria

- **AC-1:** `grep -nE '"(stunde|hour|minute|halbe|half|uhr)"' Shared/Services/TimeExpressionParser.swift Shared/Enrichment/DurationRule.swift` leer.
- **AC-2:** `rule-golden.json` unverändert im Diff.
- **AC-3:** `./scripts/sim.sh unit` und CI grün.

## Definition of Done

- [ ] AC-1 bis AC-3 im PR belegt. PR `refactor: Sprachpaket, Zeit und Dauer (Refs #750, Closes #752)`; Merge; Board Done.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.
