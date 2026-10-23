import Foundation

/// A deadline that passed is no deadline (#548, Henning 2026-10-18: "Ich habe mir vorgenommen, etwas bis
/// heute Mittag zu erledigen. Hat nicht geklappt. Nun muss ich mir eine neue Deadline überlegen, denn die
/// alte kann ich nicht mehr einhalten."). The old time stays in the revisions; the views treat it as
/// over: no red, a "New date" button with a grey trace of what was planned, until the user decides.
/// "Now" shows it (last, or by rank when lined up) and the app icon counts it, one number (#637).
/// Subtasks count like tasks. Pure rules, no model.
///
/// Two readings of "passed", on purpose: in the lists a day-only date is today's until the day ends, so
/// "Now" keeps today's tasks all day (`needsNewDate`). The evening look is the end of the day: there a
/// day-only date counts as passed after the reminder time of its day, the silent time of a task without
/// one (`passed(_:reminderTime:)`, #550). A due time is a deadline in both readings.
enum NewDateRule {
    /// What stands small and grey under the button: what had been planned.
    enum Trace: Equatable, Sendable {
        /// The deadline was today: its time, or nothing for a day-only date ("was today").
        case today(time: Date?)
        case yesterday
        /// Two to six days ago: the weekday.
        case weekday(Date)
        /// Longer ago: day and month.
        case date(Date)
    }

    /// In the lists: open, not blocked, and its deadline is behind. A due time is behind once it
    /// passed; a day-only date once its day is over.
    static func needsNewDate(_ task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard task.isOpen, !task.isBlocked, let due = task.dueDate else { return false }
        if task.dueHasTime { return due < now }
        return calendar.startOfDay(for: due) < calendar.startOfDay(for: now)
    }

    /// Every task that needs a new date, the oldest deadline first; subtasks among them.
    static func tasks(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        all.filter { needsNewDate($0, now: now, calendar: calendar) }
            .sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
    }

    /// The moment a deadline passes for the evening look (#550): the due time, or for a day-only date
    /// the reminder time of that day.
    static func deadline(of task: TaskItem, reminderTime: DueReminders.Time, calendar: Calendar = .current) -> Date? {
        guard let due = task.dueDate else { return nil }
        if task.dueHasTime { return due }
        return calendar.date(bySettingHour: reminderTime.hour, minute: reminderTime.minute, second: 0, of: due) ?? due
    }

    /// For the evening look (#550): open, not blocked, and the deadline lies before `now`. Strictly
    /// before: "erst nach der Uhrzeit" (Henning, 2026-10-18).
    static func passed(_ task: TaskItem, reminderTime: DueReminders.Time, now: Date, calendar: Calendar = .current) -> Bool {
        guard task.isOpen, !task.isBlocked, let deadline = deadline(of: task, reminderTime: reminderTime, calendar: calendar) else {
            return false
        }
        return deadline < now
    }

    /// The trace of a due date, read against today. Nil without a date.
    static func trace(of task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> Trace? {
        guard let due = task.dueDate else { return nil }
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: today).day ?? 0
        switch days {
        case ...0: return .today(time: task.dueHasTime ? due : nil)
        case 1: return .yesterday
        case 2...6: return .weekday(due)
        default: return .date(due)
        }
    }

    /// "Later today" in the date choice: the next full hour at least half an hour away, while that is
    /// still today. Nil late in the evening, and the choice does not offer it.
    static func laterToday(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let earliest = calendar.date(byAdding: .minute, value: 30, to: now) else { return nil }
        let parts = calendar.dateComponents([.hour, .minute], from: earliest)
        let hour = (parts.hour ?? 0) + ((parts.minute ?? 0) > 0 ? 1 : 0)
        guard hour <= 23, let at = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) else { return nil }
        return at
    }
}
