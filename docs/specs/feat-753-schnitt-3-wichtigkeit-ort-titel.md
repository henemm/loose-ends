---
entity_id: feat-753-schnitt-3-wichtigkeit-ort-titel
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-753-schnitt-3-wichtigkeit-ort-titel
---

# Spec: #753 Schnitt 3 — Wichtigkeit, Dringlichkeit, Ort und Titel-Füllwörter ins Sprachpaket

Epic #750. Nach #751, unabhängig von #752. Modell: Haiku.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750.

## Purpose

Dieselbe Bewegung wie #752 für drei weitere Regeln. Keine Logikänderung; die Negationslogik (#214, #220) bleibt in der Regel.

Ohne Modell geht es nicht: nicht relevant.

## Source

- `Shared/Enrichment/ImportanceUrgencyRule.swift`: Wortlisten der `ImportanceSignal`/`UrgencySignal`-Fälle (Z. 10–48, je Fall `keywords` und `reason`), `negations` (70), `intensifiers` (82).
- `Shared/Enrichment/PlaceWordRule.swift`: `phrases` (12).
- `Shared/Services/TitleRule.swift`: `leadIns` (18), `connectors` (21), `dateWords` (68).

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| Shared/Language/LanguagePack.swift | MODIFY | `importanceSignals: [Signal: [String]]`, `urgencySignals`, `negations`, `intensifiers`, `placePhrases`, `titleLeadIns`, `titleConnectors` |
| Shared/Language/EnglishPack.swift, GermanPack.swift | MODIFY | Werte |
| Shared/Enrichment/ImportanceUrgencyRule.swift, PlaceWordRule.swift | MODIFY | lesen Sichten |
| Shared/Services/TitleRule.swift | MODIFY | `leadIns`/`connectors` aus Sicht; `dateWords` aus `LanguagePacks.weekdays.keys ∪ months.keys` |
| LooseEndsTests/Language/LanguagePackTests.swift | MODIFY | zwei Tests |

LoC ≈ +110 / −60.

## Implementation Details

- Die Signal-Fälle (`ImportanceSignal`, `UrgencySignal`, `CaseIterable`) bleiben als Enum in der Regel; nur ihre
  Wortlisten kommen aus `LanguagePacks.importanceWords(for: signal)` (Vereinigung über `active`). Die Fälle sind der
  Schlüssel im Pack (`[ImportanceSignal: [String]]`); ein Pack darf einen Fall leer lassen.
- `placePhrases` als `[(words: [String], slot: SavedPlaces.Slot)]`; `SavedPlaces` liegt in `Shared/Models` (sichtbar in allen Targets).
- `dateWords` in `TitleRule` wird abgeleitet statt doppelt gepflegt: `Set(LanguagePacks.weekdays.keys).union(LanguagePacks.months.keys)`.
  Achtung Golden-Test: die heutige Liste in `TitleRule` ist **kleiner** (Englisch ohne „april“, „may“, „august“, „september“,
  „november“, weil sie zugleich Wörter sind). Darum **zwei Commits**: erst `dateWords` ableiten und `RuleGoldenTests`
  laufen lassen. Ändert sich eine Zeile der Fixture, bleibt `dateWords` eine eigene Pack-Tabelle mit den heutigen Wörtern
  (`titleDateWords`), und der Spec-Changelog vermerkt es. Nichts darf die Fixture ändern.
- `leadIns` de: `bis`, `am`, `um`, `ab`, `zum`; en: `by`, `on`, `at`. `connectors` de: `und`; en: `and`.

## Test Plan

- [ ] `LanguagePackTests.everyPackHasNegationAndSignals`: GIVEN jedes Pack THEN `negations` nicht leer, mindestens ein Wort für `ImportanceSignal.explicit` und das explizite Dringlichkeitssignal.
- [ ] `LanguagePackTests.everyPackHasPlacePhrasesForBothSlots`: GIVEN jedes Pack THEN je Slot (`home`, `work`) mindestens eine Phrase.
- [ ] Bestand grün: `RuleGoldenTests`, `ImportanceUrgencyRuleTests`, `PlaceWordRuleTests`, `TitleRuleTests`, `TextFormRuleReportTests`.

## Acceptance Criteria

- **AC-1:** `grep -nE '"(wichtig|dringend|important|urgent|nicht|not|hause|home|bis|by|und|and)"' Shared/Enrichment/ImportanceUrgencyRule.swift Shared/Enrichment/PlaceWordRule.swift Shared/Services/TitleRule.swift` leer.
- **AC-2:** `rule-golden.json` unverändert.
- **AC-3:** `./scripts/sim.sh unit` und CI grün.

## Definition of Done

- [ ] AC-1 bis AC-3 belegt. PR `refactor: Sprachpaket, Wichtigkeit, Ort, Titelwörter (Refs #750, Closes #753)`; Merge; Board Done.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.
