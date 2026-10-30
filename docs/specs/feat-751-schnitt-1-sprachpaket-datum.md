---
entity_id: feat-751-schnitt-1-sprachpaket-datum
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-751-schnitt-1-sprachpaket-datum
---

# Spec: #751 Schnitt 1 — `LanguagePack` und die Datumstabellen

Epic #750. Nach #764. Modell: Sonnet oder Opus (der Typ wird Muster für #752–#755).

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750. Keine Rückfrage.

## Purpose

Eine Datei je Sprache trägt die Wörter, die eine Regel kennt; `LanguagePacks.shipped` ist die eine Liste der
ausgelieferten Sprachen. In diesem Schnitt nur das Datum. Regeln prüfen alle ausgelieferten Sprachen zugleich
(Henning, 2026-10-30), wie heute Deutsch und Englisch (`DateExpressionParser.swift` Z. 25: kein Sprachfeld im Produkt).

Ohne Modell geht es nicht: nicht relevant, Regelcode.

## Source

- `Shared/Services/DateExpressionParser.swift`: `ExpressionText.numbers` (Z. 74), `weekdays` (156), `months` (162),
  `relativeDays` (169), `nextWords` (170), `dayUnits` (171), `weekUnits` (172), `dayPrepositions` (173),
  `ordinalSuffixes` (174), `repetitions` (175). Faltung `ExpressionText.folded` (Z. 31) bleibt.

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| #764 `RuleGoldenTests` | test | Gleichheit der Ausgabe |
| `DateParserCorpusTests`, `DateExpressionParserTests`, `DueDateRuleTests`, `TitleRuleTests` | test | bleiben grün |
| `Shared/` in allen Targets (project.yml Z. 40, 127, 213, 245) | build | neue Dateien brauchen keinen Eintrag; `generate` läuft |

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| Shared/Language/LanguagePack.swift | NEW | `struct LanguagePack` (nur Datumsfelder) + `enum LanguagePacks` mit `shipped`, `active`, zusammengeführte Sichten |
| Shared/Language/EnglishPack.swift | NEW | `extension LanguagePack { static let english }` |
| Shared/Language/GermanPack.swift | NEW | `static let german` |
| Shared/Services/DateExpressionParser.swift | MODIFY | Tabellen raus, Sichten rein; `ExpressionText.numbers` wird `LanguagePacks.numbers` |
| LooseEndsTests/Language/LanguagePackTests.swift | NEW | Formtests |

LoC: ≈ +170 / −60. Unter 250.

## Implementation Details

```swift
struct LanguagePack: Sendable {
    let code: String            // ISO 639-1, "en", "de"
    let name: String            // englischer Name, "English", "German" (für #757)
    let numbers: [String: Int]
    let weekdays: [String: Int] // 1 = Sonntag wie Calendar
    let months: [String: Int]
    let relativeDays: [String: Int]
    let nextWords: [String]
    let dayUnits: [String]
    let weekUnits: [String]
    let dayPrepositions: [String]
    let ordinalSuffixes: [String]
    let repetitions: [String]
}

enum LanguagePacks {
    static let shipped: [LanguagePack] = [.english, .german]
    /// Testhaken (#755): die Tests hängen ein Paket ein. Produktcode liest nur `active`.
    nonisolated(unsafe) static var active: [LanguagePack] = shipped
    static var numbers: [String: Int] { merged(\.numbers) }
    static var weekdays: [String: Int] { merged(\.weekdays) }
    // … je Feld eine Sicht; Listen: `active.flatMap`, nach Länge absteigend sortiert, Duplikate entfernt
    private static func merged(_ key: KeyPath<LanguagePack, [String: Int]>) -> [String: Int] {
        active.reduce(into: [:]) { result, pack in
            result.merge(pack[keyPath: key]) { old, new in
                precondition(old == new, "Wort mit zwei Werten in zwei Packs")
                return old
            }
        }
    }
}
```

- Alle Wörter **gefaltet** eintragen, wie sie heute stehen („nachste“, „ubermorgen“); kein Wort dazu, keins weg.
  Deutsch bekommt genau die deutschen, Englisch die englischen; „ubermorgen“ → de, `ordinalSuffixes` → en,
  `dayPrepositions` („am“, „zum“, „bis“) → de (Englisch nutzt „the“-Logik Z. 252, bleibt in der Regel).
- Swift 6: `active` ist Testhaken; `nonisolated(unsafe)` mit Kommentar, oder `@MainActor`, falls alle Aufrufer
  es schon sind — der Agent prüft, was kompiliert, ohne `try?` und ohne Warnung.
- Die Sichten **nicht cachen** (jeder Zugriff liest `active`); Laufzeit ist bei zwei Packs unerheblich.
- `DateExpressionParser` ändert keine Logik, nur die Quelle der Tabellen.

## Test Plan

- [ ] `LanguagePackTests.shippedIsEnglishAndGerman`: GIVEN `shipped` THEN Codes genau `["en", "de"]`.
- [ ] `LanguagePackTests.everyPackHasSevenWeekdaysAndTwelveMonths`: GIVEN jedes Pack THEN 7 Wochentagswerte 1–7 und 12 Monatswerte 1–12 vorhanden.
- [ ] `LanguagePackTests.mergedViewsHoldBothLanguages`: GIVEN `active = shipped` THEN `weekdays["montag"] == 2` und `weekdays["monday"] == 2`.
- [ ] `LanguagePackTests.wordsAreFolded`: GIVEN jedes Wort jedes Packs THEN `ExpressionText.folded(word) == word`.
- [ ] Bestand: `RuleGoldenTests`, `DateParserCorpusTests`, `DateExpressionParserTests`, `DueDateRuleTests`, `TitleRuleTests` unverändert grün.

## Acceptance Criteria

- **AC-1:** `grep -nE '"(montag|monday|januar|january|heute|today|next|nachste)"' Shared/Services/DateExpressionParser.swift` liefert nichts.
- **AC-2:** `RuleGoldenTests` grün ohne Fixture-Änderung (Diff enthält `rule-golden.json` nicht).
- **AC-3:** `./scripts/sim.sh unit` grün; CI grün.
- **AC-4:** `DATE-TITLE-REPORT` im CI-Log zeigt Regelspalte 99.3 % / 0.0 % wie `docs/reference/date-title-fidelity.md`.

## Definition of Done

- [ ] AC-1 bis AC-4 im PR belegt (grep-Ausgabe, Diff-Dateiliste, CI-Link, Report-Auszug).
- [ ] `./scripts/sim.sh generate` gelaufen; „Generate leaves the tree clean“ grün.
- [ ] PR `refactor: Sprachpaket, Datumstabellen (Refs #750, Closes #751)`; Merge; Board Done.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“

## Architektur-Entscheidung (ADR)

- ADR-10 wird in #762 neu gefasst; dieser Schnitt kippt nichts.

## Changelog

- 2026-10-30: Spec erstellt.
