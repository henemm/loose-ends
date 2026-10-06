import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Siri's link, flag and tags on a new task (#225, precondition for #25). `resolve` checks before
/// anything is saved, `apply` writes on the saved task; the caller saves.
@Suite("Siri-Angaben (#225)")
@MainActor
struct SiriFieldsTests {
    private let linkA = URL(string: "https://example.com/a")!
    private let linkB = URL(string: "https://example.com/b")!

    private func revisions(of field: RevisedField, on task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.field == field }
    }

    /// Resolves and applies on a freshly captured task, the order #25 uses.
    private func capture(_ fields: SiriFields, in context: ModelContext, text: String = "Rasen mähen") throws -> TaskItem {
        let resolved = try SiriFields.resolve(fields, in: context)
        let task = try CaptureService.save(text, via: .siri, in: context)
        SiriFields.apply(resolved, to: task)
        try context.save()
        return task
    }

    // MARK: Link

    @Test("Ein Link wird zur Quelle, ohne Revision (AC-1)")
    func singleLinkBecomesSourceURL() throws {
        let store = try TestStore()
        let task = try capture(SiriFields(urls: [linkA], isFlagged: nil, tags: []), in: store.context)
        #expect(task.sourceURL == linkA)
        #expect((task.revisions ?? []).isEmpty, "the link is source material, like sharing")
    }

    @Test("Derselbe Link zweimal zählt einmal (AC-2)")
    func duplicateLinksCountOnce() throws {
        let store = try TestStore()
        let resolved = try SiriFields.resolve(SiriFields(urls: [linkA, linkA], isFlagged: nil, tags: []), in: store.context)
        #expect(resolved.url == linkA)
    }

    @Test("Mehrere verschiedene Links werden abgelehnt, bevor etwas geschrieben wird (AC-2, AC-11)")
    func multipleLinksAreRejectedBeforeAnythingIsWritten() throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()
        let fields = SiriFields(urls: [linkA, linkB, linkA], isFlagged: true, tags: ["Garten"])
        #expect(throws: SiriFieldsError.multipleLinks(2)) { try SiriFields.resolve(fields, in: store.context) }
        #expect(!store.context.hasChanges)
        #expect(try store.context.fetch(FetchDescriptor<TaskItem>()).isEmpty)
    }

    @Test("Ohne Link bleibt die Quelle leer (AC-3)")
    func noLinksSetsNothing() throws {
        let store = try TestStore()
        let task = try capture(SiriFields(urls: [], isFlagged: nil, tags: []), in: store.context)
        #expect(task.sourceURL == nil)
    }

    // MARK: Markierung

    @Test("Markierung setzt Wichtigkeit hoch als Nutzerangabe (AC-4)")
    func flaggedSetsHighImportanceAsUser() throws {
        let store = try TestStore()
        let task = try capture(SiriFields(urls: [], isFlagged: true, tags: []), in: store.context)
        #expect(task.importance == .high)
        #expect(task.importanceSourceRaw == FieldSource.user.rawValue)
        #expect(task.importanceConfidence == nil)
        let revision = try #require(revisions(of: .importance, on: task).only)
        #expect(revision.oldValue == nil)
        #expect(revision.newValue == Importance.high.rawValue)
        #expect(revision.author == .user)
        #expect(revision.reason == "Siri")
        #expect(revision.seenAt != nil)
    }

    @Test("Die Revision trägt die vorherige Wichtigkeit (AC-4)")
    func flaggedRevisionKeepsPreviousValue() throws {
        let store = try TestStore()
        let resolved = try SiriFields.resolve(SiriFields(urls: [], isFlagged: true, tags: []), in: store.context)
        let task = try CaptureService.save("Zettel sortieren", via: .siri, in: store.context)
        task.importance = .medium
        SiriFields.apply(resolved, to: task)
        #expect(revisions(of: .importance, on: task).only?.oldValue == Importance.medium.rawValue)
    }

    @Test("Nicht markiert setzt nichts (AC-5, #220)", arguments: [false, nil] as [Bool?])
    func notFlaggedWritesNothing(flag: Bool?) throws {
        let store = try TestStore()
        let task = try capture(SiriFields(urls: [], isFlagged: flag, tags: []), in: store.context)
        #expect(task.importance == nil)
        #expect(revisions(of: .importance, on: task).isEmpty)
    }

    // MARK: Tags

    @Test("Tags treffen Kontexte ohne Rücksicht auf Groß/Klein, Akzente und Leerraum (AC-6)")
    func tagsMatchIgnoringCaseAndAccents() throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten", sortOrder: 0))
        store.context.insert(TaskContext(name: "Büro", sortOrder: 1))
        try store.context.save()
        let task = try capture(SiriFields(urls: [], isFlagged: nil, tags: ["garten ", "BURO"]), in: store.context)
        // A to-many relationship has no order in SwiftData; the revision carries the deterministic one.
        #expect(Set((task.contexts ?? []).map(\.name)) == ["Garten", "Büro"])
        #expect((task.contexts ?? []).count == 2)
        #expect(revisions(of: .contexts, on: task).only?.newValue == EnrichmentWriter.encode(["Garten", "Büro"]))
    }

    @Test("Tags werden als Nutzerangabe mit Revision geschrieben (AC-6)")
    func tagsAreWrittenAsUserWithRevision() throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()
        let task = try capture(SiriFields(urls: [], isFlagged: nil, tags: ["Garten"]), in: store.context)
        #expect(task.contextsSourceRaw == FieldSource.user.rawValue)
        #expect(task.contextsConfidence == nil)
        let revision = try #require(revisions(of: .contexts, on: task).only)
        #expect(revision.oldValue == nil)
        #expect(revision.author == .user)
        #expect(revision.reason == "Siri")
        #expect(revision.seenAt != nil)
    }

    @Test("Ein unbekanntes Tag lehnt alles ab und nennt seinen Namen (AC-7, AC-11)")
    func unknownTagIsRejectedWithItsName() throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()
        let fields = SiriFields(urls: [linkA], isFlagged: true, tags: ["Garten", "Bürro"])
        #expect(throws: SiriFieldsError.unknownTag("Bürro")) { try SiriFields.resolve(fields, in: store.context) }
        #expect(!store.context.hasChanges)
        #expect(try store.context.fetch(FetchDescriptor<TaskItem>()).isEmpty)
    }

    @Test("Zwei Tags, die gleich falten, ergeben einen Kontext (AC-8)")
    func tagsFoldingToTheSameContextGiveOne() throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()
        let task = try capture(SiriFields(urls: [], isFlagged: nil, tags: ["garten", "GARTEN"]), in: store.context)
        #expect((task.contexts ?? []).count == 1)
    }

    @Test("Bei Dubletten gilt der Überlebende der Zusammenführung (AC-8, #157)")
    func duplicateContextsPickTheSurvivor() throws {
        let store = try TestStore()
        let other = TaskContext(name: "Garten", isSystemDefault: false, sortOrder: 0)
        let survivor = TaskContext(name: "garten", isSystemDefault: true, sortOrder: 5)
        store.context.insert(other)
        store.context.insert(survivor)
        try store.context.save()
        let resolved = try SiriFields.resolve(SiriFields(urls: [], isFlagged: nil, tags: ["Garten"]), in: store.context)
        #expect(resolved.contexts.map(\.id) == [survivor.id])
    }

    @Test("Ohne Tags bleiben die Kontexte leer, keine Revision (AC-9)")
    func emptyTagsSetNothing() throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()
        let task = try capture(SiriFields(urls: [], isFlagged: nil, tags: []), in: store.context)
        #expect((task.contexts ?? []).isEmpty)
        #expect(revisions(of: .contexts, on: task).isEmpty)
    }

    // MARK: Schutz vor Überschreiben

    /// An earlier task with the same raw text and another context: the recognition would take its
    /// context over wherever the field is not the user's.
    private func earlierTask(_ rawText: String, context taskContext: TaskContext, in context: ModelContext) {
        let task = TaskItem(rawText: rawText)
        task.status = .active
        task.processedAt = Date(timeIntervalSince1970: 1_700_000_000)
        task.contexts = [taskContext]
        task.contextsSourceRaw = FieldSource.user.rawValue
        context.insert(task)
    }

    @Test("„Neu analysieren“ lässt Siri-Markierung und -Tags stehen (AC-10)")
    func siriValuesSurviveReanalysis() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten", sortOrder: 0)
        let office = TaskContext(name: "Büro", sortOrder: 1)
        store.context.insert(garden)
        store.context.insert(office)
        earlierTask("Rasen mähen", context: office, in: store.context)
        try store.context.save()
        let task = try capture(SiriFields(urls: [], isFlagged: true, tags: ["Garten"]), in: store.context)
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(), container: store.container)
        await coordinator.processPending()

        _ = await coordinator.reanalyze(task)

        #expect(task.importance == .high)
        #expect((task.contexts ?? []).map(\.name) == ["Garten"], "a user value is never re-analysed away")
    }

    @Test("Der erste Durchlauf nach dem Erfassen lässt Siri-Markierung und -Tags stehen (AC-10)")
    func siriValuesSurviveFirstPass() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten", sortOrder: 0)
        let office = TaskContext(name: "Büro", sortOrder: 1)
        store.context.insert(garden)
        store.context.insert(office)
        earlierTask("Rasen mähen", context: office, in: store.context)
        try store.context.save()
        let task = try capture(SiriFields(urls: [], isFlagged: true, tags: ["Garten"]), in: store.context)
        var draft = EnrichmentDraft()
        draft.importance = EnrichmentDraft.Guess(.low, confidence: 0.9, reason: "Stub.")
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(draft: draft), container: store.container)

        await coordinator.processPending()

        #expect(task.importance == .high)
        #expect((task.contexts ?? []).map(\.name) == ["Garten"])
    }

    // MARK: Kette

    @Test("Prüfen, Speichern, Anwenden: die Aufgabe trägt alle drei Angaben nach dem Neuladen")
    func fullPathResolveSaveApply() throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()
        let id = try capture(SiriFields(urls: [linkA], isFlagged: true, tags: ["garten"]), in: store.context).id

        let reloaded = try #require(try store.context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == id })
        #expect(reloaded.sourceURL == linkA)
        #expect(reloaded.importance == .high)
        #expect((reloaded.contexts ?? []).map(\.name) == ["Garten"])
        #expect(reloaded.capturedVia == .siri)
    }
}

private extension Array {
    /// The single element, or nil when there are none or several.
    var only: Element? { count == 1 ? first : nil }
}
