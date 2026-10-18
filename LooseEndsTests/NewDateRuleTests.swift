import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// A deadline that passed is no deadline (#548, Henning 2026-10-18): the task needs a new date, the
/// old time stays only as a trace.
@Suite("New date rule (#548)") struct NewDateRuleTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Thursday, 12 March 2026, 10:00 in Berlin.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 10))!

    static func day(_ offset: Int, hour: Int = 0, minute: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(day: offset, hour: hour, minute: minute), to: calendar.startOfDay(for: now))!
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

    static func needs(_ task: TaskItem) -> Bool {
        NewDateRule.needsNewDate(task, now: now, calendar: calendar)
    }

    @Test("With a time: behind once the time passed, today included; ahead until then")
    @MainActor func timed() async throws {
        let store = try TestStore()
        #expect(Self.needs(Self.task("Anruf", due: Self.day(0, hour: 9), hasTime: true, in: store)), "9:00 at 10:00")
        #expect(!Self.needs(Self.task("Zahnarzt", due: Self.day(0, hour: 15), hasTime: true, in: store)), "15:00 at 10:00")
        #expect(Self.needs(Self.task("Paket", due: Self.day(-1, hour: 18), hasTime: true, in: store)))
        #expect(!Self.needs(Self.task("Reifen", due: Self.day(1, hour: 8), hasTime: true, in: store)))
    }

    @Test("Without a time: today's until the day is over, behind from the next day on")
    @MainActor func dayOnly() async throws {
        let store = try TestStore()
        #expect(!Self.needs(Self.task("Hecke", due: Self.day(0), in: store)), "today at 10:00 is still today")
        #expect(Self.needs(Self.task("Keller", due: Self.day(-1), in: store)))
        #expect(Self.needs(Self.task("Steuer", due: Self.day(-1, hour: 23), in: store)), "stored at another hour, still yesterday")
        #expect(!Self.needs(Self.task("Brot", due: Self.day(1), in: store)))
    }

    @Test("Done, parked, blocked and undated never need a new date; a subtask does")
    @MainActor func whoCounts() async throws {
        let store = try TestStore()
        #expect(!Self.needs(Self.task("Erledigt", due: Self.day(-1), status: .done, in: store)))
        #expect(!Self.needs(Self.task("Geparkt", due: Self.day(-1), status: .parked, in: store)))
        #expect(!Self.needs(Self.task("Irgendwann", due: nil, in: store)))
        let blocker = Self.task("Antwort", due: nil, in: store)
        let blocked = Self.task("Vertrag", due: Self.day(-1), in: store)
        blocked.blockedBy = [blocker]
        #expect(!Self.needs(blocked))
        let parent = Self.task("Umzug", due: nil, in: store)
        let sub = Self.task("Kartons", due: Self.day(-2), in: store)
        sub.parent = parent
        #expect(Self.needs(sub))
        let listed = NewDateRule.tasks(in: [blocked, blocker, parent, sub, Self.task("Paket", due: Self.day(-1, hour: 18), hasTime: true, in: store)],
                                       now: Self.now, calendar: Self.calendar)
        #expect(listed.map(\.rawText) == ["Kartons", "Paket"], "oldest deadline first, the subtask among them")
    }

    @Test("The trace says what had been planned: the time today, yesterday, the weekday, then the date")
    @MainActor func trace() async throws {
        let store = try TestStore()
        let nine = Self.day(0, hour: 9)
        #expect(NewDateRule.trace(of: Self.task("Anruf", due: nine, hasTime: true, in: store), now: Self.now, calendar: Self.calendar) == .today(time: nine))
        #expect(NewDateRule.trace(of: Self.task("Hecke", due: Self.day(0), in: store), now: Self.now, calendar: Self.calendar) == .today(time: nil))
        #expect(NewDateRule.trace(of: Self.task("Keller", due: Self.day(-1), in: store), now: Self.now, calendar: Self.calendar) == .yesterday)
        #expect(NewDateRule.trace(of: Self.task("Paket", due: Self.day(-6), in: store), now: Self.now, calendar: Self.calendar) == .weekday(Self.day(-6)))
        #expect(NewDateRule.trace(of: Self.task("Steuer", due: Self.day(-7), in: store), now: Self.now, calendar: Self.calendar) == .date(Self.day(-7)))
        #expect(NewDateRule.trace(of: Self.task("Ohne", due: nil, in: store), now: Self.now, calendar: Self.calendar) == nil)
        #expect(NewDateRule.Trace.yesterday.text == String(localized: "was yesterday"))
    }

    @Test("For the evening look a day-only date passes at the reminder time of its day (#550)")
    @MainActor func eveningReading() async throws {
        let store = try TestStore()
        let nine = DueReminders.Time(hour: 9, minute: 0)
        let late = DueReminders.Time(hour: 21, minute: 0)
        let hedge = Self.task("Hecke", due: Self.day(0), in: store)
        #expect(NewDateRule.deadline(of: hedge, reminderTime: nine, calendar: Self.calendar) == Self.day(0, hour: 9))
        #expect(NewDateRule.passed(hedge, reminderTime: nine, now: Self.day(0, hour: 20), calendar: Self.calendar))
        #expect(!NewDateRule.passed(hedge, reminderTime: late, now: Self.day(0, hour: 20), calendar: Self.calendar), "21:00 is not behind at 20:00")
        let timed = Self.task("Kino", due: Self.day(0, hour: 22), hasTime: true, in: store)
        #expect(!NewDateRule.passed(timed, reminderTime: nine, now: Self.day(0, hour: 20), calendar: Self.calendar))
        #expect(NewDateRule.passed(timed, reminderTime: nine, now: Self.day(1, hour: 20), calendar: Self.calendar))
        let exact = Self.task("Punkt", due: Self.day(0, hour: 20), hasTime: true, in: store)
        #expect(!NewDateRule.passed(exact, reminderTime: nine, now: Self.day(0, hour: 20), calendar: Self.calendar), "strictly after the time")
    }

    @Test("Later today is the next full hour at least half an hour away, while the day has one left")
    func laterToday() {
        #expect(NewDateRule.laterToday(now: Self.day(0, hour: 19, minute: 11), calendar: Self.calendar) == Self.day(0, hour: 20))
        #expect(NewDateRule.laterToday(now: Self.day(0, hour: 19, minute: 45), calendar: Self.calendar) == Self.day(0, hour: 21))
        #expect(NewDateRule.laterToday(now: Self.day(0, hour: 22, minute: 30), calendar: Self.calendar) == Self.day(0, hour: 23))
        #expect(NewDateRule.laterToday(now: Self.day(0, hour: 22, minute: 31), calendar: Self.calendar) == nil)
    }

    @Test("A new date with a time, or a day only, is a user revision; a day lands at its start")
    @MainActor func setDue() async throws {
        let store = try TestStore()
        let task = Self.task("Anruf", due: Self.day(0, hour: 9), hasTime: true, in: store)
        TaskActions.setDue(task, to: Self.day(1, hour: 15), hasTime: true, contexts: [], projects: [], now: Self.now, calendar: Self.calendar)
        #expect(task.dueDate == Self.day(1, hour: 15) && task.dueHasTime)
        TaskActions.setDue(task, to: Self.day(2, hour: 15), hasTime: false, contexts: [], projects: [], now: Self.now, calendar: Self.calendar)
        #expect(task.dueDate == Self.day(2) && !task.dueHasTime)
        #expect((task.revisions ?? []).filter { $0.field == .dueDate && $0.author == .user }.count == 2)
        #expect(!Self.needs(task))
    }
}
