import Foundation

/// The repetition Siri hands over in the Reminders schema (`createReminder.recurrence`, a
/// `Calendar.RecurrenceRule`, #25) mapped onto the one rule a task carries (`RepeatRule`, ADR-7).
/// Pure mapping, no intent, no model (#224).
///
/// Apple documents the type, not which forms Siri fills. So every form the type can express is
/// either mapped or named as not mappable, never cut down silently: a rule that ends after a date
/// or a count, repeats hourly, picks "the second Monday" or several months has no place in
/// `RepeatRule`, and taking half of it would repeat the task on days the user never said.
enum SiriRepeatMapping {
    /// What of a recurrence rule `RepeatRule` cannot carry.
    enum Unmappable: Hashable, Sendable {
        case frequency          // hourly, minutely
        case end                // after a date or a number of occurrences
        case calendar           // not the Gregorian calendar the app counts in
        case nthWeekday         // "the second Monday"
        case weekdaysOutsideWeek // weekdays with a monthly or yearly frequency
        case daysOfTheMonth
        case daysOfTheYear
        case months
        case weeks
        case setPositions
        case time               // several times a day, or minutes without an hour
    }

    enum Outcome: Equatable, Sendable {
        case rule(RepeatRule)
        case unmappable(Set<Unmappable>)
    }

    /// Shown in the revision, like every other derived field.
    static var reason: String { String(localized: "From Siri.") }

    static func map(_ recurrence: Calendar.RecurrenceRule) -> Outcome {
        var problems = Set<Unmappable>()

        if recurrence.calendar.identifier != .gregorian { problems.insert(.calendar) }
        if recurrence.end != .never { problems.insert(.end) }
        if !recurrence.daysOfTheMonth.isEmpty { problems.insert(.daysOfTheMonth) }
        if !recurrence.daysOfTheYear.isEmpty { problems.insert(.daysOfTheYear) }
        if !recurrence.months.isEmpty { problems.insert(.months) }
        if !recurrence.weeks.isEmpty { problems.insert(.weeks) }
        if !recurrence.setPositions.isEmpty { problems.insert(.setPositions) }

        let frequency: RepeatRule.Frequency?
        switch recurrence.frequency {
        case .daily: frequency = .daily
        case .weekly: frequency = .weekly
        case .monthly: frequency = .monthly
        case .yearly: frequency = .yearly
        default:
            frequency = nil
            problems.insert(.frequency)
        }

        var weekdays: [Int] = []
        for weekday in recurrence.weekdays {
            switch weekday {
            case .every(let day):
                if let dayNumber = number(of: day) { weekdays.append(dayNumber) } else { problems.insert(.nthWeekday) }
            default: problems.insert(.nthWeekday)
            }
        }
        weekdays = Array(Set(weekdays)).sorted()

        // "Every weekday" arrives as a daily rule limited to Monday to Friday: that is a weekly
        // rule on those days. Only every day, though: "every second day, Mondays only" is not.
        var mapped = frequency
        if !weekdays.isEmpty {
            switch frequency {
            case .weekly: break
            case .daily where recurrence.interval == 1: mapped = .weekly
            case .daily: problems.insert(.weekdaysOutsideWeek)
            default: problems.insert(.weekdaysOutsideWeek)
            }
        }

        let time = timeOfDay(hours: recurrence.hours, minutes: recurrence.minutes, seconds: recurrence.seconds)
        if time == nil, !(recurrence.hours.isEmpty && recurrence.minutes.isEmpty && recurrence.seconds.isEmpty) {
            problems.insert(.time)
        }

        guard problems.isEmpty, let mapped else { return .unmappable(problems) }
        var rule = RepeatRule(frequency: mapped, interval: max(recurrence.interval, 1))
        if mapped == .weekly, !weekdays.isEmpty { rule.weekdays = weekdays }
        rule.hour = time?.hour
        rule.minute = time?.minute
        return .rule(rule)
    }

    /// Sets the mapped rule on the task as the user's own input: what Siri hands over is what the
    /// user said (Henning, 2026-10-06, #25). One revision with the user as author and Siri as the
    /// reason, already seen like every user change. The caller saves.
    @discardableResult
    static func apply(_ rule: RepeatRule, to task: TaskItem, now: Date = Date()) -> Revision? {
        let old = FieldCodec.encode(.repeatRule, of: task)
        let new = FieldCodec.encode(rule)
        guard old != new else { return nil }
        FieldCodec.apply(new, to: .repeatRule, of: task, as: .user, contexts: [], projects: [])
        let revision = Revision(task: task, field: .repeatRule, oldValue: old, newValue: new, author: .user, reason: reason)
        revision.createdAt = now
        revision.seenAt = now
        task.revisions = (task.revisions ?? []) + [revision]
        return revision
    }

    /// One time of day or nothing: `RepeatRule` keeps a single hour and minute (#102).
    private static func timeOfDay(hours: [Int], minutes: [Int], seconds: [Int]) -> (hour: Int, minute: Int)? {
        guard hours.count == 1, let hour = hours.first, (0...23).contains(hour),
              minutes.count <= 1, seconds.allSatisfy({ $0 == 0 }), seconds.count <= 1 else { return nil }
        let minute = minutes.first ?? 0
        guard (0...59).contains(minute) else { return nil }
        return (hour, minute)
    }

    /// 1 = Sunday … 7 = Saturday, the numbering `RepeatRule.weekdays` uses. A day this code does
    /// not know is not guessed.
    private static func number(of day: Locale.Weekday) -> Int? {
        switch day {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        @unknown default: nil
        }
    }
}
