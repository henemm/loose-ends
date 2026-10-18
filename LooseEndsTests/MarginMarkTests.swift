import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The margin of a row (#424): the one time that counts, red only for time pressure.
@Suite("Margin of a row") struct MarginMarkTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Thursday, 12 March 2026, 10:00 in Berlin.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 10))!

    static func day(_ offset: Int, hour: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(day: offset, hour: hour), to: calendar.startOfDay(for: now))!
    }

    @MainActor static func mark(due: Date?, hasTime: Bool = false, duration: DurationBucket? = nil,
                                status: TaskStatus = .active, in store: TestStore) -> ViewRules.MarginMark {
        let task = TaskItem(rawText: "Steuerbescheid prüfen")
        task.status = status
        task.dueDate = due
        task.dueHasTime = hasTime
        task.duration = duration
        store.context.insert(task)
        return ViewRules.marginMark(of: task, now: now, calendar: calendar)
    }

    @Test("Today: the time when there is one, else Today; both press")
    @MainActor func today() async throws {
        let store = try TestStore()
        let noon = Self.day(0, hour: 12)
        #expect(Self.mark(due: noon, hasTime: true, in: store) == .time(noon))
        #expect(Self.mark(due: Self.day(0), in: store) == .today)
        #expect(ViewRules.MarginMark.time(noon).pressing)
        #expect(ViewRules.MarginMark.today.pressing)
    }

    @Test("Passed: a deadline that passed is no deadline, the margin offers a new date over the trace (#548)")
    @MainActor func passed() async throws {
        let store = try TestStore()
        #expect(Self.mark(due: Self.day(-1, hour: 14), hasTime: true, in: store) == .passed(.yesterday))
        #expect(Self.mark(due: Self.day(-3, hour: 9), hasTime: true, in: store) == .passed(.weekday(Self.day(-3, hour: 9))))
        #expect(Self.mark(due: Self.day(-2), in: store) == .passed(.weekday(Self.day(-2))))
        #expect(Self.mark(due: Self.day(-9), in: store) == .passed(.date(Self.day(-9))))
        let nine = Self.day(0, hour: 9)
        #expect(Self.mark(due: nine, hasTime: true, in: store) == .passed(.today(time: nine)), "9:00 is behind at 10:00")
        #expect(!ViewRules.MarginMark.passed(.yesterday).pressing, "no pressure left, only a decision")
    }

    @Test("A waiting task past its deadline shows its trace too; only Now leaves it out")
    @MainActor func blockedPassed() async throws {
        let store = try TestStore()
        let blocker = TaskItem(rawText: "Antwort von Anna")
        blocker.status = .active
        store.context.insert(blocker)
        let task = TaskItem(rawText: "Vertrag schicken")
        task.status = .active
        task.dueDate = Self.day(-1)
        task.blockedBy = [blocker]
        store.context.insert(task)
        #expect(ViewRules.marginMark(of: task, now: Self.now, calendar: Self.calendar) == .passed(.yesterday))
        #expect(ViewRules.leftovers(in: [task, blocker], now: Self.now, calendar: Self.calendar).isEmpty)
    }

    @Test("Ahead: tomorrow, then the weekday for six days, then the date")
    @MainActor func ahead() async throws {
        let store = try TestStore()
        #expect(Self.mark(due: Self.day(1), in: store) == .tomorrow)
        #expect(Self.mark(due: Self.day(2), in: store) == .weekday(Self.day(2)))
        #expect(Self.mark(due: Self.day(6, hour: 9), hasTime: true, in: store) == .weekday(Self.day(6, hour: 9)))
        #expect(Self.mark(due: Self.day(7), in: store) == .date(Self.day(7)))
        #expect(!ViewRules.MarginMark.tomorrow.pressing)
    }

    @Test("Without a date the duration stands in the margin; without both it stays empty")
    @MainActor func duration() async throws {
        let store = try TestStore()
        #expect(Self.mark(due: nil, duration: .minutes30, in: store) == .duration(.minutes30))
        #expect(Self.mark(due: nil, in: store) == .none)
        #expect(Self.mark(due: Self.day(1), duration: .minutes30, in: store) == .tomorrow, "a date wins over the duration")
    }

    @Test("Done and parked tasks leave the margin empty")
    @MainActor func closed() async throws {
        let store = try TestStore()
        #expect(Self.mark(due: Self.day(0), status: .done, in: store) == .none)
        #expect(Self.mark(due: Self.day(-1, hour: 9), hasTime: true, status: .parked, in: store) == .none)
    }
}
