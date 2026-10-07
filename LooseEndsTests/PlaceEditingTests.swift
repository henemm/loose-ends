import Foundation
import Testing
@testable import LooseEnds

/// The place set by hand in the detail (#241, Schnitt 3a): every change one user revision, nothing
/// twice, and a place beyond the 20 watched ones is named, never dropped silently.
@Suite("PlaceEditing (#241)") struct PlaceEditingTests {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func place(_ name: String = "Bauhaus, Hamburg-Altona", event: TaskPlace.Event = .arrive) throws -> TaskPlace {
        try #require(TaskPlace(name: name, latitude: 53.55, longitude: 9.93, event: event))
    }

    private func revisions(_ task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.field == .place }
    }

    @Test("Setting writes the place with one user revision; the same place again writes nothing")
    @MainActor func set() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        store.context.insert(task)

        let bauhaus = try place()
        let revision = try #require(PlaceEditing.set(bauhaus, on: task))

        #expect(task.place == bauhaus)
        #expect(task.placeSourceRaw == FieldSource.user.rawValue)
        #expect(revision.author == .user)
        #expect(revision.oldValue == nil)
        #expect(PlaceEditing.set(bauhaus, on: task) == nil)
        #expect(revisions(task).count == 1)
    }

    @Test("Switching to leave keeps name and coordinate; without a place it does nothing")
    @MainActor func setEvent() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        store.context.insert(task)
        #expect(PlaceEditing.setEvent(.depart, on: task) == nil)

        PlaceEditing.set(try place(), on: task)
        let revision = try #require(PlaceEditing.setEvent(.depart, on: task))
        let leaving = try place(event: .depart)

        #expect(task.place == leaving)
        #expect(revision.newValue == FieldCodec.encode(leaving))
        #expect(PlaceEditing.setEvent(.depart, on: task) == nil)
        #expect(revisions(task).count == 2)
    }

    @Test("Removing clears the place with one revision; without a place it does nothing")
    @MainActor func remove() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        store.context.insert(task)
        #expect(PlaceEditing.remove(from: task) == nil)

        let bauhaus = try place()
        PlaceEditing.set(bauhaus, on: task)
        let revision = try #require(PlaceEditing.remove(from: task))

        #expect(task.place == nil)
        #expect(task.placeSourceRaw == nil)
        #expect(revision.newValue == nil)
        #expect(revision.oldValue == FieldCodec.encode(bauhaus))
        #expect(revisions(task).count == 2)
    }

    @Test("Beyond 20 places the lowest-ranked task is named not watched; on the Mac the others say so")
    @MainActor func note() throws {
        let store = try TestStore()
        var tasks: [TaskItem] = []
        for index in 0..<21 {
            let task = TaskItem(rawText: "Aufgabe \(index)")
            task.capturedAt = start.addingTimeInterval(Double(index) * 60)
            task.place = try place()
            store.context.insert(task)
            tasks.append(task)
        }
        let oldest = tasks[0]   // the newest rank first, so the oldest is cut
        let bare = TaskItem(rawText: "ohne Ort")
        store.context.insert(bare)

        #expect(PlaceEditing.note(for: oldest, among: tasks, isMac: false) == .notWatched)
        #expect(PlaceEditing.note(for: oldest, among: tasks, isMac: true) == .notWatched)
        #expect(PlaceEditing.note(for: tasks[20], among: tasks, isMac: false) == nil)
        #expect(PlaceEditing.note(for: tasks[20], among: tasks, isMac: true) == .macOnly)
        #expect(PlaceEditing.note(for: bare, among: tasks + [bare], isMac: true) == nil)
    }
}
