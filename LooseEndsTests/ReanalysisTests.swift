import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// "Analyze again" in the detail (#34): the second run ADR-4 allows on the user's request. Since #982 (ADR-22) it
/// runs the rules only; old AI values stay unless a rule finds a different value for a field the user never touched.
@Suite("Re-analysis") struct ReanalysisTests {
    private func revisions(of field: RevisedField, on task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.field == field }.sorted { $0.createdAt < $1.createdAt }
    }

    /// A task an earlier build enriched with the model: AI title and duration with their revisions, rule step done.
    @MainActor
    private func enrichedByTheModel(_ rawText: String, in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: rawText)
        task.title = "Zettel"
        task.titleSourceRaw = FieldSource.ai.rawValue
        task.duration = .minutes15
        task.durationSourceRaw = FieldSource.ai.rawValue
        task.status = .active
        task.processedAt = Date(timeIntervalSince1970: 1_700_000_000)
        task.rulesAppliedAt = task.processedAt
        task.revisions = [
            Revision(task: task, field: .title, oldValue: nil, newValue: "Zettel", author: .ai, reason: nil),
            Revision(task: task, field: .duration, oldValue: nil, newValue: DurationBucket.minutes15.rawValue,
                     author: .ai, reason: nil),
        ]
        store.context.insert(task)
        return task
    }

    @Test("A rule value replaces an old AI value as a new rule revision; the AI revision stays")
    @MainActor func ruleReplacesAISetField() async throws {
        let store = try TestStore()
        let task = enrichedByTheModel("Zettel sortieren 20 Minuten", in: store)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(container: store.container)

        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 1))
        #expect(task.duration == .minutes30)
        #expect(task.durationSourceRaw == FieldSource.rule.rawValue)
        let durations = revisions(of: .duration, on: task)
        #expect(durations.map(\.author) == [.ai, .rule], "the first run's revision stays, nothing is deleted")
        #expect(durations.last?.oldValue == DurationBucket.minutes15.rawValue)
        #expect(durations.last?.seenAt == nil, "the change is unseen until looked at")
        #expect(task.title == "Zettel", "no rule rewrites a title")
        #expect(revisions(of: .title, on: task).map(\.author) == [.ai])
    }

    @Test("A field the user set stays; a rule field beside it still fills")
    @MainActor func keepsWhatTheUserSet() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren 20 Minuten morgen")
        store.context.insert(task)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()
        #expect(task.duration == .minutes30)
        RevisionService.set(.duration, to: DurationBucket.hour1.rawValue, on: task, contexts: [], projects: [])
        task.dueDate = nil   // emptied without a user revision: the rule may fill it again
        try store.context.save()

        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 1))
        #expect(task.duration == .hour1, "the user's correction is never overwritten")
        #expect(task.durationSourceRaw == FieldSource.user.rawValue)
        #expect(task.dueDate != nil)
    }

    @Test("The same result again adds no revision")
    @MainActor func sameResultAddsNothing() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren 20 Minuten")
        store.context.insert(task)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()
        let before = task.revisions?.count

        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 0))
        #expect(task.revisions?.count == before)
    }

    @Test("An empty field is filled; a field no rule finds is not cleared")
    @MainActor func fillsEmptyAndNeverClears() async throws {
        let store = try TestStore()
        let task = enrichedByTheModel("Zettel sortieren wichtig", in: store)
        task.duration = nil
        task.durationSourceRaw = nil
        task.revisions = (task.revisions ?? []).filter { $0.field != .duration }
        try store.context.save()
        let coordinator = EnrichmentCoordinator(container: store.container)

        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 1))
        #expect(task.importance == .high, "the empty importance is filled by the rule")
        #expect(task.duration == nil, "no rule finds a duration, none is made up")
        #expect(task.title == "Zettel", "the AI title nobody found again stays")
    }

    @Test("The rules run, and the result counts their changes")
    @MainActor func rulesOnly() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Steuererklärung morgen abgeben")
        store.context.insert(task)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()
        let due = try #require(task.dueDate, "the rule sets the due date on the first run")
        let before = task.revisions?.count

        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 0))
        #expect(task.dueDate == due, "the same rule hit again changes nothing")
        #expect(task.revisions?.count == before)
    }

    @Test("A recognised duration stays on a re-analysis")
    @MainActor func recognitionStays() async throws {
        let store = try TestStore()
        let earlier = TaskItem(rawText: "Rasen mähen")
        earlier.duration = .hour1
        earlier.durationSourceRaw = FieldSource.user.rawValue
        earlier.rulesAppliedAt = Date(timeIntervalSince1970: 0)
        earlier.status = .done
        store.context.insert(earlier)
        let task = TaskItem(rawText: "rasen mähen")
        store.context.insert(task)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()
        #expect(task.duration == .hour1, "recognition sets the duration on the first run (#136)")
        let before = revisions(of: .duration, on: task).count

        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 0))
        #expect(task.duration == .hour1)
        #expect(revisions(of: .duration, on: task).count == before)
    }
}
