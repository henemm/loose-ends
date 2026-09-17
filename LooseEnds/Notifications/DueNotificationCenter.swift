import Foundation
import OSLog
import SwiftData
import UserNotifications

/// Talks to the system for `DueReminders`: registers the category with its three actions, mirrors
/// the plan into pending requests after every save, and applies an action when the user taps one.
/// Silent under tests, where a permission prompt would block the run.
@MainActor
final class DueNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    private let container: ModelContainer
    private var debounce: Task<Void, Never>?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Notifications")

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
            let reminders = DueReminders.plan(for: tasks)
            let stale = await center.pendingNotificationRequests()
                .map(\.identifier)
                .filter { $0.hasPrefix(DueReminders.identifierPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for reminder in reminders {
                try await center.add(Self.request(for: reminder))
            }
        } catch {
            Self.logger.error("Scheduling due reminders failed: \(error, privacy: .public)")
        }
    }

    private static func request(for reminder: DueReminders.Reminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = String(localized: "Due today")
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
