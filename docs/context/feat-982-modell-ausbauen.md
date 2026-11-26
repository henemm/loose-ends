# Context: feat-982-modell-ausbauen

## Request Summary
Das On-Device-Modell (Apple Intelligence) verlässt den Produktweg (Epic #999, ADR-22): Titel kommt nur aus
`TitleRule`, Dauer nur genannt (`DurationRule`) oder wiedererkannt (`RecognitionRule`). „Neu analysieren“ läuft
nur die Regeln. Alte KI-Werte und ihre Revisionen bleiben stehen. Messcode (`Measurement/`, Labor-App) bleibt.

## Related Files
| File | Relevance |
|------|-----------|
| `Shared/Enrichment/EnrichmentCoordinator.swift` | einziger Modellaufrufer: `processPending` (Nachzügler + nach Erfassung) und `reanalyze`; `callModel`, `examples`, `modelTimeout`, `enricher` |
| `LooseEnds/App/LooseEndsApp.swift:44-46, 242-255` | baut `FoundationModelsEnricher` (bzw. `ModelOffEnricher` unter UI-Tests) und übergibt ihn |
| `LooseEnds/Views/TaskDetailView.swift:659-668` | zeigt nach „Neu analysieren“ „Apple Intelligence did not run, only the rules.“ bei `modelRan == false` |
| `LooseEnds/App/ContentView.swift:36-43, 228` | `modelUnavailableReason` → Onboarding |
| `LooseEnds/Views/OnboardingView.swift`, `OnboardingFlow.swift:13-57` | Hinweis „Apple Intelligence is off. Turn it on … so new tasks get a title and a duration“ u. a. — wird falsch |
| `Shared/Enrichment/FoundationModelsEnricher.swift`, `EnrichmentDraft.swift` | bleiben: die Labor-App kompiliert sie (`project.yml` LooseEndsLab) |
| `Shared/Enrichment/EnrichmentWriter.swift` | bleibt: `mayWrite`/`userHasTouched` tragen die Regeln; `apply` (Modellentwurf schreiben) wird im Produkt unbenutzt |
| `Shared/Enrichment/ModelDeadline.swift`, `ModelFailure.swift` | nur vom Modellzweig des Koordinators benutzt |
| `Shared/Models/TaskItem.swift:19-23` | `processedAt` = „Modell lief“, `rulesAppliedAt` = „Regelschritt lief“ (#144) |
| `LooseEnds/Resources/Localizable.xcstrings` | Onboarding-Hinweise, Detailzeile; „Estimated by Apple Intelligence“ bleibt (alte KI-Werte) |
| `docs/reference/datenschutz-entwurf.md:53,65,231,289,387` | nennt das Modell; Rechtstext nur mit Hennings Freigabe und Website-Änderung |

## Existing Patterns
- Regelschritt vor und unabhängig vom Modell (#95/#144); ohne Modell läuft heute schon „rules only“ (Geräte ohne AI, UI-Tests via `ModelOffEnricher`).
- Teilaufgaben: nur Regeln, markiert allein über `rulesAppliedAt` (#565) — Vorbild für Aufgaben ohne Modell.
- Revisionen statt Löschen: bestehende KI-Werte bleiben.

## Dependencies
- Upstream: Regeln (`DueDateRule`, `ImportanceUrgencyRule`, `RecognitionRule`, `DurationRule`, `ContextWordRule`, `PhoneRule`, `ProjectNameRule`, `PlaceWordRule`), `EnrichmentWriter.mayWrite`.
- Downstream: `LooseEndsApp`, `ContentView`/Erfassung (ruft `processPending`), `TaskDetailView` (`reanalyze`), `TaskInteractions.listAnalysis`; ~110 Konstruktionen `EnrichmentCoordinator(enricher:…)` in 19 Testdateien.

## Risks & Considerations
- **Nachzügler wächst ohne Ende:** Auswahl heute `processedAt == nil`. Ohne Modell bleibt `processedAt` für jede neue Aufgabe leer → jeder Lauf (Start, jede Erfassung) nimmt alle offenen Aufgaben erneut. Auswahl muss auf `rulesAppliedAt == nil` wechseln (ein Lauf je Aufgabe, ADR-4).
- Status: das Modell hob `unprocessed` → `active`/`unverified`. Ohne Modell bleiben neue Aufgaben in „Neu“ bis #1000 — so wie heute schon auf Geräten ohne AI. Kein Teil von #982.
- Sichtbare Texte, die falsch werden: Detailzeile „Apple Intelligence did not run …“ (käme bei jedem „Neu analysieren“), Onboarding-Hinweise.
- Gerätestufe: `EnrichmentCoordinator.swift` steht auf der Pfadliste; Ausnahme #680 greift nicht (Modellaufruf wird geändert) → Stufe 3 über TestFlight.
- Teständerungen groß, aber mechanisch (Init-Signatur); Modell-Tests (`ModelSeamTests`, Stub-Fälle in `EnrichmentTests`/`ReanalysisTests`) fallen weg oder werden zu Regel-Tests.
- Datenschutztext und CLAUDE.md-Absatz „Rules before the model“ werden ungenau → eigener Schnitt, Rechtstext nur nach Freigabe.

## Analysis

### Type
Feature (Produktentscheidung ADR-22; kein Fehler im engeren Sinn — Anlass belegt per Screenshot im Issue).

### Affected Files (with changes) — Schnitt 1
| File | Change Type | Description |
|------|-------------|-------------|
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | `init(container:savedPlaces:)` ohne `enricher`/`modelTimeout`; Modellzweige in `processPending` und `reanalyze` raus; `callModel` raus; `ReanalysisResult.finished(changed:)`; Auswahl der Nachzügler `rulesAppliedAt == nil && processedAt == nil` |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | kein `FoundationModelsEnricher`, `ModelOffEnricher` entfernt |
| `LooseEnds/Views/TaskDetailView.swift` | MODIFY | Ergebnisfall ohne `modelRan`, Zeile „Apple Intelligence did not run, only the rules.“ entfällt |
| `LooseEnds/App/ContentView.swift` | MODIFY | Onboarding bekommt keinen Modellgrund mehr aus `FoundationModelsEnricher` (Hinweis verschwindet sofort) |
| Tests (`LooseEndsTests/*`) | MODIFY/DELETE | ~110 Konstruktionen mechanisch; `ModelSeamTests`/`ModelUnavailableTests`/Stub-Fälle werden Regel-Tests oder entfallen; `RealModel*`, `TitleFidelityPromptTests`, `ModelPromptLanguagesTests` kompilieren weiter (Adapter bleibt) |

### Scope Assessment
- Schnitt 1: 4 App-Dateien, ca. +25/−170 LoC App-Code; Tests mechanisch groß.
- Risk Level: MEDIUM — zentraler Erfassungsweg, aber Regelweg existiert und läuft heute schon auf Geräten ohne AI und in allen UI-Tests.

### Technical Approach
Variante A (Plan-Bewertung): Modell aus dem Koordinator entfernen, sodass der Compiler jeden Modellaufruf im Produkt ausschließt.
Nachzügler-Gate `rulesAppliedAt == nil && processedAt == nil` (Konjunktion, damit Aufgaben von vor #144 mit nur `processedAt` keine nachträgliche Regel-Dauer bekommen). `processedAt` behält seine Bedeutung „Modell lief“, wird nur nicht mehr gesetzt.
Varianten verglichen:
| Variante | App-Dateien | LoC | Bewertung |
|---|---|---|---|
| A: Koordinator ohne Modell | 4 | ~−150 | gewählt; Compiler beweist „kein Aufruf“ |
| B: Naht behalten, „kein Modell“-Enricher verdrahten | 1–2 | ~+10 | verworfen: Modellzweige bleiben, verfehlt ADR-22 |
| C: A + Modelldateien aus dem App-Ziel | 6+ (`project.yml`) | ~−400 | zu groß für einen Schnitt → Schnitt 3 |
Alternative mit gekippter ADR: Modell nur auf Wunsch über „Neu analysieren“ (ADR-22 hat das verworfen; ADR-4-Modellteil bliebe).

### Schnitte
1. Modell aus dem Produktweg (Dateien oben), Gerätestufe über TestFlight (Pfadliste: `EnrichmentCoordinator.swift`).
2. Onboarding-Hinweise (`OnboardingFlow.ModelNote`, `OnboardingView`, Strings, `OnboardingTests`, `--ui-testing-model-reason`).
3. Aufräumen: `ModelDeadline`, `ModelFailure`, `EnrichmentWriter.apply`, `examples`, Modelltests neu verorten; CLAUDE.md-Absatz „Rules before the model“, ADR-4-Hinweis.
Getrennt, nur mit PO-Freigabe: Datenschutztext + Website.

### Nachweis
- RED: Gate-Tests (Aufgabe mit `rulesAppliedAt` wird nicht erneut angefasst; altes Modell-Task mit „20 Minuten“ bekommt keine Regel-Dauer), Test gegen `EnrichmentCoordinator(container:)` (kompiliert heute nicht), „Vor Konzert“ → Titel „Vor Konzert“, keine Dauer, keine KI-Revision, `processedAt` leer.
- Simulator: UI-Test ohne `--ui-testing` (echte Verdrahtung wie `CaptureCancelCrashTests`), „Vor Konzert“ erfassen → Titel „Vor Konzert“, kein KI-Merkmal.

### Open Questions
- keine PO-Frage für Schnitt 1 (Produktentscheidung steht in ADR-22).
