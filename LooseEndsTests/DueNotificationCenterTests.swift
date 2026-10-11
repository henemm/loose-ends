import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import LooseEnds

/// #328: what `DueNotificationCenter` hands to the system, with a recorder in place of
/// `UNUserNotificationCenter` (its `add` fails in the iOS 27 simulator, and a real run would ask
/// for permission). `DueRemindersTests` covers the plan; this covers the bridge.
@Suite("DueNotificationCenter") struct DueNotificationCenterTests {
    @MainActor
    final class Recorder: DueScheduling {
        var pending: [String: UNNotificationRequest] = [:]
        var badge: Int?

        func pendingIdentifiers() async -> [String] { Array(pending.keys) }
        func remove(_ identifiers: [String]) { identifiers.forEach { pending[$0] = nil } }
        func add(_ request: UNNotificationRequest) async throws { pending[request.identifier] = request }
        func setBadgeCount(_ count: Int) async throws { badge = count }
    }

    @MainActor
    final class Cloud: ReminderTimeCloud {
        var reminderMinutes: Int?
        func setReminderMinutes(_ minutes: Int) { reminderMinutes = minutes }
    }

    /// Holds the container for the whole test (`TestStore`) next to the center under test.
    @MainActor
    struct Fixture {
        let store: TestStore
        let recorder = Recorder()
        let cloud = Cloud()
        let center: DueNotificationCenter
        let calendar = Calendar.current
        let tomorrow: Date

        init() throws {
            store = try TestStore()
            let defaults = try #require(UserDefaults(suiteName: "DueNotificationCenterTests-\(UUID().uuidString)"))
            center = DueNotificationCenter(container: store.container, scheduler: recorder, defaults: defaults, cloud: cloud)
            tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())))
        }

        func task(_ raw: String, hour: Int? = nil, minute: Int = 0) throws -> TaskItem {
            let task = TaskItem(rawText: raw)
            task.status = .active
            if let hour {
                task.dueDate = try #require(calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow))
                task.dueHasTime = true
            } else {
                task.dueDate = tomorrow
            }
            store.context.insert(task)
            try store.context.save()
            return task
        }

        func request(for task: TaskItem) -> UNNotificationRequest? {
            recorder.pending[DueReminders.identifierPrefix + task.id.uuidString]
        }

        func fireComponents(of request: UNNotificationRequest?) -> (day: Int?, hour: Int?, minute: Int?) {
            let parts = (request?.trigger as? UNCalendarNotificationTrigger)?.dateComponents
            return (parts?.day, parts?.hour, parts?.minute)
        }
    }

    @Test("A task with a due time is handed over as due now, at that time, in the DUE category")
    @MainActor func timedTask() async throws {
        let fixture = try Fixture()
        let task = try fixture.task("Um 14:30 Zahnarzt anrufen", hour: 14, minute: 30)

        await fixture.center.reschedule()

        let request = try #require(fixture.request(for: task))
        #expect(request.content.body == String(localized: "Due now"))
        #expect(request.content.title == task.displayTitle)
        #expect(request.content.categoryIdentifier == DueReminders.categoryIdentifier)
        #expect(request.content.userInfo["taskID"] as? String == task.id.uuidString)
        let fire = fixture.fireComponents(of: request)
        #expect(fire.day == fixture.calendar.component(.day, from: fixture.tomorrow))
        #expect(fire.hour == 14 && fire.minute == 30)
        #expect((request.trigger as? UNCalendarNotificationTrigger)?.repeats == false)
        #expect(fixture.recorder.badge != nil, "every reschedule sets the badge (#299)")
    }

    @Test("A task without a due time is handed over as due today, at the set time; a new time replaces it")
    @MainActor func untimedTaskFollowsTheSetting() async throws {
        let fixture = try Fixture()
        let task = try fixture.task("Steuer abgeben")

        await fixture.center.reschedule()
        let first = fixture.fireComponents(of: fixture.request(for: task))
        #expect(first.hour == 9 && first.minute == 0, "9:00 while nothing is set")
        #expect(fixture.request(for: task)?.content.body == String(localized: "Due today"))

        fixture.center.reminderTime = DueReminders.Time(hour: 7, minute: 30)
        await fixture.center.reschedule()

        #expect(fixture.recorder.pending.count == 1, "the old request is replaced, not doubled")
        let moved = fixture.fireComponents(of: fixture.request(for: task))
        #expect(moved.hour == 7 && moved.minute == 30)
        #expect(fixture.cloud.reminderMinutes == 7 * 60 + 30, "the new time goes to iCloud for the other devices")
    }

    @Test("Other requests stay; a completed task loses its request")
    @MainActor func replacesOnlyDueRequests() async throws {
        let fixture = try Fixture()
        let task = try fixture.task("Steuer abgeben")
        let place = UNNotificationRequest(identifier: "place_x", content: UNMutableNotificationContent(), trigger: nil)
        fixture.recorder.pending[place.identifier] = place

        await fixture.center.reschedule()
        #expect(fixture.request(for: task) != nil)

        task.status = .done
        try fixture.store.context.save()
        await fixture.center.reschedule()

        #expect(fixture.request(for: task) == nil)
        #expect(fixture.recorder.pending.keys.sorted() == ["place_x"])
    }

    @Test("A time set on another device is taken over and planned with")
    @MainActor func takesTheCloudTime() async throws {
        let fixture = try Fixture()
        let task = try fixture.task("Steuer abgeben")
        fixture.cloud.reminderMinutes = 18 * 60 + 15

        #expect(fixture.center.takeCloudTime())
        #expect(fixture.center.takeCloudTime() == false, "the same value twice changes nothing")
        await fixture.center.reschedule()

        #expect(fixture.center.reminderTime == DueReminders.Time(hour: 18, minute: 15))
        let fire = fixture.fireComponents(of: fixture.request(for: task))
        #expect(fire.hour == 18 && fire.minute == 15)
    }
}
