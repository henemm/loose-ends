import Foundation
import SwiftData
import Testing
import XCTest
@testable import LooseEnds

/// Fake model (ADR-11): returns a fixed draft, or fails, and counts calls. For the cases only a real
/// model shows otherwise (#530): an answer per note (`respond`), and a call that takes its time
/// (`delay`, per note through `delayFor`), honouring cancellation like the real session.
final class StubEnricher: TaskEnricher, @unchecked Sendable {
    var draft: EnrichmentDraft
    var failure: Error?
    var unavailableReason: String?
    var delay: Duration?
    var delayFor: (@Sendable (EnrichmentInput) -> Duration?)?
    var respond: (@Sendable (EnrichmentInput) throws -> EnrichmentDraft)?
    private(set) var calls = 0
    private(set) var notes: [String] = []

    init(draft: EnrichmentDraft = EnrichmentDraft(), failure: Error? = nil, unavailableReason: String? = nil) {
        self.draft = draft
        self.failure = failure
        self.unavailableReason = unavailableReason
    }

    func enrich(_ input: EnrichmentInput) async throws -> EnrichmentDraft {
        calls += 1
        notes.append(input.rawText)
        if let wait = delayFor?(input) ?? delay {
            try await Task.sleep(for: wait)
        }
        if let failure { throw failure }
        if let respond { return try respond(input) }
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

        #expect(written == 3, "contexts are never the model's (#215)")
        #expect(task.title == "Rasenmäher: Ölwechsel")
        #expect(task.titleSourceRaw == "ai")
        #expect(task.titleConfidence == 0.9)
        #expect(task.status == .active)
        #expect(task.dueDate == saturday)
        #expect(task.dueHasTime == false)
        #expect(task.importance == nil, "die Regel setzt Wichtigkeit, nicht mehr der Modell-Draft (#117, AC-7)")
        #expect(task.urgency == nil, "die Regel setzt Dringlichkeit, nicht mehr der Modell-Draft (#117, AC-7)")
        #expect(task.duration == .minutes15)
        #expect((task.contexts ?? []).isEmpty, "the model's contexts are not written (#215)")
        #expect(task.processedAt == now)

        let revisions = try #require(task.revisions)
        #expect(revisions.count == 3)
        let allFromAI = revisions.allSatisfy { $0.author == .ai && $0.seenAt == nil && !($0.reason ?? "").isEmpty }
        #expect(allFromAI, "every revision is unseen, by the AI, with a reason")
        #expect(Set(revisions.map(\.field)) == [.title, .dueDate, .duration])
        #expect(task.hasUnseenAutomaticRevisions)
        #expect(task.displayTitle == "Rasenmäher: Ölwechsel")

        let all = try context.fetch(FetchDescriptor<TaskItem>())
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

    @Test("The model's project is never written (#469)")
    @MainActor func modelProjectIsIgnored() async throws {
        let store = try TestStore()
        let context = store.context
        let house = Project(name: "Haus")
        context.insert(house)
        let task = TaskItem(rawText: "Dachrinne reinigen")
        context.insert(task)
        var draft = EnrichmentDraft()
        draft.project = EnrichmentDraft.Guess("Haus", confidence: 0.9, reason: "House upkeep.")

        EnrichmentWriter.apply(draft, to: task, contexts: [], projects: [house])
        try context.save()
        #expect(task.project == nil)
        #expect(!(task.revisions ?? []).contains { $0.field == .project })
    }
}

@Suite("EnrichmentCoordinator") struct EnrichmentCoordinatorTests {
    @Test("Every unprocessed task gets the rule step once; a second pass touches nothing (#982)")
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
        let coordinator = EnrichmentCoordinator(container: container)

        await coordinator.processPending()
        let firstMarker = try #require(first.rulesAppliedAt)
        #expect(second.rulesAppliedAt != nil)
        #expect(first.processedAt == nil && second.processedAt == nil, "no model, no model marker")
        #expect(done.rulesAppliedAt == nil, "only unprocessed tasks run")

        await coordinator.processPending()
        #expect(first.rulesAppliedAt == firstMarker, "once means once")
    }

