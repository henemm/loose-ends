import Foundation
import OSLog
import SwiftData
import UserNotifications

/// Talks to the system for `DueReminders`: registers both categories (due and place, #240), mirrors
/// the plan into pending requests after every save, sets the app badge (#299), and applies an
/// action when the user taps one. The only notification delegate; `place_` responses mark their task.
/// Holds the reminder time for tasks without a due time (#311): kept in `UserDefaults` and mirrored
/// to the iCloud key-value store, so a change on one device reschedules the others.
/// Silent under tests, where a permission prompt would block the run; unit tests hand in a
/// recording `DueScheduling` and their own stores instead (#328). The notification UI test (#295)
/// lets it run with `--ui-testing-notifications` while the store stays in memory; the banner itself
/// comes from `simctl push`, because `add` from the app fails in the iOS 27 Simulator.
@MainActor
final class DueNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    private let container: ModelContainer
    /// Nil under tests unless one is handed in: then nothing reaches the system.
    private let scheduler: (any DueScheduling)?
    private let defaults: UserDefaults
    private let cloud: any ReminderTimeCloud
    /// The place reconcile (#240), iOS only; nil on the Mac and in tests that do not hand one in.
    private let places: (any PlaceReconciling)?
    private var debounce: Task<Void, Never>?
    private var cloudObserver: (any NSObjectProtocol)?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Notifications")
    static let timeKey = "dueReminderMinutes"
    static let carryKey = "carryMode"
    static let eveningKey = "eveningReminderMinutes"

    private static var suppressed: Bool {
        ModelContainerFactory.isRunningTests || (ModelContainerFactory.isUITesting && !isNotificationUITest)
    }

    private static var isNotificationUITest: Bool {
        ModelContainerFactory.isUITesting && ProcessInfo.processInfo.arguments.contains("--ui-testing-notifications")
    }

    init(
        container: ModelContainer,
        scheduler: (any DueScheduling)? = nil,
        defaults: UserDefaults = .standard,
        cloud: any ReminderTimeCloud = NSUbiquitousKeyValueStore.default,
        places: (any PlaceReconciling)? = nil
    ) {
        self.container = container
        if let scheduler {
            self.scheduler = scheduler
        } else {
            self.scheduler = Self.suppressed ? nil : SystemDueScheduler()
        }
        self.defaults = defaults
        self.cloud = cloud
        self.places = places
        super.init()
    }

    /// Call once at launch, before the first notification response can arrive.
    /// All categories go in one call (#240: due and place, #414: carry and evening): every call
    /// replaces the earlier set.
    func activate() {
        scheduler?.setNotificationCategories(NotificationCategories.all().union([Self.carryCategory, Self.eveningCategory]))
        guard !Self.suppressed else { return }
        UNUserNotificationCenter.current().delegate = self
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.takeCloudTime() }
        }
        NSUbiquitousKeyValueStore.default.synchronize()
        takeCloudTime()
    }

    /// The time of day for tasks without a due time; changing it reschedules every reminder.
    var reminderTime: DueReminders.Time {
        get { DueReminders.Time(minutesSinceMidnight: defaults.object(forKey: Self.timeKey) as? Int) }
        set {
            defaults.set(newValue.minutesSinceMidnight, forKey: Self.timeKey)
            cloud.setReminderMinutes(newValue.minutesSinceMidnight)
            rescheduleSoon()
        }
    }

    /// What happens to a task still open after its day (#414); travels like the reminder time.
    var carryMode: CarryReminders.Mode {
        get { CarryReminders.Mode(stored: defaults.string(forKey: Self.carryKey)) }
        set {
            defaults.set(newValue.rawValue, forKey: Self.carryKey)
            cloud.setCarryMode(newValue.rawValue)
            rescheduleSoon()
        }
    }

    /// The time of the evening look (#414 Schnitt 3); travels like the reminder time.
    var eveningTime: DueReminders.Time {
        get {
            guard let minutes = defaults.object(forKey: Self.eveningKey) as? Int else { return CarryReminders.eveningStandard }
            return DueReminders.Time(minutesSinceMidnight: minutes)
        }
        set {
            defaults.set(newValue.minutesSinceMidnight, forKey: Self.eveningKey)
            cloud.setEveningMinutes(newValue.minutesSinceMidnight)
            rescheduleSoon()
        }
    }

    /// Another device set a time or a carry mode (or this launch is the first to see it): take it
    /// over locally. Returns whether a local value changed.
    @discardableResult
    func takeCloudTime() -> Bool {
        var changed = false
        if let minutes = cloud.reminderMinutes, minutes != defaults.object(forKey: Self.timeKey) as? Int {
            defaults.set(minutes, forKey: Self.timeKey)
            changed = true
        }
        if let mode = cloud.carryModeRaw, mode != defaults.string(forKey: Self.carryKey) {
            defaults.set(mode, forKey: Self.carryKey)
            changed = true
        }
        if let minutes = cloud.eveningMinutes, minutes != defaults.object(forKey: Self.eveningKey) as? Int {
            defaults.set(minutes, forKey: Self.eveningKey)
            changed = true
        }
        if changed { rescheduleSoon() }
        return changed
    }

    func requestAuthorization() async {
        guard !Self.suppressed else { return }
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Self.logger.error("Notification authorization failed: \(error, privacy: .public)")
        }
    }

    /// Saves come in bursts (enrichment writes per task); one reschedule shortly after the last.
    func rescheduleSoon() {
        guard scheduler != nil else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            await self?.reschedule()
        }
    }

    /// Replaces every pending due reminder with the current plan, then reconciles the places (#240).
    func reschedule() async {
        await rescheduleDue()
        await places?.reconcile()
    }

    private func rescheduleDue() async {
        guard let scheduler else { return }
        do {
            let tasks = try container.mainContext.fetch(FetchDescriptor<TaskItem>())
            let reminders = DueReminders.plan(for: tasks, time: reminderTime)
            let carried = CarryReminders.plan(for: tasks, mode: carryMode, time: reminderTime, eveningTime: eveningTime)
            let stale = await scheduler.pendingIdentifiers()
                .filter { $0.hasPrefix(DueReminders.identifierPrefix) || $0.hasPrefix(CarryReminders.identifierPrefix) }
            scheduler.remove(stale)
            // The bundled ones first, and one failing request does not cost the rest (#518): the
            // morning notification stayed away while a single reminder before it failed.
            let requests = carried.map { Self.request(for: $0) } + reminders.map { Self.request(for: $0) }
            for request in requests {
                do {
                    try await scheduler.add(request)
                } catch {
                    Self.logger.error("Scheduling \(request.identifier, privacy: .public) failed: \(error, privacy: .public)")
                }
            }
            await updateBadge(for: tasks, with: scheduler)
        } catch {
            Self.logger.error("Scheduling due reminders failed: \(error, privacy: .public)")
        }
    }

    /// The number on the app icon (#299): "Next up" plus "Due today", each task once. Set with
    /// every reschedule, so after every save and whenever the app comes to the front; a day that
    /// turns over while the app is closed shows on the icon at the next launch.
    private func updateBadge(for tasks: [TaskItem], with scheduler: any DueScheduling) async {
        do {
            try await scheduler.setBadgeCount(ViewRules.badgeCount(in: tasks))
        } catch {
            Self.logger.error("Setting the app badge failed: \(error, privacy: .public)")
        }
    }

    private static func request(for reminder: DueReminders.Reminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        switch reminder.kind {
        case .now: content.body = String(localized: "Due now")
        case .today: content.body = String(localized: "Due today")
        }
        content.sound = .default
        content.categoryIdentifier = DueReminders.categoryIdentifier
        content.userInfo = ["taskID": reminder.taskID.uuidString]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }

    /// The morning after or the evening of the day (#414): one notification for every task still open.
    private static func request(for reminder: CarryReminders.Reminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        switch reminder.kind {
        case .morning:
            content.title = String(localized: "Still open: \(reminder.taskIDs.count)")
            content.categoryIdentifier = CarryReminders.categoryIdentifier
        case .evening:
            content.title = String(localized: "Loose ends from today: \(reminder.taskIDs.count)")
            content.categoryIdentifier = CarryReminders.eveningCategoryIdentifier
        }
        content.body = ListFormatter.localizedString(byJoining: reminder.titles)
        content.sound = .default
        content.userInfo = ["taskIDs": reminder.taskIDs.map(\.uuidString)]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }

    /// "Today again" stays in the notification; "Show" opens the app on its start screen.
    private static var carryCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: CarryReminders.categoryIdentifier,
            actions: [
                UNNotificationAction(identifier: CarryReminders.Action.today.rawValue, title: String(localized: "Today again"), options: []),
                UNNotificationAction(identifier: CarryReminders.Action.show.rawValue, title: String(localized: "Show"), options: [.foreground]),
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    /// "All to tomorrow" stays in the notification; "Look over" opens the look-over sheet.
    private static var eveningCategory: UNNotificationCategory {
        UNNotificationCategory(
            identifier: CarryReminders.eveningCategoryIdentifier,
            actions: [
                UNNotificationAction(identifier: CarryReminders.Action.tomorrow.rawValue, title: String(localized: "All to tomorrow"), options: []),
                UNNotificationAction(identifier: CarryReminders.Action.review.rawValue, title: String(localized: "Look over"), options: [.foreground]),
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Callback variants, not async (#295): the async bridge called the system's completion from the
    // cooperative pool and the app aborted on tap; the completion has to come from the main thread.
    // `@Sendable` because the handler crosses into the main-actor task (the SDK leaves it unannotated).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let actionRaw = response.actionIdentifier
        let taskID = response.notification.request.content.userInfo["taskID"] as? String
        let taskIDs = response.notification.request.content.userInfo["taskIDs"] as? [String] ?? []
        // A tap on the evening notification itself opens the look-over too.
        let tappedEvening = actionRaw == UNNotificationDefaultActionIdentifier
            && response.notification.request.content.categoryIdentifier == CarryReminders.eveningCategoryIdentifier
        let isPlace = identifier.hasPrefix(PlaceReminders.identifierPrefix)
        Task { @MainActor in
            if !isPlace, let carry = tappedEvening ? CarryReminders.Action.review : CarryReminders.Action(rawValue: actionRaw) {
                await applyCarry(carry, taskIDs: taskIDs)
            } else {
                await respond(identifier: identifier, actionRaw: actionRaw, taskID: taskID)
            }
            completionHandler()
        }
    }

    /// The completion comes at once; marking a place notification (#240) runs in its own task after it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let identifier = notification.request.identifier
        let taskID = notification.request.content.userInfo["taskID"] as? String
        completionHandler(Self.presentationOptions)
        Task { @MainActor in
            present(identifier: identifier, taskID: taskID)
        }
    }

    nonisolated static let presentationOptions: UNNotificationPresentationOptions = [.banner, .list, .sound]

    /// Routes by identifier alone (#240): `place_` marks the task, applies a button and opens on a tap;
    /// every other identifier takes the due path unchanged.
    func respond(identifier: String, actionRaw: String?, taskID: String?) async {
        guard identifier.hasPrefix(PlaceReminders.identifierPrefix) else {
            await apply(actionRaw: actionRaw ?? "", taskID: taskID)
            return
        }
        let changed = markPlace(identifier: identifier, actionRaw: actionRaw, taskID: taskID)
        if let actionRaw, let open = DueReminders.taskToOpen(actionIdentifier: actionRaw, taskID: taskID) {
            OpenTaskRequest.shared.taskID = open
        }
        if changed { await reschedule() }
    }

    /// A place notification shown while the app is open marks its task, once for all devices (#240).
    @discardableResult
    func present(identifier: String, taskID: String?) -> Task<Void, Never>? {
        guard identifier.hasPrefix(PlaceReminders.identifierPrefix) else { return nil }
        return Task { @MainActor [weak self] in
            self?.markPlace(identifier: identifier, actionRaw: nil, taskID: taskID)
        }
    }

    /// Mark plus button through `PlaceNotifications.respond`; saves when something changed.
    @discardableResult
    private func markPlace(identifier: String, actionRaw: String?, taskID: String?) -> Bool {
        let context = container.mainContext
        do {
            let changed = PlaceNotifications.respond(
                identifier: identifier, actionRaw: actionRaw, taskID: taskID,
                in: try context.fetch(FetchDescriptor<TaskItem>()),
                contexts: try context.fetch(FetchDescriptor<TaskContext>()),
                projects: try context.fetch(FetchDescriptor<Project>())
            )
            if changed { try context.save() }
            return changed
        } catch {
            Self.logger.error("Answering place notification failed: \(error, privacy: .public)")
            return false
        }
    }

    private func apply(actionRaw: String, taskID: String?) async {
        if let open = DueReminders.taskToOpen(actionIdentifier: actionRaw, taskID: taskID) {
            OpenTaskRequest.shared.taskID = open
            return
        }
        guard let action = DueReminders.Action(rawValue: actionRaw),
              let taskID, let id = UUID(uuidString: taskID) else { return }
        let context = container.mainContext
        do {
            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            let contexts = try context.fetch(FetchDescriptor<TaskContext>())
            let projects = try context.fetch(FetchDescriptor<Project>())
            guard DueReminders.handle(action, taskID: id, in: tasks, contexts: contexts, projects: projects) else { return }
            try context.save()
            await reschedule()
        } catch {
            Self.logger.error("Applying \(actionRaw, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}

extension DueNotificationCenter {
    /// "Today again" or "All to tomorrow" from a carry notification (#414); "Show" only brings the
    /// app forward, "Look over" opens the look-over sheet on these tasks.
    func applyCarry(_ action: CarryReminders.Action, taskIDs: [String]) async {
        let ids = taskIDs.compactMap(UUID.init(uuidString:))
        if action == .review {
            CarryReviewRequest.shared.taskIDs = ids
            return
        }
        let context = container.mainContext
        do {
            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            let contexts = try context.fetch(FetchDescriptor<TaskContext>())
            let projects = try context.fetch(FetchDescriptor<Project>())
            guard CarryReminders.handle(action, taskIDs: ids, in: tasks, contexts: contexts, projects: projects) > 0 else { return }
            try context.save()
            await reschedule()
        } catch {
            Self.logger.error("Applying \(action.rawValue, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}

/// The part of `UNUserNotificationCenter` the due reminders use (#328): the app talks to the
/// system, unit tests hand in a recorder.
@MainActor
protocol DueScheduling {
    func pendingIdentifiers() async -> [String]
    func remove(_ identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
    func setBadgeCount(_ count: Int) async throws
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
}

/// Runs after every due reschedule (#240): the place reconcile on iOS, nothing on the Mac.
@MainActor
protocol PlaceReconciling: AnyObject {
    func reconcile() async
}

/// The part of `UNUserNotificationCenter` the place reminders use (#240); unit tests hand in a recorder.
@MainActor
protocol PlaceScheduling {
    func pendingIdentifiers() async -> [String]
    func remove(_ identifiers: [String])
    func add(_ request: UNNotificationRequest) async throws
}

struct SystemDueScheduler: DueScheduling {
    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func remove(_ identifiers: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await UNUserNotificationCenter.current().add(request)
    }

    func setBadgeCount(_ count: Int) async throws {
        try await UNUserNotificationCenter.current().setBadgeCount(count)
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
}

extension SystemDueScheduler: PlaceScheduling {}

/// Where the reminder time (#311) and the carry mode (#414) travel between devices: the iCloud
/// key-value store in the app.
@MainActor
protocol ReminderTimeCloud {
    var reminderMinutes: Int? { get }
    func setReminderMinutes(_ minutes: Int)
    var carryModeRaw: String? { get }
    func setCarryMode(_ raw: String)
    var eveningMinutes: Int? { get }
    func setEveningMinutes(_ minutes: Int)
}

extension NSUbiquitousKeyValueStore: ReminderTimeCloud {
    var reminderMinutes: Int? { object(forKey: DueNotificationCenter.timeKey) as? Int }

    func setReminderMinutes(_ minutes: Int) {
        set(Int64(minutes), forKey: DueNotificationCenter.timeKey)
    }

    var carryModeRaw: String? { string(forKey: DueNotificationCenter.carryKey) }

    func setCarryMode(_ raw: String) {
        set(raw, forKey: DueNotificationCenter.carryKey)
    }

    var eveningMinutes: Int? { object(forKey: DueNotificationCenter.eveningKey) as? Int }

    func setEveningMinutes(_ minutes: Int) {
        set(Int64(minutes), forKey: DueNotificationCenter.eveningKey)
    }
}
