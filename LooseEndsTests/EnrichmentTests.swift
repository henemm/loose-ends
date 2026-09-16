import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Fake model (ADR-11): returns a fixed draft, or fails, and counts calls.
final class StubEnricher: TaskEnricher, @unchecked Sendable {
    var draft: EnrichmentDraft
    var failure: Error?
    var unavailableReason: String?
    private(set) var calls = 0

    init(draft: EnrichmentDraft = EnrichmentDraft(), failure: Error? = nil, unavailableReason: String? = nil) {
        self.draft = draft
        self.failure = failure
        self.unavailableReason = unavailableReason
    }

    func enrich(_ input: EnrichmentInput) async throws -> EnrichmentDraft {
        calls += 1
        if let failure { throw failure }
        return draft
    }
}

struct StubFailure: Error {}

@MainActor
private func makeStore() throws -> (ModelContainer, ModelContext) {
    let container = try ModelContainerFactory.make(inMemory: true)
    return (container, container.mainContext)
}

@Suite("EnrichmentWriter") struct EnrichmentWriterTests {
    @Test("Fields at or above the threshold are written with source, confidence and one AI revision each")
    @MainActor func appliesFieldsAboveThreshold() throws {
        let (_, context) = try makeStore()
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        let computer = TaskContext(name: "Computer", isSystemDefault: true, sortOrder: 0)
        context.insert(garden)
        context.insert(computer)
        let task = TaskItem(rawText: "Rasenmäher Ölwechsel am Samstag, dauert ne Viertelstunde")
        context.insert(task)
        try context.save()

        let saturday = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 19)))
        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess("Rasenmäher: Ölwechsel", confidence: 0.9, reason: "The note names the job.")
        draft.dueDate = EnrichmentDraft.Guess(saturday, confidence: 0.8, reason: "Saturday after the capture date.")
        draft.importance = EnrichmentDraft.Guess(.medium, confidence: 0.7, reason: "Maintenance, nobody waits.")
        draft.urgency = EnrichmentDraft.Guess(.high, confidence: 0.3, reason: "No signal.")
        draft.duration = EnrichmentDraft.Guess(.minutes15, confidence: 0.65, reason: "A quarter of an hour is stated.")
        draft.contexts = EnrichmentDraft.Guess(["garten", "Werkstatt"], confidence: 0.9, reason: "Lawn mower lives in the garden.")

        let now = Date()
        let written = EnrichmentWriter.apply(draft, to: task, contexts: [computer, garden], projects: [], now: now)
        try context.save()

        #expect(written == 5)
        #expect(task.title == "Rasenmäher: Ölwechsel")
        #expect(task.titleSourceRaw == "ai")
        #expect(task.titleConfidence == 0.9)
        #expect(task.status == .active)
        #expect(task.dueDate == saturday)
        #expect(task.dueHasTime == false)
        #expect(task.importance == .medium)
        #expect(task.urgency == nil, "below threshold stays empty")
        #expect(task.duration == .minutes15)
        #expect((task.contexts ?? []).map(\.name) == ["Garten"], "matched case-insensitively, unknown names dropped")
        #expect(task.processedAt == now)

        let revisions = try #require(task.revisions)
        #expect(revisions.count == 5)
        #expect(revisions.allSatisfy { $0.author == .ai && $0.seenAt == nil && !($0.reason ?? "").isEmpty })
        #expect(Set(revisions.map(\.field)) == [.title, .dueDate, .importance, .duration, .contexts])
        #expect(task.hasUnseenAIRevisions)
        #expect(task.displayTitle == "Rasenmäher: Ölwechsel")

        let all = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(ViewRules.tasks(for: .new, in: all).map(\.id) == [task.id], "unseen AI changes keep it in New")
        #expect(ViewRules.tasks(for: .quick, in: all).map(\.id) == [task.id])
    }

    @Test("A title below the threshold leaves the task unverified with the raw text on show")
    @MainActor func titleBelowThresholdIsUnverified() throws {
        let (_, context) = try makeStore()
        let task = TaskItem(rawText: "das Ding mit dem Zeug")
        context.insert(task)
        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess("Thing", confidence: 0.4, reason: "Unclear note.")

        let written = EnrichmentWriter.apply(draft, to: task, contexts: [], projects: [])
        try context.save()

        #expect(written == 0)
        #expect(task.status == .unverified)
        #expect(task.title == nil)
        #expect(task.displayTitle == "das Ding mit dem Zeug")
        #expect(task.processedAt != nil, "processed exactly once, even without a result")
        #expect((task.revisions ?? []).isEmpty)
    }

    @Test("A project is assigned only when the name matches an existing project")
    @MainActor func projectMatchesByName() throws {
        let (_, context) = try makeStore()
        let house = Project(name: "Haus")
        context.insert(house)
        let task = TaskItem(rawText: "Dachrinne reinigen")
        context.insert(task)
        var draft = EnrichmentDraft()
        draft.project = EnrichmentDraft.Guess("haus", confidence: 0.8, reason: "House upkeep.")

        EnrichmentWriter.apply(draft, to: task, contexts: [], projects: [house])
        try context.save()
        #expect(task.project?.name == "Haus")

        let other = TaskItem(rawText: "Reifen wechseln")
        context.insert(other)
        draft.project = EnrichmentDraft.Guess("Auto", confidence: 0.9, reason: "Car.")
        EnrichmentWriter.apply(draft, to: other, contexts: [], projects: [house])
        #expect(other.project == nil)
    }
}

