import Foundation

/// What happens to a task still open after its due day (#414, Henning 2026-10-14). The user picks it
/// in the settings; "Remind in the morning" is the default. Pure planning and handling;
/// `DueNotificationCenter` talks to the system.
enum CarryReminders {
    static let categoryIdentifier = "CARRY"
    static let identifierPrefix = "carry_"
    /// A task comes back on at most this many mornings after its day; then it is carried quietly.
    static let mornings = 3

    enum Mode: String, CaseIterable, Sendable {
        /// No notification; the row says how long the task has been carried.
        case quiet
        /// One bundled notification at the reminder time on the mornings after the due day.
        case morning

        static let standard = Mode.morning

        /// The stored form; anything unknown falls back to the standard.
        init(stored: String?) {
            self = stored.flatMap(Mode.init(rawValue:)) ?? .standard
        }
    }

    enum Action: String, CaseIterable, Sendable {
        /// "Today again": every task in the notification is due today.
        case today = "CARRY_TODAY"
        /// "Show": opens the app; nothing changes.
        case show = "CARRY_SHOW"
    }

    struct Reminder: Equatable, Sendable {
        let day: Date
        let fireDate: Date
        let taskIDs: [UUID]
        let titles: [String]
        /// One per morning: `carry_2026-03-13`.
        let identifier: String
    }

    /// One reminder per coming morning (today included while the time is ahead) that has open tasks
    /// whose due day lies one to `mornings` days back. Same tasks as "Due today": top level, open,
    /// not blocked; with or without a due time. Planned ahead as if nothing changes; every save
    /// replans, so a task done or moved meanwhile drops out.
    static func plan(
        for tasks: [TaskItem],
        mode: Mode,
        time: DueReminders.Time = .standard,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        guard mode == .morning else { return [] }
        let candidates = tasks.filter { $0.parent == nil && $0.isOpen && !$0.isBlocked && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        let today = calendar.startOfDay(for: now)
        return (0...mornings).compactMap { offset -> Reminder? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day),
                  fire > now else { return nil }
            let open = candidates.filter { task in
                guard let due = task.dueDate else { return false }
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: day).day ?? 0
                return (1...mornings).contains(days)
            }
            guard !open.isEmpty else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let stamp = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            return Reminder(day: day, fireDate: fire, taskIDs: open.map(\.id), titles: open.map(\.displayTitle),
                            identifier: identifierPrefix + stamp)
        }
    }

    /// "Today again": each listed task that still exists and is open is due today, as a user
    /// revision like "Tomorrow" in the due notification. Returns how many moved.
    @discardableResult
    static func handle(
        _ action: Action,
        taskIDs: [UUID],
        in tasks: [TaskItem],
        contexts: [TaskContext],
        projects: [Project],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        switch action {
        case .today:
            let ids = Set(taskIDs)
            let open = tasks.filter { ids.contains($0.id) && $0.isOpen }
            for task in open {
                TaskActions.move(task, to: .date(now), contexts: contexts, projects: projects, now: now, calendar: calendar)
            }
            return open.count
        case .show:
            return 0
        }
    }
}
