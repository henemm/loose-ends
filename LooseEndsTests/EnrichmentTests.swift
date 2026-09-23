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

/// Holds the container for the whole test: a ModelContext does not retain its ModelContainer,
/// and a context whose container was released crashes on the next save or fetch.
@MainActor
struct TestStore {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
    }
}

@Suite("EnrichmentWriter") struct EnrichmentWriterTests {
    @Test("Fields at or above the threshold are written with source, confidence and one AI revision each")
    @MainActor func appliesFieldsAboveThreshold() async throws {
        let store = try TestStore()
        let context = store.context
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
        let allFromAI = revisions.allSatisfy { $0.author == .ai && $0.seenAt == nil && !($0.reason ?? "").isEmpty }
        #expect(allFromAI, "every revision is unseen, by the AI, with a reason")
        #expect(Set(revisions.map(\.field)) == [.title, .dueDate, .importance, .duration, .contexts])
        #expect(task.hasUnseenAIRevisions)
        #expect(task.displayTitle == "Rasenmäher: Ölwechsel")

        let all = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(ViewRules.tasks(for: .new, in: all).map(\.id) == [task.id], "unseen AI changes keep it in New")
        #expect(ViewRules.tasks(for: .quick, in: all).map(\.id) == [task.id])
    }

    @Test("A title below the threshold leaves the task unverified with the raw text on show")
    @MainActor func titleBelowThresholdIsUnverified() async throws {
        let store = try TestStore()
        let context = store.context
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
    @MainActor func projectMatchesByName() async throws {
        let store = try TestStore()
        let context = store.context
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
        let store = try TestStore()
        let context = store.context
        let container = store.container
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
        let store = try TestStore()
        let context = store.context
        let container = store.container
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
        let store = try TestStore()
        let context = store.context
        let container = store.container
        context.insert(TaskItem(rawText: "Irgendwas"))
        try context.save()
        let stub = StubEnricher(unavailableReason: "deviceNotEligible")
        let coordinator = EnrichmentCoordinator(enricher: stub, container: container)

        await coordinator.processPending()
        #expect(stub.calls == 0)
    }

    @Test("Examples are the most recent completed tasks with their final attributes")
    @MainActor func examplesComeFromDoneTasks() async throws {
        let store = try TestStore()
        let context = store.context
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

    /// „Regeln vor Modell" heißt nicht „Regeln nur, wenn das Modell kann" (#95, AC-7): der
    /// Regelschritt läuft im Koordinator, unabhängig vom Modell-Gate. Auf einem Gerät ohne Apple
    /// Intelligence, bei gesperrtem Gerät oder am Ratenlimit entsteht das Datum trotzdem.
    @Test("Ohne verfügbares Modell schreibt die Regel trotzdem das Datum")
    @MainActor func ruleWritesDueDateWithoutModel() async throws {
        let store = try TestStore()
        let context = store.context
        let container = store.container
        let task = TaskItem(rawText: "Nächsten Freitag die Miete überweisen")
        // Donnerstag, 12. März 2026 — im Kalender des Testrechners, damit die Erwartung unten
        // zeitzonenunabhängig bleibt.
        task.capturedAt = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 12)))
        context.insert(task)
        try context.save()
        let stub = StubEnricher(unavailableReason: "deviceNotEligible")
        let coordinator = EnrichmentCoordinator(enricher: stub, container: container)

        await coordinator.processPending()

