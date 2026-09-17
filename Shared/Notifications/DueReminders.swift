import Foundation

/// The one notification kind in v1 (data model doc, "Mitteilungen"): "Due today" on the due day
/// at the reminder hour, only for active tasks. Three actions, none opens the app. Pure planning
/// and handling; `DueNotificationCenter` talks to the system.
enum DueReminders {
    static let categoryIdentifier = "DUE"
    static let identifierPrefix = "due_"
    static let defaultHour = 9

    enum Action: String, CaseIterable, Sendable {
        case done = "DUE_DONE"
        case next = "DUE_NEXT"
        case tomorrow = "DUE_TOMORROW"
    }

    struct Reminder: Equatable, Sendable {
        let taskID: UUID
        let title: String
        let fireDate: Date

        var identifier: String { DueReminders.identifierPrefix + taskID.uuidString }
    }

    /// One reminder per active task with a due date whose reminder time is still ahead.
    static func plan(
        for tasks: [TaskItem],
        hour: Int = defaultHour,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        tasks.compactMap { task -> Reminder? in
            guard task.status == .active, let due = task.dueDate else { return nil }
            let fire = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: due) ?? due
            guard fire > now else { return nil }
            return Reminder(taskID: task.id, title: task.displayTitle, fireDate: fire)
        }
        .sorted { $0.fireDate < $1.fireDate }
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
