import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// "Loose ends" sorted by pressure (#545, Henning 2026-10-18: "Erst was drängt"): overdue and due
/// today, then the coming days, then the undated by weight, and the parked ones as a block at the
/// end in the order of "Parked". Parked tasks stay in the list (#319), but no longer in the middle.
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

    @Test("All four stages: overdue and today, the coming days, undated by weight, parked at the end")
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

        #expect(Self.open(all) == [overdue, today, tomorrow, nextWeek, undatedHigh, undatedLow, undatedNone, parked].map(\.id))
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

    @Test("Done tasks and subtasks stay out; a waiting task sorts by its own date and weight")
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
        let all = [done, parent, sub, blocker, waiting]

        #expect(Self.open(all) == [waiting, parent, blocker].map(\.id))
    }

    @Test("The comparator is a strict weak order: never both ways, and a task never before itself")
    @MainActor func comparatorIsStrict() async throws {
        let store = try TestStore()
        let parked = Self.task("Keller", minute: 0, in: store)
        TaskActions.park(parked, now: Self.now)
        let dated = Self.task("Zahnarzt", due: Self.day(1), minute: 1, in: store)
        let undated = Self.task("Buch", urgency: .medium, minute: 2, in: store)
        let all = [parked, dated, undated]

        for a in all {
            #expect(!ViewRules.byPressureThenWeight(a, a))
            for b in all where a.id != b.id {
                #expect(ViewRules.byPressureThenWeight(a, b) != ViewRules.byPressureThenWeight(b, a))
            }
        }
    }
}
