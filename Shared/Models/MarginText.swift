import Foundation

/// The margin's words (#424), shared by the list rows and the "Next up" widget (#521) so both say the
/// same time in the same words. A day-only date past its day says how long it has been carried (#414).
extension ViewRules.MarginMark {
    var text: String {
        switch self {
        case .time(let date): date.formatted(date: .omitted, time: .shortened)
        case .today: String(localized: "Today")
        case .passed(let trace): trace.text
        case .tomorrow: String(localized: "Tomorrow")
        case .weekday(let date): date.formatted(.dateTime.weekday(.abbreviated))
        case .date(let date): date.formatted(.dateTime.day().month(.abbreviated))
        case .duration(let bucket): bucket.shortText
        case .none: ""
        }
    }
}

extension NewDateRule.Trace {
    /// What had been planned, small and grey under "New date" (#548): "was 15:00", "was yesterday", "was Tue".
    var text: String {
        switch self {
        case .today(let time?): String(localized: "was \(time.formatted(date: .omitted, time: .shortened))")
        case .today(nil): String(localized: "was today")
        case .yesterday: String(localized: "was yesterday")
        case .weekday(let date): String(localized: "was \(date.formatted(.dateTime.weekday(.abbreviated)))")
        case .date(let date): String(localized: "was \(date.formatted(.dateTime.day().month(.abbreviated)))")
        }
    }
}

extension DurationBucket {
    /// The short form for a margin or a trait: "15 min".
    var shortText: String {
        switch self {
        case .minutes5: String(localized: "5 min")
        case .minutes15: String(localized: "15 min")
        case .minutes30: String(localized: "30 min")
        case .hour1: String(localized: "1 h")
        case .hours2plus: String(localized: "2 h+")
        }
    }
}