        #expect(stub.calls == 0, "das Modell wird nicht befragt")
        let due = try #require(task.dueDate, "die Regel muss ein Datum liefern")
        #expect(Calendar.current.dateComponents([.year, .month, .day], from: due)
                == DateComponents(year: 2026, month: 3, day: 20))
        #expect(task.dueHasTime == false)
        #expect(task.dueSourceRaw == FieldSource.ai.rawValue)
        #expect(task.dueConfidence == 1.0)
        let dueRevisions = (task.revisions ?? []).filter { $0.field == .dueDate }
        #expect(dueRevisions.count == 1)
        #expect(dueRevisions.first?.author == .ai)
        #expect(dueRevisions.first?.reason?.isEmpty == false)
        #expect(task.processedAt == nil, "Titel und Wichtigkeit stehen noch aus")
    }

    /// `processedAt` bleibt der Marker für „das Modell hat es gesehen" (ADR-4). Sonst verlöre eine
    /// einmal ohne Apple Intelligence erfasste Aufgabe Titel und Wichtigkeit für immer. Beim
    /// Nachhol-Durchgang darf die Regel aber keine zweite Revision auf dasselbe Feld legen
    /// (#95, AC-8).
    @Test("Der Nachhol-Durchgang holt den Titel, ohne die Regel-Revision zu verdoppeln")
    @MainActor func catchUpPassDoesNotDuplicateRuleRevision() async throws {
        let store = try TestStore()
        let context = store.context
        let container = store.container
        let task = TaskItem(rawText: "Nächsten Freitag die Miete überweisen")
        task.capturedAt = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 12)))
        context.insert(task)
        try context.save()
        let stub = StubEnricher(unavailableReason: "deviceNotEligible")
        let coordinator = EnrichmentCoordinator(enricher: stub, container: container)

        await coordinator.processPending()
        let dueAfterRule = try #require(task.dueDate)

        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess("Miete überweisen", confidence: 0.9, reason: "Stub.")
        stub.draft = draft
        stub.unavailableReason = nil

        await coordinator.processPending()

        #expect(stub.calls == 1, "das Modell wird im Nachhol-Durchgang genau einmal befragt")
        #expect(task.title == "Miete überweisen")
        #expect(task.processedAt != nil, "jetzt hat das Modell die Aufgabe gesehen")
        #expect(task.dueDate == dueAfterRule, "das Datum der Regel bleibt stehen")
        #expect((task.revisions ?? []).filter { $0.field == .dueDate }.count == 1,
                "die Regel legt beim zweiten Durchgang keine zweite Revision an")
    }

    /// #117, AC-5: `matchImportance(in:)`/`matchUrgency(in:)` nehmen bewusst keinen Referenz-
    /// zeitpunkt entgegen — das Alter der Notiz ist kein Wichtigkeits-Signal. Zwei stark
    /// unterschiedliche `capturedAt`-Zeitpunkte müssen deshalb dasselbe Ergebnis liefern.
    @Test("Wichtigkeit ist unabhängig vom Erfassungszeitpunkt (AC-5)")
    @MainActor func ruleIgnoresCapturedAt() async throws {
        let store = try TestStore()
        let context = store.context
        let container = store.container
        let stub = StubEnricher(unavailableReason: "deviceNotEligible")
        let coordinator = EnrichmentCoordinator(enricher: stub, container: container)

        let recent = TaskItem(rawText: "250 Euro an den Verein überweisen")
        recent.capturedAt = Date()
        let old = TaskItem(rawText: "250 Euro an den Verein überweisen")
        old.capturedAt = try #require(Calendar.current.date(byAdding: .year, value: -2, to: Date()))
        context.insert(recent)
        context.insert(old)
        try context.save()

        await coordinator.processPending()

        #expect(recent.importance == .high)
        #expect(old.importance == .high, "das Alter der Notiz darf das Ergebnis nicht ändern")
    }

    /// #117, AC-6: Wie beim Fälligkeitsdatum darf der Nachhol-Durchgang keine zweite Revision auf
    /// ein bereits gesetztes Feld legen — getrennt für Wichtigkeit und Dringlichkeit geprüft, weil
    /// beide unabhängige Guard-Blöcke sind.
    @Test("Der Nachhol-Durchgang verdoppelt keine Wichtigkeits-/Dringlichkeits-Revision (AC-6)")
    @MainActor func catchUpPassDoesNotDuplicateImportanceOrUrgencyRevision() async throws {
        let store = try TestStore()
        let context = store.context
        let container = store.container
        let task = TaskItem(rawText: "Dringend 250 Euro an den Verein überweisen")
        context.insert(task)
        try context.save()
        let stub = StubEnricher(unavailableReason: "deviceNotEligible")
        let coordinator = EnrichmentCoordinator(enricher: stub, container: container)

        await coordinator.processPending()
        let importanceAfterRule = task.importance
        let urgencyAfterRule = task.urgency

        stub.unavailableReason = nil
        await coordinator.processPending()

        #expect(task.importance == importanceAfterRule)
        #expect(task.urgency == urgencyAfterRule)
        #expect((task.revisions ?? []).filter { $0.field == .importance }.count == 1,
                "die Regel legt beim zweiten Durchgang keine zweite Wichtigkeits-Revision an")
        #expect((task.revisions ?? []).filter { $0.field == .urgency }.count == 1,
                "die Regel legt beim zweiten Durchgang keine zweite Dringlichkeits-Revision an")
    }
}

@Suite("EnrichmentParsing") struct EnrichmentParsingTests {
    /// Was left over when the model schema lost its date fields (#95): a model may still answer
    /// with a confidence outside 0…1, and the threshold check must not see it.
    @Test("Confidences outside 0 to 1 are clamped")
    func clampsConfidence() {
        #expect(EnrichmentParsing.clamp(1.7) == 1)
        #expect(EnrichmentParsing.clamp(-0.2) == 0)
        #expect(EnrichmentParsing.clamp(0.65) == 0.65)
    }
}

@Suite("ContextSeeder") struct ContextSeederTests {
    @Test("The default contexts are seeded once and never re-added after deletion")
    @MainActor func seedsOnce() async throws {
        let store = try TestStore()
        let context = store.context
        let suite = "ContextSeederTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let created = try ContextSeeder.seedIfNeeded(in: context, defaults: defaults)
        #expect(created.count == 6)
        let allDefaults = created.allSatisfy(\.isSystemDefault)
        #expect(allDefaults)

        for item in created { context.delete(item) }
        try context.save()
        let again = try ContextSeeder.seedIfNeeded(in: context, defaults: defaults)
        #expect(again.isEmpty)
        #expect(try context.fetchCount(FetchDescriptor<TaskContext>()) == 0)
    }
}
