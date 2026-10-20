import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The start screen's "Due today" and the app badge (#299): today, not the whole week; a task in
/// "Next up" and due today stands in both lists but counts once. What is left from earlier days
/// leaves "Due today" until it has a new date (#518); the badge counts it like the "Due" list (#584).
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

    @Test("Today counts; earlier needs a new date first, tomorrow and later do not; done tasks and subtasks stay out")
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
        #expect(due.map(\.id) == [tonight.id])
        #expect(ViewRules.leftovers(in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [overdue.id])
        #expect(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).contains { $0.id == overdue.id },
                "the Due view keeps what is left from earlier")
        #expect(!ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).contains { $0.id == tomorrow.id },
                "the Due view does not look ahead")
    }

    @Test("The badge counts Due and Next up as the lists do, a task in both once; a passed time and an earlier day keep counting (#584)")
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
        let passed = TaskItem(rawText: "Zahnarzt anrufen")
        passed.status = .active
        passed.dueDate = Self.day(0, hour: 9)
        passed.dueHasTime = true
        let all = [lined, both, dueOnly, later, passed]
        all.forEach(store.context.insert)

        #expect(Set(ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id)) == [both.id, passed.id],
                "a task in Next up and due today stands in both lists; Now leaves the passed time out (#548)")
        #expect(ViewRules.now(in: all, now: Self.now, calendar: Self.calendar).all.map(\.id) == [both.id, lined.id])
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 4,
                "lined, both, yesterday's and the passed time: Due plus Next up, each once (#584)")
        TaskActions.move(dueOnly, to: .date(Self.now), contexts: [], projects: [], now: Self.now, calendar: Self.calendar)
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 4, "a new date changes nothing on the icon")
        TaskActions.complete(passed)
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 3)
        #expect(ViewRules.badgeCount(in: [], now: Self.now, calendar: Self.calendar) == 0)
    }

    /// #443: a weekly task whose next round lies ahead is not due, before or after completing it;
    /// the same task due today or overdue is.
    @Test("A repeating task stands in Due only on its day, also after completing")
    @MainActor func repeatingTaskDueOnlyOnItsDay() async throws {
        let store = try TestStore()
        func weekly(_ text: String, due: Date) -> TaskItem {
            let task = TaskItem(rawText: text)
            task.status = .active
            task.dueDate = due
            task.repeatRule = RepeatRule(frequency: .weekly, hour: 19, minute: 0)
            store.context.insert(task)
            return task
        }
        let tomorrow = weekly("Fußnagel behandeln", due: Self.day(1, hour: 19))
        let nextWeek = weekly("Wäsche waschen", due: Self.day(7, hour: 19))
        let tonight = weekly("Pflanzen gießen", due: Self.day(0, hour: 19))
        let overdue = weekly("Tabletten nehmen", due: Self.day(-1, hour: 19))
        let rolling = weekly("Bad putzen", due: Self.day(0, hour: 9))
        let all = [tomorrow, nextWeek, tonight, overdue, rolling]

        func dueIDs() -> Set<UUID> {
            Set(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).map(\.id))
        }
        #expect(dueIDs() == [tonight.id, overdue.id, rolling.id])

        TaskActions.complete(rolling, now: Self.now, calendar: Self.calendar)
        TaskActions.complete(tonight, now: Self.now, calendar: Self.calendar)
        TaskActions.complete(overdue, now: Self.now, calendar: Self.calendar)
        #expect(dueIDs().isEmpty, "after completing, the next round is a week ahead or later")
        #expect(rolling.dueDate.map { $0 > Self.day(0, hour: 23) } == true)
    }
}
