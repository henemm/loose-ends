import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Left from an earlier day (#518, Henning 2026-10-17): not carried on, it needs a new date.
@Suite("Needs a new date (#518)") struct LeftoversTests {
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

    @MainActor private func leftover(_ text: String, in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.status = .active
        task.dueDate = Self.day(-1, hour: 18)
        task.dueHasTime = true
        store.context.insert(task)
        return task
    }

    @Test("A new date (today, tomorrow, weekend) or parking takes the task out; the date is a user revision")
    @MainActor func newDateOrParkSortsTheTask() async throws {
        let store = try TestStore()
        let today = leftover("Rechnung bezahlen", in: store)
        let tomorrow = leftover("Zahnarzt anrufen", in: store)
        let weekend = leftover("Fahrrad putzen", in: store)
        let park = leftover("Keller", in: store)
        let all = [today, tomorrow, weekend, park]
        #expect(ViewRules.leftovers(in: all, now: Self.now, calendar: Self.calendar).count == 4)

        for (task, target) in [(today, TaskActions.MoveTarget.date(Self.now)), (tomorrow, .tomorrow), (weekend, .weekend)] {
            TaskActions.move(task, to: target, contexts: [], projects: [], now: Self.now, calendar: Self.calendar)
        }
        TaskActions.park(park, now: Self.now)

        #expect(ViewRules.leftovers(in: all, now: Self.now, calendar: Self.calendar).isEmpty)
        #expect(Self.calendar.isDate(try #require(today.dueDate), inSameDayAs: Self.now))
        #expect(ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [today.id])
        #expect(Self.calendar.isDate(try #require(tomorrow.dueDate), inSameDayAs: Self.day(1)))
        #expect(try #require(weekend.dueDate) > Self.now)
        #expect(park.status == .parked)
        #expect((today.revisions ?? []).contains { $0.field == .dueDate && $0.author == .user })
    }

    @Test("At most 40 single reminders, the soonest, so the bundled morning one and the places fit")
    @MainActor func singleRemindersAreCapped() async throws {
        let store = try TestStore()
        let tasks = (1...60).map { offset -> TaskItem in
            let task = TaskItem(rawText: "Aufgabe \(offset)")
            task.status = .active
            task.dueDate = Self.day(offset)
            store.context.insert(task)
            return task
        }

        let plan = DueReminders.plan(for: tasks, now: Self.now, calendar: Self.calendar)

        #expect(plan.count == DueReminders.maxPlanned)
        #expect(plan.first?.taskID == tasks[0].id, "the soonest first")
        #expect(plan.last?.taskID == tasks[DueReminders.maxPlanned - 1].id)
    }
}
