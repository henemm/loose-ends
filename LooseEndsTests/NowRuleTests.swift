import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The start screen's "Now" (#368): due today, then the rest of "Next up", each task once. Built
/// from the same sets as the app badge, so the two never disagree. What is left from earlier days
/// stays out until it has a new date (#518).
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

    @Test("Due today before the rest of Next up; a task left from yesterday stands last, asking for a new date (#518, #637)")
    @MainActor func overdueBeforeTodayBeforeLined() async throws {
        let store = try TestStore()
        let lined = Self.task("Angebot schreiben", rank: 0)
        let today = Self.task("Müll rausbringen", due: Self.day(0, hour: 18))
        let overdue = Self.task("Rechnung bezahlen", due: Self.day(-1))
        let all = [lined, today, overdue]
        all.forEach(store.context.insert)

        let result = Self.now(all)
        #expect(result.all.map(\.id) == [today.id, lined.id, overdue.id])
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

    @Test("Lined up and left from earlier: the user's lining up counts, it stands with the lined-up tasks (#637)")
    @MainActor func leftoverWithRankStandsInLined() async throws {
        let store = try TestStore()
        let both = Self.task("Paket abholen", due: Self.day(-3), rank: 0)
        let other = Self.task("Angebot schreiben", rank: 1)
        store.context.insert(both)
        store.context.insert(other)

        #expect(Self.now([both, other]).lined.map(\.id) == [both.id, other.id])
        #expect(Self.now([both, other]).all.map(\.id) == [both.id, other.id])
        #expect(ViewRules.leftovers(in: [both], now: Self.now, calendar: Self.calendar).map(\.id) == [both.id])
    }

    @Test("Left from earlier without a rank stands last, the oldest deadline first (#637)")
    @MainActor func leftoverWithoutRankStandsLastOldestFirst() async throws {
        let store = try TestStore()
        let today = Self.task("Müll rausbringen", due: Self.day(0, hour: 18))
        let lined = Self.task("Angebot schreiben", rank: 0)
        let twoDays = Self.task("Zwei Tage", due: Self.day(-2))
        let fiveDays = Self.task("Fünf Tage", due: Self.day(-5))
        let all = [twoDays, lined, fiveDays, today]
        all.forEach(store.context.insert)

        #expect(Self.now(all).all.map(\.id) == [today.id, lined.id, fiveDays.id, twoDays.id])
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

    @Test("Blocked, done and parked stay out, and so does a subtask without a date of its own, even lined up (#565)")
    @MainActor func blockedSubtasksDoneParkedStayOut() async throws {
        let store = try TestStore()
        let blocker = Self.task("Schlüssel holen")
        let blocked = Self.task("Wohnung aufschließen", due: Self.day(0), rank: 0)
        blocked.blockedBy = [blocker]
        let parent = Self.task("Umzug")
        let sub = Self.task("Kartons holen", rank: 1)
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

    @Test("Now holds exactly Due today, Next up and what needs a new date; the icon counts the same (#584, #637)")
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
        let left = ViewRules.leftovers(in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        #expect(Set(ids) == Set(next + due + left))
        #expect(ids.count == Set(ids).count, "each task once")
        #expect(ids.count == 4)
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == ids.count,
                "C from yesterday stands in Now and on the icon (#518, #584, #637)")
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

    @Test("Henning's case: four deadlines passed, one of them lined up, one more lined up: icon and Now say 5 (#637)")
    @MainActor func henningsCaseIsFiveEverywhere() async throws {
        let store = try TestStore()
        let all = [
            Self.task("Altpapier", due: Self.day(-2), rank: 0), Self.task("Steuer", due: Self.day(-3)),
            Self.task("Karte", due: Self.day(-1)), Self.task("Kette", due: Self.day(-4)),
            Self.task("Friederich", rank: 1),
        ]
        all.forEach(store.context.insert)

        #expect(Self.now(all).all.count == 5)
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 5)
        #expect(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).count == 4)
        #expect(ViewRules.tasks(for: .next, in: all, now: Self.now, calendar: Self.calendar).count == 2)
    }

    @Test("The icon number is the number over Now, rows plus a counting Knäuel, whatever the mix (#637, #643)")
    @MainActor func badgeEqualsNowEverywhere() async throws {
        let store = try TestStore()
        let blocker = Self.task("Schlüssel holen")
        let blocked = Self.task("Wohnung aufschließen", due: Self.day(-1))
        blocked.blockedBy = [blocker]
        let parked = Self.task("Keller", due: Self.day(-1), rank: 0)
        parked.status = .parked
        let done = Self.task("Erledigt", due: Self.day(-1), rank: 1)
        done.status = .done
        let parent = Self.task("Umzug")
        let plainSub = Self.task("Kartons holen", rank: 2)
        plainSub.parent = parent
        let datedSub = Self.task("Kartons abholen", due: Self.day(-2))
        datedSub.parent = parent
        let scenes: [[TaskItem]] = [
            [],
            [Self.task("Heute", due: Self.day(0, hour: 18))],
            [Self.task("Heute", due: Self.day(0, hour: 18), rank: 0), Self.task("Eingereiht", rank: 1)],
            [Self.task("Gestern", due: Self.day(-1)), Self.task("Gestern eingereiht", due: Self.day(-1), rank: 0)],
            [Self.task("Frühstück", due: Self.day(0, hour: 9)), Self.task("Brief", due: Self.day(0, hour: 0))],
            [blocker, blocked, parked, done, parent, plainSub, datedSub],
            [Self.task("Morgen", due: Self.day(1)), Self.task("Morgen eingereiht", due: Self.day(1), rank: 0)],
        ]
        // With a Knäuel (#643): it stands under the date, not among the rows, and the number over "Now"
        // counts it when it is "Due" or "Next up" (Henning, 2026-10-24). Its share is written out here.
        let knaeuelScenes: [(scene: [TaskItem], share: Int)] = [
            ([Self.knaeuel("Knäuel heute", due: Self.day(0, hour: 18)), Self.task("Heute", due: Self.day(0, hour: 18))], 1),
            ([Self.knaeuel("Knäuel eingereiht", rank: 0), Self.task("Eingereiht", rank: 1)], 1),
            ([Self.knaeuel("Knäuel ohne Datum"), Self.task("Eingereiht", rank: 0)], 0),
            ([Self.knaeuel("Knäuel gestern", due: Self.day(-1)), Self.task("Gestern", due: Self.day(-1))], 1),
        ]
        scenes.forEach { $0.forEach(store.context.insert) }
        knaeuelScenes.forEach { $0.scene.forEach(store.context.insert) }

        let all = scenes.map { ($0, 0) } + knaeuelScenes.map { ($0.scene, $0.share) }
        for (index, (scene, share)) in all.enumerated() {
            let badge = ViewRules.badgeCount(in: scene, now: Self.now, calendar: Self.calendar)
            #expect(badge == ViewRules.nowCount(in: scene, now: Self.now, calendar: Self.calendar), "scene \(index)")
            #expect(badge == Self.now(scene).all.count + share, "scene \(index)")
        }
    }

    static func knaeuel(_ text: String, due: Date? = nil, rank: Int? = nil) -> TaskItem {
        let task = Self.task(text, due: due, rank: rank)
        task.knaeuelAt = Self.now
        return task
    }
}
