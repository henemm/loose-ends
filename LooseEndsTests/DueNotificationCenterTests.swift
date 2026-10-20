import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import LooseEnds

/// #328: what `DueNotificationCenter` hands to the system, with a recorder in place of
/// `UNUserNotificationCenter` (its `add` fails in the iOS 27 simulator, and a real run would ask
/// for permission). `DueRemindersTests` covers the plan; this covers the bridge.
/// Serialized: several tests set the shared `OpenTaskRequest.shared` and would reset it under each other.
@Suite("DueNotificationCenter", .serialized) struct DueNotificationCenterTests {
    @MainActor
    final class Recorder: DueScheduling {
        var pending: [String: UNNotificationRequest] = [:]
        var badge: Int?
        var categorySets: [Set<UNNotificationCategory>] = []

        func pendingIdentifiers() async -> [String] { Array(pending.keys) }
        func remove(_ identifiers: [String]) { identifiers.forEach { pending[$0] = nil } }
        func add(_ request: UNNotificationRequest) async throws { pending[request.identifier] = request }
        func setBadgeCount(_ count: Int) async throws { badge = count }
        func setNotificationCategories(_ categories: Set<UNNotificationCategory>) { categorySets.append(categories) }
    }

    /// Stands in for the place reconcile (#240): counts the runs `reschedule()` triggers.
    @MainActor
    final class PlaceSpy: PlaceReconciling {
        var runs = 0
        func reconcile() async { runs += 1 }
    }

    @MainActor
    final class Cloud: ReminderTimeCloud {
        var reminderMinutes: Int?
        func setReminderMinutes(_ minutes: Int) { reminderMinutes = minutes }
        var carryModeRaw: String?
        func setCarryMode(_ raw: String) { carryModeRaw = raw }
        var eveningMinutes: Int?
        func setEveningMinutes(_ minutes: Int) { eveningMinutes = minutes }
        var morningMinutes: Int?
        func setMorningMinutes(_ minutes: Int) { morningMinutes = minutes }
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

        init(places: (any PlaceReconciling)? = nil) throws {
            store = try TestStore()
            let defaults = try #require(UserDefaults(suiteName: "DueNotificationCenterTests-\(UUID().uuidString)"))
            center = DueNotificationCenter(
                container: store.container, scheduler: recorder, defaults: defaults, cloud: cloud, places: places
            )
            tomorrow = try #require(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())))
        }

        func placed(_ raw: String) throws -> TaskItem {
            let task = try task(raw)
            task.place = try #require(TaskPlace(name: "Büro", latitude: 51.99563, longitude: 7.71357, event: .arrive))
            try store.context.save()
            return task
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
        fixture.center.carryMode = .evening   // morning off: at 9:00 it would carry the task itself (#551)
        let task = try fixture.task("Steuer abgeben")

        await fixture.center.reschedule()
        let first = fixture.fireComponents(of: fixture.request(for: task))
        #expect(first.hour == 9 && first.minute == 0, "9:00 while nothing is set")
        #expect(fixture.request(for: task)?.content.body == String(localized: "Due today"))

        fixture.center.reminderTime = DueReminders.Time(hour: 7, minute: 30)
        await fixture.center.reschedule()

        #expect(fixture.recorder.pending.keys.filter { $0.hasPrefix(DueReminders.identifierPrefix) }.count == 1,
                "the old request is replaced, not doubled")
        let moved = fixture.fireComponents(of: fixture.request(for: task))
        #expect(moved.hour == 7 && moved.minute == 30)
        #expect(fixture.cloud.reminderMinutes == 7 * 60 + 30, "the new time goes to iCloud for the other devices")
    }

