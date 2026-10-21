---
entity_id: fix-535-dauerfehler
type: bugfix
created: 2026-10-21
updated: 2026-10-21
status: draft
workflow: fix-535-dauerfehler
---

# Spec: #535 — Dauerhafte Modellfehler nicht bei jedem Durchlauf wiederholen

## Approval

- [ ] Approved

## Purpose

Schlägt der Modellaufruf einer Notiz fehl, bleibt `processedAt` leer, damit der nächste Durchlauf es erneut
versucht (#530). Das ist richtig für vorübergehende Fehler. Für dauerhafte (Guardrail, Kontextfenster) ist es
falsch: Dieselbe Notiz geht bei jedem App-Start und nach jeder Erfassung erneut ans Modell, ohne Aussicht auf
Erfolg. Diese Spec teilt den Fehler per Regel (kein Modell, kein Textvergleich) in dauerhaft und vorübergehend
ein und markiert dauerhaft abgelehnte Notizen mit `processedAt`, ohne KI-Revision. „Neu analysieren" bleibt der
ausdrückliche zweite Versuch (ADR-4). Es hat nie anders funktioniert: die Lücke besteht seit #530.

## Source

- **Datei:** `Shared/Enrichment/EnrichmentCoordinator.swift`
- **Bezeichner:** `func processPending()`, das `catch` um `callModel(input)`
- **Datei:** `Shared/Enrichment/ModelFailure.swift` (neu)
- **Bezeichner:** `enum ModelFailure { static func isPermanent(_ error: Error) -> Bool }`

## Dependencies

| Baustein | Art | Zweck |
|---|---|---|
| `LanguageModelError` (iOS-27-SDK) | SDK | Fälle `guardrailViolation`, `contextSizeExceeded` sind dauerhaft; alle übrigen vorübergehend |
| `MeasurementErrorKind.classify` (`Measurement/MeasurementRun.swift`) | Vorlage | Nur Ausgangspunkt der Fallliste. Wird **nicht** übernommen: `Measurement/` kompiliert nur in `LooseEndsTests` und Labor-App, bleibt unangetastet |
| `ModelDeadline.Exceeded` | Fehlertyp | Zeitgrenze, vorübergehend |
| `EnrichmentWriter.apply` | Vorbild | Bisher einzige Schreibstelle von `processedAt`; bleibt unverändert |
| `StubEnricher` (`EnrichmentTests.swift`) | Testhelfer | `failure`, `calls`; kein Umbau nötig |
| ADR-4 (`docs/project/00-entscheidungen.md`) | Entscheidung | „Veredelung genau einmal" — wird ergänzt, nicht revidiert |
| `MeasurementRunTests.swift:73–78` | Beleg | Alle `LanguageModelError`-Fälle sind in Tests ohne Modell konstruierbar |

## Scope

### Affected Files

| Datei | Änderungsart | Beschreibung |
|---|---|---|
| `Shared/Enrichment/ModelFailure.swift` | CREATE | Reine Einteilung `isPermanent(_:)`. Unter `#if canImport(FoundationModels) && !os(watchOS)` die SDK-Fälle, sonst immer `false` (Datei muss in Watch und Widgets kompilieren) |
| `Shared/Enrichment/EnrichmentCoordinator.swift` | MODIFY | Im `catch` von `processPending`: bei `ModelFailure.isPermanent(error)` `task.processedAt = Date()`, Log auf `notice` mit „permanent". Keine `Revision`. `reanalyze` unverändert |
| `Shared/Models/TaskItem.swift` | MODIFY | Nur der Kommentar am Feld `rulesAppliedAt`/`processedAt`: `processedAt` heißt auch „Modell hat endgültig abgelehnt" (#535). Kein neues Feld, keine Schema-Änderung |
| `LooseEndsTests/ModelSeamTests.swift` | MODIFY | `guardrailRefusal` dreht sich um; neue Fälle für Kontextfenster, vorübergehende Fehler, Zweitlauf, „Neu analysieren"; Einteilungstests je Fehlerfall |
| `docs/project/00-entscheidungen.md` | MODIFY | ADR-4 um einen Satz zu `processedAt` bei Dauerfehler ergänzen |

### Estimated Changes

- Dateien: 5 (Produktivcode: 2 + 1 Kommentarzeile)
- LoC: Produktiv +~35/−~2, Tests +~110, Doku +~6 — unter 250 LoC

## Implementation Details

**1. Einteilung.**

| Fehler | Einstufung | Grund |
|---|---|---|
| `LanguageModelError.guardrailViolation` | dauerhaft | Eingabe ändert sich nicht (Apple DTS: Umformulieren hilft, Wiederholen nicht) |
| `LanguageModelError.contextSizeExceeded` | dauerhaft | Notiztext ändert sich nicht |
| `.rateLimited`, `.timeout`, `ModelDeadline.Exceeded` | vorübergehend | Zeit/Last |
| `SystemLanguageModel.Error.assetsUnavailable`, `LanguageModelSession.Error.*` | vorübergehend | Zustand des Geräts |
| `.refusal` | vorübergehend | Ablehnung kann je Lauf wechseln; nicht gemessen, im Zweifel Wiederholung |
| `.unsupported…` (Sprache, Guide, Capability) | vorübergehend | Systemsprache und OS können sich ändern |
| `GeneratedContent.ParsingError`, `@unknown default`, fremde Typen (`StubFailure`) | vorübergehend | Nichts Wiederholbares verlieren |

```swift
enum ModelFailure {
    /// Retrying the same note cannot succeed (#535). Everything else stays retryable.
    static func isPermanent(_ error: Error) -> Bool {
        #if canImport(FoundationModels) && !os(watchOS)
        if let model = error as? LanguageModelError {
            switch model {
            case .guardrailViolation, .contextSizeExceeded: return true
            default: return false
            }
        }
        #endif
        return false
    }
}
```

**2. Koordinator.** Im `catch` nach dem Log: `if ModelFailure.isPermanent(error) { task.processedAt = Date() }`.
`rulesAppliedAt` ist für die Aufgabe ohnehin gesetzt (#144), der anschließende `context.save()` schreibt beides.
Der Pending-Fetch (`processedAt == nil`) nimmt die Notiz damit nicht mehr auf.

**3. Keine neuen Felder.** `processedAt` existiert (CD_processedAt). Keine CloudKit-Schema-Arbeit, kein Deploy
durch Henning. Der Wiedererkennungs-Pool liest `processedAt != nil` oder `rulesAppliedAt != nil`; die Aufgabe
steht dort wegen `rulesAppliedAt` schon, der Pool ändert sich nicht. Keine Ansicht liest `processedAt`.

**4. Bekannte Grenze.** Ein Dauerfehler bleibt über OS-Updates stehen (ein Guardrail kann sich mit einem Update
ändern). Abhilfe: „Neu analysieren". Kein Hinweis im Detail (nicht Teil des Tickets).

## Acceptance Criteria

- **AC-1:** Wirft das Modell für eine Notiz `guardrailViolation`, setzt `processPending` danach `processedAt`, schreibt keine `Revision` und lässt `rulesAppliedAt` gesetzt.
- **AC-2:** Wirft das Modell `contextSizeExceeded`, gilt dasselbe wie in AC-1.
- **AC-3:** Nach einem Dauerfehler ruft ein zweites `processPending` das Modell für diese Notiz nicht mehr auf (Aufrufzähler des `StubEnricher` bleibt 1).
- **AC-4:** Bei `timeout`, `ModelDeadline.Exceeded`, `rateLimited`, `assetsUnavailable` und einem unbekannten Fehlertyp bleibt `processedAt` leer; ein zweites `processPending` ruft das Modell erneut auf (Zähler 2).
- **AC-5:** `refusal`, `unsupportedLanguageOrLocale` und `GeneratedContent.ParsingError` gelten als vorübergehend (`ModelFailure.isPermanent == false`), nur `guardrailViolation` und `contextSizeExceeded` als dauerhaft.
- **AC-6:** „Neu analysieren" (`reanalyze`) ruft das Modell für eine dauerhaft abgelehnte Notiz weiterhin auf.
- **AC-7:** `ModelFailure.isPermanent` und `Shared/Enrichment/ModelFailure.swift` kompilieren auf watchOS (ohne FoundationModels liefert die Funktion `false`); der Watch-Build bleibt grün.
- **AC-8:** ADR-4 nennt, dass `processedAt` bei einem dauerhaften Modellfehler ohne KI-Revision gesetzt wird.

## Test Plan

### Automated Tests (TDD RED)

Alle in `LooseEndsTests/ModelSeamTests.swift`, mit `StubEnricher(failure:)` und `TestStore`; SDK-Fälle unter
`#if canImport(FoundationModels) && !os(watchOS)`.

- **GIVEN** `StubEnricher` wirft `guardrailViolation` **WHEN** `processPending` **THEN** `processedAt != nil`, keine Revisionen, `rulesAppliedAt != nil` (AC-1; ersetzt `guardrailRefusal`, das heute `processedAt == nil` fordert).
- **GIVEN** `contextSizeExceeded(.init(contextSize: 10, tokenCount: 20, debugDescription:))` **WHEN** `processPending` **THEN** wie oben (AC-2).
- **GIVEN** Dauerfehler **WHEN** `processPending` zweimal läuft **THEN** `stub.calls == 1` (AC-3). Rot heute: `calls == 2`.
- **GIVEN** je `timeout`, `rateLimited`, `StubFailure` und eine `delay` über der Zeitgrenze **WHEN** `processPending` zweimal läuft **THEN** `processedAt == nil`, `calls == 2` (AC-4).
- **GIVEN** je ein Fehler pro Zeile der Tabelle **WHEN** `ModelFailure.isPermanent` **THEN** nur Guardrail und Kontextfenster `true` (AC-5).
- **GIVEN** Notiz nach Dauerfehler **WHEN** `reanalyze(task)` **THEN** `stub.calls` steigt (AC-6).
- AC-7: Beleg durch den Watch-Build (`./scripts/sim.sh build` plus Watch-Target in der CI); kein eigener Unit-Test.
- AC-8: Sichtprüfung der Diff.

Reproduktion (Pflicht, vor dem Fix): erster Test und Zähler-Test laufen rot; Ausgabe wird als Beleg festgehalten.

### Simulator-Nachweis (Stufe 2)

Unter `--ui-testing` ist das Modell abgeschaltet (`ModelOffEnricher`); der Fehlerzweig ist im Simulator nur über
die Unit-Tests erreichbar. Der Durchlauf in der App zeigt, dass Erfassen, Regelschritt und „Neu analysieren"
unverändert funktionieren.

### Stufe 3

`EnrichmentCoordinator.swift` steht auf der Geräteliste: Nachweis über TestFlight nach dem Merge. Nichts auf
Hennings Geräten ohne sein „jetzt ist ein Test möglich".

## Expected Behavior

Eine Notiz, die das Modell dauerhaft ablehnt, behält ihre Regelergebnisse (Datum, Wichtigkeit, Wiedererkennung)
und wird danach nicht mehr bei jedem Start ans Modell geschickt. Für den Nutzer ändert sich nichts Sichtbares.
Vorübergehende Fehler werden wie bisher beim nächsten Durchlauf wiederholt.

## Definition of Done

- [ ] Alle Unit-Tests grün (`./scripts/sim.sh sim-unit`), Watch- und iOS-Build grün
- [ ] Rot-Beleg vor dem Fix (`calls == 2`), Grün-Beleg danach
- [ ] Simulator-Durchlauf als Beleg registriert (Erfassen, „Neu analysieren")
- [ ] ADR-4 ergänzt
- [ ] PR referenziert #535 (`Closes #535`), CI grün
- [ ] Nach dem Merge: Hauptordner nachgezogen, TestFlight-Bau für Stufe 3

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — ADR-4 wird um einen Satz ergänzt, nicht revidiert; kein neuer Baustein, keine Schema-Änderung, Regel statt Modell

## Changelog

- 2026-10-21: Spec aus dem Analyse-Kontext (`docs/context/fix-535-dauerfehler.md`)
