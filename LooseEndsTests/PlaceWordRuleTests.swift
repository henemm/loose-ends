import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// "zu Hause" and "im Büro" set the saved place (Henning, 2026-10-25, #680).
@Suite("Place from its words") struct PlaceWordRuleTests {
    static let home = SavedPlaces.Spot(name: "Zuhause", latitude: 53.55, longitude: 9.99)!
    static let work = SavedPlaces.Spot(name: "Büro", latitude: 53.56, longitude: 9.93)!
    static let places = SavedPlaces.empty.setting(.home, to: home).setting(.work, to: work)

    @Test("Home and work words name their slot", arguments: [
        ("Erinnere mich zu Hause daran, Donauwellen rausnehmen um 10:00 Uhr", SavedPlaces.Slot.home),
        ("Zuhause die Pflanzen gießen", .home),
        ("Daheim den Keller aufräumen", .home),
        ("Water the plants at home", .home),
        ("Im Büro den Drucker reparieren", .work),
        ("Auf der Arbeit Kuchen mitbringen", .work),
        ("Bei der Arbeit nach dem Schlüssel fragen", .work),
        ("Print the tickets at work", .work),
        ("Pick up the badge at the office", .work),
    ])
    func slot(text: String, slot: SavedPlaces.Slot) {
        #expect(PlaceWordRule.slot(in: text) == slot, "\(text)")
    }

    @Test("Other words name no place", arguments: [
        "Hausaufgaben kontrollieren",
        "Das Haus streichen",
        "Arbeitsvertrag unterschreiben",
        "Büroklammern kaufen",
        "Homework for Monday",
    ])
    func noSlot(text: String) {
        #expect(PlaceWordRule.slot(in: text) == nil, "\(text)")
    }

    @Test("The saved place on arrival; nothing while the slot is empty")
    func match() throws {
        let guess = try #require(PlaceWordRule.match(in: "Zu Hause Donauwellen rausnehmen", places: Self.places))
        #expect(guess.value.name == "Zuhause" && guess.value.event == .arrive)
        #expect(guess.value.latitude == 53.55 && guess.value.longitude == 9.99)
        #expect(guess.confidence == 1.0 && !guess.reason.isEmpty)
        #expect(PlaceWordRule.match(in: "Im Büro anrufen", places: Self.places)?.value.name == "Büro")
        #expect(PlaceWordRule.match(in: "Zu Hause Donauwellen rausnehmen", places: .empty) == nil)
    }

    @Test("The rule step sets the place with the rule as its origin")
    @MainActor func ruleStep() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Erinnere mich zu Hause daran, Donauwellen rausnehmen")
        store.context.insert(task)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(draft: EnrichmentDraft()), container: store.container,
                                                savedPlaces: { Self.places })
        await coordinator.processPending()
        #expect(task.place?.name == "Zuhause")
        #expect(task.placeSourceRaw == FieldSource.rule.rawValue)
        #expect((task.revisions ?? []).contains { $0.field == .place && $0.author == .rule })
    }

    @Test("A place the user cleared stays cleared on Analyze again")
    @MainActor func userClearedStays() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zu Hause Donauwellen rausnehmen")
        store.context.insert(task)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(draft: EnrichmentDraft()), container: store.container,
                                                savedPlaces: { Self.places })
        await coordinator.processPending()
        RevisionService.set(.place, to: nil, on: task, contexts: [], projects: [])
        try store.context.save()
        _ = await coordinator.reanalyze(task)
        #expect(task.place == nil)
    }

    @Test("The reasons are translated into German")
    func reasonsAreTranslated() throws {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let germanBundle = try #require(Bundle(path: path))
        for key in ["From “at home” in the note: your saved home.", "From “at work” in the note: your saved work place."] {
            #expect(germanBundle.localizedString(forKey: key, value: key, table: nil) != key, "\(key)")
        }
    }
}
