# Kontext: #982 Schnitt 2 – Onboarding ohne Modellhinweis

## Request Summary
Teil von Epic #999 (ADR-22, kein Modell). Schnitt 1 hat das Modell aus dem Produktweg genommen; seither reicht
`ContentView` dem Onboarding keinen Modellgrund mehr (nur unter `--ui-testing` per `--ui-testing-model-reason=`).
Schnitt 2 entfernt den Hinweis selbst: `OnboardingFlow.ModelNote`/`modelNote(for:)`, die Anzeige in
`OnboardingView`, den Parameter `modelUnavailableReason`, `ContentView.onboardingModelReason`, das Testargument
`--ui-testing-model-reason`, die drei Katalogschlüssel und die Tests dazu.

## Related Files
| Datei | Rolle |
|---|---|
| `LooseEnds/Views/OnboardingFlow.swift:11-15, 50-57` | `ModelNote`, `modelNote(for:)` – entfallen |
| `LooseEnds/Views/OnboardingView.swift:3-12, 18-20, 81-96` | Parameter, Anzeige, `modelNote(_:)` – entfallen; Doc-Kommentar anpassen |
| `LooseEnds/App/ContentView.swift:34-42, 224-227` | `onboardingModelReason` – entfällt, Aufruf ohne Grund |
| `LooseEnds/Resources/Localizable.xcstrings` | drei Hinweis-Schlüssel („Apple Intelligence is off…“, „…still getting ready…“, „This device has no Apple Intelligence…“) – löschen |
| `LooseEndsTests/OnboardingFlowTests.swift:55-62` | Test `modelNote` – entfällt |
| `LooseEndsTests/NoModelCoordinatorTests.swift:176-185` | Test 8 (AC-8 aus S1) – entfällt mit der Funktion |
| `LooseEndsUITests/OnboardingTests.swift:11-31, 83-114` | vier Hinweistests + `modelNoteText` – entfallen; `launch(reason:)` ohne Grund; `testNoNoteWhileTheModelIsThere` wird „nie ein Hinweis“ |

## Existing Patterns
- Onboarding ist rein (`OnboardingFlow`) + View; UI-Test startet mit `--ui-testing-onboarding`.
- Katalog: Schlüssel ohne Code-Verwendung werden aus `Localizable.xcstrings` gelöscht (kein „stale“ stehen lassen);
  `scripts/test_catalog_languages.py` prüft Vollständigkeit.

## Dependencies / Dependents
- Labor-App (`LooseEndsLab`) nutzt `enricher.unavailableReason` selbst, nicht das Onboarding – unberührt.
- `FoundationModelsEnricher.unavailableReason`, `RealModelTests`, `EnrichmentTests`-Stub – unberührt (Schnitt 3).
- Übrige KI-Schlüssel („Estimated by Apple Intelligence“, „Apple Intelligence did not run…“, „That happens by itself…“) gehören
  zu Schnitt 3 bzw. bleiben für alte Werte.

## Existing Specs
- `docs/specs/feat-342-schnitt-1a-hinweis-ohne-modell.md` (Einführung des Hinweises, #342)
- `docs/specs/feat-982-*.md` (Schnitt 1)

## Sichtbarkeit
Im echten Produkt ist der Hinweis seit Schnitt 1 schon nie zu sehen (kein Grund wird übergeben). Für den Nutzer ändert sich
nichts Sichtbares; kein Entwurf vor der Spec nötig. Kein Pfad der Geräteliste berührt.

## Risks
- Umfang: App-Code 4 Dateien, nur Löschungen (~-60 LoC) – im Limit.
- Ein vergessener Katalogschlüssel bliebe als „stale“ stehen → Katalog im selben Schnitt bereinigen, Wächter grün.
- Alternative: Hinweis umschreiben statt löschen („Loose Ends findet Datum … aus deinen Worten“) – ADR-22 kennt keinen
  Modellzustand mehr, der einen Hinweis begründet; empfohlen wird Löschen.

## Analysis

**Type:** Feature (Rückbau, ADR-22). Die Suche ist vollständig per `grep` über alle Swift-, Skript- und Katalogdateien
erfolgt (Treffer oben); Teilagenten waren für einen reinen Löschschnitt mit bekannter Trefferliste nicht nötig.

### Affected Files
| Datei | Change | Inhalt |
|---|---|---|
| `LooseEnds/Views/OnboardingFlow.swift` | MODIFY | `ModelNote`, `modelNote(for:)` und deren Doc-Kommentare entfernen |
| `LooseEnds/Views/OnboardingView.swift` | MODIFY | `modelUnavailableReason`, Anzeige auf Schritt 1, `modelNote(_:)` entfernen; Kopfkommentar ohne „note when Apple Intelligence is not there“ |
| `LooseEnds/App/ContentView.swift` | MODIFY | `onboardingModelReason` entfernen, `OnboardingView(` ohne Grund |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | drei Hinweisschlüssel löschen |
| `LooseEndsTests/OnboardingFlowTests.swift` | MODIFY | Test `modelNote` entfernen |
| `LooseEndsTests/NoModelCoordinatorTests.swift` | MODIFY | Test 8 (`testTheRealAppPassesNoModelReasonToTheOnboarding`) entfernen |
| `LooseEndsUITests/OnboardingTests.swift` | MODIFY | vier Hinweistests + Helfer entfernen, `launch` ohne `reason`; neuer Test: auch mit dem alten Argument `--ui-testing-model-reason=deviceNotEligible` steht kein Hinweis (beweist, dass der Weg wirklich weg ist und nicht nur nichts übergeben wird) |

### Scope / Risk
App-Code 4 Dateien, nur Löschungen (geschätzt −60 LoC, Katalog ~−60 Zeilen JSON). Risiko niedrig: Onboarding erscheint
einmal je Gerät, der Hinweis ist im Produkt seit Schnitt 1 schon unsichtbar. Kein Pfad der Geräteliste berührt.

### Technical Approach
1. RED: UI-Test „kein Hinweis, auch mit altem Grund-Argument“ (heute rot, weil das Argument den Hinweis unter `--ui-testing` noch zeigt);
   Unit-Test: `Localizable.xcstrings` enthält keinen der drei Schlüssel mehr (heute rot).
2. Löschen in Flow, View, ContentView, Katalog; alte Tests entfernen.
3. Katalogwächter (`scripts/test_catalog_languages.py`) und Onboarding-UI-Tests grün; `test-proof OnboardingTests`.

### Alternative
Hinweis umschreiben zu einem modellfreien Satz („Datum, Wichtigkeit und Etiketten findet Loose Ends in deinen Worten“).
Abgelehnt: der Hinweis existierte nur, um einen fehlenden Modellzustand zu erklären (#342); ohne Modell gibt es keinen
Zustand, der ihn begründet, und das Onboarding „zeigt, statt sich zu erklären“. Fiele: nichts (ADR-22 deckt das Löschen).

### Dependencies
Labor-App und `FoundationModelsEnricher.unavailableReason` bleiben unberührt (Schnitt 3).

### Open Questions
Keine.
