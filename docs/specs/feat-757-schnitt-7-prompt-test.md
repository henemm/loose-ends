---
entity_id: feat-757-schnitt-7-prompt-test
type: feature
created: 2026-10-30
updated: 2026-10-30
status: approved
workflow: feat-757-schnitt-7-prompt-test
---

# Spec: #757 Schnitt 7 — Test bindet den Modell-Prompt an `LanguagePacks.shipped`

Epic #750. Nach #751. Modell: Haiku. Kein Produktcode. Keine Stufe 3.

## Approval

- [x] Approved — pauschal durch Henning am 2026-10-30 über #750.

## Purpose

`Shared/Enrichment/FoundationModelsEnricher.swift` steht auf der Geräteliste (Stufe 3 mit Hennings Rückmeldung).
Das Epic läuft ohne Henning, die Datei bleibt unberührt; ihr Satz „The note may be German or English; answer in the
note's language“ (Z. 26) gilt für beide ausgelieferten Sprachen. Ein Test stellt sicher, dass eine dritte Sprache den
Prompt nicht vergisst.

Ohne Modell geht es nicht: nicht relevant, nur ein Test.

## Source

- `FoundationModelsEnricher.instructions` (Z. 25–34), `#if canImport(FoundationModels)` um die Datei.
- `LanguagePack.name` (#751): „English“, „German“.

## Scope

| File | Change Type | Description |
|------|-------------|-------------|
| LooseEndsTests/Language/ModelPromptLanguagesTests.swift | NEW | ein Test |
| docs/reference/modell-verfuegbarkeit.md | MODIFY | ein Satz zur Sprache |

LoC Test ≈ 30.

## Implementation Details

- Der Test liest die **Datei als Text** (Pfad aus `#filePath` → `../../Shared/Enrichment/FoundationModelsEnricher.swift`),
  nicht das Symbol: so hängt er nicht an `canImport(FoundationModels)` und fasst die Datei nie an.
- Für jedes Pack in `LanguagePacks.shipped`: `#expect(text.contains(pack.name), "Prompt nennt \(pack.name) nicht. Prompt anpassen und auf dem Gerät messen (Stufe 3, docs/reference/neue-sprache.md Punkt 4).")`.
- Doku-Satz: Apple Intelligence antwortet nur in den unter „Apple Intelligence & Siri“ eingestellten Sprachen
  (`06-annahmen-und-experimente.md`); eine Notiz in einer anderen Sprache kann die Verweigerung auslösen, die als
  fehlgeschlagener Aufruf zählt (#530); die Regelwerte bleiben.

## Test Plan

- [ ] `ModelPromptLanguagesTests.promptNamesEveryShippedLanguage`: GIVEN `shipped` = en, de THEN grün.
- [ ] Manuell im PR: GIVEN `withPacks(shipped + [.test])` (lokal) THEN rot mit der Meldung samt „Testish“; Logauszug, nicht eingecheckt.

## Acceptance Criteria

- **AC-1:** `git diff --stat main -- Shared/Enrichment/FoundationModelsEnricher.swift` leer.
- **AC-2:** Test grün in CI; roter Probelauf im PR gezeigt.

## Definition of Done

- [ ] AC-1, AC-2 belegt. PR `test: Prompt an die ausgelieferten Sprachen gebunden (Refs #750, Closes #757)`; Merge; Board Done.
- [ ] „Kein Pfad der Geräteliste berührt.“

## Changelog

- 2026-10-30: Spec erstellt.