    @Test("Other requests stay; a completed task loses its request")
    @MainActor func replacesOnlyDueRequests() async throws {
        let fixture = try Fixture()
        fixture.center.carryMode = .evening   // morning off: at 9:00 it would carry the task itself (#551)
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
        fixture.center.carryMode = .evening   // morning off: at 9:00 it would carry the task itself (#551)
        let task = try fixture.task("Steuer abgeben")
        fixture.cloud.reminderMinutes = 18 * 60 + 15

        #expect(fixture.center.takeCloudTime())
        #expect(fixture.center.takeCloudTime() == false, "the same value twice changes nothing")
        await fixture.center.reschedule()

        #expect(fixture.center.reminderTime == DueReminders.Time(hour: 18, minute: 15))
        let fire = fixture.fireComponents(of: fixture.request(for: task))
        #expect(fire.hour == 18 && fire.minute == 15)
    }

    /// A task due yesterday without a time (#414).
    @MainActor func carriedTask(_ fixture: Fixture, _ raw: String) throws -> TaskItem {
        let task = TaskItem(rawText: raw)
        task.status = .active
        task.dueDate = try #require(fixture.calendar.date(byAdding: .day, value: -2, to: fixture.tomorrow))
        fixture.store.context.insert(task)
        try fixture.store.context.save()
        return task
    }

    @Test("A change from elsewhere replans, like a save: a task saved behind the center's back gets its reminder (#553)")
    @MainActor func changeFromElsewhereReplans() async throws {
        let fixture = try Fixture()
        await fixture.center.reschedule()
        let task = try fixture.task("Zahnarzt anrufen", hour: 14)
        #expect(fixture.request(for: task) == nil, "saved without the center hearing of it")

        fixture.center.storeChangedElsewhere()
        try await Task.sleep(for: .seconds(1))

        #expect(fixture.request(for: task) != nil)
    }

    @Test("The morning notification counts the loose ends and names the longest open, in the CARRY category (#518, #551)")
    @MainActor func carriedMorningNotification() async throws {
        let fixture = try Fixture()
        let a = try carriedTask(fixture, "Steuerbescheid ablegen")
        let b = try carriedTask(fixture, "Hecke schneiden")

        await fixture.center.reschedule()

        // Each day has a morning and an evening one now (#518): pick the morning one.
        let mornings = fixture.recorder.pending.values.filter { $0.content.categoryIdentifier == CarryReminders.categoryIdentifier }
        let tomorrowMorning = try #require(mornings.first { fixture.fireComponents(of: $0).day == fixture.calendar.component(.day, from: fixture.tomorrow) })
        #expect(tomorrowMorning.content.categoryIdentifier == CarryReminders.categoryIdentifier)
        #expect((tomorrowMorning.content.userInfo["taskIDs"] as? [String] ?? []).isEmpty, "an invitation, not a list")
        #expect(tomorrowMorning.content.title == String(localized: "Loose ends: \(2)"))
        let named = ListFormatter.localizedString(byJoining: [a.displayTitle, b.displayTitle])
        #expect(tomorrowMorning.content.body == String(localized: "Longest open: \(named)"))
        #expect(fixture.fireComponents(of: tomorrowMorning).hour == 9)
        // The morning carries the icon's number for its day: both are in Due tomorrow (#584).
        #expect(tomorrowMorning.content.badge?.intValue == 2)
        let evenings = fixture.recorder.pending.values.filter { $0.content.categoryIdentifier == CarryReminders.eveningCategoryIdentifier }
        #expect(!evenings.isEmpty && evenings.allSatisfy { $0.content.badge == nil }, "the evening carries no number")
    }

