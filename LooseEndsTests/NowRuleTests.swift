import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The start screen's "Now" (#368): due today, then the rest of "Next up", each task once. Built
/// from the same sets as the app badge, so the two never disagree. What is left from earlier days
/// waits in the "Loose ends" card until it is sorted (#518).
@Suite("Now on the start screen") struct NowRuleTests {
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

    static func task(_ text: String, due: Date? = nil, rank: Int? = nil) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.status = .active
        task.dueDate = due
        task.nextRank = rank.map(Double.init)
        return task
    }

    static func now(_ all: [TaskItem]) -> ViewRules.NowTasks {
        ViewRules.now(in: all, now: Self.now, calendar: Self.calendar)
    }

    @Test("Due today before the rest of Next up; a task left from yesterday waits in the card (#518)")
    @MainActor func overdueBeforeTodayBeforeLined() async throws {
        let store = try TestStore()
        let lined = Self.task("Angebot schreiben", rank: 0)
        let today = Self.task("Müll rausbringen", due: Self.day(0, hour: 18))
        let overdue = Self.task("Rechnung bezahlen", due: Self.day(-1))
        let all = [lined, today, overdue]
        all.forEach(store.context.insert)

        let result = Self.now(all)
        #expect(result.all.map(\.id) == [today.id, lined.id])
        #expect(ViewRules.leftovers(in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [overdue.id])
        #expect(result.today.map(\.id) == [today.id])
        #expect(result.lined.map(\.id) == [lined.id])
    }

    @Test("A task lined up and due today stands once, in the today group")
    @MainActor func lineEachTaskOnce() async throws {
        let store = try TestStore()
        let both = Self.task("Steuer abgeben", due: Self.day(0, hour: 15), rank: 0)
        store.context.insert(both)

        let result = Self.now([both])
        #expect(result.all.map(\.id) == [both.id])
        #expect(result.today.map(\.id) == [both.id])
        #expect(result.lined.isEmpty)
    }

    @Test("Lined up and left from earlier: it waits in the card too, until it is sorted (#518)")
    @MainActor func overdueAndLinedStaysInTimePressureGroup() async throws {
        let store = try TestStore()
        let both = Self.task("Paket abholen", due: Self.day(-3), rank: 0)
        store.context.insert(both)

        #expect(Self.now([both]).all.isEmpty)
        #expect(ViewRules.leftovers(in: [both], now: Self.now, calendar: Self.calendar).map(\.id) == [both.id])
    }

    @Test("Due earlier today is today, not overdue: the day counts, not the hour")
    @MainActor func todayAtEarlierHourIsToday() async throws {
        let store = try TestStore()
        let morning = Self.task("Bäcker", due: Self.day(0, hour: 9))
        store.context.insert(morning)

        let result = Self.now([morning])
        #expect(result.today.map(\.id) == [morning.id])
        #expect(ViewRules.leftovers(in: [morning], now: Self.now, calendar: Self.calendar).isEmpty)
    }

    @Test("Due today sorts by hour, earliest first")
    @MainActor func todaySortedByHour() async throws {
        let store = try TestStore()
        let evening = Self.task("Training", due: Self.day(0, hour: 19))
        let noon = Self.task("Mittag mit Jan", due: Self.day(0, hour: 12))
        let all = [evening, noon]
        all.forEach(store.context.insert)

        #expect(Self.now(all).today.map(\.id) == [noon.id, evening.id])
    }

    @Test("The rest of Next up keeps its own order")
    @MainActor func linedSortedByRank() async throws {
        let store = try TestStore()
        let third = Self.task("Drei", rank: 3)
        let first = Self.task("Eins", rank: 1)
        let second = Self.task("Zwei", rank: 2)
        let all = [third, first, second]
        all.forEach(store.context.insert)

        #expect(Self.now(all).lined.map(\.id) == [first.id, second.id, third.id])
    }

    @Test("Loose ends: the oldest first, blocked, parked and done stay out (#518)")
    @MainActor func overdueOldestFirst() async throws {
        let store = try TestStore()
        let twoDays = Self.task("Zwei Tage", due: Self.day(-2))
        let fiveDays = Self.task("Fünf Tage", due: Self.day(-5))
        let parked = Self.task("Keller", due: Self.day(-1))
        parked.status = .parked
        let done = Self.task("Erledigt", due: Self.day(-1))
        done.status = .done
        let blocker = Self.task("Schlüssel holen")
        let blocked = Self.task("Wohnung aufschließen", due: Self.day(-1))
        blocked.blockedBy = [blocker]
        let all = [twoDays, fiveDays, parked, done, blocker, blocked]
        all.forEach(store.context.insert)

        #expect(ViewRules.leftovers(in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [fiveDays.id, twoDays.id])
    }

    @Test("Blocked, subtasks, done and parked stay out, even when due today or lined up")
    @MainActor func blockedSubtasksDoneParkedStayOut() async throws {
        let store = try TestStore()
        let blocker = Self.task("Schlüssel holen")
        let blocked = Self.task("Wohnung aufschließen", due: Self.day(0), rank: 0)
        blocked.blockedBy = [blocker]
        let parent = Self.task("Umzug")
        let sub = Self.task("Kartons holen", due: Self.day(0), rank: 1)
        sub.parent = parent
        let done = Self.task("Blumen gießen", due: Self.day(0), rank: 2)
        done.status = .done
        let parked = Self.task("Keller", due: Self.day(-1), rank: 3)
        parked.status = .parked
        let all = [blocker, blocked, parent, sub, done, parked]
        all.forEach(store.context.insert)

        #expect(Self.now(all).all.isEmpty)
    }

    @Test("Due later without a rank stays out")
    @MainActor func futureDueWithoutRankStaysOut() async throws {
        let store = try TestStore()
        let tomorrow = Self.task("Zahnarzt", due: Self.day(1))
        store.context.insert(tomorrow)

        #expect(Self.now([tomorrow]).all.isEmpty)
    }

    @Test("Due later but lined up stands with the lined-up tasks")
    @MainActor func futureDueWithRankIsLined() async throws {
        let store = try TestStore()
        let friday = Self.task("Reifen wechseln", due: Self.day(1), rank: 0)
        store.context.insert(friday)

        #expect(Self.now([friday]).lined.map(\.id) == [friday.id])
    }

    @Test("Nothing in, nothing out")
    @MainActor func emptyInputIsEmpty() async throws {
        let result = Self.now([])
        #expect(result.all.isEmpty)
        #expect(result.today.isEmpty && result.lined.isEmpty)
    }

    @Test("Now holds exactly Due today and Next up, and as many tasks as the badge counts")
    @MainActor func unionMatchesTheTwoSources() async throws {
        let store = try TestStore()
        let all = [
            Self.task("A", rank: 0), Self.task("B", due: Self.day(0), rank: 1), Self.task("C", due: Self.day(-1)),
            Self.task("D", due: Self.day(3)), Self.task("E"), Self.task("F", due: Self.day(2), rank: 2),
        ]
        all.forEach(store.context.insert)

        let ids = Self.now(all).all.map(\.id)
        let next = ViewRules.tasks(for: .next, in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        let due = ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        #expect(Set(ids) == Set(next + due))
        #expect(ids.count == Set(ids).count, "each task once")
        #expect(ids.count == ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar))
    }

    @Test("Due today and the badge are unchanged: a lined-up task due today still stands in Due today (#299)")
    @MainActor func badgeCountAndDueTodayUnchanged() async throws {
        let store = try TestStore()
        let both = Self.task("Steuer abgeben", due: Self.day(0), rank: 0)
        let lined = Self.task("Angebot schreiben", rank: 1)
        let all = [both, lined]
        all.forEach(store.context.insert)

        #expect(ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [both.id])
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 2)
        #expect(Self.now(all).all.map(\.id) == [both.id, lined.id])
    }
}