@Suite("EnrichmentCoordinator") struct EnrichmentCoordinatorTests {
    @Test("Every unprocessed task is enriched once; a second pass touches nothing")
    @MainActor func processesOnce() async throws {
        let (container, context) = try makeStore()
        let first = TaskItem(rawText: "Erste")
        let second = TaskItem(rawText: "Zweite")
        let done = TaskItem(rawText: "Fertige")
        done.status = .done
        context.insert(first)
        context.insert(second)
        context.insert(done)
        try context.save()

        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess("Titel", confidence: 0.9, reason: "Stub.")
        let stub = StubEnricher(draft: draft)
        let coordinator = EnrichmentCoordinator(enricher: stub, container: container)

        await coordinator.processPending()
        #expect(stub.calls == 2)
        #expect(first.processedAt != nil && second.processedAt != nil)
        #expect(done.processedAt == nil, "only unprocessed tasks run")

        await coordinator.processPending()
        #expect(stub.calls == 2)
    }

    @Test("A failing model leaves the task unprocessed for the next pass")
    @MainActor func failureLeavesTaskUnprocessed() async throws {
        let (container, context) = try makeStore()
        let task = TaskItem(rawText: "Steuer abgeben")
        context.insert(task)
        try context.save()
        let stub = StubEnricher(failure: StubFailure())
        let coordinator = EnrichmentCoordinator(enricher: stub, container: container)

        await coordinator.processPending()

        #expect(stub.calls == 1)
        #expect(task.status == .unprocessed)
        #expect(task.processedAt == nil)
        #expect((task.revisions ?? []).isEmpty)
    }

    @Test("An unavailable model is not called at all")
    @MainActor func unavailableModelIsSkipped() async throws {
        let (container, context) = try makeStore()
        context.insert(TaskItem(rawText: "Irgendwas"))
        try context.save()
        let stub = StubEnricher(unavailableReason: "deviceNotEligible")
        let coordinator = EnrichmentCoordinator(enricher: stub, container: container)

        await coordinator.processPending()
        #expect(stub.calls == 0)
    }

    @Test("Examples are the most recent completed tasks with their final attributes")
    @MainActor func examplesComeFromDoneTasks() throws {
        let (_, context) = try makeStore()
        let garden = TaskContext(name: "Garten")
        context.insert(garden)
        for index in 0..<7 {
            let task = TaskItem(rawText: "Erledigt \(index)")
            task.status = .done
            task.title = "Titel \(index)"
            task.importance = .high
            task.completedAt = Date(timeIntervalSince1970: Double(index) * 60)
            context.insert(task)
            task.contexts = [garden]
        }
        context.insert(TaskItem(rawText: "Offen"))
        try context.save()

        let examples = try EnrichmentCoordinator.examples(in: context)
        #expect(examples.count == 5)
        #expect(examples.first?.rawText == "Erledigt 6")
        #expect(examples.first?.title == "Titel 6")
        #expect(examples.first?.importance == .high)
        #expect(examples.first?.contexts == ["Garten"])
    }
}

@Suite("EnrichmentParsing") struct EnrichmentParsingTests {
    @Test("Day and time strings become a date; malformed input becomes nil")
    func parsesDueDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))

        let dateOnly = try #require(EnrichmentParsing.dueDate(day: "2026-09-19", time: "", calendar: calendar))
        #expect(dateOnly.hasTime == false)
        #expect(calendar.component(.day, from: dateOnly.date) == 19)

        let withTime = try #require(EnrichmentParsing.dueDate(day: "2026-09-19", time: "14:30", calendar: calendar))
        #expect(withTime.hasTime)
        #expect(calendar.component(.hour, from: withTime.date) == 14)
        #expect(calendar.component(.minute, from: withTime.date) == 30)

        #expect(EnrichmentParsing.dueDate(day: "", time: "", calendar: calendar) == nil)
        #expect(EnrichmentParsing.dueDate(day: "next week", time: "", calendar: calendar) == nil)
        #expect(EnrichmentParsing.dueDate(day: "2026-13-40", time: "", calendar: calendar) == nil)
        #expect(EnrichmentParsing.clamp(1.7) == 1)
        #expect(EnrichmentParsing.clamp(-0.2) == 0)
    }
}

@Suite("ContextSeeder") struct ContextSeederTests {
    @Test("The default contexts are seeded once and never re-added after deletion")
    @MainActor func seedsOnce() throws {
        let (_, context) = try makeStore()
        let suite = "ContextSeederTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let created = try ContextSeeder.seedIfNeeded(in: context, defaults: defaults)
        #expect(created.count == 6)
        #expect(created.allSatisfy(\.isSystemDefault))

        for item in created { context.delete(item) }
        try context.save()
        let again = try ContextSeeder.seedIfNeeded(in: context, defaults: defaults)
        #expect(again.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<TaskContext>()) == 0)
    }
}