    @Test("Morning and reminder time at the same minute: one notification with today's day-only tasks, no single one for them (#551)")
    @MainActor func morningCarriesTheDayOnlyReminders() async throws {
        let fixture = try Fixture()
        let dayOnly = try fixture.task("Steuer abgeben")
        let timed = try fixture.task("Zahnarzt anrufen", hour: 14, minute: 30)

        await fixture.center.reschedule()

        let mornings = fixture.recorder.pending.values.filter { $0.content.categoryIdentifier == CarryReminders.categoryIdentifier }
        let tomorrowMorning = try #require(mornings.first { fixture.fireComponents(of: $0).day == fixture.calendar.component(.day, from: fixture.tomorrow) })
        #expect(tomorrowMorning.content.body.hasPrefix(String(localized: "Today: \(dayOnly.displayTitle)")))
        #expect(fixture.request(for: dayOnly) == nil, "named in the morning, so no second notification at 9:00")
        #expect(fixture.request(for: timed) != nil, "a time keeps its own reminder")

        fixture.center.morningTime = DueReminders.Time(hour: 8, minute: 0)
        await fixture.center.reschedule()
        #expect(fixture.request(for: dayOnly) != nil, "different minutes: the single reminder is back")
        let eight = fixture.recorder.pending.values.first {
            $0.content.categoryIdentifier == CarryReminders.categoryIdentifier
                && fixture.fireComponents(of: $0).day == fixture.calendar.component(.day, from: fixture.tomorrow)
        }
        #expect(eight?.content.body.hasPrefix(String(localized: "Today: \(dayOnly.displayTitle)")) == false,
                "no Today line at 8:00; the longest-open line may still name the task")
    }

    @Test("Both switched off hands over no morning or evening notification, and the choice goes to iCloud")
    @MainActor func quietCarry() async throws {
        let fixture = try Fixture()
        _ = try carriedTask(fixture, "Steuerbescheid ablegen")
        #expect(fixture.center.carryMode == .both, "evening and morning while nothing is set (#518)")

        fixture.center.carryMode = .quiet
        await fixture.center.reschedule()

        #expect(!fixture.recorder.pending.keys.contains { $0.hasPrefix(CarryReminders.identifierPrefix) })
        #expect(fixture.cloud.carryModeRaw == "quiet")
    }

    @Test("A carry mode set on another device is taken over")
    @MainActor func takesTheCloudCarryMode() async throws {
        let fixture = try Fixture()
        fixture.cloud.carryModeRaw = "quiet"

        #expect(fixture.center.takeCloudTime())
        #expect(fixture.center.takeCloudTime() == false)
        #expect(fixture.center.carryMode == .quiet)
    }

    @Test("Today again from the morning notification makes the tasks due today and replans")
    @MainActor func todayAgainFromNotification() async throws {
        let fixture = try Fixture()
        let task = try carriedTask(fixture, "Steuerbescheid ablegen")

        await fixture.center.applyCarry(.today, taskIDs: [task.id.uuidString])

        let today = fixture.calendar.startOfDay(for: Date())
        #expect(task.dueDate == today)
        let thisMorning = fixture.recorder.pending.values.filter {
            $0.content.categoryIdentifier == CarryReminders.categoryIdentifier
                && fixture.fireComponents(of: $0).day == fixture.calendar.component(.day, from: today)
        }
        #expect(thisMorning.allSatisfy { !($0.content.userInfo["taskIDs"] as? [String] ?? []).contains(task.id.uuidString) },
                "due today now: it does not need a new date this morning, only from tomorrow if still open")
    }

    @Test("The evening hands over what needs a new date at 20:00 in the CARRY_EVENING category")
    @MainActor func eveningNotification() async throws {
        let fixture = try Fixture()
        let task = try fixture.task("Steuerbescheid ablegen")
        fixture.center.carryMode = .evening

        await fixture.center.reschedule()

        let evening = fixture.recorder.pending.values.filter { $0.content.categoryIdentifier == CarryReminders.eveningCategoryIdentifier }
        let request = try #require(evening.first { fixture.fireComponents(of: $0).day == fixture.calendar.component(.day, from: fixture.tomorrow) })
        #expect(fixture.fireComponents(of: request).hour == 20)
        #expect(request.content.userInfo["taskIDs"] as? [String] == [task.id.uuidString])
        #expect(request.content.title == String(localized: "Needs a new date: \(1)"))
        #expect(fixture.cloud.carryModeRaw == "evening")
    }

    @Test("A changed evening time is planned with and goes to iCloud")
    @MainActor func eveningTimeChange() async throws {
        let fixture = try Fixture()
        _ = try fixture.task("Steuerbescheid ablegen")
        fixture.center.carryMode = .evening
        fixture.center.eveningTime = DueReminders.Time(hour: 19, minute: 15)

        await fixture.center.reschedule()

        let evening = fixture.recorder.pending.values.filter { $0.content.categoryIdentifier == CarryReminders.eveningCategoryIdentifier }
        #expect(!evening.isEmpty)
        #expect(evening.allSatisfy { fixture.fireComponents(of: $0).hour == 19 && fixture.fireComponents(of: $0).minute == 15 })
        #expect(fixture.cloud.eveningMinutes == 19 * 60 + 15)
    }

    @Test("Look over hands the tasks to the look-over sheet and changes nothing")
    @MainActor func lookOver() async throws {
        let fixture = try Fixture()
        let task = try fixture.task("Steuerbescheid ablegen")
        let due = task.dueDate
        CarryReviewRequest.shared.taskIDs = []

        await fixture.center.applyCarry(.review, taskIDs: [task.id.uuidString])

        #expect(CarryReviewRequest.shared.taskIDs == [task.id])
        #expect(task.dueDate == due)
        CarryReviewRequest.shared.taskIDs = []
    }

    @Test("A changed morning time is planned with and goes to iCloud (#518)")
    @MainActor func morningTimeChange() async throws {
        let fixture = try Fixture()
        _ = try carriedTask(fixture, "Steuerbescheid ablegen")
        fixture.center.morningTime = DueReminders.Time(hour: 7, minute: 30)

        await fixture.center.reschedule()

        let mornings = fixture.recorder.pending.values.filter { $0.content.categoryIdentifier == CarryReminders.categoryIdentifier }
        #expect(!mornings.isEmpty)
        #expect(mornings.allSatisfy { fixture.fireComponents(of: $0).hour == 7 && fixture.fireComponents(of: $0).minute == 30 })
        #expect(fixture.cloud.morningMinutes == 7 * 60 + 30)
    }

    @Test("A morning time set on another device is taken over")
    @MainActor func takesTheCloudMorningTime() async throws {
        let fixture = try Fixture()
        fixture.cloud.morningMinutes = 8 * 60

        #expect(fixture.center.takeCloudTime())
        #expect(fixture.center.morningTime == DueReminders.Time(hour: 8, minute: 0))
    }

    @Test("Show in the morning notification opens Loose ends and changes nothing (#518)")
    @MainActor func showOpensLooseEnds() async throws {
        let fixture = try Fixture()
        let task = try carriedTask(fixture, "Steuerbescheid ablegen")
        let due = task.dueDate
        OpenViewRequest.shared.view = nil

        await fixture.center.applyCarry(.show, taskIDs: [task.id.uuidString])

        #expect(OpenViewRequest.shared.view == .open)
        #expect(task.dueDate == due)
        OpenViewRequest.shared.view = nil
    }

    // MARK: - #240 Schnitt 2: one category set, routing by prefix, the place reconcile

    @Test("Activating sets the categories once: DUE with Tomorrow, PLACE without, and both carry categories (AC-1, #414)")
    @MainActor func oneCategorySet() throws {
        let fixture = try Fixture()

        fixture.center.activate()

        #expect(fixture.recorder.categorySets.count == 1)
        let categories = try #require(fixture.recorder.categorySets.first)
        let actions = Dictionary(uniqueKeysWithValues: categories.map { ($0.identifier, $0.actions.map(\.identifier)) })
        #expect(actions == [
            DueReminders.categoryIdentifier: ["DUE_DONE", "DUE_NEXT", "DUE_TOMORROW"],
            PlaceNotifications.categoryIdentifier: ["DUE_DONE", "DUE_NEXT"],
            CarryReminders.categoryIdentifier: ["CARRY_SHOW"],
            CarryReminders.eveningCategoryIdentifier: ["CARRY_TOMORROW", "CARRY_REVIEW"],
        ])
    }

    @Test("Tapping a place notification marks the task, saves, and opens it — without any place center (AC-3, AC-4)")
    @MainActor func tapOnPlaceMarksAndOpens() async throws {
        let fixture = try Fixture()
        let task = try fixture.placed("Drucker abholen")
        OpenTaskRequest.shared.taskID = nil

        await fixture.center.respond(
            identifier: "place_" + task.id.uuidString,
            actionRaw: UNNotificationDefaultActionIdentifier,
            taskID: task.id.uuidString
        )

        #expect(task.placeRemindedAt != nil)
        #expect(fixture.store.context.hasChanges == false, "the mark is saved")
        #expect(OpenTaskRequest.shared.taskID == task.id)
        OpenTaskRequest.shared.taskID = nil
    }

    @Test("Complete and Next up on a place notification act and mark; Tomorrow changes nothing there (AC-4)")
    @MainActor func buttonsOnPlace() async throws {
        let fixture = try Fixture()
        let done = try fixture.placed("Drucker abholen")
        let next = try fixture.placed("Papier kaufen")
        let tomorrow = try fixture.placed("Pflanzen gießen")
        let due = tomorrow.dueDate

        await fixture.center.respond(identifier: "place_" + done.id.uuidString, actionRaw: "DUE_DONE", taskID: done.id.uuidString)
        await fixture.center.respond(identifier: "place_" + next.id.uuidString, actionRaw: "DUE_NEXT", taskID: next.id.uuidString)
        await fixture.center.respond(identifier: "place_" + tomorrow.id.uuidString, actionRaw: "DUE_TOMORROW", taskID: tomorrow.id.uuidString)

        #expect(done.status == .done)
        #expect(done.placeRemindedAt != nil)
        #expect(next.nextRank != nil)
        #expect(next.placeRemindedAt != nil)
        #expect(tomorrow.dueDate == due)
        #expect(tomorrow.status == .active)
        #expect(tomorrow.placeRemindedAt != nil)
    }

    @Test("A due notification keeps its path and never sets the place mark (AC-3)")
    @MainActor func dueKeepsItsPath() async throws {
        let fixture = try Fixture()
        let task = try fixture.placed("Drucker abholen")

        await fixture.center.respond(identifier: "due_" + task.id.uuidString, actionRaw: "DUE_DONE", taskID: task.id.uuidString)

        #expect(task.status == .done)
        #expect(task.placeRemindedAt == nil)
    }

    @Test("A place notification in front marks its task in its own task; a due one does not (AC-5)")
    @MainActor func presentMarks() async throws {
        let fixture = try Fixture()
        let task = try fixture.placed("Drucker abholen")
        #expect(DueNotificationCenter.presentationOptions == [.banner, .list, .sound])

        let dueMark = fixture.center.present(identifier: "due_" + task.id.uuidString, taskID: task.id.uuidString)
        #expect(dueMark == nil)
        #expect(task.placeRemindedAt == nil)

        let placeMark = try #require(fixture.center.present(identifier: "place_" + task.id.uuidString, taskID: task.id.uuidString))
        await placeMark.value
        #expect(task.placeRemindedAt != nil)
        #expect(fixture.store.context.hasChanges == false, "the mark is saved")
    }

    @Test("Every reschedule runs the place reconcile after the due run, which still completes (AC-9)")
    @MainActor func rescheduleRunsThePlaceReconcile() async throws {
        let spy = PlaceSpy()
        let fixture = try Fixture(places: spy)
        // With a time: at 9:00 the morning would carry a day-only task itself (#551).
        let task = try fixture.task("Steuer abgeben", hour: 14)

        await fixture.center.reschedule()

        #expect(spy.runs == 1)
        #expect(fixture.request(for: task) != nil)
        #expect(fixture.recorder.badge != nil)
    }

    // MARK: - #240 AC-2, AC-5: the delegate's callback variants, called as the system calls them

    /// What the completion handlers saw; they run on the main thread, like the system's.
    final class Calls: @unchecked Sendable {
        var count = 0
        var options: [UNNotificationPresentationOptions] = []
        var markSetAtCompletion: [Bool] = []
    }

    /// `UNNotification` and `UNNotificationResponse` have no public initializer; the usual test route
    /// is the `NSCoding` initializer with an empty archiver, then the properties by key-value coding.
    /// An unarchiver over an empty archive: every key decodes to nil (an archiver as coder throws on decode).
    static func emptyCoder() throws -> NSKeyedUnarchiver {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        let coder = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        coder.requiresSecureCoding = false
        return coder
    }

    static func notification(identifier: String, taskID: UUID) throws -> UNNotification {
        let content = UNMutableNotificationContent()
        content.userInfo = ["taskID": taskID.uuidString]
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        let notification = try #require(UNNotification(coder: try emptyCoder()))
        notification.setValue(request, forKey: "request")
        return notification
    }

    static func response(identifier: String, taskID: UUID, action: String) throws -> UNNotificationResponse {
        let response = try #require(UNNotificationResponse(coder: try emptyCoder()))
        response.setValue(try notification(identifier: identifier, taskID: taskID), forKey: "notification")
        response.setValue(action, forKey: "actionIdentifier")
        return response
    }

    /// The mark is set in a main-actor task after `willPresent` returns; give it a bounded moment.
    @MainActor static func waitForMark(on task: TaskItem) async throws {
        for _ in 0..<100 where task.placeRemindedAt == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("didReceive (callback variant) answers a place tap, then calls its completion exactly once (AC-2)")
    @MainActor func didReceiveCallsCompletionOnce() async throws {
        let fixture = try Fixture()
        let task = try fixture.placed("Drucker abholen")
        let response = try Self.response(
            identifier: "place_" + task.id.uuidString, taskID: task.id, action: UNNotificationDefaultActionIdentifier
        )
        let calls = Calls()
        OpenTaskRequest.shared.taskID = nil

        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            fixture.center.userNotificationCenter(.current(), didReceive: response) {
                calls.count += 1
                done.resume()
            }
        }

        #expect(response.actionIdentifier == UNNotificationDefaultActionIdentifier)
        #expect(response.notification.request.identifier == "place_" + task.id.uuidString)
        #expect(response.notification.request.content.userInfo["taskID"] as? String == task.id.uuidString)
        #expect(calls.count == 1)
        #expect(task.placeRemindedAt != nil, "the work is done before the completion")
        #expect(fixture.store.context.hasChanges == false, "the mark is saved")
        // Opening is not asserted here: in the test host the app's `ContentView` observes `OpenTaskRequest.shared`
        // and consumes it (sets it back to nil) while this test waits for the completion; `tapOnPlaceMarksAndOpens`
        // covers the opening.
        OpenTaskRequest.shared.taskID = nil
    }

    @Test("willPresent (callback variant): completion once with banner, list, sound, before the mark; mark after (AC-2, AC-5)")
    @MainActor func willPresentCompletesBeforeTheMark() async throws {
        let fixture = try Fixture()
        let task = try fixture.placed("Drucker abholen")
        let notification = try Self.notification(identifier: "place_" + task.id.uuidString, taskID: task.id)
        let calls = Calls()

        fixture.center.userNotificationCenter(.current(), willPresent: notification) { options in
            calls.count += 1
            calls.options.append(options)
            calls.markSetAtCompletion.append(task.placeRemindedAt != nil)
        }

        #expect(calls.count == 1)
        #expect(calls.options == [[.banner, .list, .sound]])
        #expect(calls.markSetAtCompletion == [false], "the completion does not wait for the mark")
        try await Self.waitForMark(on: task)
        #expect(task.placeRemindedAt != nil)
        #expect(fixture.store.context.hasChanges == false, "the mark is saved")
        #expect(calls.count == 1)
    }

    @Test("willPresent of a due reminder completes once and never sets the place mark (AC-5)")
    @MainActor func willPresentDueLeavesTheMark() async throws {
        let fixture = try Fixture()
        let task = try fixture.placed("Drucker abholen")
        let notification = try Self.notification(identifier: "due_" + task.id.uuidString, taskID: task.id)
        let calls = Calls()

        fixture.center.userNotificationCenter(.current(), willPresent: notification) { options in
            calls.count += 1
            calls.options.append(options)
        }
        try await Task.sleep(for: .milliseconds(200))

        #expect(calls.count == 1)
        #expect(calls.options == [[.banner, .list, .sound]])
        #expect(task.placeRemindedAt == nil)
    }
}