    @Test("An active task seen before its rule step still gets its one run (#318)")
    @MainActor func confirmedBeforeEnrichmentStillRuns() async throws {
        let store = try TestStore()
        let context = store.context
        let container = store.container
        let task = TaskItem(rawText: "Zettel sortieren morgen")
        task.title = "Zettel sortieren"
        let sub = TaskItem(rawText: "Erster Stapel")
        sub.status = .active
        sub.parent = task
        context.insert(task)
        context.insert(sub)
        try context.save()
        _ = RevisionService.markSeen(task)
        task.status = .active
        let coordinator = EnrichmentCoordinator(container: container)

        await coordinator.processPending()
        let marker = try #require(task.rulesAppliedAt, "the confirmed task runs once")
        #expect(task.dueDate != nil, "its rules ran")
        #expect(task.status == .active)

        await coordinator.processPending()
        #expect(task.rulesAppliedAt == marker, "once means once")
        #expect((task.revisions ?? []).filter { $0.field == .dueDate }.count == 1)
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

    /// Der Regelschritt schreibt das Datum (#95, AC-7); seit #982 gibt es nur ihn.
    @Test("Die Regel schreibt das Datum")
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
        let coordinator = EnrichmentCoordinator(container: container)

        await coordinator.processPending()

        let due = try #require(task.dueDate, "die Regel muss ein Datum liefern")
        #expect(Calendar.current.dateComponents([.year, .month, .day], from: due)
                == DateComponents(year: 2026, month: 3, day: 20))
        #expect(task.dueHasTime == false)
        #expect(task.dueSourceRaw == FieldSource.rule.rawValue, "aus deinen Worten, nicht geraten (#101)")
        #expect(task.dueConfidence == 1.0)
        let dueRevisions = (task.revisions ?? []).filter { $0.field == .dueDate }
        #expect(dueRevisions.count == 1)
        #expect(dueRevisions.first?.author == .rule)
        #expect(dueRevisions.first?.reason?.isEmpty == false)
        #expect(task.processedAt == nil, "kein Modell, kein Modellvermerk (#982)")
    }

    /// Beim Nachhol-Durchgang darf die Regel keine zweite Revision auf dasselbe Feld legen (#95, AC-8);
    /// seit #982 nimmt der Durchgang eine Aufgabe mit Regelvermerk gar nicht erst wieder.
    @Test("Der Nachhol-Durchgang verdoppelt die Regel-Revision nicht")
    @MainActor func catchUpPassDoesNotDuplicateRuleRevision() async throws {
        let store = try TestStore()
        let context = store.context
        let container = store.container
        let task = TaskItem(rawText: "Nächsten Freitag die Miete überweisen")
        task.capturedAt = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 12)))
        context.insert(task)
        try context.save()
        let coordinator = EnrichmentCoordinator(container: container)

        await coordinator.processPending()
        let dueAfterRule = try #require(task.dueDate)

        await coordinator.processPending()

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
        let coordinator = EnrichmentCoordinator(container: container)

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
        let coordinator = EnrichmentCoordinator(container: container)

        await coordinator.processPending()
        let importanceAfterRule = task.importance
        let urgencyAfterRule = task.urgency

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
    /// A suite of its own per test, so no test reads or writes the real defaults.
    private func scratchDefaults() throws -> UserDefaults {
        let name = "ContextSeederTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("An empty store gets the default contexts; a store with contexts gets none")
    @MainActor func seedsEmptyStoreOnly() async throws {
        let store = try TestStore()
        let defaults = try scratchDefaults()

        let created = try ContextSeeder.seedIfNeeded(in: store.context, defaults: defaults)
        #expect(created.count == 6)
        // `allSatisfy` rethrows; inside `#expect` the macro cannot see that the key path never throws.
        let allDefaults = created.allSatisfy(\.isSystemDefault)
        #expect(allDefaults)

        let again = try ContextSeeder.seedIfNeeded(in: store.context, defaults: defaults)
        #expect(again.isEmpty, "contexts are there, nothing to seed")
        #expect(try store.context.fetchCount(FetchDescriptor<TaskContext>()) == 6)
    }

    @Test("A lost store is seeded again even though this device seeded before (#146)")
    @MainActor func lostStoreIsSeededAgain() async throws {
        let defaults = try scratchDefaults()
        // The marker of the old seeder, as a device that ran an earlier version carries it.
        defaults.set(true, forKey: "contextsSeeded")
        let first = try TestStore()
        try ContextSeeder.seedIfNeeded(in: first.context, defaults: defaults)

        // A fresh store with the same defaults: restored backup, rebuilt store, `--ui-testing`.
        let rebuilt = try TestStore()
        let created = try ContextSeeder.seedIfNeeded(in: rebuilt.context, defaults: defaults)

        #expect(created.count == 6)
        #expect(try rebuilt.context.fetchCount(FetchDescriptor<TaskContext>()) == 6)
    }

    @Test("Deleting one context never brings the defaults back")
    @MainActor func deletingOneKeepsItGone() async throws {
        let store = try TestStore()
        let defaults = try scratchDefaults()
        let created = try ContextSeeder.seedIfNeeded(in: store.context, defaults: defaults)
        let garden = try #require(created.first)

        CatalogService.delete(garden, in: store.context, among: created, defaults: defaults)
        try store.context.save()
        let again = try ContextSeeder.seedIfNeeded(in: store.context, defaults: defaults)

        #expect(again.isEmpty)
        #expect(try store.context.fetchCount(FetchDescriptor<TaskContext>()) == 5)
    }

    @Test("A catalog the user emptied stays empty; adding one context lifts that again (#146)")
    @MainActor func emptiedByUserStaysEmpty() async throws {
        let store = try TestStore()
        let defaults = try scratchDefaults()
        var remaining = try ContextSeeder.seedIfNeeded(in: store.context, defaults: defaults)
        while let item = remaining.first {
            CatalogService.delete(item, in: store.context, among: remaining, defaults: defaults)
            remaining.removeFirst()
        }
        try store.context.save()

        let afterEmptying = try ContextSeeder.seedIfNeeded(in: store.context, defaults: defaults)
        #expect(afterEmptying.isEmpty, "a deliberately emptied catalog is not refilled")
        #expect(try store.context.fetchCount(FetchDescriptor<TaskContext>()) == 0)

        let own = try CatalogService.addContext(named: "Werkstatt", in: store.context, existing: [], defaults: defaults)
        try store.context.save()
        #expect(!defaults.bool(forKey: ContextSeeder.emptiedByUserKey))
        CatalogService.delete(own, in: store.context, among: [own], defaults: defaults)
        try store.context.save()
        #expect(defaults.bool(forKey: ContextSeeder.emptiedByUserKey), "emptied again by the user")
    }
}

