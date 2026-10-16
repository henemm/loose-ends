import Foundation
import Testing
@testable import LooseEnds

/// The due editor's quick choices (#440).
@Suite("Quick due") struct QuickDueTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// 2026-10-12 is a Monday.
    static func date(_ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test("Today and tomorrow")
    func todayTomorrow() {
        let now = Self.date(15, hour: 10)   // Thursday
        #expect(QuickDue.day(.today, now: now, calendar: Self.calendar) == Self.date(15))
        #expect(QuickDue.day(.tomorrow, now: now, calendar: Self.calendar) == Self.date(16))
    }

    @Test("The weekend is the coming Saturday, today on Saturday and Sunday")
    func weekend() {
        #expect(QuickDue.day(.weekend, now: Self.date(15, hour: 10), calendar: Self.calendar) == Self.date(17))
        #expect(QuickDue.day(.weekend, now: Self.date(12, hour: 10), calendar: Self.calendar) == Self.date(17))
        #expect(QuickDue.day(.weekend, now: Self.date(17, hour: 10), calendar: Self.calendar) == Self.date(17))
        #expect(QuickDue.day(.weekend, now: Self.date(18, hour: 10), calendar: Self.calendar) == Self.date(18))
    }

    @Test("Next week is the coming Monday, a week ahead on a Monday")
    func nextWeek() {
        #expect(QuickDue.day(.nextWeek, now: Self.date(15, hour: 10), calendar: Self.calendar) == Self.date(19))
        #expect(QuickDue.day(.nextWeek, now: Self.date(12, hour: 10), calendar: Self.calendar) == Self.date(19))
        #expect(QuickDue.day(.nextWeek, now: Self.date(18, hour: 10), calendar: Self.calendar) == Self.date(19))
    }

    @Test("A time sets the full hour; a new day keeps an existing time")
    func timeAndMove() {
        #expect(QuickDue.at(hour: 15, on: Self.date(16), calendar: Self.calendar) == Self.date(16, hour: 15))
        let existing = Self.date(15, hour: 14, minute: 30)
        #expect(QuickDue.move(existing, hasTime: true, to: Self.date(16), calendar: Self.calendar) == Self.date(16, hour: 14, minute: 30))
        #expect(QuickDue.move(existing, hasTime: false, to: Self.date(16), calendar: Self.calendar) == Self.date(16))
    }

    @Test("The chip of the day the date falls on is marked")
    func matching() {
        let now = Self.date(15, hour: 10)
        #expect(QuickDue.matching(Self.date(16, hour: 15), now: now, calendar: Self.calendar) == .tomorrow)
        #expect(QuickDue.matching(Self.date(25), now: now, calendar: Self.calendar) == nil)
        #expect(QuickDue.matching(nil, now: now, calendar: Self.calendar) == nil)
    }

    @Test("The calendar shows this week and the next, from the first weekday")
    func fortnight() {
        var calendar = Self.calendar
        calendar.firstWeekday = 2   // Monday, as in Germany
        let days = QuickDue.fortnight(now: Self.date(15, hour: 10), calendar: calendar)
        #expect(days.count == 14)
        #expect(days.first == Self.date(12))
        #expect(days.last == Self.date(25))
    }
}

