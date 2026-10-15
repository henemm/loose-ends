import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Still open after its day (#414): one bundled notification on the mornings after, at most three,
/// and a day-only date carried longer than a week leaves "Now" and the app badge.
@Suite("CarryReminders") struct CarryRemindersTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Thursday, 12 March 2026, 08:00 in Berlin: before the 9:00 reminder time.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 8))!

    static func day(_ offset: Int, hour: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(day: offset, hour: hour), to: calendar.startOfDay(for: now))!
    }

    @MainActor static func task(_ text: String, due: Date?, hasTime: Bool = false, status: TaskStatus = .active,
                                in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.status = status
        task.dueDate = due
        task.dueHasTime = hasTime
        store.context.insert(task)
        return task
    }

    static func plan(_ tasks: [TaskItem], mode: CarryReminders.Mode = .morning, now: Date = now) -> [CarryReminders.Reminder] {
        CarryReminders.plan(for: tasks, mode: mode, now: now, calendar: calendar)
    }

    @Test("Yesterday's open task comes back this morning at the reminder time, in one bundled reminder")
    @MainActor func yesterdayThisMorning() async throws {
        let store = try TestStore()
        let a = Self.task("Steuerbescheid ablegen", due: Self.day(-1), in: store)
        let b = Self.task("Zahnarzt anrufen", due: Self.day(-1, hour: 14), hasTime: true, in: store)

        let first = try #require(Self.plan([a, b]).first)
        #expect(first.fireDate == Self.day(0, hour: 9))
        #expect(Set(first.taskIDs) == [a.id, b.id])
        #expect(first.titles.count == 2)
        #expect(first.identifier == "carry_2026-03-12")
    }

    @Test("A task comes back on at most three mornings after its day")
    @MainActor func atMostThreeMornings() async throws {
        let store = try TestStore()
        let task = Self.task("Hecke schneiden", due: Self.day(0), in: store)

        let reminders = Self.plan([task])
        #expect(reminders.map(\.fireDate) == [Self.day(1, hour: 9), Self.day(2, hour: 9), Self.day(3, hour: 9)])
    }

    @Test("Past the reminder time, this morning is skipped; days already used up do not return")
    @MainActor func pastTimeAndUsedUp() async throws {
        let store = try TestStore()
        let yesterday = Self.task("Paket", due: Self.day(-1), in: store)
        let threeDays = Self.task("Keller", due: Self.day(-3), in: store)
        let later = Self.day(0, hour: 10)

        let reminders = Self.plan([yesterday, threeDays], now: later)
        #expect(reminders.map(\.fireDate) == [Self.day(1, hour: 9), Self.day(2, hour: 9)])
        #expect(reminders.allSatisfy { $0.taskIDs == [yesterday.id] })
    }

    @Test("Due today or later, done, parked, subtasks and undated tasks are not carried")
    @MainActor func notCarried() async throws {
        let store = try TestStore()
        let today = Self.task("Heute", due: Self.day(0), in: store)
        let done = Self.task("Erledigt", due: Self.day(-1), status: .done, in: store)
        let parked = Self.task("Geparkt", due: Self.day(-1), status: .parked, in: store)
        let undated = Self.task("Irgendwann", due: nil, in: store)
        let parent = Self.task("Umzug", due: nil, in: store)
        let sub = Self.task("Kartons", due: Self.day(-1), in: store)
        sub.parent = parent

        let thisMorning = Self.plan([today, done, parked, undated, parent, sub]).filter { $0.day == Self.day(0) }
        #expect(thisMorning.isEmpty)
    }

    @Test("Carrying quietly plans nothing")
    @MainActor func quietPlansNothing() async throws {
        let store = try TestStore()
        let task = Self.task("Steuer", due: Self.day(-1), in: store)
        #expect(Self.plan([task], mode: .quiet).isEmpty)
    }

    @Test("The stored mode falls back to the morning reminder")
    func storedMode() {
        #expect(CarryReminders.Mode(stored: nil) == .morning)
        #expect(CarryReminders.Mode(stored: "nonsense") == .morning)
        #expect(CarryReminders.Mode(stored: "quiet") == .quiet)
    }

    @Test("Today again makes every listed open task due today, as a user revision without a time")
    @MainActor func todayAgain() async throws {
        let store = try TestStore()
        let a = Self.task("Steuer", due: Self.day(-1), in: store)
        let b = Self.task("Anruf", due: Self.day(-2, hour: 14), hasTime: true, in: store)
        let done = Self.task("Fertig", due: Self.day(-1), status: .done, in: store)

        let moved = CarryReminders.handle(.today, taskIDs: [a.id, b.id, done.id, UUID()], in: [a, b, done],
                                          contexts: [], projects: [], now: Self.now, calendar: Self.calendar)
        #expect(moved == 2)
        #expect(a.dueDate == Self.day(0))
        #expect(b.dueDate == Self.day(0))
        #expect(b.dueHasTime == false)
        #expect(done.dueDate == Self.day(-1))
        #expect(ViewRules.postponeCount(a) == 1)
    }

    @Test("A day-only date carried longer than seven days leaves Now and the badge, not Due's overdue")
    @MainActor func weekOldLeavesNow() async throws {
        let store = try TestStore()
        let seven = Self.task("Sieben Tage", due: Self.day(-7), in: store)
        let eight = Self.task("Acht Tage", due: Self.day(-8), in: store)
        let timed = Self.task("Termin", due: Self.day(-20, hour: 10), hasTime: true, in: store)
        let all = [seven, eight, timed]

        let today = ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        #expect(Set(today) == [seven.id, timed.id])
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 2)
        #expect(ViewRules.now(in: all, now: Self.now, calendar: Self.calendar).all.contains { $0.id == eight.id } == false)
        #expect(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).contains { $0.id == eight.id })
    }
}