/// Wiedererkennung bekannter Rohtexte (#136, Folge der B1-Entscheidung vom 2026-09-27): Wird eine
/// Aufgabe wortgleich erneut erfasst, übernimmt sie Kontexte und Dauer der früheren — still, mit
/// Konfidenz 1.0, KI-Marker und je einer `Revision`. Energie ausdrücklich nicht: Nachbarn schlagen
/// dort die Konstante auf keiner Lesart (#112).
///
/// „Wortgleich" heißt: gleiche normalisierte Wortmenge. Groß-/Kleinschreibung, Satzzeichen und
/// Wortstellung sind egal, ein anderes Wort nicht — auf dem Korpus gemessen 100 % exakt auf beiden
/// Feldern, gegen 100 %/97,2 % bei der ursprünglich vorgesehenen Ähnlichkeitsschwelle 0,34.
@Suite("Wiedererkennung im Coordinator (#136)")
struct RecognitionCoordinatorTests {

    /// Baut eine bereits veredelte Aufgabe: `processedAt` gesetzt, also nie wieder im Pending-Fetch,
    /// und genau deshalb als Vergleichsmenge zulässig (die Regel kann sich nicht selbst füttern).
    @MainActor
    private func makeProcessed(
        _ rawText: String,
        duration: DurationBucket?,
        durationSource: FieldSource = .user,
        contexts: [TaskContext] = [],
        contextsSource: FieldSource = .user,
        in context: ModelContext
    ) -> TaskItem {
        let task = TaskItem(rawText: rawText)
        task.status = .active
        task.processedAt = Date(timeIntervalSince1970: 1_700_000_000)
        if let duration {
            task.duration = duration
            task.durationSourceRaw = durationSource.rawValue
            task.durationConfidence = 1.0
        }
        if !contexts.isEmpty {
            task.contexts = contexts
            task.contextsSourceRaw = contextsSource.rawValue
            task.contextsConfidence = 1.0
        }
        context.insert(task)
        return task
    }


    @Test("Wortgleiche Wiedererfassung übernimmt Dauer und Kontexte der früheren Aufgabe (AC-1)")
    @MainActor func adoptsDurationAndContextsFromIdenticalRawText() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        context.insert(garden)
        _ = makeProcessed("Rasen mähen", duration: .minutes30, contexts: [garden], in: context)
        let fresh = TaskItem(rawText: "Rasen mähen")
        context.insert(fresh)
        try context.save()

        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()

        #expect(fresh.duration == .minutes30)
        #expect(fresh.durationSourceRaw == FieldSource.rule.rawValue)
        #expect(fresh.durationConfidence == 1.0)
        #expect((fresh.contexts ?? []).map(\.name) == ["Garten"])
        #expect(fresh.contextsSourceRaw == FieldSource.rule.rawValue)
        #expect(fresh.contextsConfidence == 1.0)

