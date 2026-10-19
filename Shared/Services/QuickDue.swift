import Foundation

/// The quick choices of the due editor (#440): a day in one tap, then a time in one more, so "tomorrow
/// at 3 pm" takes three taps from the detail instead of six. Pure calendar arithmetic, no model.
enum QuickDue {
    enum Day: CaseIterable, Sendable {
        case today, tomorrow, weekend, nextWeek
    }

    /// The times offered after a day; "without" and "other …" sit next to them in the editor.
    static let hours = [9, 12, 15, 18]

    /// The start of the chosen day. The weekend is the coming Saturday (today on a Saturday or a
    /// Sunday), next week the coming Monday, never today.
    static func day(_ day: Day, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        func add(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: today) ?? today }
        let weekday = calendar.component(.weekday, from: today)   // 1 = Sunday … 7 = Saturday
        switch day {
        case .today:
            return today
        case .tomorrow:
            return add(1)
        case .weekend:
            if weekday == 7 || weekday == 1 { return today }
            return add(7 - weekday)
        case .nextWeek:
            return add((9 - weekday) % 7 == 0 ? 7 : (9 - weekday) % 7)
        }
    }

    /// The time words after a day (#556): the four full hours and, when the due date carries a time
    /// outside them, that time in its place by the clock. "Other time …" is not among them: the editor
    /// always shows it after the last, so a set 8:00 never takes its place (Henning, 2026-10-19).
    static func timeChoices(on day: Date, due: Date?, hasTime: Bool, calendar: Calendar = .current) -> [Date] {
        let presets = hours.map { at(hour: $0, on: day, calendar: calendar) }
        guard hasTime, let due, !presets.contains(due), calendar.isDate(due, inSameDayAs: day) else { return presets }
        return (presets + [due]).sorted()
    }

    /// The same day at a full hour.
    static func at(hour: Int, on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    /// The chosen day, keeping the time of day an existing due date already had.
    static func move(_ existing: Date?, hasTime: Bool, to day: Date, calendar: Calendar = .current) -> Date {
        guard let existing, hasTime else { return day }
        let time = calendar.dateComponents([.hour, .minute], from: existing)
        return calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day) ?? day
    }

    /// Which quick day the date falls on, for marking the chosen chip; nil for any other day.
    static func matching(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> Day? {
        guard let date else { return nil }
        let start = calendar.startOfDay(for: date)
        return Day.allCases.first { day($0, now: now, calendar: calendar) == start }
    }

    /// The two weeks the due editor shows as a calendar (#482): from the start of this week (the
    /// calendar's first weekday) fourteen days on, each at the start of its day.
    static func fortnight(now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        return (0..<14).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}
