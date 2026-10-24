import Foundation

/// The words of the start screen's headline (#426). Facts stated, no praise, no exclamation marks.
/// Numbers up to twelve are spelled out; times as the system writes them. Every sentence about a
/// task names it (#585); only a count stands without a title.
enum StartHeadlineText {
    static func sentence(_ headline: StartHeadline, locale: Locale = .current) -> String {
        // A spelled-out number or a lower-case title may open the sentence.
        let text = words(headline, locale: locale)
        return text.prefix(1).uppercased() + text.dropFirst()
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