        let revisions = fresh.revisions ?? []
        let durationRevision = try #require(revisions.first { $0.field == .duration })
        #expect(durationRevision.author == .rule)
        #expect(durationRevision.newValue == DurationBucket.minutes30.rawValue)
        #expect(!(durationRevision.reason ?? "").isEmpty)
        let contextsRevision = try #require(revisions.first { $0.field == .contexts })
        #expect(contextsRevision.author == .rule)
        #expect(contextsRevision.newValue == EnrichmentWriter.encode(["Garten"]))
    }

    @Test("Groß-/Kleinschreibung, Satzzeichen und Wortstellung verhindern die Wiedererkennung nicht (AC-3)")
    @MainActor func normalisationDoesNotBlockRecognition() async throws {
        let store = try TestStore()
        let context = store.context
        _ = makeProcessed("LinkedIn Nachrichten beantworten.", duration: .minutes15, in: context)
        let fresh = TaskItem(rawText: "nachrichten  linkedin beantworten")
        context.insert(fresh)
        try context.save()

        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()

        #expect(fresh.duration == .minutes15)
    }

    /// Der Negativtest gegen den Vier-Zeichen-Filter aus der Messung: „Tee" und „Bad" fielen dort
    /// heraus, beide Texte wären zu `{holen}` verschmolzen. Ein falsch gesetzter Kontext ist für den
    /// Nutzer unsichtbar, deshalb entscheidet die Regel hier zugunsten der Strenge.
    @Test("Ein anderes Wort verhindert die Übernahme (AC-2, AC-4)")
    @MainActor func differentWordBlocksAdoption() async throws {
        let store = try TestStore()
        let context = store.context
        _ = makeProcessed("Bad holen", duration: .minutes30, in: context)
        _ = makeProcessed("60 Minuten Sport", duration: .hour1, in: context)
        let tea = TaskItem(rawText: "Tee holen")
        let sport = TaskItem(rawText: "30 Minuten Sport")
        let unrelated = TaskItem(rawText: "Zettel sortieren")
        context.insert(tea)
        context.insert(sport)
        context.insert(unrelated)
        try context.save()

        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()

        #expect(tea.duration == nil, "Tee holen ist nicht Bad holen")
        #expect(sport.duration == .minutes30,
                "30 Minuten Sport nennt seine Länge selbst (Regel, #673), übernimmt aber nichts von 60 Minuten Sport")
        #expect(sport.durationSourceRaw == FieldSource.rule.rawValue)
        #expect(unrelated.duration == nil)
    }

    @Test("Energie wird nie übernommen (AC-5)")
    @MainActor func energyIsNeverAdopted() async throws {
        let store = try TestStore()
        let context = store.context
        let source = makeProcessed("Klavier spielen", duration: .hour1, in: context)
        source.energy = .givesClearly
        source.energySourceRaw = FieldSource.user.rawValue
        source.energyConfidence = 1.0
        let fresh = TaskItem(rawText: "Klavier spielen")
        context.insert(fresh)
        try context.save()

        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()

        #expect(fresh.duration == .hour1, "Dauer ja")
        #expect(fresh.energyRaw == nil, "Energie nein — bleibt manuell (#112)")
        #expect(!(fresh.revisions ?? []).contains { $0.field == .energy })
    }

    /// ADR-5: „Korrekturen des Nutzers bleiben Beispiele erster Klasse." Eine Nutzerkorrektur soll
    /// sich auf künftige Wiedererfassungen fortpflanzen, nicht ein KI-Fehler.
    @Test("Ein nutzergesetzter Wert schlägt einen KI-gesetzten (AC-6)")
    @MainActor func userSetValueWinsOverAISetValue() async throws {
        let store = try TestStore()
        let context = store.context
        _ = makeProcessed("Steuer sortieren", duration: .minutes15, durationSource: .ai, in: context)
        _ = makeProcessed("Steuer sortieren", duration: .hours2plus, durationSource: .user, in: context)
        let fresh = TaskItem(rawText: "Steuer sortieren")
        context.insert(fresh)
        try context.save()

        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()

        #expect(fresh.duration == .hours2plus, "die Korrektur des Nutzers gewinnt, nicht der KI-Wert")
    }

    /// Die Vergleichsmenge besteht nur aus bereits veredelten Aufgaben. Damit kann eine Aufgabe aus
    /// demselben Nachzügler-Lauf strukturell nie Quelle für eine andere sein — ein Fehler
    /// vervielfältigt sich nicht still.
    @Test("Zwei unverarbeitete Aufgaben im selben Lauf befruchten sich nicht (AC-7)")
    @MainActor func unprocessedTasksAreNotPartOfThePool() async throws {
        let store = try TestStore()
        let context = store.context
        let first = TaskItem(rawText: "Fahrrad reparieren")
        first.duration = .hour1
        first.durationSourceRaw = FieldSource.user.rawValue
        let second = TaskItem(rawText: "Fahrrad reparieren")
        context.insert(first)
        context.insert(second)
        try context.save()

        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()

        #expect(second.duration == nil, "die erste Aufgabe war beim Lauf noch nicht veredelt")
    }

    @Test("Der Nachzügler-Lauf hängt keine zweite Revision an (AC-8)")
    @MainActor func catchUpPassAddsNoSecondRevision() async throws {
        let store = try TestStore()
        let context = store.context
        _ = makeProcessed("Fenster putzen", duration: .minutes30, in: context)
        let fresh = TaskItem(rawText: "Fenster putzen")
        context.insert(fresh)
        try context.save()

        // Erster Lauf: die Regel greift, `processedAt` bleibt leer (ADR-4, #982).
        await EnrichmentCoordinator(container: store.container).processPending()
        #expect(fresh.duration == .minutes30)
        #expect(fresh.processedAt == nil)

        // Zweiter Lauf: kein zweiter Regelschritt auf dasselbe Feld.
        await EnrichmentCoordinator(container: store.container).processPending()

        let durationRevisions = (fresh.revisions ?? []).filter { $0.field == .duration }
        #expect(durationRevisions.count == 1)
        #expect(fresh.duration == .minutes30)
    }

    /// Die Lücke, die die Analyse im heutigen Code gefunden hat: `EnrichmentWriter.apply` schreibt
    /// `duration` und `contexts` ohne `== nil`-Guard und läuft im Coordinator **nach** dem
    /// Regelschritt. Ohne diesen Test überschreibt das Modell den Regelwert still und hängt eine
    /// zweite Revision an dasselbe Feld.
    @Test("Der Modellwert überschreibt einen gesetzten Wert nicht mehr (AC-9)")
    @MainActor func modelDoesNotOverwriteAnExistingValue() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        let computer = TaskContext(name: "Computer", isSystemDefault: true, sortOrder: 0)
        context.insert(garden)
        context.insert(computer)
        let task = TaskItem(rawText: "Hecke schneiden")
        task.duration = .minutes30
        task.durationSourceRaw = FieldSource.ai.rawValue
        task.durationConfidence = 1.0
        task.contexts = [garden]
        task.contextsSourceRaw = FieldSource.ai.rawValue
        task.contextsConfidence = 1.0
        context.insert(task)
        try context.save()

        var draft = EnrichmentDraft()
        draft.duration = EnrichmentDraft.Guess(.hour1, confidence: 0.9, reason: "Modellschätzung.")
        draft.contexts = EnrichmentDraft.Guess(["Computer"], confidence: 0.9, reason: "Modellschätzung.")

        let written = EnrichmentWriter.apply(draft, to: task, contexts: [computer, garden], projects: [])
        try context.save()

        #expect(written == 0, "der Rückgabewert zählt die übersprungenen Felder nicht mit")
        #expect(task.duration == .minutes30, "der bereits gesetzte Wert bleibt stehen")
        #expect(task.durationConfidence == 1.0)
        #expect((task.contexts ?? []).map(\.name) == ["Garten"], "der bereits gesetzte Wert bleibt stehen")
        #expect((task.revisions ?? []).filter { $0.field == .duration }.isEmpty)
        #expect((task.revisions ?? []).filter { $0.field == .contexts }.isEmpty)
    }

    /// Ein vom Nutzer geleertes Feld ist am Herkunftsvermerk nicht zu erkennen: `FieldCodec` setzt
    /// beim Leeren `durationSourceRaw` auf `nil` (`FieldCodec.swift:56`) — genau der Zustand einer nie
    /// berührten Aufgabe. Nur die Nutzer-`Revision` bleibt, weil Revisionen nie gelöscht werden
    /// („Revisions, not undo"); sie ist deshalb der verlässliche Marker.
    @Test("Eine vom Nutzer zurückgesetzte Dauer wird nicht wieder gesetzt")
    @MainActor func userResetOfDurationIsNotUndone() async throws {
        let store = try TestStore()
        let context = store.context
        _ = makeProcessed("Rechnungen sortieren", duration: .minutes30, in: context)
        let fresh = TaskItem(rawText: "Rechnungen sortieren")
        context.insert(fresh)
        try context.save()

        // Erster Lauf: die Regel greift, `processedAt` bleibt leer (ADR-4, #982).
        await EnrichmentCoordinator(container: store.container).processPending()
        #expect(fresh.duration == .minutes30)
        #expect(fresh.processedAt == nil)

        // Der Nutzer setzt das Feld über eine Revision auf den Stand vor der KI zurück: leer.
        let aiRevision = try #require(RevisionService.firstAutomaticRevision(of: .duration, on: fresh))
        RevisionService.revert(aiRevision, on: fresh, contexts: [], projects: [])
        try context.save()
        #expect(fresh.duration == nil)
        #expect(fresh.durationSourceRaw == nil, "der Herkunftsvermerk fällt beim Leeren mit weg")

        await EnrichmentCoordinator(container: store.container).processPending()

        #expect(fresh.duration == nil, "der Nutzerentscheid bleibt stehen")
        let aiRevisions = (fresh.revisions ?? []).filter { $0.field == .duration && $0.author == .rule }
        #expect(aiRevisions.count == 1, "keine zweite KI-Revision auf dasselbe Feld")
    }

    /// Dasselbe für Kontexte: `FieldCodec` setzt beim Leeren `contextsSourceRaw` auf `nil`
    /// (`FieldCodec.swift:65`), und ein geleertes Relationship ist ein leeres Array wie ein nie
    /// gesetztes. Die Nutzer-`Revision` unterscheidet beide Fälle.
    @Test("Vom Nutzer entfernte Kontexte werden nicht wieder gesetzt")
    @MainActor func userResetOfContextsIsNotUndone() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        context.insert(garden)
        _ = makeProcessed("Beete jäten", duration: nil, contexts: [garden], in: context)
        let fresh = TaskItem(rawText: "Beete jäten")
        context.insert(fresh)
        try context.save()

        // Erster Lauf: die Regel greift, `processedAt` bleibt leer (ADR-4, #982).
        await EnrichmentCoordinator(container: store.container).processPending()
        #expect((fresh.contexts ?? []).map(\.name) == ["Garten"])
        #expect(fresh.processedAt == nil)

        let aiRevision = try #require(RevisionService.firstAutomaticRevision(of: .contexts, on: fresh))
        RevisionService.revert(aiRevision, on: fresh, contexts: [garden], projects: [])
        try context.save()
        #expect((fresh.contexts ?? []).isEmpty)
        #expect(fresh.contextsSourceRaw == nil, "der Herkunftsvermerk fällt beim Leeren mit weg")

        await EnrichmentCoordinator(container: store.container).processPending()

        #expect((fresh.contexts ?? []).isEmpty, "der Nutzerentscheid bleibt stehen")
        let aiRevisions = (fresh.revisions ?? []).filter { $0.field == .contexts && $0.author == .rule }
        #expect(aiRevisions.count == 1, "keine zweite KI-Revision auf dasselbe Feld")
    }
}

