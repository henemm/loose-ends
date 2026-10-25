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
    /// `spans` are the word indices the rule read it from (`ExpressionText.words`), for the title and
    /// the trigger marking.
    struct Match: Equatable, Sendable {
        var guess: EnrichmentDraft.Guess<Date>
        var hasTime: Bool
        var spans: [Range<Int>] = []
    }

    /// A rule hit is deterministically there or not — an in-between number would be an invented
    /// one. 1.0 clears the 0.6 threshold of `EnrichmentWriter` (AC-9).
    static let confidence = 1.0

    /// The due date the rule stands behind, or nothing. Three ways, the first that reads wins:
    /// "in 1 Stunde" from the moment of capture (#679); a named day, sharpened by a time; a time alone
    /// that names itself as one ("um 10:00 Uhr"), today while it is still ahead, otherwise tomorrow
    /// (Henning, 2026-10-25, #679). A repetition anywhere ("jeden Tag um 7 Uhr") keeps the last two
    /// out: that time belongs to the repeat rule; the date parser already skips the named day (#92).
    static func match(in text: String, reference: Date, calendar: Calendar = .current) -> Match? {
        let clock = TimeExpressionParser()
        let repeating = DateExpressionParser.mentionsRepetition(in: text)
        if !repeating, let offset = clock.offset(in: text),
           let minute = calendar.dateInterval(of: .minute, for: reference)?.start,
           let value = calendar.date(byAdding: .minute, value: offset.minutes, to: minute) {
            let guess = EnrichmentDraft.Guess(value, confidence: confidence, reason: offsetReason)
            return Match(guess: guess, hasTime: true, spans: [offset.span])
        }

        let parser = DateExpressionParser(calendar: calendar)
        if let expression = parser.expression(in: text), let day = parser.resolve(expression, reference: reference) {
            var value = day
            var hasTime = false
            var spans = [parser.span(in: text)].compactMap { $0 }
            if let time = clock.time(in: text),
               let sharpened = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day) {
                value = sharpened
                hasTime = true
                if let span = clock.span(in: text) { spans.append(span) }
            }
            let guess = EnrichmentDraft.Guess(value, confidence: confidence, reason: reason(for: expression))
            return Match(guess: guess, hasTime: hasTime, spans: spans)
        }

        guard !repeating, let time = clock.explicitTime(in: text),
              let value = nextOccurrence(of: time, after: reference, calendar: calendar) else { return nil }
        let guess = EnrichmentDraft.Guess(value, confidence: confidence, reason: timeOnlyReason)
        return Match(guess: guess, hasTime: true, spans: [clock.span(in: text)].compactMap { $0 })
    }

    /// Today at that time while it is still ahead (or this very minute), otherwise tomorrow.
    static func nextOccurrence(of time: (hour: Int, minute: Int), after reference: Date, calendar: Calendar) -> Date? {
        guard let today = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: reference),
              let minute = calendar.dateInterval(of: .minute, for: reference)?.start else { return nil }
        if today >= minute { return today }
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference)) else { return nil }
        return calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: tomorrow)
    }

    static var offsetReason: String { String(localized: "From “in” plus hours or minutes in the note.") }
    static var timeOnlyReason: String {
        String(localized: "From the time in the note: today, or tomorrow once it has passed.")
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
