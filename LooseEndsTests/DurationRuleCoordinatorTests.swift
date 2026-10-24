import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// #673: `DurationRule` (#441) was never called in the product path. These tests go through the
/// coordinator, not the rule alone: the rule's own tests passed all along.
@Suite("DurationRule im Koordinator (#673)")
struct DurationRuleCoordinatorTests {
    private let text = "Steuerbescheid prüfen 20 Minuten"

    private func noModel() -> StubEnricher { StubEnricher(unavailableReason: "Kein Apple Intelligence") }

    private func durationRevisions(_ task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.field == .duration }
    }

    @Test("Der erste Lauf setzt die genannte Länge als Regelwert mit einer Revision (AC-1)")
    @MainActor func firstRunSetsDuration() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: text)
        store.context.insert(task)
        try store.context.save()

        await EnrichmentCoordinator(enricher: noModel(), container: store.container).processPending()

        #expect(task.duration == .minutes30, "20 Minuten sind der nächste Eimer: 30 min")
        #expect(task.durationSourceRaw == FieldSource.rule.rawValue)
        #expect(task.durationConfidence == DurationRule.confidence)
        let revisions = durationRevisions(task)
        #expect(revisions.count == 1)
        #expect(revisions.first?.author == .rule)
        #expect(revisions.first?.newValue == DurationBucket.minutes30.rawValue)
    }

    @Test("Ein vom Nutzer gesetzter oder geleerter Wert bleibt im ersten Lauf (AC-2)")
    @MainActor func userValueStaysInFirstRun() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: text)
        task.duration = .hour1
        task.durationSourceRaw = FieldSource.user.rawValue
        task.revisions = [Revision(task: task, field: .duration, oldValue: nil,
                                   newValue: DurationBucket.hour1.rawValue, author: .user, reason: "Nutzer")]
        store.context.insert(task)
        try store.context.save()

        await EnrichmentCoordinator(enricher: noModel(), container: store.container).processPending()

        #expect(task.duration == .hour1)
        #expect(durationRevisions(task).count == 1, "keine Regel-Revision neben der des Nutzers")
    }

    @Test("Neu analysieren ersetzt einen Regelwert, nie einen Nutzerwert (AC-3)")
    @MainActor func reanalysisReplacesRuleValueOnly() async throws {
        let store = try TestStore()
        let coordinator = EnrichmentCoordinator(enricher: noModel(), container: store.container)
        let ruled = TaskItem(rawText: text)
        ruled.duration = .hours2plus
        ruled.durationSourceRaw = FieldSource.rule.rawValue
        let touched = TaskItem(rawText: text + " heute")
        touched.duration = .hours2plus
        touched.durationSourceRaw = FieldSource.user.rawValue
        touched.revisions = [Revision(task: touched, field: .duration, oldValue: nil,
                                      newValue: DurationBucket.hours2plus.rawValue, author: .user, reason: "Nutzer")]
        store.context.insert(ruled)
        store.context.insert(touched)
        try store.context.save()

        _ = await coordinator.reanalyze(ruled)
        _ = await coordinator.reanalyze(touched)

        #expect(ruled.duration == .minutes30)
        #expect(durationRevisions(ruled).last?.author == .rule)
        #expect(touched.duration == .hours2plus, "der Nutzerwert bleibt")
    }

    @Test("Die Erkennung schlägt die Wortregel (AC-4)")
    @MainActor func recognitionBeatsTheRule() async throws {
        let store = try TestStore()
        let first = TaskItem(rawText: text)
        first.duration = .hour1
        first.durationSourceRaw = FieldSource.user.rawValue
        first.rulesAppliedAt = Date()
        first.revisions = [Revision(task: first, field: .duration, oldValue: nil,
                                    newValue: DurationBucket.hour1.rawValue, author: .user, reason: "Nutzer")]
        store.context.insert(first)
        let second = TaskItem(rawText: text)
        store.context.insert(second)
        try store.context.save()

        await EnrichmentCoordinator(enricher: noModel(), container: store.container).processPending()

        #expect(second.duration == .hour1, "der frühere Nutzerwert, nicht der gelesene Eimer")
        #expect(durationRevisions(second).count == 1)
    }

    @Test("Das Modell überschreibt den Regeltreffer nicht, auch nicht beim Neu analysieren (AC-5)")
    @MainActor func modelStaysAwayFromRuleHit() async throws {
        let store = try TestStore()
        var draft = EnrichmentDraft()
        draft.duration = EnrichmentDraft.Guess(.hours2plus, confidence: 0.99, reason: "Stub.")
        draft.title = EnrichmentDraft.Guess("Steuerbescheid prüfen", confidence: 0.9, reason: "Stub.")
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(draft: draft), container: store.container)
        let task = TaskItem(rawText: text)
        store.context.insert(task)
        try store.context.save()

        await coordinator.processPending()
        #expect(task.duration == .minutes30)
        #expect(task.durationSourceRaw == FieldSource.rule.rawValue)

        _ = await coordinator.reanalyze(task)
        #expect(task.duration == .minutes30)
        #expect(task.durationSourceRaw == FieldSource.rule.rawValue)
    }

    @Test("Ohne Treffer bleibt die Modelldauer wie bisher (AC-5)")
    @MainActor func modelStillSetsDurationWithoutHit() async throws {
        let store = try TestStore()
        var draft = EnrichmentDraft()
        draft.duration = EnrichmentDraft.Guess(.hour1, confidence: 0.99, reason: "Stub.")
        let task = TaskItem(rawText: "Steuerbescheid prüfen")
        store.context.insert(task)
        try store.context.save()

        await EnrichmentCoordinator(enricher: StubEnricher(draft: draft), container: store.container).processPending()

        #expect(task.duration == .hour1)
        #expect(task.durationSourceRaw == FieldSource.ai.rawValue)
    }

    @Test("Eine Unteraufgabe bekommt keine Dauer (AC-6)")
    @MainActor func subtaskGetsNoDuration() async throws {
        let store = try TestStore()
        let parent = TaskItem(rawText: "Steuer erledigen")
        parent.status = .active
        parent.processedAt = Date()
        parent.rulesAppliedAt = Date()
        store.context.insert(parent)
        let line = try Subtasks.add(text, to: parent, in: store.context)
        try store.context.save()

        await EnrichmentCoordinator(enricher: noModel(), container: store.container).processPending()

        #expect(line.duration == nil)
        #expect(durationRevisions(line).isEmpty)
    }

    @Test("Bestand ohne Nachlauf: Regelvermerk gesetzt heißt keine Dauer, Neu analysieren holt sie (AC-7)")
    @MainActor func existingTaskOnlyViaReanalysis() async throws {
        let store = try TestStore()
        let coordinator = EnrichmentCoordinator(enricher: noModel(), container: store.container)
        let task = TaskItem(rawText: text)
        task.rulesAppliedAt = Date()
        store.context.insert(task)
        try store.context.save()

        await coordinator.processPending()
        #expect(task.duration == nil)

        _ = await coordinator.reanalyze(task)
        #expect(task.duration == .minutes30)
    }

    @Test("Ohne Treffer bleibt das Feld leer, ein Zeitpunkt ist keine Länge (AC-8)")
    @MainActor func noHitLeavesFieldEmpty() async throws {
        let store = try TestStore()
        let plain = TaskItem(rawText: "Steuerbescheid prüfen")
        let point = TaskItem(rawText: "Steuerbescheid in 2 Stunden prüfen")
        store.context.insert(plain)
        store.context.insert(point)
        try store.context.save()

        await EnrichmentCoordinator(enricher: noModel(), container: store.container).processPending()

        for task in [plain, point] {
            #expect(task.duration == nil)
            #expect(durationRevisions(task).isEmpty)
        }
    }
}