/// Folgebefund zu #136, ausgelöst durch Hennings Frage vom 2026-09-27, ob die modellfreien Teile
/// im Simulator geprüft werden. Alle Tests oben setzen `processedAt` per `makeProcessed` von Hand
/// und prüfen damit nur die Regel selbst — nicht, ob eine Aufgabe auf dem echten Weg je in die
/// Vergleichsmenge gelangt. Genau das steht hier zur Prüfung.
@Suite("Vergleichsmenge auf dem echten Weg (#136 Folgebefund)")
struct RecognitionPoolReachabilityTests {

    /// Der Ablauf, den jemand ohne Apple Intelligence erlebt (Simulator, nicht berechtigtes Gerät,
    /// abgeschaltete Funktion): erfassen, Werte selbst setzen, dasselbe erneut erfassen.
    /// Die Regel braucht kein Modell — also muss sie hier greifen.
    @Test("Ohne Modell übernimmt die zweite wortgleiche Erfassung die Werte der ersten")
    @MainActor func recognitionWorksWithoutTheModel() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten")
        context.insert(garden)

        // Erste Erfassung, danach der Veredelungs-Durchgang wie in der App.
        let first = TaskItem(rawText: "Rasen mähen")
        context.insert(first)
        try context.save()
        await EnrichmentCoordinator(container: store.container).processPending()

