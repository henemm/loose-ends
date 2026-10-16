import Foundation

/// The words of the start screen's headline (#426). Facts stated, no praise, no exclamation marks.
/// Numbers up to twelve are spelled out; times as the system writes them.
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
            let named = titles.compactMap { $0 }
            let first: String
            if count <= 2, named.count == count {
                first = String(localized: "Today tied up: \(ListFormatter.localizedString(byJoining: named)).")
            } else if let last = named.first {
                first = String(localized: "Today \(number(count)) tied up, last \(last).")
            } else {
                first = String(localized: "Today \(number(count)) tied up.")
            }
            guard let next else { return first }
            let then = next.title.map { String(localized: "At \(time(next.at)) still: \($0).") }
                ?? String(localized: "At \(time(next.at)) one more fixed time.")
            return first + " " + then
        case .missed(let title, let at):
            return title.map { String(localized: "\($0) at \(time(at)) has passed.") }
                ?? String(localized: "The fixed time at \(time(at)) has passed.")
        case .upcoming(let title, let at, let count):
            if count > 1 {
                return String(localized: "Today \(number(count)) fixed times, the first at \(time(at)).")
            }
            return title.map { String(localized: "Today at \(time(at)): \($0).") }
                ?? String(localized: "Today a fixed time at \(time(at)).")
        case .dueToday(let title, let count):
            if count > 1 { return String(localized: "Today \(number(count)) things due.") }
            return title.map { String(localized: "Today: \($0).") } ?? String(localized: "Today one thing due.")
        case .waiting(let title, let days):
            return title.map { String(localized: "\($0) has been waiting for \(number(days)) days.") }
                ?? String(localized: "A task has been waiting for \(number(days)) days.")
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
