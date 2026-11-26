---
entity_id: feat-982-schnitt-2-onboarding-ohne-modellhinweis
type: feature
created: 2026-11-26
updated: 2026-11-26
status: draft
workflow: feat-982-s2-onboarding-modellhinweis
---

# Spec: Onboarding ohne Modellhinweis, Schnitt 2 (Feature #982, Epic #999)

## Approval

- [ ] Approved

## GitHub Issue

#982 (Epic #999). Henning, 2026-11-26: „Die AI hat in der Summe keinen Mehrwert, sondern stört eher.“ Entscheidung:
ADR-22 (`docs/project/00-entscheidungen.md`): das On-Device-Modell verlässt den Produktweg. Schnittplan im Issue-Kommentar
zu Schnitt 1: „Schnitt 2: Onboarding-Hinweis (`OnboardingFlow.ModelNote`, `OnboardingView`, Strings, `OnboardingTests`).“

## Purpose

Der erste Schritt des Onboardings konnte einen Satz über Apple Intelligence zeigen („ist aus, schalte es ein, damit neue
Aufgaben Titel und Dauer bekommen“, „wird noch vorbereitet“, „dieses Gerät hat kein Apple Intelligence“). Seit Schnitt 1
reicht die App keinen Modellzustand mehr weiter, der Satz erscheint im Produkt also schon nicht mehr; nur unter UI-Tests
lässt er sich noch per Startargument hervorholen. Dieser Schnitt entfernt den Hinweis samt Weg dorthin, Texten und Tests,
damit kein Code mehr einen Modellzustand im Onboarding kennt.

## Nicht in diesem Schnitt (Schnitt 3)

- `ModelDeadline`, `ModelFailure`, `EnrichmentWriter.apply`, `examples`, `StubEnricher`, Verortung der Modelltests,
  CLAUDE.md-Abschnitt „Rules before the model“, übrige KI-Katalogschlüssel („Apple Intelligence did not run, only the
  rules.“, „That happens by itself once Apple Intelligence is ready.“). „Estimated by Apple Intelligence“ bleibt (alte KI-Werte).
- `FoundationModelsEnricher.unavailableReason` und die Labor-App bleiben unberührt.
- Datenschutztext (nur nach Hennings Freigabe).

## Was darf sich nicht ändern

- Die drei Schritte des Onboardings (Siri, Mitteilungen, Etiketten), ihre Texte, Knöpfe, „Überspringen“ und das
  Einmal-je-Gerät-Verhalten (`OnboardingFlow.shouldShow`, `finish`, `doneKey`, `--ui-testing-onboarding`).
- Alle anderen Katalogschlüssel.

## Alternativen