        // Der Nutzer setzt Dauer und Kontext selbst — der Normalfall, wenn kein Modell da ist.
        first.duration = .minutes30
        first.durationSourceRaw = FieldSource.user.rawValue
        first.contexts = [garden]
        first.contextsSourceRaw = FieldSource.user.rawValue
        try context.save()

        // Zweite Erfassung, wortgleich.
        let second = TaskItem(rawText: "Rasen mähen")
        context.insert(second)
        try context.save()
        await EnrichmentCoordinator(container: store.container).processPending()

        #expect(second.duration == .minutes30, "die Dauer von vorhin muss übernommen werden")
        #expect((second.contexts ?? []).map(\.name) == ["Garten"], "die Kontexte von vorhin auch")
    }

    /// Der Grund, isoliert: `processedAt` wird ausschließlich in `EnrichmentWriter.apply` gesetzt,
    /// und das läuft nur, wenn das Modell verfügbar ist. `processedAt` behält diese Bedeutung
    /// (ADR-4) — die Vergleichsmenge darf deshalb nicht daran hängen, sondern an einem eigenen
    /// Vermerk des Regelschritts (`rulesAppliedAt`, #144). Die Aussage dieses Tests ist unverändert
    /// dieselbe wie im RED-Stand: wer die Regeln durchlaufen hat, gehört in die Vergleichsmenge —
    /// nur das geprüfte Feld wechselt vom falschen auf das tatsächliche Lesekriterium.
    @Test("Ohne Modell bekommt jede Aufgabe den Regel-Vermerk (AC-2)")
    @MainActor func ruleMarkerFillsThePoolWithoutTheModel() async throws {
        let store = try TestStore()
        let context = store.context

        for index in 0..<3 {
            context.insert(TaskItem(rawText: "Aufgabe \(index)"))
        }
        try context.save()
        await EnrichmentCoordinator(container: store.container).processPending()

        let pool = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.rulesAppliedAt != nil }))
        #expect(pool.count == 3, "wer die Regeln durchlaufen hat, gehört in die Vergleichsmenge")
        let unseenByModel = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.processedAt == nil }))
        #expect(unseenByModel.count == 3, "`processedAt` behält seine Bedeutung: das Modell war nicht da")
    }

    /// Die Bestandsdaten-Lücke: Aufgaben, die vor #144 veredelt wurden — lokal oder per CloudKit von
    /// einem Gerät mit Apple Intelligence — tragen `processedAt`, aber nie `rulesAppliedAt`. Sie
    /// müssen Quelle bleiben, sonst tauscht die Änderung eine leere Vergleichsmenge gegen eine
    /// halbe. Ohne die Zusammenführung beider Vermerke schlägt dieser Test an.
    @Test("Eine vor dieser Änderung veredelte Aufgabe bleibt Quelle (AC-4)")
    @MainActor func legacyProcessedTaskStaysReachable() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten")
        context.insert(garden)

        let legacy = TaskItem(rawText: "Hecke schneiden")
        legacy.status = .active
        legacy.processedAt = Date(timeIntervalSince1970: 1_700_000_000)
        legacy.rulesAppliedAt = nil            // genau der Bestandszustand
        legacy.duration = .hour1
        legacy.durationSourceRaw = FieldSource.user.rawValue
        legacy.durationConfidence = 1.0
        legacy.contexts = [garden]
        legacy.contextsSourceRaw = FieldSource.user.rawValue
        legacy.contextsConfidence = 1.0
        context.insert(legacy)

        let fresh = TaskItem(rawText: "Hecke schneiden")
        context.insert(fresh)
        try context.save()

        await EnrichmentCoordinator(container: store.container).processPending()

        #expect(fresh.duration == .hour1, "die Bestandsaufgabe muss erreichbar bleiben")
        #expect((fresh.contexts ?? []).map(\.name) == ["Garten"])
    }

    /// Zwei Vermerke, zwei Fetches — also muss die Zusammenführung entdoppeln. Geprüft direkt an der
    /// Vergleichsmenge, nicht nur am Ergebnis: Eine Dublette im Pool bliebe am geschriebenen Wert
    /// unsichtbar, weil `applyRecognitionRule` pro Feld ohnehin nur einmal schreibt. Genau deshalb
    /// steht hier der Pool selbst zur Prüfung.
    @Test("Eine Aufgabe mit beiden Vermerken steht genau einmal in der Vergleichsmenge (AC-5)")
    @MainActor func aTaskWithBothMarkersAppearsOnceInThePool() async throws {
        let store = try TestStore()
        let context = store.context
        let both = TaskItem(rawText: "Steuer sortieren")
        both.status = .active
        both.processedAt = Date(timeIntervalSince1970: 1_700_000_000)
        both.rulesAppliedAt = Date(timeIntervalSince1970: 1_700_000_100)
        both.duration = .hours2plus
        both.durationSourceRaw = FieldSource.user.rawValue
        both.durationConfidence = 1.0
        context.insert(both)
        try context.save()

        let inputs = try EnrichmentCoordinator.recognitionInputs(in: context)

        #expect(inputs.pool.filter { $0.id == both.id }.count == 1, "beide Vermerke, ein Eintrag")
        #expect(inputs.pool.count == 1)
        #expect(inputs.tasksByID.count == 1)

        // Und keine doppelte Revision auf einer wortgleichen dritten Aufgabe.
        let fresh = TaskItem(rawText: "Steuer sortieren")
        context.insert(fresh)
        try context.save()
        await EnrichmentCoordinator(container: store.container).processPending()

        #expect(fresh.duration == .hours2plus)
        #expect((fresh.revisions ?? []).filter { $0.field == .duration }.count == 1)
    }

    /// AC-8 aus #136 und #95 unter der neuen Lesart: Ab dem zweiten Durchgang steht eine Aufgabe mit
    /// Regel-Vermerk selbst in der Vergleichsmenge — auch in der eigenen. Ein Selbsttreffer darf
    /// nichts bewirken, die Guards `Feld == nil` müssen tragen.
    @Test("Mehrere Regelläufe ohne Modell legen keine zweite Revision an (AC-7)")
    @MainActor func repeatedRulePassesAddNoSecondRevision() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten")
        context.insert(garden)

        let source = TaskItem(rawText: "Fenster putzen")
        source.status = .active
        source.processedAt = Date(timeIntervalSince1970: 1_700_000_000)
        source.duration = .minutes30
        source.durationSourceRaw = FieldSource.user.rawValue
        source.durationConfidence = 1.0
        source.contexts = [garden]
        source.contextsSourceRaw = FieldSource.user.rawValue
        source.contextsConfidence = 1.0
        context.insert(source)

        let fresh = TaskItem(rawText: "Fenster putzen")
        context.insert(fresh)
        try context.save()

        for _ in 0..<3 {
            await EnrichmentCoordinator(container: store.container).processPending()
        }

        #expect(fresh.duration == .minutes30)
        #expect((fresh.contexts ?? []).map(\.name) == ["Garten"])
        #expect((fresh.revisions ?? []).filter { $0.field == .duration }.count == 1,
                "drei Durchgänge, eine Revision")
        #expect((fresh.revisions ?? []).filter { $0.field == .contexts }.count == 1,
                "drei Durchgänge, eine Revision")
    }
}

