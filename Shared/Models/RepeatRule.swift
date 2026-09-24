import Foundation

/// A task carries at most one rule. On completion the same task moves to the next due date;
/// there are no templates, instances or series (ADR-7).
struct RepeatRule: Codable, Hashable, Sendable {
    enum Frequency: String, Codable, CaseIterable, Sendable { case daily, weekly, monthly, yearly }
    enum Basis: String, Codable, CaseIterable, Sendable { case fromDueDate, fromCompletion }

    var frequency: Frequency
    var interval: Int = 1
    /// 1 = Sunday ... 7 = Saturday (Calendar weekday numbering). Only used for `.weekly`.
    var weekdays: [Int]? = nil
    var basis: Basis = .fromDueDate
    /// Time of day the repetition refers to, taken once from the raw text when the rule is created (#102).
    var hour: Int? = nil
    var minute: Int? = nil

    /// Next due date after a completion.
    func nextDueDate(previousDue: Date?, completedOn: Date, calendar: Calendar = .current) -> Date {
        let anchor: Date
        if basis == .fromCompletion { anchor = completedOn } else { anchor = previousDue ?? completedOn }
        let step = max(interval, 1)
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: step, to: anchor) ?? anchor
        case .weekly:
            guard let days = weekdays, !days.isEmpty else {
                return calendar.date(byAdding: .day, value: 7 * step, to: anchor) ?? anchor
            }
            let anchorWeekday = calendar.component(.weekday, from: anchor)
            let sorted = days.sorted()
            if let nextSameWeek = sorted.first(where: { $0 > anchorWeekday }) {
                return calendar.date(byAdding: .day, value: nextSameWeek - anchorWeekday, to: anchor) ?? anchor
            }
            let first = sorted[0]
            let daysToFirst = 7 * step - (anchorWeekday - first)
            return calendar.date(byAdding: .day, value: daysToFirst, to: anchor) ?? anchor
        case .monthly:
            return calendar.date(byAdding: .month, value: step, to: anchor) ?? anchor
        case .yearly:
            return calendar.date(byAdding: .year, value: step, to: anchor) ?? anchor
        }
    }
}

extension RepeatRule {
    /// Pass-through to the rule-based time parser (#92) — no detection logic of its own.
    static func timeGuess(from rawText: String) -> (hour: Int, minute: Int)? {
        TimeExpressionParser().time(in: rawText)
    }

    /// What picking a frequency in the editor yields. An existing rule keeps its time — the raw text
    /// is asked once only, when the rule comes into being (AC-3).
    static func selecting(_ frequency: Frequency, existing: RepeatRule?, rawText: String) -> RepeatRule {
        var next = existing ?? {
            var created = RepeatRule(frequency: frequency)
            if let guess = timeGuess(from: rawText) {
                created.hour = guess.hour
                created.minute = guess.minute
            }
            return created
        }()
        next.frequency = frequency
        if frequency != .weekly { next.weekdays = nil }
        return next
    }
}
