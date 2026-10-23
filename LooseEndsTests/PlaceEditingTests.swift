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

    // MARK: Schnitt 3b (#241): location off, already there, current location

    private func fix(northMeters: Double, accuracy: Double) -> LocationFix {
        // One degree of latitude is about 111,195 m.
        LocationFix(latitude: 53.55 + northMeters / 111_195, longitude: 9.93, accuracy: accuracy)
    }

    @Test("Within the radius counts as already there")
    func alreadyThereWithin() throws {
        #expect(PlaceEditing.isAlreadyThere(try place(), at: fix(northMeters: 100, accuracy: 20)) == true)
    }

    @Test("Beyond radius plus accuracy is not there")
    func alreadyThereBeyond() throws {
        #expect(PlaceEditing.isAlreadyThere(try place(), at: fix(northMeters: 300, accuracy: 20)) == false)
    }

    @Test("The reported accuracy widens the radius")
    func alreadyThereAccuracyExtendsRadius() throws {
        #expect(PlaceEditing.isAlreadyThere(try place(), at: fix(northMeters: 200, accuracy: 60)) == true)
    }

    @Test("An invalid accuracy is unknown, not yes")
    func alreadyThereInvalidAccuracyUnknown() throws {
        #expect(PlaceEditing.isAlreadyThere(try place(), at: fix(northMeters: 150, accuracy: -1)) == nil)
    }

    @Test("An accuracy beyond 100 m is unknown, even right on the place")
    func alreadyThereHugeAccuracyUnknown() throws {
        #expect(PlaceEditing.isAlreadyThere(try place(), at: fix(northMeters: 0, accuracy: 500)) == nil)
    }

    @Test("The already-here sentence needs arrive, a granted permission and a fix at the place")
    func alreadyThereNeedsGrantedPermissionAndArriveEvent() throws {
        let here = fix(northMeters: 10, accuracy: 10)
        let far = fix(northMeters: 5_000, accuracy: 10)
        #expect(PlaceEditing.showsAlreadyThere(try place(), permission: .whenInUse, fix: here))
        #expect(PlaceEditing.showsAlreadyThere(try place(), permission: .always, fix: here))
        #expect(!PlaceEditing.showsAlreadyThere(try place(event: .depart), permission: .whenInUse, fix: here))
        #expect(!PlaceEditing.showsAlreadyThere(try place(), permission: .refused, fix: here))
        #expect(!PlaceEditing.showsAlreadyThere(try place(), permission: .notDetermined, fix: here))
        #expect(!PlaceEditing.showsAlreadyThere(try place(), permission: .whenInUse, fix: far))
        #expect(!PlaceEditing.showsAlreadyThere(try place(), permission: .whenInUse, fix: nil))
        #expect(!PlaceEditing.showsAlreadyThere(try place(), permission: .whenInUse, fix: fix(northMeters: 0, accuracy: 500)))
    }

    @Test("A refused permission with a place says the location is off")
    @MainActor func noteLocationOffWithPlace() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        task.place = try place()
        store.context.insert(task)
        #expect(PlaceEditing.note(for: task, among: [task], isMac: false, permission: .refused) == .locationOff)
    }

    @Test("Not watched beats location off")
    @MainActor func noteNotWatchedBeatsLocationOff() throws {
        let store = try TestStore()
        var tasks: [TaskItem] = []
        for index in 0..<21 {
            let task = TaskItem(rawText: "Aufgabe \(index)")
            task.capturedAt = start.addingTimeInterval(Double(index) * 60)
            task.place = try place()
            store.context.insert(task)
            tasks.append(task)
        }
        #expect(PlaceEditing.note(for: tasks[0], among: tasks, isMac: false, permission: .refused) == .notWatched)
        #expect(PlaceEditing.note(for: tasks[20], among: tasks, isMac: false, permission: .refused) == .locationOff)
    }

    @Test("On the Mac the Mac note stays; location off is never shown there")
    @MainActor func noteMacOnlyBeatsLocationOffOnMac() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        task.place = try place()
        store.context.insert(task)
        #expect(PlaceEditing.note(for: task, among: [task], isMac: true, permission: .refused) == .macOnly)
    }

    @Test("Undecided or granted permission shows no location note")
    @MainActor func noteNoneWhenUndecided() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        task.place = try place()
        store.context.insert(task)
        #expect(PlaceEditing.note(for: task, among: [task], isMac: false, permission: .notDetermined) == nil)
        #expect(PlaceEditing.note(for: task, among: [task], isMac: false, permission: .whenInUse) == nil)
        #expect(PlaceEditing.note(for: task, among: [task], isMac: false, permission: .always) == nil)
    }

    @Test("Without a place there is never a note")
    @MainActor func noteNeverWithoutPlace() throws {
        let store = try TestStore()
        let bare = TaskItem(rawText: "ohne Ort")
        store.context.insert(bare)
        #expect(PlaceEditing.note(for: bare, among: [bare], isMac: false, permission: .refused) == nil)
    }

    @Test("A current fix sets a named place with one user revision; the same fix again writes nothing")
    @MainActor func currentFixSetsPlaceWithOneUserRevision() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        store.context.insert(task)
        let here = LocationFix(latitude: 53.5561, longitude: 9.9285, accuracy: 10)

        let revision = try #require(PlaceEditing.setCurrent(here, name: "Hohe Straße, Hamburg", on: task))

        #expect(task.place?.name == "Hohe Straße, Hamburg")
        #expect(task.place?.latitude == 53.5561)
        #expect(task.place?.event == .arrive)
        #expect(revision.author == .user)
        #expect(PlaceEditing.setCurrent(here, name: "Hohe Straße, Hamburg", on: task) == nil)
        #expect(revisions(task).count == 1)
    }

    @Test("A current fix keeps the event of a place the task already has")
    @MainActor func currentFixKeepsExistingEvent() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dübel kaufen")
        store.context.insert(task)
        PlaceEditing.set(try place(event: .depart), on: task)
        PlaceEditing.setCurrent(LocationFix(latitude: 53.6, longitude: 9.9, accuracy: 10), name: "Hier", on: task)
        #expect(task.place?.event == .depart)
        #expect(task.place?.name == "Hier")
    }

    @Test("The current location row is offered on iPhone and iPad, not on the Mac")
    func currentLocationRowOfferedOnlyOnIOS() {
        #expect(PlaceEditing.offersCurrentLocation(isMac: false))
        #expect(!PlaceEditing.offersCurrentLocation(isMac: true))
    }

    // MARK: The lookup behind "current location"

    @MainActor
    final class FakeLocator: CurrentLocating {
        var permission: PlaceNotifications.Permission
        let answerToRequest: PlaceNotifications.Permission
        var result: Result<LocationFix, Error>
        private(set) var requests = 0
        private(set) var fixCalls = 0
        struct Failure: Error {}

        init(permission: PlaceNotifications.Permission,
             answerToRequest: PlaceNotifications.Permission = .whenInUse,
             result: Result<LocationFix, Error> = .success(LocationFix(latitude: 53.55, longitude: 9.93, accuracy: 10))) {
            self.permission = permission
            self.answerToRequest = answerToRequest
            self.result = result
        }

        func requestPermissionIfNeeded() async -> PlaceNotifications.Permission {
            requests += 1
            permission = answerToRequest
            return permission
        }

        func currentFix() async throws -> LocationFix {
            fixCalls += 1
            return try result.get()
        }
    }

    @Test("Undecided asks exactly once; granted or refused never asks again")
    @MainActor func currentLocationAsksOnce() async {
        let undecided = FakeLocator(permission: .notDetermined)
        _ = await CurrentLocationLookup.run(undecided)
        #expect(undecided.requests == 1)
        let granted = FakeLocator(permission: .whenInUse)
        _ = await CurrentLocationLookup.run(granted)
        #expect(granted.requests == 0)
        let refused = FakeLocator(permission: .refused)
        _ = await CurrentLocationLookup.run(refused)
        #expect(refused.requests == 0)
    }

    @Test("A refusal ends with refused and asks for no fix")
    @MainActor func currentLocationRefusedYieldsNoFix() async {
        let refusedAtPrompt = FakeLocator(permission: .notDetermined, answerToRequest: .refused)
        #expect(await CurrentLocationLookup.run(refusedAtPrompt) == .refused)
        #expect(refusedAtPrompt.fixCalls == 0)
        let alreadyRefused = FakeLocator(permission: .refused)
        #expect(await CurrentLocationLookup.run(alreadyRefused) == .refused)
        #expect(alreadyRefused.fixCalls == 0)
    }

    @Test("A granted permission returns the fix; a failing lookup is unavailable, not a guess")
    @MainActor func currentLocationFixOrUnavailable() async {
        let ok = FakeLocator(permission: .whenInUse)
        #expect(await CurrentLocationLookup.run(ok) == .fix(LocationFix(latitude: 53.55, longitude: 9.93, accuracy: 10)))
        let failing = FakeLocator(permission: .whenInUse, result: .failure(FakeLocator.Failure()))
        #expect(await CurrentLocationLookup.run(failing) == .unavailable)
    }
}
