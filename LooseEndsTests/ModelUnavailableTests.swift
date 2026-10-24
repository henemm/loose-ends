import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// #68 (A4): Wann steht das Modell bereit? Der Code beantwortet das Meiste schon; diese Tests halten
/// fest, was bisher nur für **einen** Nichtverfügbar-Grund geprüft war (`unavailableModelIsSkipped`,
/// `ruleMarkerDoesNotHideATaskFromTheModelPass`), und das Verhalten beim Doppellauf. Es sind
/// Charakterisierungstests gegen unveränderten Produktcode, keine RED-Tests (Spec, Test Plan).
/// Der Grund ist ein String: `FoundationModelsEnricher` liefert `String(describing: reason)`.
@Suite("Modell nicht verfügbar (#68)") struct ModelUnavailableTests {
    static let reasons = ["deviceNotEligible", "appleIntelligenceNotEnabled", "modelNotReady", "etwas Unbekanntes"]

    /// AC-7 und AC-8: Bei jedem Grund laufen die Regeln, das Modell wird nicht gerufen, die Aufgabe
    /// bleibt für den Nachzügler fällig; wird das Modell verfügbar, ruft der nächste Lauf es genau
    /// einmal, ohne die Regel-Revision zu verdoppeln.
    @Test("Regeln laufen ohne Modell, das Modell holt später nach", arguments: ModelUnavailableTests.reasons)
    @MainActor func rulesRunAndModelCatchesUp(reason: String) async throws {
        let store = try TestStore()
        let context = store.context
        let task = TaskItem(rawText: "Nächsten Freitag dringend die Miete überweisen")
        task.capturedAt = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 12)))
        context.insert(task)
        try context.save()
        let stub = StubEnricher(unavailableReason: reason)
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)

        await coordinator.processPending()

        #expect(stub.calls == 0, "ohne Modell wird nichts gefragt (\(reason))")
        #expect(task.rulesAppliedAt != nil, "der Regelschritt lief (\(reason))")
        #expect(task.processedAt == nil, "das Modell hat die Aufgabe nicht gesehen (\(reason))")
        let dueAfterRule = try #require(task.dueDate, "das Datum setzt die Regel (\(reason))")
        #expect(task.urgency != nil, "die Dringlichkeit setzt die Stichwortregel (\(reason))")
        #expect(task.status != .done)

        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess("Miete überweisen", confidence: 0.9, reason: "Stub.")
        stub.draft = draft
        stub.unavailableReason = nil

        await coordinator.processPending()

        #expect(stub.calls == 1, "der Nachzügler fragt das Modell genau einmal (\(reason))")
        #expect(task.processedAt != nil, "jetzt hat das Modell die Aufgabe gesehen (\(reason))")
        #expect(task.dueDate == dueAfterRule, "das Datum der Regel bleibt stehen (\(reason))")
        #expect((task.revisions ?? []).filter { $0.field == .dueDate }.count == 1,
                "keine zweite Regel-Revision (\(reason))")
    }

    /// AC-9: Zwei Geräte sehen dieselbe Aufgabe als fällig, weil dem zweiten der Abgleich noch fehlt
    /// (`processedAt` zurückgesetzt). Der zweite Modelllauf mit abweichender Antwort beschädigt nichts.
    /// Nicht belegt: zwei echte Geräte und der CloudKit-Abgleich selbst.
    @Test("Doppellauf: der zweite Modelllauf überschreibt keinen Nutzerwert")
    @MainActor func secondModelRunLeavesUserValuesAlone() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        context.insert(garden)
        let task = TaskItem(rawText: "Vitrine im Wohnzimmer abstauben")
        context.insert(task)
        try context.save()
        RevisionService.set(.duration, to: DurationBucket.minutes30.rawValue, on: task, contexts: [garden], projects: [])
        try context.save()

        var first = EnrichmentDraft()
        first.title = EnrichmentDraft.Guess("Vitrine abstauben", confidence: 0.9, reason: "Stub.")
        first.duration = EnrichmentDraft.Guess(.hour1, confidence: 0.9, reason: "Stub.")
        first.contexts = EnrichmentDraft.Guess(["Garten"], confidence: 0.9, reason: "Stub.")
        let stub = StubEnricher(draft: first)
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)

        await coordinator.processPending()
        #expect(stub.calls == 1)
        #expect(task.processedAt != nil)

        var second = EnrichmentDraft()
        second.title = EnrichmentDraft.Guess("Vitrine entstauben", confidence: 0.9, reason: "Stub, anderes Gerät.")
        second.duration = EnrichmentDraft.Guess(.hours2plus, confidence: 0.9, reason: "Stub, anderes Gerät.")
        second.contexts = EnrichmentDraft.Guess(["Garten"], confidence: 0.9, reason: "Stub, anderes Gerät.")
        stub.draft = second
        task.processedAt = nil

        await coordinator.processPending()

        #expect(stub.calls == 2, "das zweite Gerät fragt sein Modell ebenfalls")
        #expect(task.duration == .minutes30, "der Nutzerwert bleibt unverändert")
        #expect(task.durationSourceRaw == FieldSource.user.rawValue)
        #expect((task.revisions ?? []).filter { $0.field == .duration }.count == 1,
                "genau eine Revision auf der Dauer, die des Nutzers")
        #expect((task.contexts ?? []).isEmpty, "das Modell setzt nie Kontexte (#215)")
        #expect((task.revisions ?? []).filter { $0.author == .user }.count == 1,
                "der zweite Lauf legt keine Nutzer-Revision an")
    }
}
