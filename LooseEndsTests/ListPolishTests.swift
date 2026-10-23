import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("Next up order, Old and Completed details") struct ListPolishTests {
    @Test("Dragging a row renumbers every rank in the new order")
    @MainActor func moveNext() async throws {
        let store = try TestStore()
        let names = ["Eins", "Zwei", "Drei", "Vier"]
        let items = names.enumerated().map { index, name -> TaskItem in
            let task = TaskItem(rawText: name)
            task.status = .active
            task.nextRank = Double(index + 1) * 10
            store.context.insert(task)
            return task
        }

        TaskActions.moveNext(items, from: IndexSet(integer: 3), to: 1)
        try store.context.save()

        let ordered = ViewRules.tasks(for: .next, in: items)
        #expect(ordered.map(\.rawText) == ["Eins", "Vier", "Zwei", "Drei"])
        #expect(ordered.map(\.nextRank) == [1, 2, 3, 4])
    }

    @Test("Postponed counts only the user's moves to a later date")
    @MainActor func postponeCount() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Steuer")
        task.status = .active
        store.context.insert(task)
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)
        let day2 = day1.addingTimeInterval(86_400)
        let day3 = day2.addingTimeInterval(86_400)

        RevisionService.set(.dueDate, to: day1.ISO8601Format(), on: task, contexts: [], projects: [])
        #expect(ViewRules.postponeCount(task) == 0, "a first due date is not a postponement")
        RevisionService.set(.dueDate, to: day2.ISO8601Format(), on: task, contexts: [], projects: [])
        RevisionService.set(.dueDate, to: day3.ISO8601Format(), on: task, contexts: [], projects: [])
        #expect(ViewRules.postponeCount(task) == 2)
        RevisionService.set(.dueDate, to: day1.ISO8601Format(), on: task, contexts: [], projects: [])
        #expect(ViewRules.postponeCount(task) == 2, "pulling a task forward is not a postponement")

        let ai = Revision(task: task, field: .dueDate, oldValue: day1.ISO8601Format(), newValue: day3.ISO8601Format(), author: .ai)
        task.revisions = (task.revisions ?? []) + [ai]
        try store.context.save()
        #expect(ViewRules.postponeCount(task) == 2, "the AI's guesses do not count against the user")
    }

    @Test("Completed tasks group by day, newest day first, newest task first within a day")
    @MainActor func groupedByDay() async throws {
        let store = try TestStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        func at(_ day: Int, _ hour: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour)))
        }
        let a = TaskItem(rawText: "A"); a.status = .done; a.completedAt = try at(15, 9)
        let b = TaskItem(rawText: "B"); b.status = .done; b.completedAt = try at(16, 18)
        let c = TaskItem(rawText: "C"); c.status = .done; c.completedAt = try at(16, 8)
        for item in [a, b, c] { store.context.insert(item) }

        let shown = ViewRules.tasks(for: .done, in: [a, b, c])
        let groups = ViewRules.groupedByCompletionDay(shown, calendar: calendar)

        #expect(groups.count == 2)
        #expect(groups.map { calendar.component(.day, from: $0.day) } == [16, 15])
        #expect(groups[0].tasks.map(\.rawText) == ["B", "C"])
        #expect(groups[1].tasks.map(\.rawText) == ["A"])
    }

    @Test("Completed by weeks (#646): Monday to Sunday, newest first, the days inside, the week's beads, the current week marked")
    @MainActor func groupedByWeek() async throws {
        let store = try TestStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        func at(_ day: Int, _ hour: Int) throws -> Date {
            try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)))
        }
        // Week 19 to 25 October (Mon to Sun), week 12 to 18, and the one before.
        let a = TaskItem(rawText: "A"); a.status = .done; a.completedAt = try at(25, 23); a.countsAt = try at(1, 9)
        let b = TaskItem(rawText: "B"); b.status = .done; b.completedAt = try at(19, 0)
        let c = TaskItem(rawText: "C"); c.status = .done; c.completedAt = try at(18, 23); c.knaeuelAt = try at(1, 9)
        let d = TaskItem(rawText: "D"); d.status = .done; d.completedAt = try at(5, 12)
        let all = [a, b, c, d]
        all.forEach(store.context.insert)

        let shown = ViewRules.tasks(for: .done, in: all)
        let weeks = ViewRules.groupedByCompletionWeek(shown, all: all, now: try at(22, 10), calendar: calendar)
        #expect(weeks.count == 3)
        #expect(weeks.map { calendar.component(.day, from: $0.week.lowerBound) } == [19, 12, 5])
        #expect(weeks.map(\.isCurrent) == [true, false, false])
        #expect(weeks[0].days.flatMap { $0.tasks.map(\.rawText) } == ["A", "B"], "Sunday 23:00 and Monday 0:00 are one week")
        #expect(weeks[0].days.count == 2)
        #expect(weeks[0].beads.map(\.title) == ["A"])
        #expect(weeks[1].beads.map(\.isKnaeuel) == [true])
        #expect(weeks[2].beads.isEmpty, "a week without a bead shows its empty string")
        let en = Locale(identifier: "en_US")
        let head = TaskListView.weekHead(weeks[2], calendar: calendar, locale: en)
        #expect(head.contains("5") && head.contains("11"), "5 to 11 October in Berlin, not the UTC days: \(head)")
        #expect(TaskListView.weekHead(weeks[0], calendar: calendar, locale: en).contains("19"))
    }
}
