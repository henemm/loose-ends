import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// "Loose ends" sorted by pressure (#545, Henning 2026-10-18: "Erst was drängt"; #657, 2026-10-24):
/// overdue and due today, then the undated by weight, then the coming days under "Later", and the
/// parked ones as a block at the end in the order of "Parked". Parked tasks stay in the list (#319),
/// but no longer in the middle. A far date no longer pushes an undated task down.
@Suite("Loose ends by pressure (#545)") struct PressureOrderTests {
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

    @MainActor static func task(
        _ text: String, due: Date? = nil, urgency: Urgency? = nil, importance: Importance? = nil,
        minute: Double = 0, in store: TestStore
    ) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.status = .active
        task.dueDate = due
        task.urgency = urgency
        task.importance = importance
        task.capturedAt = day(-10).addingTimeInterval(minute * 60)
        store.context.insert(task)
        return task
    }

    static func open(_ all: [TaskItem]) -> [UUID] {
        ViewRules.tasks(for: .open, in: all, now: Self.now, calendar: Self.calendar).map(\.id)
    }

    @Test("All four stages: overdue and today, undated by weight, the coming days, parked at the end")
    @MainActor func fourStagesInOrder() async throws {
        let store = try TestStore()
        let parked = Self.task("Keller aufräumen", minute: 0, in: store)
        let undatedLow = Self.task("Fotos sortieren", urgency: .low, minute: 1, in: store)
        let nextWeek = Self.task("Reifen wechseln", due: Self.day(6), minute: 2, in: store)
        let undatedHigh = Self.task("Angebot schreiben", urgency: .high, minute: 3, in: store)
        let today = Self.task("Müll rausbringen", due: Self.day(0, hour: 18), minute: 4, in: store)
        let tomorrow = Self.task("Zahnarzt anrufen", due: Self.day(1), minute: 5, in: store)
        let overdue = Self.task("Rechnung bezahlen", due: Self.day(-2), minute: 6, in: store)
        let undatedNone = Self.task("Buch zurückgeben", minute: 7, in: store)
        TaskActions.park(parked, now: Self.now)
        let all = [parked, undatedLow, nextWeek, undatedHigh, today, tomorrow, overdue, undatedNone]

        #expect(Self.open(all) == [overdue, today, undatedHigh, undatedLow, undatedNone, tomorrow, nextWeek, parked].map(\.id))
    }

    @Test("A parked task of high urgency and importance stands below everything, even below an unweighted one")
    @MainActor func parkedHighUrgencyStandsLast() async throws {
        let store = try TestStore()
        let parkedPressing = Self.task("Steuer machen", due: Self.day(-3), urgency: .high, importance: .high, minute: 0, in: store)
        let plain = Self.task("Blumen gießen", minute: 1, in: store)
        let due = Self.task("Paket abholen", due: Self.day(0), minute: 2, in: store)
        TaskActions.park(parkedPressing, now: Self.now)
        let all = [parkedPressing, plain, due]

        #expect(Self.open(all) == [due, plain, parkedPressing].map(\.id))
        #expect(Self.open(all).last == parkedPressing.id)
    }

    @Test("Dated tasks sort by due date alone, weight does not pull a later date forward")
    @MainActor func datedSortByDueNotWeight() async throws {
        let store = try TestStore()
        let laterUrgent = Self.task("Vertrag kündigen", due: Self.day(3), urgency: .high, importance: .high, minute: 0, in: store)
        let soonerPlain = Self.task("Brot kaufen", due: Self.day(1), minute: 1, in: store)
        let sameDayLater = Self.task("Training", due: Self.day(1, hour: 19), minute: 2, in: store)
        let all = [laterUrgent, soonerPlain, sameDayLater]

        #expect(Self.open(all) == [soonerPlain, sameDayLater, laterUrgent].map(\.id))
    }

    @Test("Undated tasks keep urgency, then importance, then the older one first")
    @MainActor func undatedByWeightThenAge() async throws {
        let store = try TestStore()
        let low = Self.task("niedrig", urgency: .low, minute: 0, in: store)
        let highLater = Self.task("hoch später", urgency: .high, minute: 5, in: store)
        let none = Self.task("ohne", minute: 1, in: store)
        let mediumImportant = Self.task("mittel wichtig", urgency: .medium, importance: .high, minute: 3, in: store)
        let medium = Self.task("mittel", urgency: .medium, minute: 2, in: store)
        let highEarlier = Self.task("hoch früher", urgency: .high, minute: 3, in: store)
        let all = [low, highLater, none, mediumImportant, medium, highEarlier]

        #expect(Self.open(all) == [highEarlier, highLater, mediumImportant, medium, low, none].map(\.id))
    }

    @Test("The parked block keeps the order of the Parked view: last parked first")
    @MainActor func parkedBlockInParkedViewOrder() async throws {
        let store = try TestStore()
        let first = Self.task("Fahrrad verkaufen", urgency: .high, minute: 0, in: store)
        let second = Self.task("Keller", minute: 1, in: store)
        let third = Self.task("Dachboden", due: Self.day(-1), minute: 2, in: store)
        let open = Self.task("Rechnung bezahlen", minute: 3, in: store)
        TaskActions.park(first, now: Self.day(-5))
        TaskActions.park(second, now: Self.day(-3))
        TaskActions.park(third, now: Self.day(-1))
        let all = [first, second, third, open]

        let parkedView = ViewRules.tasks(for: .parked, in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        #expect(parkedView == [third, second, first].map(\.id))
        #expect(Self.open(all) == [open.id] + parkedView)
    }

    @Test("Done tasks and bare subtasks stay out; a dated subtask sorts by its date (#565); a waiting task by its own date and weight")
    @MainActor func doneAndSubtasksOutWaitingInPlace() async throws {
        let store = try TestStore()
        let done = Self.task("Erledigt", due: Self.day(-1), minute: 0, in: store)
        done.status = .done
        let parent = Self.task("Umzug", minute: 1, in: store)
        let sub = Self.task("Kartons holen", due: Self.day(0), minute: 2, in: store)
        sub.parent = parent
        let blocker = Self.task("Schlüssel holen", minute: 3, in: store)
        let waiting = Self.task("Wohnung aufschließen", due: Self.day(0), minute: 4, in: store)
        waiting.blockedBy = [blocker]
        let bare = Self.task("Kisten packen", minute: 5, in: store)
        bare.parent = parent
        let all = [done, parent, sub, blocker, waiting, bare]

        #expect(Self.open(all) == [sub, waiting, parent, blocker].map(\.id))
    }

    @Test("The comparator is a strict weak order: never both ways, and a task never before itself")
    @MainActor func comparatorIsStrict() async throws {
        let store = try TestStore()
        let parked = Self.task("Keller", minute: 0, in: store)
        TaskActions.park(parked, now: Self.now)
        let dated = Self.task("Zahnarzt", due: Self.day(1), minute: 1, in: store)
        let undated = Self.task("Buch", urgency: .medium, minute: 2, in: store)
        let today = Self.task("Müll", due: Self.day(0, hour: 18), minute: 3, in: store)
        let all = [parked, dated, undated, today]
        let order = ViewRules.byPressureThenWeight(now: Self.now, calendar: Self.calendar)

        for a in all {
            #expect(!order(a, a))
            for b in all where a.id != b.id {
                #expect(order(a, b) != order(b, a))
            }
        }
    }

    @Test("A far date rests below an undated task of no weight (#657)")
    @MainActor func farDateBelowUndated() async throws {
        let store = try TestStore()
        let farUrgent = Self.task("Steuererklärung", due: Self.day(40), urgency: .high, importance: .high, minute: 0, in: store)
        let plain = Self.task("Fahrrad flicken", minute: 1, in: store)
        let all = [farUrgent, plain]

        #expect(Self.open(all) == [plain, farUrgent].map(\.id))
        #expect(ViewRules.looseEndsStage(farUrgent, now: Self.now, calendar: Self.calendar) == .later)
    }

    @Test("Tomorrow is Later today and Today tomorrow: the task moves up on its own (#657)")
    @MainActor func tomorrowMovesUpOnItsDay() async throws {
        let store = try TestStore()
        let tomorrow = Self.task("Zahnarzt anrufen", due: Self.day(1, hour: 0), minute: 0, in: store)
        let plain = Self.task("Buch zurückgeben", minute: 1, in: store)
        let all = [tomorrow, plain]
        let nextDay = Self.calendar.date(byAdding: .day, value: 1, to: Self.now)!

        #expect(Self.open(all) == [plain, tomorrow].map(\.id))
        #expect(ViewRules.looseEndsStage(tomorrow, now: Self.now, calendar: Self.calendar) == .later)
        let moved = ViewRules.tasks(for: .open, in: all, now: nextDay, calendar: Self.calendar).map(\.id)
        #expect(moved == [tomorrow, plain].map(\.id))
        #expect(ViewRules.looseEndsStage(tomorrow, now: nextDay, calendar: Self.calendar) == .today)
    }

    @Test("A parked task with a date of today is parked, not today (#657)")
    @MainActor func parkedBeatsToday() async throws {
        let store = try TestStore()
        let parked = Self.task("Keller", due: Self.day(0, hour: 18), minute: 0, in: store)
        TaskActions.park(parked, now: Self.now)

        #expect(ViewRules.looseEndsStage(parked, now: Self.now, calendar: Self.calendar) == .parked)
    }

    @Test("Quick, a tag and a project stand in the same blocks: today, no date by weight, later (#657, 2026-10-27)")
    @MainActor func otherListsInTheSameBlocks() async throws {
        let store = try TestStore()
        let phone = TaskContext(name: "Telefon")
        let house = Project(name: "Haus")
        store.context.insert(phone)
        store.context.insert(house)
        let farUrgent = Self.task("Schnupperkurs buchen", due: Self.day(50), urgency: .high, minute: 0, in: store)
        let plain = Self.task("Massage buchen", minute: 1, in: store)
        let weighty = Self.task("Fußnagel behandeln", importance: .high, minute: 2, in: store)
        let today = Self.task("Rhea schreiben", due: Self.day(0, hour: 18), minute: 3, in: store)
        let all = [farUrgent, plain, weighty, today]
        for task in all {
            task.duration = .minutes15
            task.contexts = [phone]
            task.project = house
        }
        let expected = [today, weighty, plain, farUrgent].map(\.id)

        #expect(ViewRules.tasks(for: .quick, in: all, now: Self.now, calendar: Self.calendar).map(\.id) == expected)
        #expect(ViewRules.tasks(inContext: phone, in: all, now: Self.now, calendar: Self.calendar).map(\.id) == expected)
        #expect(ViewRules.tasks(inProject: house, in: all, now: Self.now, calendar: Self.calendar).map(\.id) == expected)
    }

    @Test("A project's subtask line stands in the block of its task (#657)")
    @MainActor func subtaskLineFollowsItsTask() async throws {
        let store = try TestStore()
        let house = Project(name: "Haus")
        store.context.insert(house)
        let later = Self.task("Umzug", due: Self.day(5), minute: 0, in: store)
        let sub = Self.task("Kartons holen", minute: 1, in: store)
        sub.parent = later
        later.project = house
        let line = ViewRules.ProjectLine.subtask(sub, parent: later)

        #expect(line.owner.id == later.id)
        #expect(ViewRules.looseEndsStage(line.owner, now: Self.now, calendar: Self.calendar) == .later)
    }
}
