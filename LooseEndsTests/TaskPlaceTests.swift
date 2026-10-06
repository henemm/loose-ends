import Foundation
import Testing
@testable import LooseEnds

/// A place on a task (#226, Schnitt 1): whole or not at all, one encoding, one revision per change.
@Suite("TaskPlace (#226)") struct TaskPlaceTests {
    private func bauhaus(_ event: TaskPlace.Event = .arrive) throws -> TaskPlace {
        try #require(TaskPlace(name: "  Bauhaus, Hamburg-Altona ", latitude: 53.55, longitude: 9.93, event: event))
    }

    @Test("A valid place keeps its trimmed name; an empty name or an impossible coordinate is no place")
    func validation() throws {
        let valid = try bauhaus()
        #expect(valid.name == "Bauhaus, Hamburg-Altona")
        #expect(TaskPlace(name: "", latitude: 0, longitude: 0, event: .arrive) == nil)
        #expect(TaskPlace(name: "  \n", latitude: 0, longitude: 0, event: .arrive) == nil)
        #expect(TaskPlace(name: "Nord", latitude: 90.5, longitude: 0, event: .arrive) == nil)
        #expect(TaskPlace(name: "Süd", latitude: -90.5, longitude: 0, event: .arrive) == nil)
        #expect(TaskPlace(name: "Ost", latitude: 0, longitude: 180.5, event: .depart) == nil)
        #expect(TaskPlace(name: "West", latitude: 0, longitude: -180.5, event: .depart) == nil)
        #expect(TaskPlace(name: "Pol", latitude: 90, longitude: -180, event: .depart) != nil)
    }

    @Test("Encoding round-trips and the same place always encodes to the same text")
    func codec() throws {
        let place = try bauhaus(.depart)
        let encoded = try #require(FieldCodec.encode(place))
        #expect(FieldCodec.decodePlace(encoded) == place)
        #expect(FieldCodec.encode(place) == encoded)
        #expect(encoded.contains(#""event":"depart""#))
    }

    @Test("A stored value that fails the checks, or garbage, reads as no place")
    func invalidStoredValue() {
        #expect(FieldCodec.decodePlace(#"{"event":"arrive","latitude":95,"longitude":9,"name":"X"}"#) == nil)
        #expect(FieldCodec.decodePlace(#"{"event":"arrive","latitude":53,"longitude":9,"name":" "}"#) == nil)
        #expect(FieldCodec.decodePlace("kaputt") == nil)
        #expect(FieldCodec.decodePlace(nil) == nil)
    }

    @Test("Applying an empty or broken value clears place and origin")
    @MainActor func applyClears() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        store.context.insert(task)
        let encoded = try FieldCodec.encode(bauhaus())
        FieldCodec.apply(encoded, to: .place, of: task, as: .user, contexts: [], projects: [])
        #expect(task.place != nil)
        #expect(task.placeSourceRaw == FieldSource.user.rawValue)

        FieldCodec.apply("kaputt", to: .place, of: task, as: .user, contexts: [], projects: [])
        #expect(task.place == nil)
        #expect(task.placeSourceRaw == nil)

        FieldCodec.apply(encoded, to: .place, of: task, as: .user, contexts: [], projects: [])
        FieldCodec.apply(nil, to: .place, of: task, as: .user, contexts: [], projects: [])
        #expect(task.place == nil)
        #expect(task.placeSourceRaw == nil)
    }

    @Test("A user change writes one revision; the same place again writes nothing")
    @MainActor func userRevision() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        store.context.insert(task)
        let place = try bauhaus()
        let encoded = FieldCodec.encode(place)

        let revision = try #require(RevisionService.set(.place, to: encoded, on: task, contexts: [], projects: []))
        #expect(task.place == place)
        #expect(revision.field == .place)
        #expect(revision.author == .user)
        #expect(revision.oldValue == nil)
        #expect(revision.newValue == encoded)
        #expect(RevisionService.origin(of: .place, on: task) == .user)

        #expect(RevisionService.set(.place, to: encoded, on: task, contexts: [], projects: []) == nil)
        #expect((task.revisions ?? []).count == 1)
    }

    @Test("Resetting restores the state before a place a rule set")
    @MainActor func revert() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        store.context.insert(task)
        let encoded = try FieldCodec.encode(bauhaus())
        FieldCodec.apply(encoded, to: .place, of: task, as: .rule, contexts: [], projects: [])
        let ruleRevision = Revision(task: task, field: .place, oldValue: nil, newValue: encoded, author: .rule)
        task.revisions = [ruleRevision]
        #expect(RevisionService.automaticFields(on: task).contains(.place))

        RevisionService.revertAll(on: task, contexts: [], projects: [])

        #expect(task.place == nil)
        #expect(task.placeSourceRaw == nil)
    }

    @Test("The label reads „Ort“ in German, the value is the place's name")
    func formatting() throws {
        let encoded = try FieldCodec.encode(bauhaus())
        #expect(FieldFormatting.value(encoded, for: .place) == "Bauhaus, Hamburg-Altona")
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let german = try #require(Bundle(path: path))
        #expect(german.localizedString(forKey: "Place", value: nil, table: nil) == "Ort")
    }
}
