import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Gelernte Wörter sichtbar und löschbar (#233 Schnitt 2b): Die Zeile „Erkennt: …“ zeigt die Wörter in
/// der Schreibweise des Nutzers; ein gestrichenes Wort verschwindet sofort und wird für dieses Etikett
/// nie wieder gelernt, für ein anderes Etikett wirkt der Strich nicht (AC-4, AC-9).
@Suite("Gelernte Wörter: Anzeige und Vergessen (#233 Schnitt 2b)")
struct ContextWordForgettingTests {
    @MainActor
    private func makeTagged(_ rawText: String, _ contexts: [TaskContext], in context: ModelContext) {
        let task = TaskItem(rawText: rawText)
        task.status = .active
        task.rulesAppliedAt = Date(timeIntervalSince1970: 1_700_000_000)
        task.contexts = contexts
        task.contextsSourceRaw = FieldSource.user.rawValue
        context.insert(task)
    }

    @Test("Vergessen speichert das Wort normalisiert, einmal, und überlebt einen Neustart des Stores")
    @MainActor func forgetStoresNormalized() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten", sortOrder: 3)
        store.context.insert(garden)
        CatalogService.forget("  Brücke ", on: garden)
        CatalogService.forget("brucke", on: garden)
        CatalogService.forget("", on: garden)
        try store.context.save()

        #expect(garden.forgottenWords == ["brucke"])
        #expect(garden.forgottenWordsRaw == "brucke")
        let fetched = try store.context.fetch(FetchDescriptor<TaskContext>())
        #expect(fetched.first?.forgottenWords == ["brucke"])
    }

    @Test("Die Zeile zeigt die Wörter wie geschrieben; ein gestrichenes fehlt sofort (AC-9)")
    @MainActor func recognizedWordsAreSpelledAndStruck() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", sortOrder: 3)
        let home = TaskContext(name: "Haus", sortOrder: 2)
        context.insert(garden)
        context.insert(home)
        makeTagged("Brücke streichen", [garden], in: context)
        makeTagged("Kirschbaum gießen", [garden], in: context)
        try context.save()
        let tasks = try context.fetch(FetchDescriptor<TaskItem>())

        let before = EnrichmentCoordinator.recognizedWords(in: tasks, catalog: [home, garden])
        #expect(before["Garten"] == ["Brücke", "gießen", "Kirschbaum", "streichen"])
        #expect(before["Haus"] == nil)

        CatalogService.forget("Brücke", on: garden)
        CatalogService.forget("gießen", on: home)   // ein Strich bei Haus wirkt nicht auf Garten
        let after = EnrichmentCoordinator.recognizedWords(in: tasks, catalog: [home, garden])
        #expect(after["Garten"] == ["gießen", "Kirschbaum", "streichen"])
    }

    @Test("Ein gestrichenes Wort setzt das Etikett nicht mehr (AC-4)")
    @MainActor func struckWordNoLongerSetsContext() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        context.insert(garden)
        makeTagged("Kirschbaum schneiden", [garden], in: context)
        CatalogService.forget("Kirschbaum", on: garden)
        let fresh = TaskItem(rawText: "Kirschbaum gießen")
        context.insert(fresh)
        try context.save()

        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess("Titel", confidence: 0.9, reason: "Stub.")
        await EnrichmentCoordinator(enricher: StubEnricher(draft: draft), container: store.container).processPending()

        #expect((fresh.contexts ?? []).isEmpty)
        #expect(!(fresh.revisions ?? []).contains { $0.field == .contexts })
    }
}
