/// The two daily notifications around the loose ends (#414, rewritten #518, Henning 2026-10-17: "Abends
/// daran erinnert werden, neue Termine zu planen, und morgens mir die losen Enden anschauen"). Evening:
/// what needs a new date. Morning: an invitation to look at the loose ends. Each one is switched on
/// its own in the settings, both on by default. Pure planning and handling; `DueNotificationCenter`
/// talks to the system.
enum CarryReminders {
    static let categoryIdentifier = "CARRY"
    static let eveningCategoryIdentifier = "CARRY_EVENING"
    static let identifierPrefix = "carry_"
    /// A task left without a new date is in the evening notification on this many days after its
    /// day, then once a week on `weeklyWeekday`, until it has a new date, is parked or done.
    static let dailyDays = 3
    /// Monday, in `Calendar` numbering.
    static let weeklyWeekday = 2
    /// Planned this many days ahead, so the next Monday is always in; every save replans.
    static let daysAhead = 7
    /// "Longest open" in the morning names this many tasks.
    static let longestNamed = 2
    static let eveningStandard = DueReminders.Time(hour: 20, minute: 0)

    /// Which of the two notifications are on. Stored as one word, so the old setting carries over:
    /// "morning" and "evening" keep their one notification, "quiet" none.
    enum Mode: String, CaseIterable, Sendable {
        case quiet
        case morning
        case evening
        case both

        static let standard = Mode.both

        /// The stored form; anything unknown falls back to the standard.
        init(stored: String?) {
            self = stored.flatMap(Mode.init(rawValue:)) ?? .standard
        }

        init(morning: Bool, evening: Bool) {
            switch (morning, evening) {
            case (true, true): self = .both
            case (true, false): self = .morning
            case (false, true): self = .evening
            case (false, false): self = .quiet
            }
        }

        var remindsMorning: Bool { self == .morning || self == .both }
        var remindsEvening: Bool { self == .evening || self == .both }
    }

    enum Action: String, CaseIterable, Sendable {
        /// "Today again" (#414): every task in the notification is due today. No longer offered;
        /// kept so a notification delivered before #518 still works.
        case today = "CARRY_TODAY"
        /// Morning, "Show": opens "Loose ends"; nothing changes.
        case show = "CARRY_SHOW"
        /// Evening, "All to tomorrow": every task in the notification is due tomorrow.
        case tomorrow = "CARRY_TOMORROW"
        /// Evening, "Look over": opens the sheet to give each one a new date.
        case review = "CARRY_REVIEW"
    }

    struct Reminder: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            /// "Loose ends: N" at the reminder time.
            case morning
            /// "Needs a new date: N" at the evening time.
            case evening
        }

        let kind: Kind
        let day: Date
        let fireDate: Date
        /// What needs a new date that day.
        let taskIDs: [UUID]
        let titles: [String]
        /// Morning: every loose end, as "Loose ends" counts them.
        var openCount = 0
        /// Morning: the longest open, named when nothing needs a new date.
        var longestOpen: [String] = []
        /// One per day and kind: `carry_2026-03-13`, `carry_evening_2026-03-13`.
        let identifier: String
    }

    /// One reminder per coming day and switched-on kind. Planned ahead as if nothing changes; every
    /// save replans, so a task done, parked or given a new date meanwhile drops out.
    static func plan(
        for tasks: [TaskItem],
        mode: Mode,
        time: DueReminders.Time = .standard,
        eveningTime: DueReminders.Time = eveningStandard,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        let dated = tasks.filter { $0.parent == nil && $0.isOpen && !$0.isBlocked && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        let loose = ViewRules.tasks(for: .open, in: tasks, now: now, calendar: calendar)
        let longest = loose.filter { $0.status != .parked }
            .sorted { $0.capturedAt < $1.capturedAt }
            .prefix(longestNamed).map(\.displayTitle)
        let today = calendar.startOfDay(for: now)
        var reminders: [Reminder] = []
        for offset in 0...daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let since = { (task: TaskItem) -> Int in
                calendar.dateComponents([.day], from: calendar.startOfDay(for: task.dueDate ?? day), to: day).day ?? -1
            }
            let stamp = Self.stamp(day, calendar: calendar)
            if mode.remindsMorning, !loose.isEmpty, let fire = fireDate(time, on: day, after: now, calendar: calendar) {
                let left = dated.filter { since($0) > 0 }
                reminders.append(Reminder(kind: .morning, day: day, fireDate: fire, taskIDs: left.map(\.id),
                                          titles: left.map(\.displayTitle), openCount: loose.count,
                                          longestOpen: Array(longest), identifier: identifierPrefix + stamp))
            }
            if mode.remindsEvening, let fire = fireDate(eveningTime, on: day, after: now, calendar: calendar) {
                let due = dated.filter { comesBack(since: since($0), on: day, calendar: calendar) }
                if !due.isEmpty {
                    reminders.append(Reminder(kind: .evening, day: day, fireDate: fire, taskIDs: due.map(\.id),
                                              titles: due.map(\.displayTitle), identifier: identifierPrefix + "evening_" + stamp))
                }
            }
        }
        return reminders
    }

    /// In the evening: due that day, then daily up to `dailyDays` days after, then on Mondays.
    static func comesBack(since: Int, on day: Date, calendar: Calendar) -> Bool {
        if since >= 0, since <= dailyDays { return true }
        return since > dailyDays && calendar.component(.weekday, from: day) == weeklyWeekday
    }

    private static func fireDate(_ time: DueReminders.Time, on day: Date, after now: Date, calendar: Calendar) -> Date? {
        guard let fire = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day), fire > now else { return nil }
        return fire
    }

    private static func stamp(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
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
