import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("RevisionService") struct RevisionServiceTests {
    /// A task the AI just enriched: title, due date, duration and one context, one revision each.
    @MainActor
    private func enrichedTask(in store: TestStore) throws -> (TaskItem, TaskContext, Date) {
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        context.insert(garden)
        let task = TaskItem(rawText: "Rasenmäher Ölwechsel am Samstag")
        context.insert(task)
        let saturday = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 19)))
        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess("Rasenmäher: Ölwechsel", confidence: 0.9, reason: "Names the job.")
        draft.dueDate = EnrichmentDraft.Guess(saturday, confidence: 0.8, reason: "Saturday.")
        draft.duration = EnrichmentDraft.Guess(.minutes30, confidence: 0.7, reason: "Maintenance.")
        draft.contexts = EnrichmentDraft.Guess(["Garten"], confidence: 0.9, reason: "Garden tool.")
        EnrichmentWriter.apply(draft, to: task, contexts: [garden], projects: [])
        try context.save()
        return (task, garden, saturday)
    }

    @Test("Resetting the AI title puts the raw text back and records a user revision")
    @MainActor func revertTitle() async throws {
        let store = try TestStore()
        let (task, garden, _) = try enrichedTask(in: store)
        let aiTitle = try #require(RevisionService.firstAIRevision(of: .title, on: task))

        let written = RevisionService.revert(aiTitle, on: task, contexts: [garden], projects: [])
        try store.context.save()

        #expect(task.title == nil)
        #expect(task.titleSourceRaw == nil)
        #expect(task.titleConfidence == nil)
        #expect(task.displayTitle == "Rasenmäher Ölwechsel am Samstag")
        #expect(written.author == .user)
        #expect(written.field == .title)
        #expect(written.oldValue == "Rasenmäher: Ölwechsel")
        #expect(written.newValue == nil)
        #expect((task.revisions ?? []).count == 5, "four AI revisions plus one user revision, nothing deleted")
        #expect(!RevisionService.aiSetFields(on: task).contains(.title))
    }

    @Test("Resetting due date and contexts restores the pre-AI state")
    @MainActor func revertDueAndContexts() async throws {
        let store = try TestStore()
        let (task, garden, _) = try enrichedTask(in: store)
        let due = try #require(RevisionService.firstAIRevision(of: .dueDate, on: task))
        let contexts = try #require(RevisionService.firstAIRevision(of: .contexts, on: task))

        RevisionService.revert(due, on: task, contexts: [garden], projects: [])
        RevisionService.revert(contexts, on: task, contexts: [garden], projects: [])
        try store.context.save()

        #expect(task.dueDate == nil)
        #expect(task.dueSourceRaw == nil)
        #expect((task.contexts ?? []).isEmpty)
        #expect(task.contextsSourceRaw == nil)
        #expect(task.duration == .minutes30, "untouched fields keep their AI value")
    }

    @Test("Reset all clears every AI field in one go and writes one user revision per field")
    @MainActor func revertAll() async throws {
        let store = try TestStore()
        let (task, garden, _) = try enrichedTask(in: store)

        let written = RevisionService.revertAll(on: task, contexts: [garden], projects: [])
        try store.context.save()

        #expect(written.count == 4)
        #expect(RevisionService.aiSetFields(on: task).isEmpty)
        #expect(task.title == nil && task.dueDate == nil && task.duration == nil)
        #expect((task.contexts ?? []).isEmpty)
        let userRevisions = (task.revisions ?? []).filter { $0.author == .user }
        #expect(userRevisions.count == 4)
    }

    @Test("A user title edit writes a user revision; the same value again writes nothing")
    @MainActor func setTitle() async throws {
        let store = try TestStore()
        let (task, garden, _) = try enrichedTask(in: store)

        let first = RevisionService.set(.title, to: "Ölwechsel Rasenmäher", on: task, contexts: [garden], projects: [])
        let again = RevisionService.set(.title, to: "Ölwechsel Rasenmäher", on: task, contexts: [garden], projects: [])
        try store.context.save()

        let revision = try #require(first)
        #expect(revision.author == .user)
        #expect(revision.oldValue == "Rasenmäher: Ölwechsel")
        #expect(revision.newValue == "Ölwechsel Rasenmäher")
        #expect(again == nil)
        #expect(task.title == "Ölwechsel Rasenmäher")
        #expect(task.titleSourceRaw == "user")
        #expect(task.titleConfidence == nil)
    }

    @Test("Marking seen clears the marker and takes an active task out of New")
    @MainActor func markSeen() async throws {
        let store = try TestStore()
        let (task, _, _) = try enrichedTask(in: store)
        #expect(task.hasUnseenAIRevisions)
        let before = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(ViewRules.tasks(for: .new, in: before).map(\.id) == [task.id])

        let marked = RevisionService.markSeen(task)
        try store.context.save()

        #expect(marked == 4)
        #expect(!task.hasUnseenAIRevisions)
        #expect(RevisionService.markSeen(task) == 0, "second pass finds nothing")
        let after = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(ViewRules.tasks(for: .new, in: after).isEmpty)
    }

    @Test("Project resets match by name; an unknown name leaves the project empty")
    @MainActor func projectApply() async throws {
        let store = try TestStore()
        let house = Project(name: "Haus")
        store.context.insert(house)
        let task = TaskItem(rawText: "Dachrinne reinigen")
        store.context.insert(task)

        FieldCodec.apply("Haus", to: .project, of: task, as: .user, contexts: [], projects: [house])
        #expect(task.project?.name == "Haus")
        FieldCodec.apply("Auto", to: .project, of: task, as: .user, contexts: [], projects: [house])
        #expect(task.project == nil)
    }
}

@Suite("FieldCodec") struct FieldCodecTests {
    @Test("Every revisable field survives an encode-apply round trip")
    @MainActor func roundTrip() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten")
        let phone = TaskContext(name: "Telefon")
        store.context.insert(garden)
        store.context.insert(phone)
        let source = TaskItem(rawText: "Quelle")
        let target = TaskItem(rawText: "Ziel")
        store.context.insert(source)
        store.context.insert(target)
        source.title = "Titel"
        source.dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        source.importance = .high
        source.urgency = .low
        source.duration = .hour1
        source.energy = .medium
        source.contexts = [garden, phone]
        source.people = ["Anna", "Ben"]

        for field in [RevisedField.title, .dueDate, .importance, .urgency, .duration, .energy, .contexts, .people] {
            let encoded = FieldCodec.encode(field, of: source)
            FieldCodec.apply(encoded, to: field, of: target, as: .user, contexts: [garden, phone], projects: [])
            #expect(FieldCodec.encode(field, of: target) == encoded, "\(field) round trip")
        }
        #expect(target.dueDate == source.dueDate)
        #expect(Set((target.contexts ?? []).map(\.name)) == ["Garten", "Telefon"])
        #expect(target.people == ["Anna", "Ben"])
        #expect(target.titleSourceRaw == "user")
    }

    @Test("Malformed lists read as empty instead of throwing")
    func malformedList() {
        #expect(FieldCodec.decode("not json").isEmpty)
        #expect(FieldCodec.decode(nil).isEmpty)
        #expect(FieldCodec.decode("[\"a\",\"b\"]") == ["a", "b"])
    }
}
