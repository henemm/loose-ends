import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The start screen's "Due today" and the app badge (#299): today and overdue, not the whole week;
/// a task in "Next up" and due today stands in both lists but counts once.
@Suite("Due today and the app badge") struct DueTodayTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Thursday, 12 March 2026, 10:00 in Berlin.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 10))!

    static func day(_ offset: Int, hour: Int = 9) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: DateComponents(day: offset, hour: hour), to: start)!
    }

    @Test("Overdue and today count, tomorrow and later do not; done tasks and subtasks stay out")
    @MainActor func todayAndOverdue() async throws {
        let store = try TestStore()
        let overdue = TaskItem(rawText: "Rechnung bezahlen")
        overdue.status = .active
        overdue.dueDate = Self.day(-2)
        let tonight = TaskItem(rawText: "Müll rausbringen")
        tonight.status = .active
        tonight.dueDate = Self.day(0, hour: 22)
        let tomorrow = TaskItem(rawText: "Zahnarzt")
        tomorrow.status = .active
        tomorrow.dueDate = Self.day(1)
        let done = TaskItem(rawText: "Blumen gießen")
        done.status = .done
        done.dueDate = Self.day(0)
        let parent = TaskItem(rawText: "Umzug")
        parent.status = .active
        let sub = TaskItem(rawText: "Kartons holen")
        sub.status = .active
        sub.dueDate = Self.day(0)
        sub.parent = parent
        let all = [overdue, tonight, tomorrow, done, parent, sub]
        all.forEach(store.context.insert)

        let due = ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar)
        #expect(due.map(\.id) == [overdue.id, tonight.id], "earliest first")
        #expect(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).contains { $0.id == tomorrow.id },
                "the Due view still looks a week ahead")
    }

    @Test("The badge counts Next up and Due today, a task in both once")
    @MainActor func badgeCountsEachTaskOnce() async throws {
        let store = try TestStore()
        let lined = TaskItem(rawText: "Angebot schreiben")
        lined.status = .active
        lined.nextRank = 0
        let both = TaskItem(rawText: "Steuer abgeben")
        both.status = .active
        both.nextRank = 1
        both.dueDate = Self.day(0)
        let dueOnly = TaskItem(rawText: "Paket abholen")
        dueOnly.status = .active
        dueOnly.dueDate = Self.day(-1)
        let later = TaskItem(rawText: "Reifen wechseln")
        later.status = .active
        later.dueDate = Self.day(3)
        let all = [lined, both, dueOnly, later]
        all.forEach(store.context.insert)

        #expect(ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [dueOnly.id, both.id],
                "a task in Next up and due today stands in both lists")
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 3)
        #expect(ViewRules.badgeCount(in: [], now: Self.now, calendar: Self.calendar) == 0)
    }
}
