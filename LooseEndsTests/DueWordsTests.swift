import Foundation
import Testing
@testable import LooseEnds

/// Its bundle has no `de` translations, so `String(localized:bundle:)` falls back to the English key.
private final class DueWordsBundleMarker {}

/// The detail's due date in words (#438): "Today, 14:30" rather than "15 Oct 2026, 14:30".
@Suite("Due date in words") struct DueWordsTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static let locale = Locale(identifier: "en_US_POSIX")
    static let bundle = Bundle(for: DueWordsBundleMarker.self)

    /// Thursday, 15 October 2026, 10:00 in Berlin.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 10))!

    static func at(day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    static func words(_ date: Date, hasTime: Bool) -> String {
        // ICU puts a narrow no-break space before AM/PM; compare with a plain one.
        FieldFormatting.dueWords(date, hasTime: hasTime, now: now, calendar: calendar, locale: locale, bundle: bundle)
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test("Today, tomorrow and yesterday by name, with the time after a comma")
    func namedDays() {
        #expect(Self.words(Self.at(day: 15, hour: 14, minute: 30), hasTime: true) == "Today, 2:30 PM")
        #expect(Self.words(Self.at(day: 16), hasTime: false) == "Tomorrow")
        #expect(Self.words(Self.at(day: 14, hour: 9), hasTime: true) == "Yesterday, 9:00 AM")
    }

    @Test("Any other day is the short date")
    func otherDays() {
        #expect(Self.words(Self.at(day: 20), hasTime: false) == "Oct 20, 2026")
        #expect(Self.words(Self.at(day: 10, hour: 8), hasTime: true) == "Oct 10, 2026, 8:00 AM")
    }
}
