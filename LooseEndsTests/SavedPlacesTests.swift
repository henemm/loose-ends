import Foundation
import Testing
@testable import LooseEnds

/// Home and work as saved places (#241, Schnitt 3b): a plain value, one slot changes alone, and a slot
/// never reaches back into tasks that already carry its place.
@Suite("SavedPlaces (#241)") struct SavedPlacesTests {
    private func spot(_ name: String = "Zuhause, Hamburg-Altona", latitude: Double = 53.5561) throws -> SavedPlaces.Spot {
        try #require(SavedPlaces.Spot(name: name, latitude: latitude, longitude: 9.9285))
    }

    @Test("Nothing saved is empty in both slots")
    func empty() {
        #expect(SavedPlaces.empty.spot(.home) == nil)
        #expect(SavedPlaces.empty.spot(.work) == nil)
    }

    @Test("Setting one slot leaves the other alone; nil clears it")
    func settingOneSlot() throws {
        let home = try spot()
        let saved = SavedPlaces.empty.setting(.home, to: home)
        #expect(saved.spot(.home) == home)
        #expect(saved.spot(.work) == nil)
        let both = saved.setting(.work, to: try spot("Büro", latitude: 53.57))
        #expect(both.spot(.home) == home)
        #expect(both.setting(.home, to: nil).spot(.home) == nil)
        #expect(both.setting(.home, to: nil).spot(.work) != nil)
    }

    @Test("Encoding and decoding round-trip; damaged or missing data reads as empty")
    func coding() throws {
        let saved = SavedPlaces.empty.setting(.home, to: try spot())
        #expect(SavedPlaces.decode(saved.encoded) == saved)
        #expect(SavedPlaces.decode(Data("{kaputt".utf8)) == .empty)
        #expect(SavedPlaces.decode(nil) == .empty)
    }

    @Test("A spot with an impossible coordinate or an empty name is not made")
    func invalidSpot() {
        #expect(SavedPlaces.Spot(name: "Nirgends", latitude: 91, longitude: 0) == nil)
        #expect(SavedPlaces.Spot(name: "Nirgends", latitude: 0, longitude: 181) == nil)
        #expect(SavedPlaces.Spot(name: "   ", latitude: 10, longitude: 10) == nil)
    }

    @Test("A slot makes a valid task place with the asked event; an empty slot makes none")
    func placeFromSlot() throws {
        let saved = SavedPlaces.empty.setting(.home, to: try spot())
        let place = try #require(saved.place(.home, event: .depart))
        #expect(place.name == "Zuhause, Hamburg-Altona")
        #expect(place.event == .depart)
        #expect(place.latitude == 53.5561)
        #expect(saved.place(.work, event: .arrive) == nil)
    }

    @Test("Changing or clearing a slot does not touch a task that carries its place")
    @MainActor func changeAndRemoveSlotDoNotTouchTasks() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Post abholen")
        store.context.insert(task)
        let saved = SavedPlaces.empty.setting(.home, to: try spot())
        PlaceEditing.set(try #require(saved.place(.home, event: .arrive)), on: task)
        let before = task.place
        let revisions = (task.revisions ?? []).count

        let moved = saved.setting(.home, to: try spot("Anderswo", latitude: 53.6))
        _ = moved.setting(.home, to: nil)

        #expect(task.place == before)
        #expect((task.revisions ?? []).count == revisions)
    }

    @Test("Defining a slot gives no task a place")
    @MainActor func settingHomeLeavesTasksUntouched() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Post abholen")
        store.context.insert(task)
        _ = SavedPlaces.empty.setting(.home, to: try spot())
        #expect(task.place == nil)
        #expect((task.revisions ?? []).isEmpty)
    }
}
