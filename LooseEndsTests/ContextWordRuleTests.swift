import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Kontexte aus Wörtern der Notiz (#232, Folge aus #215): Das Modell setzt keine Kontexte mehr; eine
/// knappe Wortliste je Standardkontext tut es, und jeder Kontext trifft mit seinem eigenen Namen.
/// Kein Treffer bleibt leer — kein Standardwert (Henning: leer statt geraten).
@Suite("Regelschritt: Kontexte aus der Wortliste")
struct ContextWordRuleTests {
    private let germanCatalog = ["Computer", "Telefon", "Haus", "Garten", "Besorgung", "Unterwegs"]
    private let englishCatalog = ["Computer", "Phone", "Home", "Garden", "Errands", "Out and about"]

    private func names(_ text: String, _ catalog: [String]) -> [String]? {
        ContextWordRule.match(in: text, available: catalog)?.value
    }

    @Test("Je Startkontext ein deutscher Treffer")
    func germanHitPerDefaultContext() {
        #expect(names("Drucker im Büro einrichten", germanCatalog) == ["Computer"])
        #expect(names("Mama anrufen", germanCatalog) == ["Telefon"])
        #expect(names("Fenster putzen", germanCatalog) == ["Haus"])
        #expect(names("Hecke schneiden", germanCatalog) == ["Garten"])
        #expect(names("Milch kaufen", germanCatalog) == ["Besorgung"])
        #expect(names("Auf dem Heimweg tanken", germanCatalog) == ["Unterwegs"])
    }

    @Test("Je Startkontext ein englischer Treffer")
    func englishHitPerDefaultContext() {
        #expect(names("Install the new software", englishCatalog) == ["Computer"])
        #expect(names("Call the dentist", englishCatalog) == ["Phone"])
        #expect(names("Do the laundry", englishCatalog) == ["Home"])
        #expect(names("Mow the lawn", englishCatalog) == ["Garden"])
        #expect(names("Pick up the parcel", englishCatalog) == ["Errands"])
        #expect(names("Stop at the gas station", englishCatalog) == ["Out and about"])
    }

    @Test("Der Gerätetest aus #215 bleibt leer")
    func taxLetterStaysEmpty() {
        #expect(names("Morgen wichtig Steuerbescheid prüfen", germanCatalog) == nil)
        #expect(names("Zettel sortieren", germanCatalog) == nil)
    }

    @Test("Ein deutsches Kompositum trifft über seinen Anfang")
    func compoundStart() {
        #expect(names("Rasenmäher zur Inspektion", germanCatalog)?.contains("Garten") == true)
        #expect(names("Gartenschere schleifen", germanCatalog) == ["Garten"])
    }

    @Test("Kurze Wörter treffen nur als ganzes Wort")
    func shortWordsNeedBothBoundaries() {
        #expect(names("Hausaufgaben kontrollieren", germanCatalog) == nil, "„Haus“ steckt nicht in „Hausaufgaben“")
        #expect(names("Callcenter Projekt", englishCatalog) == nil, "„call“ steckt nicht in „Callcenter“")
        #expect(names("Im Haus Licht reparieren", germanCatalog) == ["Haus"])
    }

    @Test("Ein selbst angelegter Kontext trifft mit seinem Namen")
    func ownContextByName() {
        #expect(names("Weinregal im Keller aufbauen", ["Keller", "Büro"])?.contains("Keller") == true)
        #expect(names("Ablage im Büro machen", ["Keller", "Büro"]) == ["Büro"])
    }

    @Test("Mehrere Treffer kommen in Katalogreihenfolge, die Begründung nennt das erste Wort")
    func severalHits() throws {
        let match = try #require(ContextWordRule.match(in: "Rasensamen im Baumarkt kaufen", available: germanCatalog))
        #expect(match.value == ["Garten", "Besorgung"])
        #expect(match.confidence == 1.0)
        let word = "Rasen"
        #expect(match.reason == String(localized: "From “\(word)” in the note."))
    }

    @Test("Eine Wortliste gehört nur dem ersten passenden Kontext: kein „Garden, Garten“ (#157)")
    func listBelongsToFirstMatchingContext() {
        #expect(names("Rasen mähen", ["Garden", "Garten"]) == ["Garden"])
        #expect(names("Gartenschere schleifen", ["Garden", "Garten"]) == ["Garten"], "der eigene Name trifft weiter")
    }

    @Test("Ein Wort für einen Kontext, den es im Katalog nicht gibt, trifft nicht")
    func missingContextDoesNotHit() {
        #expect(names("Fenster putzen", ["Garten"]) == nil)
    }

    @Test("Markiert wird nur das Wort des gesetzten Kontexts (#101)")
    func triggerOnlyForCarriedContexts() throws {
        let text = "Rasensamen im Baumarkt kaufen"
        let trigger = try #require(ContextWordRule.trigger(in: text, contexts: ["Besorgung"]))
        #expect(text[trigger] == "Baumarkt")
        #expect(ContextWordRule.trigger(in: text, contexts: ["Telefon"]) == nil)
    }

    // MARK: - Im Regelschritt

    @Test("Der Regelschritt setzt den Kontext mit Regel-Herkunft und einer Revision")
    @MainActor func ruleStepSetsContext() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        store.context.insert(garden)
        let task = TaskItem(rawText: "Hecke schneiden")
        store.context.insert(task)
        try store.context.save()

        await EnrichmentCoordinator(enricher: StubEnricher(unavailableReason: "Kein Modell"), container: store.container).processPending()

        #expect((task.contexts ?? []).map(\.name) == ["Garten"])
        #expect(task.contextsSourceRaw == FieldSource.rule.rawValue)
        let revisions = (task.revisions ?? []).filter { $0.field == .contexts }
        #expect(revisions.count == 1)
        #expect(revisions.first?.author == .rule)
        let word = "Hecke"
        #expect(revisions.first?.reason == String(localized: "From “\(word)” in the note."))
    }

    @Test("Ohne Treffer bleibt der Kontext leer, auch wenn das Modell einen vorschlägt")
    @MainActor func noHitStaysEmpty() async throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Unterwegs", isSystemDefault: true, sortOrder: 5))
        let task = TaskItem(rawText: "Morgen wichtig Steuerbescheid prüfen")
        store.context.insert(task)
        try store.context.save()
        var draft = EnrichmentDraft()
        draft.contexts = EnrichmentDraft.Guess(["Unterwegs"], confidence: 0.9, reason: "Geraten.")

        await EnrichmentCoordinator(enricher: StubEnricher(draft: draft), container: store.container).processPending()

        #expect((task.contexts ?? []).isEmpty)
        #expect(!(task.revisions ?? []).contains { $0.field == .contexts })
    }

    /// Der Gerätetest aus #244: Die frühere, wortgleiche Aufgabe trug „Haus“ mit Regel-Herkunft —
    /// eine Modell-Vermutung, die eine frühere Wiedererkennung schon kopiert hatte. Die neue Aufgabe
    /// bleibt trotzdem leer, weil die Wortliste nicht trifft und ein Regelwert keine Quelle ist.
    @Test("Eine kopierte Vermutung pflanzt sich nicht fort (#244)")
    @MainActor func copiedGuessDoesNotPropagate() async throws {
        let store = try TestStore()
        let home = TaskContext(name: "Haus", isSystemDefault: true, sortOrder: 2)
        store.context.insert(home)
        let earlier = TaskItem(rawText: "Morgen wichtig Steuerbescheid prüfen")
        earlier.status = .active
        earlier.rulesAppliedAt = Date(timeIntervalSince1970: 1_700_000_000)
        earlier.contexts = [home]
        earlier.contextsSourceRaw = FieldSource.rule.rawValue
        earlier.contextsConfidence = 1.0
        store.context.insert(earlier)
        let fresh = TaskItem(rawText: "Morgen wichtig Steuerbescheid prüfen")
        store.context.insert(fresh)
        try store.context.save()

        await EnrichmentCoordinator(enricher: StubEnricher(unavailableReason: "Kein Modell"), container: store.container).processPending()

        #expect((fresh.contexts ?? []).isEmpty)
        #expect(!(fresh.revisions ?? []).contains { $0.field == .contexts })
    }

    @Test("Ein vom Nutzer gesetzter Kontext wird nicht überschrieben, auch nicht beim Neu-Analysieren")
    @MainActor func userContextStays() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        let home = TaskContext(name: "Haus", isSystemDefault: true, sortOrder: 2)
        store.context.insert(garden)
        store.context.insert(home)
        let task = TaskItem(rawText: "Hecke schneiden")
        store.context.insert(task)
        RevisionService.set(.contexts, to: EnrichmentWriter.encode(["Haus"]), on: task, contexts: [garden, home], projects: [])
        try store.context.save()
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(unavailableReason: "Kein Modell"), container: store.container)

        await coordinator.processPending()
        _ = await coordinator.reanalyze(task)

        #expect((task.contexts ?? []).map(\.name) == ["Haus"])
        #expect(!(task.revisions ?? []).contains { $0.field == .contexts && $0.author == .rule })
    }
}
