---
entity_id: feat-755-schnitt-5-testpaket-konformitaet
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-755-schnitt-5-testpaket-konformitaet
---

# Spec: #755 Schnitt 5 — Testpaket und Konformitätstests

Epic #750. Nach #752–#754. Modell: Sonnet.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750.

## Purpose

Beweis, dass eine Sprache steckbar ist, ohne eine dritte auszuliefern (Henning, 2026-10-30): ein Pack mit erfundenen
Wörtern lebt in `LooseEndsTests`, wird eingehängt, und jede Regel versteht es — ohne dass eine Regeldatei angefasst wird.
Dazu Konformitätsregeln, die ein neues Pack einhalten muss, und die Entscheidung zur Faltung.

Ohne Modell geht es nicht: nicht relevant.

## Source

- `LanguagePacks.active` (#751), alle Sichten (#751–#754).
- Faltung: `ExpressionText.folded` (`DateExpressionParser.swift` Z. 31) und `RawTextWords.normalized` (Z. 15), beide `Locale("de_DE")`.

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsTests/Language/TestPack.swift | NEW | `LanguagePack.test`, Code `zz`, Name `Testish` |
| LooseEndsTests/Language/LanguagePackPluggingTests.swift | NEW | ein Satz, sieben Felder |
| LooseEndsTests/Language/LanguagePackConformanceTests.swift | NEW | Regeln über `shipped` + `test` |
| LooseEndsTests/Language/WithPacks.swift | NEW | `withPacks(_:_:)`: setzt `active`, stellt im `defer` zurück |
| Shared/Language/LanguagePack.swift | MODIFY | nur falls ein Feld für die Steckbarkeit fehlt; sonst 0 LoC |
| Shared/Services/RawTextWords.swift, DateExpressionParser.swift | MODIFY | Kommentar zur Faltung (Entscheidung unten), kein Codewechsel |

LoC Produkt ≤ 20.

## Implementation Details

**Testpaket `zz`** (alles gefaltet, keine Umlaute): `relativeDays` `blorp` = 0, `snib` = 1; `weekdays` `mondu` = 2 … `sundu` = 1;
`months` `janx` = 1 … ; `nextWords` `nexo`; `dayUnits` `dayo`; `weekUnits` `weeko`; `numbers` `uno` = 1, `duo` = 2;
`timeCues` `att`; `clockWord` `klok`; `hourUnits` `quarnt`; `minuteUnits` `minx`; `durationPhrases` `(“halfquarnt”, 30)`;
`pointInTime` `inn`; `importanceSignals[.explicit]` `zingo`; `urgencySignals[explizit]` `zoom`; `negations` `nix`;
`placePhrases` `["at", "florp"] → .home`, `["at", "worx"] → .work`; `titleLeadIns` `byy`; `contextWords["Garden"]` `grassle`.

**Steckbarkeit:** `withPacks([.english, .german, .test]) { … }` und der Satz
„grassle mowing snib att duo klok, takes halfquarnt, zingo, at florp“ ergibt: Datum = Bezugstag + 1, Zeit 02:00,
Dauer `minutes30`, Wichtigkeit `.high`, Ort `.home`, Etikett „Garden“ (mit `available = ["Garden"]`), Titel ohne „snib“
und „byy“-Zeile. Jede Erwartung ein eigenes `#expect` mit dem Feldnamen in der Meldung.

**Konformität** (je Regel ein Test, Schleife über `shipped + [.test]`):
1. Kein Wort in zwei Packs mit verschiedenem Wert (`numbers`, `weekdays`, `months`, `relativeDays`, `spelledHours`, Phrasen-Minuten).
2. Jede Tabelle nicht leer, außer dort, wo die Spec #752 Leere erlaubt (`clockWord`, `timeArticles` für `en`).
3. Jedes Wort: `ExpressionText.folded(w) == w`, kein führendes/folgendes Leerzeichen, nicht leer.
4. **Kreuzungen:** ein Wort, das in Pack A eine Rolle hat und in Pack B ein Alltagswort ist, steht in einer
   `allowedCrossings: [String: String]`-Liste mit Begründung (heute mindestens: `am` (de Präposition / en „I am“),
   `in` (beide `pointInTime`), `h`/`min` (beide Einheiten), `at` (en Cue / de nichts)). Der Test prüft nur, dass jedes Wort,
   das in ≥ 2 Packs vorkommt, entweder gleichen Wert hat oder in der Liste steht.

**Faltung, entschieden hier:** `.diacriticInsensitive` ist sprachunabhängig, `ß` bleibt stehen. Probe im Schnitt:
`Locale(identifier: "en_US_POSIX")` statt `de_DE` in beiden Funktionen, `RuleGoldenTests` laufen lassen. Fixture
unverändert → Wechsel übernehmen (ein Kommentar: „sprachneutral, geprüft #755“). Fixture ändert sich → `de_DE` bleibt,
Kommentar nennt den Satz, der kippte. Keine dritte Option.

## Test Plan

- [ ] `LanguagePackPluggingTests.testPackSetsEveryField` (sieben `#expect`).
- [ ] `LanguagePackPluggingTests.withoutTestPackNothingIsSet`: GIVEN `active = shipped` WHEN derselbe Satz THEN Datum, Zeit, Dauer, Ort, Etikett `nil`; Wichtigkeit `nil`.
- [ ] `LanguagePackConformanceTests.noWordHasTwoValues`, `.noTableIsEmpty`, `.everyWordIsFolded`, `.crossingsAreListed`.
- [ ] `WithPacks` stellt `active` auch bei `throw` zurück (`defer`), Test `activeIsRestoredAfterThrow`.
- [ ] Bestand grün inkl. `RuleGoldenTests`.

## Acceptance Criteria

- **AC-1:** Die Steckbarkeits-Tests sind grün, und `git diff --stat main -- Shared/Enrichment Shared/Services` zeigt außer Kommentaren (Faltung) **keine** Zeile.
- **AC-2:** Konformitätstests grün für `en`, `de`, `zz`.
- **AC-3:** Faltungsentscheidung im Code-Kommentar und im Spec-Changelog mit Ergebnis der Golden-Probe.

## Definition of Done

- [ ] AC-1 bis AC-3 belegt (Diff-Stat im PR). PR `test: Testpaket und Konformität der Sprachpakete (Refs #750, Closes #755)`; Merge; Board Done.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.
- 2026-10-31: Faltung entschieden: `Locale(identifier: "en_US_POSIX")` in `ExpressionText.folded` und `RawTextWords.normalized`; `RuleGoldenTests` blieb grün ohne Fixture-Änderung (CI-Lauf 41221740523). `active` ist ein Task-Local (`LanguagePacks.pluggedIn`, `withPacks`) statt `nonisolated(unsafe) var`, weil Swift Testing Tests im selben Prozess parallel fährt.
