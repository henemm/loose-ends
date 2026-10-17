import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// How a due date reads in a row (#414): red only for time pressure. Due today is red; past its
/// day only a task with a due time stays red, a day-only date turns grey and counts the days.
@Suite("Due state in a row") struct DueStateTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Thursday, 12 March 2026, 10:00 in Berlin.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 10))!

    /// Day-only dates are stored at the start of the day (`FieldEditorView.setDue`).
    static func day(_ offset: Int, hour: Int = 0) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: DateComponents(day: offset, hour: hour), to: start)!
    }

    @MainActor static func state(due: Date?, hasTime: Bool = false, status: TaskStatus = .active,
                                 in store: TestStore) -> ViewRules.DueState {
        let task = TaskItem(rawText: "Steuerbescheid ablegen")
        task.status = status
        task.dueDate = due
        task.dueHasTime = hasTime
        store.context.insert(task)
        return ViewRules.dueState(of: task, now: now, calendar: calendar)
    }

    @Test("Due today is red, with or without a time, also once the time has passed")
    @MainActor func todayIsToday() async throws {
        let store = try TestStore()
        #expect(Self.state(due: Self.day(0), in: store) == .today)
        #expect(Self.state(due: Self.day(0, hour: 18), hasTime: true, in: store) == .today)
        #expect(Self.state(due: Self.day(0, hour: 9), hasTime: true, in: store) == .today)
    }

    @Test("A day-only date past its day is carried: one day reads as yesterday, then counts")
    @MainActor func dayOnlyPastIsCarried() async throws {
        let store = try TestStore()
        #expect(Self.state(due: Self.day(-1), in: store) == .carried(days: 1))
        #expect(Self.state(due: Self.day(-3), in: store) == .carried(days: 3))
        #expect(Self.state(due: Self.day(-40), in: store) == .carried(days: 40))
    }

    @Test("A day-only date stored at another hour still counts calendar days")
    @MainActor func carriedCountsCalendarDays() async throws {
        let store = try TestStore()
        #expect(Self.state(due: Self.day(-1, hour: 23), in: store) == .carried(days: 1))
        #expect(Self.state(due: Self.day(-2, hour: 9), in: store) == .carried(days: 2))
    }

    @Test("A task with a due time past its day stays red")
    @MainActor func timedPastIsMissed() async throws {
        let store = try TestStore()
        #expect(Self.state(due: Self.day(-1, hour: 14), hasTime: true, in: store) == .missed)
        #expect(Self.state(due: Self.day(-5, hour: 8), hasTime: true, in: store) == .missed)
    }

    @Test("Future dates, no date, done and parked tasks carry no pressure")
    @MainActor func noPressure() async throws {
        let store = try TestStore()
        #expect(Self.state(due: Self.day(1), in: store) == .later)
        #expect(Self.state(due: Self.day(1, hour: 9), hasTime: true, in: store) == .later)
        #expect(Self.state(due: nil, in: store) == .later)
        #expect(Self.state(due: Self.day(-2), status: .done, in: store) == .later)
        #expect(Self.state(due: Self.day(-2, hour: 9), hasTime: true, status: .parked, in: store) == .later)
        #expect(Self.state(due: Self.day(0), status: .done, in: store) == .later)
    }

    @Test("Unchecked and unsorted tasks are open and read like active ones")
    @MainActor func unverifiedAndUnprocessedAreOpen() async throws {
        let store = try TestStore()
        #expect(Self.state(due: Self.day(-1), status: .unverified, in: store) == .carried(days: 1))
        #expect(Self.state(due: Self.day(0), status: .unprocessed, in: store) == .today)
    }

    @Test("A carried task stays out of Now and the badge until it has a new date; Due keeps it (#518)")
    @MainActor func viewsUnchanged() async throws {
        let store = try TestStore()
        let carried = TaskItem(rawText: "Hecke schneiden")
        carried.status = .active
        carried.dueDate = Self.day(-3)
        store.context.insert(carried)

        #expect(ViewRules.now(in: [carried], now: Self.now, calendar: Self.calendar).all.isEmpty)
        #expect(ViewRules.leftovers(in: [carried], now: Self.now, calendar: Self.calendar).map(\.id) == [carried.id])
        #expect(ViewRules.badgeCount(in: [carried], now: Self.now, calendar: Self.calendar) == 0)
        #expect(ViewRules.tasks(for: .due, in: [carried], now: Self.now, calendar: Self.calendar).map(\.id) == [carried.id])
    }
}
