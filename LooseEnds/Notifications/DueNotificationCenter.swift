import Foundation
import OSLog
import SwiftData
import UserNotifications

/// Talks to the system for `DueReminders`: registers the category with its three actions, mirrors
/// the plan into pending requests after every save, sets the app badge (#299), and applies an
/// action when the user taps one.
/// Holds the reminder time for tasks without a due time (#311): kept in `UserDefaults` and mirrored
/// to the iCloud key-value store, so a change on one device reschedules the others.
/// Silent under tests, where a permission prompt would block the run.
@MainActor
final class DueNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    private let container: ModelContainer
    private var debounce: Task<Void, Never>?
    private var cloudObserver: (any NSObjectProtocol)?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Notifications")
    private static let timeKey = "dueReminderMinutes"

    private static var suppressed: Bool {
        ModelContainerFactory.isRunningTests || ModelContainerFactory.isUITesting
    }

    init(container: ModelContainer) {
        self.container = container
        super.init()
    }

    /// Call once at launch, before the first notification response can arrive.
    func activate() {
        guard !Self.suppressed else { return }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([Self.category])
        let cloud = NSUbiquitousKeyValueStore.default
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.takeCloudTime() }
        }
        cloud.synchronize()
        takeCloudTime()
    }

    /// The time of day for tasks without a due time; changing it reschedules every reminder.
    var reminderTime: DueReminders.Time {
        get { DueReminders.Time(minutesSinceMidnight: UserDefaults.standard.object(forKey: Self.timeKey) as? Int) }
        set {
            UserDefaults.standard.set(newValue.minutesSinceMidnight, forKey: Self.timeKey)
            NSUbiquitousKeyValueStore.default.set(Int64(newValue.minutesSinceMidnight), forKey: Self.timeKey)
            rescheduleSoon()
        }
    }

    /// Another device set a time (or this launch is the first to see it): take it over locally.
    private func takeCloudTime() {
        guard let minutes = NSUbiquitousKeyValueStore.default.object(forKey: Self.timeKey) as? Int,
              minutes != UserDefaults.standard.object(forKey: Self.timeKey) as? Int else { return }
        UserDefaults.standard.set(minutes, forKey: Self.timeKey)
        rescheduleSoon()
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
        guard !Self.suppressed else { return }
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

    /// Replaces every pending due reminder with the current plan.
    func reschedule() async {
        guard !Self.suppressed else { return }
        let center = UNUserNotificationCenter.current()
        do {
            let tasks = try container.mainContext.fetch(FetchDescriptor<TaskItem>())
            let reminders = DueReminders.plan(for: tasks, time: reminderTime)
            let stale = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(DueReminders.identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for reminder in reminders {
                try await center.add(Self.request(for: reminder))
            }
            await updateBadge(for: tasks)
        } catch {
            Self.logger.error("Scheduling due reminders failed: \(error, privacy: .public)")
        }
    }

    /// The number on the app icon (#299): "Next up" plus "Due today", each task once. Set with
    /// every reschedule, so after every save and whenever the app comes to the front; a day that
    /// turns over while the app is closed shows on the icon at the next launch.
    private func updateBadge(for tasks: [TaskItem]) async {
        do {
            try await UNUserNotificationCenter.current().setBadgeCount(ViewRules.badgeCount(in: tasks))
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

    private static var category: UNNotificationCategory {
        UNNotificationCategory(
            identifier: DueReminders.categoryIdentifier,
            actions: [
                UNNotificationAction(identifier: DueReminders.Action.done.rawValue, title: String(localized: "Complete"), options: []),
                UNNotificationAction(identifier: DueReminders.Action.next.rawValue, title: String(localized: "Next up"), options: []),
                UNNotificationAction(identifier: DueReminders.Action.tomorrow.rawValue, title: String(localized: "Tomorrow"), options: []),
            ],
            intentIdentifiers: [],
            options: []
        )
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionRaw = response.actionIdentifier
        let taskID = response.notification.request.content.userInfo["taskID"] as? String
        await apply(actionRaw: actionRaw, taskID: taskID)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
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
