import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// "Analyze again" in the detail (#34): the second run ADR-4 allows on the user's request.
@Suite("Re-analysis") struct ReanalysisTests {
    private func draft(
        title: String? = nil,
        duration: DurationBucket? = nil,
        contexts: [String]? = nil
    ) -> EnrichmentDraft {
        var draft = EnrichmentDraft()
        draft.title = title.map { EnrichmentDraft.Guess($0, confidence: 0.9, reason: "Stub.") }
        draft.duration = duration.map { EnrichmentDraft.Guess($0, confidence: 0.9, reason: "Stub.") }
        draft.contexts = contexts.map { EnrichmentDraft.Guess($0, confidence: 0.9, reason: "Stub.") }
        return draft
    }

    private func revisions(of field: RevisedField, on task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.field == field }.sorted { $0.createdAt < $1.createdAt }
    }

    @Test("AI-set fields take the new values, each change as a new AI revision from the old value")
    @MainActor func replacesAISetFields() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten", sortOrder: 0)
        let office = TaskContext(name: "Büro", sortOrder: 1)
        store.context.insert(garden)
        store.context.insert(office)
        // No rule signal (no date, importance, urgency word): this test is about the model path.
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(draft: draft(title: "Zettel sortieren", duration: .minutes15, contexts: ["Garten"]))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()

        stub.draft = draft(title: "Zettel ordnen", duration: .minutes30, contexts: ["Büro"])
        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 3, modelRan: true))
        #expect(stub.calls == 2)
        #expect(task.title == "Zettel ordnen")
        #expect(task.duration == .minutes30)
        #expect((task.contexts ?? []).map(\.name) == ["Büro"])
        let titles = revisions(of: .title, on: task)
        #expect(titles.count == 2, "the first run's revision stays, nothing is deleted")
        #expect(titles.last?.oldValue == "Zettel sortieren")
        #expect(titles.last?.newValue == "Zettel ordnen")
        #expect(titles.last?.author == .ai)
        #expect(titles.last?.seenAt == nil, "the change is unseen until looked at")
        #expect(revisions(of: .duration, on: task).last?.oldValue == DurationBucket.minutes15.rawValue)
        #expect(revisions(of: .contexts, on: task).last?.oldValue == EnrichmentWriter.encode(["Garten"]))
    }

    @Test("A field the user set stays; the AI-set ones beside it still change")
    @MainActor func keepsWhatTheUserSet() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(draft: draft(title: "Zettel sortieren", duration: .minutes15))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()
        RevisionService.set(.duration, to: DurationBucket.hour1.rawValue, on: task, contexts: [], projects: [])
        try store.context.save()

        stub.draft = draft(title: "Zettel ordnen", duration: .minutes5)
        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 1, modelRan: true))
        #expect(task.duration == .hour1, "the user's correction is never overwritten")
        #expect(task.durationSourceRaw == FieldSource.user.rawValue)
        #expect(task.title == "Zettel ordnen")
    }

    @Test("The same result again adds no revision")
    @MainActor func sameResultAddsNothing() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(draft: draft(title: "Zettel sortieren", duration: .minutes15))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()
        let before = task.revisions?.count

        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 0, modelRan: true))
        #expect(task.revisions?.count == before)
    }

    @Test("An empty field is filled; a field the new result leaves out is not cleared")
    @MainActor func fillsEmptyAndNeverClears() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten", sortOrder: 0)
        store.context.insert(garden)
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(draft: draft(title: "Zettel sortieren", duration: .minutes15))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()

        stub.draft = draft(contexts: ["Garten"])
        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 1, modelRan: true))
        #expect((task.contexts ?? []).map(\.name) == ["Garten"])
        // The writer encodes an empty list as "[]", the first run included; the rule step writes nil.
        #expect(revisions(of: .contexts, on: task).last?.oldValue == EnrichmentWriter.encode([]))
        #expect(task.title == "Zettel sortieren")
        #expect(task.duration == .minutes15)
    }

    @Test("An unverified task becomes active once the re-analysis finds a title")
    @MainActor func titleLiftsUnverified() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(draft: draft())
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()
        #expect(task.status == .unverified)

        stub.draft = draft(title: "Zettel ordnen")
        _ = await coordinator.reanalyze(task)

        #expect(task.status == .active)
        #expect(task.title == "Zettel ordnen")
    }

    @Test("Without the model the rules still run, and the result says so")
    @MainActor func rulesOnlyWithoutModel() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Steuererklärung morgen abgeben")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(unavailableReason: "deviceNotEligible")
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()
        let due = try #require(task.dueDate, "the rule sets the due date on the first run")
        let before = task.revisions?.count

        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 0, modelRan: false))
        #expect(stub.calls == 0)
        #expect(task.dueDate == due, "the same rule hit again changes nothing")
        #expect(task.revisions?.count == before)
    }

    @Test("A failing model call keeps the rule step and reports that the model did not run")
    @MainActor func failingModelReported() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(draft: draft(title: "Zettel sortieren"))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()

        stub.failure = StubFailure()
        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 0, modelRan: false))
        #expect(task.title == "Zettel sortieren")
    }

    @Test("Rules before the model: a recognised duration is not overwritten by the model's estimate")
    @MainActor func recognitionBeatsModel() async throws {
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
        let stub = StubEnricher(draft: draft(title: "Rasen mähen"))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()
        #expect(task.duration == .hour1, "recognition sets the duration on the first run (#136)")
        let before = revisions(of: .duration, on: task).count

        stub.draft = draft(title: "Rasen mähen", duration: .minutes15)
        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 0, modelRan: true))
        #expect(task.duration == .hour1)
        #expect(revisions(of: .duration, on: task).count == before)
    }

    @Test("A task never recognises itself: its own AI value is no source for a re-analysis")
    @MainActor func doesNotRecogniseItself() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(draft: draft(title: "Zettel sortieren", duration: .minutes15))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()

        // Were the task its own neighbour, the recognition would hold the duration at 15 minutes.
        stub.draft = draft(duration: .minutes30)
        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 1, modelRan: true))
        #expect(task.duration == .minutes30)
    }

    @Test("The first run is unchanged: the model still only fills an empty duration")
    @MainActor func firstRunStillGuardsDuration() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren")
        task.duration = .hour1
        task.durationSourceRaw = FieldSource.ai.rawValue
        store.context.insert(task)
        try store.context.save()

        let written = EnrichmentWriter.apply(draft(duration: .minutes5), to: task, contexts: [], projects: [])

        #expect(written == 0)
        #expect(task.duration == .hour1)
    }
}
