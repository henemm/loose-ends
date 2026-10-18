import Foundation
import UserNotifications

/// The one notification kind in v1 (data model doc, "Mitteilungen"): a task with a due time is
/// reminded at that time ("Due now"), a task with only a due day on that day at the reminder time
/// from the settings ("Due today", #311). For every open task: the rules set the due date without
/// the model, sorted or not (#352). Three actions, none opens the app.
/// Pure planning and handling; `DueNotificationCenter` talks to the system.
enum DueReminders {
    static let categoryIdentifier = "DUE"
    static let identifierPrefix = "due_"

    enum Action: String, CaseIterable, Sendable {
        case done = "DUE_DONE"
        case next = "DUE_NEXT"
        case tomorrow = "DUE_TOMORROW"
    }

    /// The time of day for tasks without a due time (#311), one value on every device.
    struct Time: Equatable, Sendable {
        static let standard = Time(hour: 9, minute: 0)

        let hour: Int
        let minute: Int

        init(hour: Int, minute: Int) {
            self.hour = min(max(hour, 0), 23)
            self.minute = min(max(minute, 0), 59)
        }

        /// The stored form: minutes since midnight. Anything out of range falls back to the standard.
        init(minutesSinceMidnight: Int?) {
            let minutes = minutesSinceMidnight.flatMap { (0..<24 * 60).contains($0) ? $0 : nil }
                ?? Time.standard.minutesSinceMidnight
            self.init(hour: minutes / 60, minute: minutes % 60)
        }

        var minutesSinceMidnight: Int { hour * 60 + minute }
    }

    struct Reminder: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            /// At the task's own due time.
            case now
            /// On the due day at the reminder time.
            case today
        }

        let taskID: UUID
        let title: String
        let fireDate: Date
        let kind: Kind

        var identifier: String { DueReminders.identifierPrefix + taskID.uuidString }
    }

    /// iOS keeps at most 64 pending notifications per app. The single reminders take at most this
    /// many, the soonest first, so the morning and evening ones (`CarryReminders`, two a day for eight
    /// days) and the places (at most 20) always fit (#518).
    static let maxPlanned = 28

    /// One reminder per open task with a due date whose reminder time is still ahead, the soonest
    /// `maxPlanned`. Unsorted and unchecked tasks count: the rules set their date without the model
    /// (#95, #144), and without Apple Intelligence a task stays unsorted for good (#352). Parked and
    /// done ones do not. With `skipsDayOnly` the tasks without a time get none: the morning
    /// notification names them at the same minute (#551).
    static func plan(
        for tasks: [TaskItem],
        time: Time = .standard,
        skipsDayOnly: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        tasks.compactMap { task -> Reminder? in
            guard task.isOpen, let due = task.dueDate, task.dueHasTime || !skipsDayOnly else { return nil }
            let kind: Reminder.Kind = task.dueHasTime ? .now : .today
            let fire = kind == .now
                ? due
                : calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: due) ?? due
            guard fire > now else { return nil }
            return Reminder(taskID: task.id, title: task.displayTitle, fireDate: fire, kind: kind)
        }
        .sorted { $0.fireDate < $1.fireDate }
        .prefix(maxPlanned)
        .map { $0 }
    }

    /// The task a tap on the notification itself opens (#331), the same way as a title in the
    /// "Next up" widget. The three actions and the dismissal open nothing.
    static func taskToOpen(actionIdentifier: String, taskID: String?) -> UUID? {
        guard actionIdentifier == UNNotificationDefaultActionIdentifier, let taskID else { return nil }
        return UUID(uuidString: taskID)
    }

    /// Applies a notification action. Returns false when the task no longer exists.
    @discardableResult
    static func handle(
        _ action: Action,
        taskID: UUID,
        in tasks: [TaskItem],
        contexts: [TaskContext],
        projects: [Project],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return false }
        switch action {
        case .done:
            TaskActions.complete(task, now: now, calendar: calendar)
        case .next:
            if task.nextRank == nil { TaskActions.toggleNext(task, among: tasks) }
        case .tomorrow:
            TaskActions.move(task, to: .tomorrow, contexts: contexts, projects: projects, now: now, calendar: calendar)
        }
        return true
    }
}
