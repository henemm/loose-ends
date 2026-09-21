import Foundation

/// The rule step for the due date (#95): `DateExpressionParser` names the day, `TimeExpressionParser`
/// the time of day, and together they become the same guess triple the model delivers — value,
/// confidence, reason. Rules before the model (CLAUDE.md): measured at 99.3 % exact days and
/// 0 % invented ones (#92), against 50 % / 96.5 % for the on-device model (#67).
///
/// Pure `Foundation` on purpose: `Shared/` also compiles into the watch, the widgets and the share
/// extension, where `FoundationModels` does not exist.
enum DueDateRule {
    /// A day, optionally sharpened to a time of day. `hasTime` maps onto `TaskItem.dueHasTime`.
    struct Match: Equatable, Sendable {
        var guess: EnrichmentDraft.Guess<Date>
        var hasTime: Bool
    }

    /// A rule hit is deterministically there or not — an in-between number would be an invented
    /// one. 1.0 clears the 0.6 threshold of `EnrichmentWriter` (AC-9).
    static let confidence = 1.0

    /// The due date the rule stands behind, or nothing. A time without a recognised day yields
    /// nothing: `TaskItem.dueHasTime` is a flag next to `dueDate`, not a slot of its own, and the
    /// repetition block of the date parser already keeps "jeden Tag um 7 Uhr" out (#92).
    static func match(in text: String, reference: Date, calendar: Calendar = .current) -> Match? {
        let parser = DateExpressionParser(calendar: calendar)
        guard let expression = parser.expression(in: text),
              let day = parser.resolve(expression, reference: reference) else { return nil }

        var value = day
        var hasTime = false
        if let time = TimeExpressionParser().time(in: text),
           let sharpened = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) {
            value = sharpened
            hasTime = true
        }

        let guess = EnrichmentDraft.Guess(value, confidence: confidence, reason: reason(for: expression))
        return Match(guess: guess, hasTime: hasTime)
    }

    /// Shown to the user in the task detail and the field editor. One sentence per kind of
    /// expression, in the app's language rather than the note's — so "end of the month" is not
    /// explained like "on Monday".
    static func reason(for expression: DateExpression) -> String {
        switch expression {
        case .offsetDays: String(localized: "From a day count in the note.")
        case .weekday: String(localized: "From the weekday named in the note.")
        case .weekdayNextWeek: String(localized: "From a weekday of next week in the note.")
        case .weekdayEitherNext: String(localized: "From “next” plus a weekday in the note: the following week.")
        case .endOfMonth: String(localized: "From “end of the month” in the note.")
        case .dayOfMonth: String(localized: "From the day of the month in the note.")
        case .weekend: String(localized: "From “weekend” in the note: Saturday.")
        case .monthRange: String(localized: "From “next month” in the note: the first of that month.")
        case .dayAndMonth: String(localized: "From the day and month in the note.")
        }
    }
}
