#if os(iOS)
import CoreLocation
import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import LooseEnds

/// #240 Schnitt 2: what `PlaceNotificationCenter` hands to the system, with recorders in place of
/// `UNUserNotificationCenter` and `CLLocationManager` (`add` fails in the iOS 27 simulator, and a real
/// run would ask for location access). `PlaceDeliveryTests` covers the diff; this covers the bridge.
@Suite("PlaceNotificationCenter (#240)") struct PlaceNotificationCenterTests {
    struct AddFailed: Error {}

    @MainActor
    final class Recorder: PlaceScheduling {
        var pending: [String: UNNotificationRequest] = [:]
        var added: [UNNotificationRequest] = []
        var removed: [String] = []
        var failAdd = false

        func pendingIdentifiers() async -> [String] { Array(pending.keys) }
        func remove(_ identifiers: [String]) {
            removed += identifiers
            identifiers.forEach { pending[$0] = nil }
        }
        func add(_ request: UNNotificationRequest) async throws {
            if failAdd { throw AddFailed() }
            added.append(request)
            pending[request.identifier] = request
        }
    }

    @MainActor
    final class Location: PlaceLocating {
        var permission: PlaceNotifications.Permission = .whenInUse
        var fullAccuracy = true
        var isActive = true
        var requests = 0

        func requestWhenInUseAuthorization() { requests += 1 }
    }

    /// Holds the container for the whole test next to the center under test.
    @MainActor
    struct Fixture {
        let store: TestStore
        let recorder = Recorder()
        let location = Location()
        let defaults: UserDefaults
        let center: PlaceNotificationCenter

        init() throws {
            store = try TestStore()
            defaults = try #require(UserDefaults(suiteName: "PlaceNotificationCenterTests-\(UUID().uuidString)"))
            center = PlaceNotificationCenter(container: store.container, scheduler: recorder, location: location, defaults: defaults)
        }

        @discardableResult
        func task(_ raw: String, place name: String = "Büro", event: TaskPlace.Event = .arrive) throws -> TaskItem {
            let task = TaskItem(rawText: raw)
            task.status = .active
            task.place = try #require(TaskPlace(name: name, latitude: 51.99563, longitude: 7.71357, event: event))
            store.context.insert(task)
            try store.context.save()
            return task
        }

        var handoverWritten: Bool { defaults.data(forKey: PlaceNotificationCenter.handoverKey) != nil }
    }

    // MARK: - AC-6

    @Test("Arriving: one request place_<id> in PLACE with taskID, title, „You're at Büro.“, 150 m, entry only, once")
    @MainActor func arriveRequest() async throws {
        let fixture = try Fixture()
        let task = try fixture.task("Drucker abholen")

        await fixture.center.reconcile()

        #expect(fixture.recorder.added.count == 1)
        let request = try #require(fixture.recorder.added.first)
        #expect(request.identifier == "place_" + task.id.uuidString)
        #expect(request.content.categoryIdentifier == PlaceNotifications.categoryIdentifier)
        #expect(request.content.userInfo["taskID"] as? String == task.id.uuidString)
        #expect(request.content.title == task.displayTitle)
        #expect(request.content.body == String(localized: "You're at \("Büro")."))
        let trigger = try #require(request.trigger as? UNLocationNotificationTrigger)
        #expect(trigger.repeats == false)
        let region = try #require(trigger.region as? CLCircularRegion)
        #expect(region.radius == TaskPlace.radius)
        #expect(region.notifyOnEntry == true)
        #expect(region.notifyOnExit == false)
    }

    @Test("Leaving: the region fires on exit only")
    @MainActor func departRequest() async throws {
        let fixture = try Fixture()
        try fixture.task("Licht ausmachen", event: .depart)

        await fixture.center.reconcile()

        let trigger = try #require(fixture.recorder.added.first?.trigger as? UNLocationNotificationTrigger)
        let region = try #require(trigger.region as? CLCircularRegion)
        #expect(region.notifyOnEntry == false)
        #expect(region.notifyOnExit == true)
    }

    // MARK: - AC-7

    @Test("Due requests are never read, replaced or withdrawn by the place reconcile")
    @MainActor func dueRequestsStay() async throws {
        let fixture = try Fixture()
        try fixture.task("Drucker abholen")
        let due = UNNotificationRequest(identifier: "due_x", content: UNMutableNotificationContent(), trigger: nil)
        fixture.recorder.pending[due.identifier] = due
        fixture.recorder.pending["place_orphan"] = due

        await fixture.center.reconcile()

        #expect(fixture.recorder.removed == ["place_orphan"])
        #expect(fixture.recorder.added.allSatisfy { $0.identifier.hasPrefix("place_") })
        #expect(fixture.recorder.pending["due_x"] != nil)
    }

    // MARK: - AC-8

    @Test("A second run without a change hands over nothing; a moved place replaces only its request")
    @MainActor func onlyTheDifference() async throws {
        let fixture = try Fixture()
        let office = try fixture.task("Drucker abholen")
        let home = try fixture.task("Pflanzen gießen", place: "Zuhause")
        await fixture.center.reconcile()
        #expect(fixture.recorder.added.count == 2)
        #expect(fixture.handoverWritten)

        fixture.recorder.added = []
        await fixture.center.reconcile()
        #expect(fixture.recorder.added.isEmpty)
        #expect(fixture.recorder.removed.isEmpty)

        office.place = try #require(TaskPlace(name: "Büro", latitude: 52.0, longitude: 7.8, event: .arrive))
        try fixture.store.context.save()
        await fixture.center.reconcile()
        #expect(fixture.recorder.removed == ["place_" + office.id.uuidString])
        #expect(fixture.recorder.added.map(\.identifier) == ["place_" + office.id.uuidString])
        #expect(fixture.recorder.pending["place_" + home.id.uuidString] != nil)
    }

    @Test("A new title replaces only the content: added again under the same identifier, nothing withdrawn")
    @MainActor func titleChange() async throws {
        let fixture = try Fixture()
        let task = try fixture.task("Drucker abholen")
        await fixture.center.reconcile()
        fixture.recorder.added = []

        task.title = "Drucker und Papier abholen"
        try fixture.store.context.save()
        await fixture.center.reconcile()

        #expect(fixture.recorder.removed.isEmpty)
        #expect(fixture.recorder.added.map(\.content.title) == [task.displayTitle])
    }

    // MARK: - AC-9

    @Test("A failing add does not throw and leaves the handover list unwritten, so the next run tries again")
    @MainActor func failingAddKeepsTheListUnwritten() async throws {
        let fixture = try Fixture()
        let task = try fixture.task("Drucker abholen")
        fixture.recorder.failAdd = true

        await fixture.center.reconcile()
        #expect(fixture.handoverWritten == false)

        fixture.recorder.failAdd = false
        await fixture.center.reconcile()
        #expect(fixture.recorder.added.map(\.identifier) == ["place_" + task.id.uuidString])
        #expect(fixture.handoverWritten)
    }

    // MARK: - AC-10

    @Test("Without permission nothing is added or noted, but a stale place request is withdrawn")
    @MainActor func withoutPermissionOnlyWithdraws() async throws {
        for (permission, full) in [(PlaceNotifications.Permission.refused, true), (.notDetermined, true), (.whenInUse, false)] {
            let fixture = try Fixture()
            fixture.location.permission = permission
            fixture.location.fullAccuracy = full
            let done = try fixture.task("Erledigt")
            done.status = .done
            try fixture.store.context.save()
            try fixture.task("Drucker abholen")
            let stale = "place_" + done.id.uuidString
            fixture.recorder.pending[stale] = UNNotificationRequest(identifier: stale, content: UNMutableNotificationContent(), trigger: nil)

            await fixture.center.reconcile()

            #expect(fixture.recorder.added.isEmpty, "\(permission), full accuracy \(full)")
            #expect(fixture.recorder.removed == [stale], "\(permission), full accuracy \(full)")
            #expect(fixture.handoverWritten == false, "\(permission), full accuracy \(full)")
        }
    }

    // MARK: - AC-11

    @Test("Asks for „while using“ once: only undecided, with a place, in the foreground, never again")
    @MainActor func asksOnce() async throws {
        let fixture = try Fixture()
        fixture.location.permission = .notDetermined
        try fixture.task("Drucker abholen")

        await fixture.center.reconcile()
        await fixture.center.reconcile()

        #expect(fixture.location.requests == 1)
        #expect(fixture.defaults.bool(forKey: PlaceNotificationCenter.askedKey))
    }

    @Test("No question without a place, when already decided, or with reduced accuracy")
    @MainActor func noQuestion() async throws {
        let empty = try Fixture()
        empty.location.permission = .notDetermined
        await empty.center.reconcile()
        #expect(empty.location.requests == 0, "no place to watch")

        for permission in [PlaceNotifications.Permission.refused, .whenInUse] {
            let fixture = try Fixture()
            fixture.location.permission = permission
            fixture.location.fullAccuracy = permission == .refused
            try fixture.task("Drucker abholen")
            await fixture.center.reconcile()
            #expect(fixture.location.requests == 0, "\(permission)")
        }
    }

    @Test("In the background it does not ask and keeps the mark unset; back in front it asks")
    @MainActor func asksOnlyInFront() async throws {
        let fixture = try Fixture()
        fixture.location.permission = .notDetermined
        fixture.location.isActive = false
        try fixture.task("Drucker abholen")

        await fixture.center.reconcile()
        #expect(fixture.location.requests == 0)
        #expect(fixture.defaults.bool(forKey: PlaceNotificationCenter.askedKey) == false)

        fixture.location.isActive = true
        await fixture.center.reconcile()
        #expect(fixture.location.requests == 1)
    }

    // MARK: - AC-15

    @Test("German text „Du bist bei %@.“ and the location purpose string in Info.plist, German and English")
    func texts() throws {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let german = try #require(Bundle(path: path))
        #expect(german.localizedString(forKey: "You're at %@.", value: nil, table: nil) == "Du bist bei %@.")
        let key = "NSLocationWhenInUseUsageDescription"
        let english = try #require(Bundle.main.object(forInfoDictionaryKey: key) as? String)
        #expect(english.isEmpty == false)
        let translated = german.localizedString(forKey: key, value: nil, table: "InfoPlist")
        #expect(translated != key && translated != english, "the German InfoPlist.strings carries its own text")
    }
}
#endif
