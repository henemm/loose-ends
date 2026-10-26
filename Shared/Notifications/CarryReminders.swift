import Foundation

/// The two daily notifications around the loose ends (#414, rewritten #518, Henning 2026-10-17: "Abends
/// daran erinnert werden, neue Termine zu planen, und morgens mir die losen Enden anschauen"). Evening:
/// what needs a new date. Morning: an invitation to look at the loose ends, nothing more (#551): the
/// number of what needs a new date belongs to the evening alone, so the morning never nags about what
/// the evening lets rest until Monday. Each one is switched on its own in the settings, both on by
/// default. Pure planning and handling; `DueNotificationCenter` talks to the system.
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
    /// The morning has its own time, like the evening (Henning, 2026-10-18); 9:00 like the reminder time.
    static let morningStandard = DueReminders.Time(hour: 9, minute: 0)

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
            /// "Loose ends: N" at the morning time.
            case morning
            /// "Needs a new date: N" at the evening time.
            case evening
        }

        let kind: Kind
        let day: Date
        let fireDate: Date
        /// Evening: what needs a new date that day. Morning: empty, it is an invitation only (#551).
        let taskIDs: [UUID]
        let titles: [String]
        /// Morning: every loose end one can act on: not done, not parked, not waiting on anyone (#551).
        var openCount = 0
        /// Morning: the longest open among them.
        var longestOpen: [String] = []
        /// Morning, when its time is the reminder time (#551): the day-only tasks due that day, which
        /// then come in this one notification instead of one each.
        var today: [String] = []
        /// Morning: the number for the app icon on its day (#584, `ViewRules.badgeCount` as of the morning),
        /// so the icon turns over with the day without an app start. The evening carries none.
        var badge: Int?
        /// One per day and kind: `carry_2026-03-13`, `carry_evening_2026-03-13`.
        let identifier: String
    }

    /// Whether the morning carries today's day-only tasks (#551, Henning 2026-10-18: "gleiche Minute,
    /// eine Mitteilung"): only while it is switched on and its time is the reminder time. Then
    /// `DueReminders` plans no single reminder for a task without a time.
    static func mergesReminders(mode: Mode, time: DueReminders.Time, reminderTime: DueReminders.Time) -> Bool {
        mode.remindsMorning && time == reminderTime
    }

    /// The longest open by `ViewRules.openSince` (#701), only those without a date ahead: a task with a
    /// date is planned, not loose; once its deadline passed (#548) it can be named again.
    static func longestOpen(_ byAge: [TaskItem], at fire: Date, calendar: Calendar = .current) -> [String] {
        byAge.filter { $0.dueDate == nil || NewDateRule.needsNewDate($0, now: fire, calendar: calendar) }
            .prefix(longestNamed).map(\.displayTitle)
    }

    /// One reminder per coming day and switched-on kind. Planned ahead as if nothing changes; every
    /// save replans, so a task done, parked or given a new date meanwhile drops out.
    /// The evening asks only once a deadline is behind (#550, Henning 2026-10-18: "erst nach der
    /// Uhrzeit"): a due time after it passed, a day-only date after the reminder time of its day
    /// (`NewDateRule.deadline`). A deadline later than the evening comes the next evening. Subtasks
    /// count like tasks.
    static func plan(
        for tasks: [TaskItem],
        mode: Mode,
        time: DueReminders.Time = morningStandard,
        eveningTime: DueReminders.Time = eveningStandard,
        reminderTime: DueReminders.Time = .standard,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Reminder] {
        let withDeadline = tasks.filter { $0.isOpen && !$0.isBlocked && $0.dueDate != nil }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        // The morning counts what one can act on (#551): "Loose ends" holds parked tasks too, the number does not.
        let loose = ViewRules.tasks(for: .open, in: tasks, now: now, calendar: calendar)
            .filter { $0.status != .parked && !$0.isBlocked }
        let byAge = loose.sorted { ViewRules.openSince($0) < ViewRules.openSince($1) }
        let merges = mergesReminders(mode: mode, time: time, reminderTime: reminderTime)
        let today = calendar.startOfDay(for: now)
        var reminders: [Reminder] = []
        for offset in 0...daysAhead {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let stamp = Self.stamp(day, calendar: calendar)
            if mode.remindsMorning, !loose.isEmpty, let fire = fireDate(time, on: day, after: now, calendar: calendar) {
                let dueThatDay = merges
                    ? withDeadline.filter { !$0.dueHasTime && calendar.isDate($0.dueDate ?? .distantPast, inSameDayAs: day) }
                    : []
                reminders.append(Reminder(kind: .morning, day: day, fireDate: fire, taskIDs: [], titles: [],
                                          openCount: loose.count,
                                          longestOpen: longestOpen(byAge, at: fire, calendar: calendar),
                                          today: dueThatDay.map(\.displayTitle),
                                          badge: ViewRules.badgeCount(in: tasks, now: fire, calendar: calendar),
                                          identifier: identifierPrefix + stamp))
            }
            if mode.remindsEvening, let fire = fireDate(eveningTime, on: day, after: now, calendar: calendar) {
                let due = withDeadline.filter { task in
                    guard let deadline = NewDateRule.deadline(of: task, reminderTime: reminderTime, calendar: calendar),
                          deadline < fire else { return false }
                    let behind = calendar.dateComponents([.day], from: calendar.startOfDay(for: deadline), to: day).day ?? -1
                    return comesBack(since: behind, on: day, calendar: calendar)
                }
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

    /// "Today again" or "All to tomorrow": each listed task that still exists and still needs a new
    /// date moves, as a user revision like "Tomorrow" in the due notification. A task given a new date
    /// meanwhile, on another device or from an older notification, stays where it was put (#550).
    /// Returns how many moved.
    @discardableResult
    static func handle(
        _ action: Action,
        taskIDs: [UUID],
        in tasks: [TaskItem],
        contexts: [TaskContext],
        projects: [Project],
        reminderTime: DueReminders.Time = .standard,
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
        let open = tasks.filter {
            ids.contains($0.id) && NewDateRule.passed($0, reminderTime: reminderTime, now: now, calendar: calendar)
        }
        for task in open {
            TaskActions.move(task, to: target, contexts: contexts, projects: projects, now: now, calendar: calendar)
        }
        return open.count
    }
}