/// #932 Schnitt 1: a title the user (or Claude, as a user revision) set before the first run stays; the model writes its title
/// only where no user revision hangs. And the chain: what Claude set at capture survives the rules and "Analyze again".
@MainActor final class EnrichmentTitleProtectionTests: XCTestCase {
    private static let fields: [RevisedField] = [
        .title, .notes, .dueDate, .importance, .urgency, .duration, .energy, .contexts, .project,
    ]

    private func modelTitle(_ title: String) -> EnrichmentDraft {
        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess(title, confidence: 0.9, reason: "The note names the job.")
        return draft
    }

    // MARK: AC-9

    func testModelTitleKeepsAUserTitleAndWritesWhereNoneHangs() throws {
        let store = try TestStore()
        let touched = TaskItem(rawText: "Rasenmäher Ölwechsel machen")
        touched.title = "Ölwechsel"
        touched.titleSourceRaw = FieldSource.user.rawValue
        touched.revisions = [Revision(task: touched, field: .title, oldValue: nil, newValue: "Ölwechsel", author: .user,
                                      reason: OrderExecutor.reason)]
        let untouched = TaskItem(rawText: "Rasenmäher Ölwechsel machen")
        store.context.insert(touched)
        store.context.insert(untouched)
        try store.context.save()

        EnrichmentWriter.apply(modelTitle("Rasenmäher: Ölwechsel"), to: touched, contexts: [], projects: [])
        EnrichmentWriter.apply(modelTitle("Rasenmäher: Ölwechsel"), to: untouched, contexts: [], projects: [])

        XCTAssertEqual(touched.title, "Ölwechsel", "the user's title stays")
        XCTAssertEqual(touched.revisions?.count, 1, "no AI revision on top")
        XCTAssertEqual(untouched.title, "Rasenmäher: Ölwechsel", "without a user revision the model writes as before")
        XCTAssertEqual(untouched.titleSourceRaw, FieldSource.ai.rawValue)
    }

