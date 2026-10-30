---
entity_id: feat-754-schnitt-4-etiketten
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-754-schnitt-4-etiketten
---

# Spec: #754 Schnitt 4 — Etikett-Wörter ins Sprachpaket, Etikettnamen aus dem Katalog

Epic #750. Nach #751. Modell: Haiku.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750.

## Purpose

`ContextWordRule` kennt die Namen der Standard-Etiketten doppelt fest (`["Garden", "Garten"]`), obwohl sie im Katalog
stehen (`TaskContext.defaultNameKeys`, deutsche Werte in `LooseEnds/Resources/Localizable.xcstrings`). Eine dritte
Sprache müsste die Regel anfassen. Nach diesem Schnitt kommen die Namen je ausgelieferter Sprache aus dem Katalog und die
Wörter aus den Packs.

Ohne Modell geht es nicht: nicht relevant. Das Modell setzt nie Etiketten (#215).

## Source

- `Shared/Enrichment/ContextWordRule.swift` Z. 19–37 (`lists`), `listIndex(for:)` (Z. 76), `same` (Z. 80), `keywords(for:)` (Z. 72).
- `Shared/Models/TaskContext.swift` Z. 29 `defaultNameKeys: [String.LocalizationValue]`.
- `Shared/Persistence/ContextSeeder.swift` Z. 25: Name in Gerätesprache gespeichert — bleibt (ein Name je Etikett, #157).

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| Shared/Language/LanguagePack.swift | MODIFY | `contextWords: [String: [String]]` (Schlüssel = englischer Katalogschlüssel als String, z. B. `"Garden"`) |
| Shared/Language/EnglishPack.swift, GermanPack.swift | MODIFY | Werte |
| Shared/Enrichment/ContextWordRule.swift | MODIFY | Namen je Sprache aus dem Katalog, Wörter aus Sicht |
| LooseEndsTests/ContextWordRuleTests.swift | MODIFY | zwei Tests |

LoC ≈ +70 / −30.

## Implementation Details

- Namen eines Schlüssels `key` in allen Sprachen: `LanguagePacks.active.map { String(localized: String.LocalizationValue(key), locale: Locale(identifier: $0.code)) }`
  (Foundation, iOS 15+). Das Bündel ist das des aufrufenden Targets; `Shared/` kompiliert in Widgets und Share mit
  eigenem Katalog — dort stehen die sechs Schlüssel **nicht**. Deshalb: `String(localized:…, bundle: .main)` **und** als
  Rückfall der Schlüssel selbst (Englisch ist Quellsprache, der Schlüssel ist der englische Name). Fehlt die Übersetzung,
  liefert Foundation den Schlüssel; das ist der heutige Zustand in Widgets und Share und kein Fehler.
- `listIndex(for:)` wird `key(for name:)`: der erste Schlüssel aus `defaultNameKeys`, dessen Namen (alle Sprachen) `same(_, name)`
  erfüllen. Verhalten #157 bleibt: ein Schlüssel wird nur einmal beansprucht (`claimed`).
- Wörter: `LanguagePacks.contextWords(for: key)` = Vereinigung über `active`.
- `ContextWordLearning` unberührt.

## Test Plan

- [ ] `ContextWordRuleTests.defaultNamesResolveInEveryShippedLanguage`: GIVEN `available = ["Garten"]` WHEN Text „Rasen mähen“ THEN Treffer „Garten“ (deutscher Name findet die Garten-Wörter), und GIVEN `available = ["Garden"]` THEN Treffer „Garden“.
- [ ] `ContextWordRuleTests.bothNamesPresentClaimOnlyFirst`: GIVEN `available = ["Garden", "Garten"]` WHEN „Rasen mähen“ THEN genau `["Garden"]` (#157 unverändert).
- [ ] Bestand grün: `RuleGoldenTests` (die Fixture nutzt beide Namenssätze in `available`, s. #764), `ContextWordRuleTests`, `ContextWordLearningTests`, `ConventionBaselineTests`, `RuleLeaveOneOutTests`.
- [ ] `LOOSEENDS_LANG=de ./scripts/sim.sh sim-unit ContextWordRuleTests` grün (Beleg, dass die Auflösung nicht an der Testsprache hängt).

## Acceptance Criteria

- **AC-1:** `grep -nE '"(Garten|Telefon|Haus|Besorgung|Unterwegs|rasen|lawn|anruf|call)"' Shared/Enrichment/ContextWordRule.swift` leer.
- **AC-2:** `rule-golden.json` unverändert.
- **AC-3:** `./scripts/sim.sh unit` grün, der `LOOSEENDS_LANG=de`-Lauf grün, CI grün.

## Definition of Done

- [ ] AC-1 bis AC-3 belegt. PR `refactor: Sprachpaket, Etikettwörter und Namen aus dem Katalog (Refs #750, Closes #754)`; Merge; Board Done.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.
