import Foundation

/// The words of the start screen's headline (#426). Facts stated, no praise, no exclamation marks.
/// Numbers up to twelve are spelled out; times as the system writes them. Every sentence about a
/// task names it (#585); only a count stands without a title. With `naming` off (the start page,
/// #677) a task that stands in "Now" right below is not named again: an overdue, due or upcoming
/// one is counted, the next fixed time after a look back is left out. Done titles stay, they stand
/// nowhere else.
enum StartHeadlineText {
    static func sentence(_ headline: StartHeadline, naming: Bool = true, locale: Locale = .current) -> String {
        // A spelled-out number or a lower-case title may open the sentence.
        let text = naming ? words(headline, locale: locale) : unnamed(headline, locale: locale)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// The start page's words (#677): what "Now" shows anyway is counted, not quoted.
    private static func unnamed(_ headline: StartHeadline, locale: Locale) -> String {
        func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
        switch headline {
        case .doneToday(let count, let titles, _):
            return words(.doneToday(count: count, titles: titles, next: nil), locale: locale)
        case .untangled(let title, let count, _):
            return words(.untangled(title: title, count: count, next: nil), locale: locale)
        case .missed(_, let at, 1):
            return String(localized: "The fixed time at \(time(at)) has passed.")
        case .upcoming(_, let at, 1):
            return String(localized: "Today one fixed time, at \(time(at)).")
        case .dueToday(_, 1):
            return String(localized: "Today one thing due.")
        case .needsNewDate(_, 1):
            return String(localized: "One thing needs a new date.")
        default:
            return words(headline, locale: locale)
        }
    }

    private static func words(_ headline: StartHeadline, locale: Locale) -> String {
        func number(_ count: Int) -> String { word(count, locale: locale) }
        func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
        switch headline {
        case .doneToday(let count, let titles, let next):
            let first: String
            if count <= 2, titles.count == count {
                first = String(localized: "Today tied up: \(ListFormatter.localizedString(byJoining: titles)).")
            } else {
                first = String(localized: "Today \(number(count)) tied up, last \(titles.first ?? "").")
            }
            guard let next else { return first }
            return first + " " + String(localized: "At \(time(next.at)) still: \(next.title).")
        case .week(let count, _):
            if count == 1 { return String(localized: "This week: one bead.") }
            return String(localized: "This week: \(number(count)) beads.")
        case .untangled(let title, let count, let next):
            let first: String
            switch count {
            case 1: first = String(localized: "Today untangled: \(title).")
            case 2: first = String(localized: "Today untangled: \(title), and one more tied up.")
            default: first = String(localized: "Today untangled: \(title), and \(number(count - 1)) more tied up.")
            }
            guard let next else { return first }
            return first + " " + String(localized: "At \(time(next.at)) still: \(next.title).")
        case .missed(let title, let at, let count):
            if count > 1 {
                return String(localized: "\(number(count)) fixed times have passed, the last at \(time(at)).")
            }
            return String(localized: "\(title) at \(time(at)) has passed.")
        case .upcoming(let title, let at, let count):
            if count > 1 {
                return String(localized: "Today \(number(count)) fixed times, the first at \(time(at)).")
            }
            return String(localized: "Today at \(time(at)): \(title).")
        case .dueToday(let title, let count):
            if count > 1 { return String(localized: "Today \(number(count)) things due.") }
            return String(localized: "Today: \(title).")
        case .needsNewDate(let title, let count):
            if count > 1 { return String(localized: "\(number(count)) things need a new date.") }
            return String(localized: "\(title) needs a new date.")
        case .pile(let label, let count):
            return String(localized: "\(number(count)) things under \(label).")
        case .old(let count):
            return String(localized: "\(number(count)) things for over a month. Time to park?")
        case .doneYesterday(let count):
            return String(localized: "Yesterday: \(number(count)) tied up.")
        case .calm:
            return String(localized: "Nothing presses today.")
        case .allDone:
            return String(localized: "All tied up.")
        }
    }

    /// "vier" rather than "4" up to twelve.
    static func word(_ count: Int, locale: Locale = .current) -> String {
        guard (1...12).contains(count) else { return count.formatted() }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: count)) ?? count.formatted()
    }
}
