import Foundation

/// What happens to a task still open after its due day (#414, Henning 2026-10-14). The user picks it
/// in the settings; "Remind in the morning" is the default. Pure planning and handling;
/// `DueNotificationCenter` talks to the system.
enum CarryReminders {
    static let categoryIdentifier = "CARRY"
    static let eveningCategoryIdentifier = "CARRY_EVENING"
    static let identifierPrefix = "carry_"
    /// A task comes back on at most this many mornings after its day; then it is carried quietly.
    static let mornings = 3
    /// The evening look is planned this many days ahead; every save replans.
    static let eveningsAhead = 7
    static let eveningStandard = DueReminders.Time(hour: 20, minute: 0)

    enum Mode: String, CaseIterable, Sendable {
        /// No notification; the row says how long the task has been carried.
        case quiet
        /// One bundled notification at the reminder time on the mornings after the due day.
        case morning
        /// One notification at the evening time on the due day itself, to look over what is left.
        case evening

        static let standard = Mode.morning

        /// The stored form; anything unknown falls back to the standard.
        init(stored: String?) {
            self = stored.flatMap(Mode.init(rawValue:)) ?? .standard
        }
    }

    enum Action: String, CaseIterable, Sendable {
        /// Morning, "Today again": every task in the notification is due today.
        case today = "CARRY_TODAY"
        /// Morning, "Show": opens the app; nothing changes.
        case show = "CARRY_SHOW"
        /// Evening, "All to tomorrow": every task in the notification is due tomorrow.
        case tomorrow = "CARRY_TOMORROW"
        /// Evening, "Look over": opens the app on the look-over sheet; nothing changes yet.
        case review = "CARRY_REVIEW"
    }

    struct Reminder: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            /// The mornings after: "Still open: N".
            case morning
            /// The evening of the due day: "Loose ends from today: N".
            case evening
        }

        let kind: Kind
        let day: Date
        let fireDate: Date
        let taskIDs: [UUID]
        let titles: [String]
        /// One per day and kind: `carry_2026-03-13`, `carry_evening_2026-03-13`.
        let identifier: String
    }

    /// Morning: one reminder per coming morning (today included while the time is ahead) with the
    /// open tasks whose due day lies one to `mornings` days back. Evening: one reminder per coming
    /// evening with the open tasks due that day. Same tasks as "Due today": top level, open, not
    /// blocked; with or without a due time. Planned ahead as if nothing changes; every save replans,
    /// so a task done or moved meanwhile drops out.
    static func plan(
        for tasks: [TaskItem],
        mode: Mode,
        time: DueReminders.Time = .standard,
        eveningTime: DueReminders.Time = eveningStandard,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        guard mode != .quiet else { return [] }
        let (kind, at, days, back): (Reminder.Kind, DueReminders.Time, Int, ClosedRange<Int>) = mode == .evening
            ? (.evening, eveningTime, eveningsAhead, 0...0)
            : (.morning, time, mornings, 1...mornings)
        let candidates = tasks.filter { $0.parent == nil && $0.isOpen && !$0.isBlocked && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        let today = calendar.startOfDay(for: now)
        return (0...days).compactMap { offset -> Reminder? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: at.hour, minute: at.minute, second: 0, of: day),
                  fire > now else { return nil }
            let open = candidates.filter { task in
                guard let due = task.dueDate else { return false }
                let since = calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: day).day ?? -1
                return back.contains(since)
            }
            guard !open.isEmpty else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let stamp = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            return Reminder(kind: kind, day: day, fireDate: fire, taskIDs: open.map(\.id), titles: open.map(\.displayTitle),
                            identifier: identifierPrefix + (kind == .evening ? "evening_" : "") + stamp)
        }
    }

    /// "Today again" or "All to tomorrow": each listed task that still exists and is open moves, as a
    /// user revision like "Tomorrow" in the due notification. Returns how many moved.
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
        let target: TaskActions.MoveTarget
        switch action {
        case .today: target = .date(now)
        case .tomorrow: target = .tomorrow
        case .show, .review: return 0
        }
        let ids = Set(taskIDs)
        let open = tasks.filter { ids.contains($0.id) && $0.isOpen }
        for task in open {
            TaskActions.move(task, to: target, contexts: contexts, projects: projects, now: now, calendar: calendar)
        }
        return open.count
    }
}
