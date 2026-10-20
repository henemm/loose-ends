import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Subtasks in the lists (#565, Henning 2026-10-20, concept D): a subtask stands outside its task
/// only with something of its own. Its own date puts it in "Due", "Now", the badge and the start
/// headline; its own tag in that tag's list. "New", "Loose ends" and "Next up" stay top level.
@Suite("Subtasks in the lists") struct SubtaskListsTests {
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

    @MainActor static func task(_ text: String, in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.title = text
        task.status = .active
        store.context.insert(task)
        return task
    }

    @Test("A subtask with its own date today stands in Due, Due today, Now and the badge; one without stays out")
    @MainActor func ownDateLists() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let dated = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        dated.dueDate = Self.day(0, hour: 15)
        dated.dueHasTime = true
        let bare = try Subtasks.add("Kisten packen", to: parent, in: store.context, now: Self.day(-1))
        let all = [parent, dated, bare]

        let due = ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        #expect(due == [dated.id])
        #expect(ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [dated.id])
        #expect(ViewRules.now(in: all, now: Self.now, calendar: Self.calendar).today.map(\.id) == [dated.id])
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 1)
    }

    @Test("A done subtask with a date stays out, as a done task does")
    @MainActor func doneSubtaskStaysOut() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let sub = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        sub.dueDate = Self.day(0)
        Subtasks.toggle(sub, now: Self.now)
        let all = [parent, sub]

        #expect(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).isEmpty)
        #expect(ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).isEmpty)
    }

    @Test("A subtask with its own tag stands in that tag's list; one without stays out")
    @MainActor func ownTagLists() async throws {
        let store = try TestStore()
        let phone = TaskContext(name: "Telefon", sortOrder: 0)
        store.context.insert(phone)
        let parent = Self.task("Umzug", in: store)
        let tagged = try Subtasks.add("Vermieter anrufen", to: parent, in: store.context)
        tagged.contexts = [phone]
        let bare = try Subtasks.add("Kisten packen", to: parent, in: store.context)
        let all = [parent, tagged, bare]

        #expect(ViewRules.tasks(inContext: phone, in: all).map(\.id) == [tagged.id])
    }

    @Test("New, Loose ends and Next up keep to top-level tasks, whatever a subtask carries")
    @MainActor func topLevelViewsStay() async throws {
        let store = try TestStore()
        let phone = TaskContext(name: "Telefon", sortOrder: 0)
        store.context.insert(phone)
        let parent = Self.task("Umzug", in: store)
        let sub = try Subtasks.add("Vermieter anrufen", to: parent, in: store.context)
        sub.dueDate = Self.day(0)
        sub.contexts = [phone]
        sub.nextRank = 0
        let all = [parent, sub]

        for kind in [ViewKind.new, .open, .next] {
            #expect(!ViewRules.tasks(for: kind, in: all, now: Self.now, calendar: Self.calendar).contains { $0.id == sub.id },
                    "\(kind) should keep to top-level tasks")
        }
    }

    @Test("The start headline counts a subtask due today by its own date")
    @MainActor func headlineCountsSubtask() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let sub = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        sub.dueDate = Self.day(0, hour: 0)
        let headline = StartHeadline.of([parent, sub], now: Self.now, calendar: Self.calendar)
        #expect(headline == .dueToday(title: "Kartons holen", count: 1))
    }
}