1. **Hinweis umschreiben** zu einem modellfreien Satz („Datum, Wichtigkeit und Etiketten findet Loose Ends in deinen
   Worten“). Verworfen: der Hinweis erklärte nur einen fehlenden Modellzustand (#342); ohne Modell gibt es keinen Zustand,
   der ihn begründet, und das Onboarding zeigt, statt sich zu erklären. Kippt keine ADR.
2. **Code stehen lassen, nur nie aufrufen** (Stand nach Schnitt 1). Verworfen: toter Pfad mit Texten, die Falsches über
   die App sagen (Titel und Dauer durch Apple Intelligence); widerspricht dem Ziel von #982.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** ADR-22
- **Rationale:** Bestehende Entscheidung (Epic #999): kein Modell im Produkt. Dieser Schnitt entfernt den letzten
  sichtbaren Ort, der einen Modellzustand erklärt; keine neue Entscheidung.

## Source

- **File:** `LooseEnds/Views/OnboardingView.swift`
- **Identifier:** `OnboardingView.modelUnavailableReason`, `OnboardingView.modelNote(_:)`; `OnboardingFlow.ModelNote`,
  `OnboardingFlow.modelNote(for:)`; `ContentView.onboardingModelReason(arguments:isUITesting:)`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `ContentView.onboarding` | module | Baut `OnboardingView`; übergibt künftig keinen Grund mehr |
| `NoModelCoordinatorTests` (Test 8) | test | Prüft `onboardingModelReason`; entfällt mit der Funktion |
| `OnboardingFlowTests.modelNote` | test | Prüft `modelNote(for:)`; entfällt |
| `scripts/test_catalog_languages.py` | script | Katalogwächter; muss nach dem Löschen der drei Schlüssel grün bleiben |

## Scope

### Affected Files

| Datei | Change | Was |
|---|---|---|
| `LooseEnds/Views/OnboardingFlow.swift` | MODIFY | `ModelNote`, `modelNote(for:)` und ihre Kommentare weg |
| `LooseEnds/Views/OnboardingView.swift` | MODIFY | Parameter `modelUnavailableReason`, Anzeige über Schritt 1, `modelNote(_:)` weg; Kopfkommentar ohne Hinweis |
| `LooseEnds/App/ContentView.swift` | MODIFY | `onboardingModelReason` weg; `OnboardingView(` ohne Grund |
| `LooseEnds/Resources/Localizable.xcstrings` | MODIFY | die drei Hinweisschlüssel gelöscht |
| `LooseEndsTests/OnboardingFlowTests.swift` | MODIFY (Test) | Test `modelNote` weg |
| `LooseEndsTests/NoModelCoordinatorTests.swift` | MODIFY (Test) | Test 8 weg |
| `LooseEndsUITests/OnboardingTests.swift` | MODIFY (Test) | vier Hinweistests und `modelNoteText` weg, `launch` ohne `reason`; neuer Test (RED) |

### Estimated Changes

- App-Code: 4 Dateien, etwa −60 LoC (Swift) und −60 Zeilen Katalog-JSON, keine Zeile neu außer dem Aufruf.
- Tests: 3 Dateien, etwa −70 / +15 LoC.

## Implementation Details

`OnboardingView` verliert die Eigenschaft und den `if flow.step == .siri, let note = …`-Block; `stepContent` steht direkt
oben im `VStack`. `ContentView.onboarding` ruft `OnboardingView(requestNotifications:onFinish:)`. Das Startargument
`--ui-testing-model-reason=` wird danach nirgends mehr gelesen. Die drei Katalogschlüssel werden samt `de`-Übersetzung aus
`Localizable.xcstrings` entfernt (per Skript, JSON-Formatierung wie Xcode: zwei Leerzeichen, `" : "`).

## Test Plan

### Automated Tests (TDD RED)

UI-Test (XCTest), Lauf `./scripts/sim.sh test-proof OnboardingTests` (iPhone).

- [ ] Test 1: GIVEN das Onboarding im Simulator, gestartet mit `--ui-testing`, `--ui-testing-onboarding` und dem alten
  Argument `--ui-testing-model-reason=deviceNotEligible` WHEN Schritt 1 (Siri) erscheint THEN steht dort kein Element
  `onboardingModelNote` und kein Text, der „Apple Intelligence“ enthält; Screenshot angehängt. RED heute: das Argument holt
  den Hinweis „This device has no Apple Intelligence …“ hervor.
- [ ] Test 2: GIVEN die beiden bestehenden Ablauftests (`testWalkThroughThreeStepsToTheStartScreen`,
  `testSkipEndsTheOnboardingAtOnce`) WHEN sie laufen THEN bestehen sie unverändert.
- [ ] Test 3: GIVEN alle übrigen Unit- und UI-Tests und den Katalogwächter WHEN sie laufen (`./scripts/sim.sh unit`,
  `python3 scripts/test_catalog_languages.py`, CI) THEN bestehen sie.

## Acceptance Criteria

- **AC-1:** Schritt 1 des Onboardings zeigt keinen Modellhinweis, auch nicht mit dem früheren Testargument
  `--ui-testing-model-reason=…` (Test 1, Screenshot geöffnet und beschrieben).
- **AC-2:** Im App-Code gibt es keine `ModelNote`, kein `modelNote`, kein `modelUnavailableReason` außerhalb der Labor-App,
  kein `onboardingModelReason` und kein `--ui-testing-model-reason`: `grep -rn "ModelNote\|modelNote\|onboardingModelReason\|ui-testing-model-reason" LooseEnds Shared LooseEndsTests LooseEndsUITests` ist leer.
- **AC-3:** `Localizable.xcstrings` enthält die drei Schlüssel „Apple Intelligence is off. …“, „Apple Intelligence is still
  getting ready. …“ und „This device has no Apple Intelligence. …“ nicht mehr; der Katalogwächter ist grün.
- **AC-4:** Durchlauf und Überspringen des Onboardings funktionieren unverändert; alle übrigen Tests grün (Tests 2, 3).

## Risiken

- **Xcode schreibt den Katalog beim Bauen zurück:** Ein gelöschter, aber noch benutzter Schlüssel käme als neuer Eintrag
  ohne Übersetzung zurück. Da die drei Texte im Code nicht mehr vorkommen, entsteht nichts; nach dem Bau wird
  `git diff` des Katalogs geprüft.

## Definition of Done

- [ ] Build grün (`./scripts/sim.sh generate`, dann `./scripts/sim.sh build`)
- [ ] Alle Unit-Tests grün (`./scripts/sim.sh unit`)
- [ ] UI-Tests grün (CI); Simulatorbeleg über `./scripts/sim.sh test-proof OnboardingTests`
- [ ] Gerätestufe: Kein Pfad der Geräteliste berührt. Die Abnahme endet nach Stufe 2.
- [ ] Ausgeliefert: PR mit `Refs #982` (Issue bleibt für Schnitt 3 und Stufe 3 offen), CI grün, gemergt

## Changelog

- 2026-11-26: Initial spec created