    // MARK: AC-10

    func testClaudesFieldsSurviveRulesAndReanalysis() async throws {
        let store = try TestStore()
        for (index, name) in ["Garten", "Büro"].enumerated() { store.context.insert(TaskContext(name: name, sortOrder: index)) }
        for (index, name) in ["Haus", "Arbeit"].enumerated() { store.context.insert(Project(name: name, sortOrder: index)) }
        try store.context.save()
        let json: [String: Any] = [
            "version": 1, "id": UUID().uuidString, "kind": "capture",
            "text": "Hecke schneiden morgen wichtig dringend 20 Minuten Garten Haus",
            "fields": [
                "title": "Hecke beim Nachbarn schneiden", "notes": "Leiter mitnehmen",
                "dueDate": OrderExecutorTests.day(6, hour: 8).ISO8601Format(), "dueHasTime": true,
                "importance": "low", "urgency": "low", "duration": "hour1", "energy": 1,
                "contexts": ["Büro"], "project": "Arbeit",
            ] as [String: Any],
        ]
        let order = try TranscriptCodec.decode(Order.self, from: JSONSerialization.data(withJSONObject: json))
        let result = try OrderExecutorTests.run(order, in: store)
        let task = try XCTUnwrap(try store.context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == result.taskID })
        let claude = Dictionary(uniqueKeysWithValues: Self.fields.map { ($0, FieldCodec.encode($0, of: task)) })
        XCTAssertEqual(claude[.title] ?? nil, "Hecke beim Nachbarn schneiden")
        XCTAssertEqual(claude[.project] ?? nil, "Arbeit")

        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()
        XCTAssertNotNil(task.rulesAppliedAt, "the rules ran")
        _ = await coordinator.reanalyze(task)

        for field in Self.fields {
            XCTAssertEqual(FieldCodec.encode(field, of: task), claude[field] ?? nil, "\(field) stays Claude's")
            let automatic = (task.revisions ?? []).filter { $0.field == field && $0.author != .user }
            XCTAssertTrue(automatic.isEmpty, "\(field): no automatic revision")
        }
    }
}
