# Context: rule-117-importance-urgency

## Request Summary
Wichtigkeit (`importance`) und Dringlichkeit (`urgency`) sollen künftig ausschließlich regelbasiert
(Textmuster/Schlüsselwörter) bestimmt werden, kein `FoundationModelsEnricher`-Aufruf mehr für diese
beiden Felder (Issue #117, aus #112 Alternative 1). Grund: #111 hat gezeigt, dass die bisherige
FocusBlox-„Wahrheit" für diese Felder ohnehin nur Fallback-Standardwerte war, nie ein echtes
Modellurteil — das bestärkt den Regelansatz zusätzlich zur Projektregel „Regeln vor Modell".

## Related Files

| File | Relevance |
|------|-----------|
| `Shared/Enrichment/DueDateRule.swift` (57 LoC) | Exaktes Vorbild-Muster für genau diesen Umbau (#92/#95, Datum statt Modell) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | `applyRules(to:)` ruft `DueDateRule` vor dem Modellaufruf auf, schreibt bei leerem Feld direkt Revision + Task-Property — neue Regel dockt hier an |
| `Shared/Enrichment/EnrichmentWriter.swift:47-59` | Heute: `draft.importance`/`draft.urgency` mit 0.6-Konfidenzschwelle geschrieben — wird toter Code, sobald das Modell die Felder nicht mehr liefert, sollte entfernt werden |
| `Shared/Enrichment/EnrichmentDraft.swift` | `Guess<Importance>?`/`Guess<Urgency>?`; `selfConsistencyValues` (#108) liest beide mit — rein lesend betroffen, keine Änderung nötig |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | `ModelEnrichment`-Schema (Z. 105-117), Prompt-Satz mit Signalwörtern (Z. 28), Mapping (Z. 67-71), Retrieval-Beispiele im Prompt (Z. 47-48) — alles zu `importance`/`urgency` müsste raus |
| `Shared/Services/DateExpressionParser.swift` (`ExpressionText`) | Geteilte Tokenisierung (`folded`, `words`), wiederverwendbar statt eigener Regex-Logik |
| `Shared/Models/Enums.swift:21-22` | `Importance`/`Urgency`: Rohwerte `low, medium, high` |
| `Shared/Models/TaskItem.swift:42-49,97-103` | `importanceRaw`/`urgencyRaw` + Source/Confidence, computed Property — unverändert nutzbar |
| `Shared/Services/FieldCodec.swift:13-14,46-53` | Generischer Reset/Encode-Pfad, feldquellen-unabhängig — keine Änderung nötig |
| `LooseEndsTests/DueDateRuleTests.swift` (153 LoC) | Teststil-Vorlage: reine Beispiel-Tests, kein Korpus-Score |
| `docs/specs/enrichment/feat-95-parser-in-app.md` | Direkte Vorlage für Spec-Gliederung (gleicher Mechanismus, gleiche Codebase-Stelle) |
| `LooseEnds/Resources/Localizable.xcstrings` | Feld-Labels „Wichtigkeit"/„Dringlichkeit" bereits übersetzt; neue Regel-Begründungssätze fehlen noch (analog #98) |

## Existing Patterns

**Vorbild-Muster (`DueDateRule`):** `DueDateRule.match(in:reference:calendar:)` liefert deterministisch
ein `Guess`-Tripel mit fester Konfidenz `1.0` (klart die 0.6-Schwelle immer) oder `nil`;
`EnrichmentCoordinator.applyRules(to:)` ruft das **vor** dem Modellaufruf auf, schreibt bei leerem
Feld direkt Revision + Task-Property — unabhängig davon, ob das Modell überhaupt verfügbar ist.
Dasselbe Muster soll `importance`/`urgency` bekommen.

**Bestehende Signalwörter** (wörtlich aus `FoundationModelsEnricher.swift:28`, heutiger Prompt):
„Importance and urgency are separate. Signals: words like **urgent, immediately, by, deadline,
reminder, cancellation, tax**; **people who wait for it**; **amounts of money and official
language**. **Age of the note is not importance.**" — Startpunkt für EN-Wortliste und eine explizite
Ausschluss-Regel (Erfassungsdatum ist kein Wichtigkeits-Signal).

## Dependencies
- Upstream (was die neue Regel nutzt): `ExpressionText`-Tokenisierung, `EnrichmentDraft.Guess`,
  `Revision`, `FieldSource`
- Downstream (was die neue Regel nutzt): `EnrichmentCoordinator` (neuer Aufruf-Ort),
  `EnrichmentWriter` (bestehender importance/urgency-Codepfad entfällt),
  `FoundationModelsEnricher` (Schema/Prompt schrumpft um vier Felder)

## Existing Specs
- `docs/specs/enrichment/feat-95-parser-in-app.md` — Gliederung eins zu eins übertragbar
- `docs/specs/measurement/spike-92-*.md` — Präzedenzfall-Messung „Regeln vor Modell" fürs Datum

## Risks & Considerations
1. **Guard gegen Doppel-Revision**: Wie bei `dueDate` (`guard task.dueDate == nil`) muss die neue
   Regel nur bei leerem Feld greifen, sonst schreibt der Catch-up-Pass eine zweite Revision.
2. **Retrieval-Beispiele im Prompt** (Z. 47-48) zeigen dem Modell heute `importance`/`urgency`
   vergangener Aufgaben — offen für die Analyse-Phase, ob diese Zeilen noch Wert haben oder toter
   Prompt-Ballast werden, sobald das Modell die Felder nicht mehr vorhersagt.
3. **Begründungssätze fehlen von Anfang an lokalisiert werden** (wie bei #98 nachträglich behoben) —
   diesmal direkt zweisprachig anlegen, nicht nachrüsten.
4. **`EnrichmentWriter`-Zweige toter Code**: Zeilen 47-59 müssen entfernt werden, nicht nur
   unbenutzt gelassen.
5. **Keine Korpus-Messung nötig/möglich**: #111 hat gezeigt, dass FocusBlox hier ohnehin nur
   Fallback-Werte lieferte — Tests sind reine Beispiel-Assertions wie bei `DueDateRuleTests`, kein
   Trefferquote-Nachweis gegen einen Korpus nötig.

## Analysis

### Type
Feature

### Affected Files (with changes)

| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/ImportanceUrgencyRule.swift` | CREATE | Zwei unabhängige Match-Funktionen `matchImportance(in:)`/`matchUrgency(in:)`, je `Guess<T>?` mit fixer Konfidenz 1.0, `nil` bei fehlendem/mehrdeutigem Signal (kein Default). Schlüsselwortlisten DE/EN direkt in der Datei, da kein wiederverwendbarer Parser wie bei Datum existiert. |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | `applyRules(to:)` um zwei Guard-Blöcke erweitern (`guard task.importance == nil` / `guard task.urgency == nil`), analog `dueDate`: direkte Revision + Task-Property, vor dem Modellaufruf. |
| `Shared/Enrichment/FoundationModelsEnricher.swift` | MODIFY | `ModelEnrichment`-Schema um die vier importance/urgency-Felder kürzen, Prompt-Satz (Signalwörter) und Retrieval-Beispielzeilen entfernen. |
| `Shared/Enrichment/EnrichmentWriter.swift` | MODIFY | Zeilen 47-59 (bestehender Schwellenwert-Schreibpfad für importance/urgency) vollständig entfernen — wird nach dem Umbau nie mehr erreicht. |
| `LooseEndsTests/ImportanceUrgencyRuleTests.swift` | CREATE | Beispiel-Tests analog `DueDateRuleTests.swift`: Konfidenz 1.0, Treffer je Schlüsselwort-Kategorie, `nil` bei fehlendem Signal, getrennt für importance und urgency. |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | Neue Regel-Begründungssätze von Anfang an DE+EN (anders als #98, das nachträglich übersetzt hat). |

### Scope Assessment
- Files: 6 (4 MODIFY, 2 CREATE)
- Estimated LoC: Produktivcode ~130–190 (unter der 250-Grenze), Testcode ~150–250 (unter der 500-Grenze)
- Risk Level: MEDIUM — ändert die Kern-Veredelungs-Pipeline für jede erfasste Aufgabe, aber nach einem bereits einmal erfolgreich gebauten, identischen Muster (#92/#95)

### Technical Approach
Zwei getrennte Match-Funktionen statt eines kombinierten Tripels, weil Wichtigkeit und Dringlichkeit
laut Datenmodell und `ViewRules.byUrgencyThenImportance` orthogonale Felder sind (z. B. „dringend,
aber unwichtig" ist valide) — anders als `dueDate`/`dueHasTime`, wo Uhrzeit nur ein Annex zum Datum
ist. Bei fehlendem oder mehrdeutigem Signal bleibt das Feld `nil`, es wird **kein** Default gesetzt
(Lehre aus #111: Fallback-Standardwerte waren genau das Problem der bisherigen FocusBlox-„Wahrheit").
Reihenfolge TDD-typisch: RED-Tests zuerst, dann `ImportanceUrgencyRule`, dann Coordinator-Integration,
dann Enricher/Writer-Bereinigung, zuletzt Lokalisierung.

### Dependencies
Nutzt: `ExpressionText`-Tokenisierung (`DateExpressionParser.swift`), `EnrichmentDraft.Guess`,
`Revision`, `FieldSource`. Downstream unverändert lauffähig: `ViewRules.swift` (Sortierung nutzt nur
Enum-Werte, nicht Confidence), `FieldCodec.swift`/`RevisionService.swift` (feldquellen-unabhängig).

### Nebenbefund (nicht Teil von #117, als Issue #118 angelegt)
Zwei bestehende Testdateien werden durch den Umbau beeinträchtigt: `FocusBloxCalibrationTests.swift`
(gated, nie in CI) hat ein hartes `#expect(!importanceOutcomes.isEmpty, ...)`, das nach dem Umbau bei
lokalem Lauf mit vorhandener Corpus-Datei fehlschlagen würde. `SelfConsistencyReportTests.swift`
(#108) würde für importance/urgency leere statt aussagekräftige Tabellen erzeugen. Präzedenzfall:
`dueDate` wurde nach #95 aus genau diesem Report-Scope entfernt — derselbe Schnitt sollte für
importance/urgency in Issue #118 erfolgen, nicht in #117 selbst (anderer Dateibereich:
Measurement-Testcode statt Enrichment-Produktcode).

### Open Questions
Keine — Ansatz, Scope und Reihenfolge sind eindeutig, das Muster ist bereits einmal erfolgreich
gebaut worden.
