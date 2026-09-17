import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("TaskActions") struct TaskActionsTests {
    /// Berlin, Gregorian: the tests reason about weekdays, so the calendar must not depend on the runner.
    private func berlin() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 10)))
    }

    @Test("Done moves a plain task to Done and out of Next up")
    @MainActor func completePlainTask() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Fenster putzen")
        task.status = .active
        task.nextRank = 3
        store.context.insert(task)
        let now = Date()

        TaskActions.complete(task, now: now)
        try store.context.save()

        #expect(task.status == .done)
        #expect(task.completedAt == now)
        #expect(task.nextRank == nil)
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(ViewRules.tasks(for: .done, in: all).map(\.id) == [task.id])
        #expect(ViewRules.tasks(for: .next, in: all).isEmpty)
    }

    @Test("Done on a repeating task records the cycle and rolls the due date forward")
    @MainActor func completeRepeatingTask() async throws {
        let store = try TestStore()
        let calendar = try berlin()
        let task = TaskItem(rawText: "Rasen mähen")
        task.status = .active
        let saturday = try day(2026, 9, 19, in: calendar)
        task.dueDate = saturday
        task.repeatRule = RepeatRule(frequency: .weekly, weekdays: [7])
        store.context.insert(task)

        TaskActions.complete(task, now: saturday, calendar: calendar)
        try store.context.save()

        #expect(task.status == .active, "a repeating task never ends")
        #expect(task.completedAt == nil)
        let records = try #require(task.completions)
        #expect(records.count == 1)
        #expect(records.first?.dueDateAtCompletion == saturday)
        let next = try #require(task.dueDate)
        let parts = calendar.dateComponents([.year, .month, .day], from: next)
        #expect(parts.year == 2026 && parts.month == 9 && parts.day == 26)
    }

    @Test("Restore takes a task back from Done and keeps its completion records")
    @MainActor func restoreFromDone() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Steuer")
        store.context.insert(task)
        task.completions = [CompletionRecord(task: task, dueDateAtCompletion: nil)]
        TaskActions.complete(task)

        TaskActions.restore(task)
        try store.context.save()

        #expect(task.status == .active)
        #expect(task.completedAt == nil)
        #expect(task.completions?.count == 1)
    }

    @Test("Next up appends after the highest rank; a second toggle removes the task again")
    @MainActor func toggleNext() async throws {
        let store = try TestStore()
        let first = TaskItem(rawText: "Eins")
        first.status = .active
        first.nextRank = 5
        let second = TaskItem(rawText: "Zwei")
        second.status = .active
        store.context.insert(first)
        store.context.insert(second)

        TaskActions.toggleNext(second, among: [first, second])
        #expect(second.nextRank == 6)
        #expect(ViewRules.tasks(for: .next, in: [first, second]).map(\.rawText) == ["Eins", "Zwei"])

        TaskActions.toggleNext(second, among: [first, second])
        #expect(second.nextRank == nil)
        try store.context.save()
    }

    @Test("Park and activate flip the status and the parked timestamp")
    @MainActor func parkAndActivate() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Keller aufräumen")
        task.status = .active
        task.nextRank = 1
        store.context.insert(task)
        let now = Date()

        TaskActions.park(task, now: now)
        #expect(task.status == .parked)
        #expect(task.parkedAt == now)
        #expect(task.nextRank == nil, "a parked task leaves Next up")
        #expect(ViewRules.tasks(for: .parked, in: [task]).count == 1)

        TaskActions.activate(task)
        try store.context.save()
        #expect(task.status == .active)
        #expect(task.parkedAt == nil)
    }

    @Test("Move targets resolve from a Wednesday to tomorrow, Saturday and Monday")
    func moveTargetsFromWednesday() throws {
        let calendar = try berlin()
        let wednesday = try day(2026, 9, 16, in: calendar)

        let tomorrow = TaskActions.dueDate(for: .tomorrow, now: wednesday, calendar: calendar)
        let weekend = TaskActions.dueDate(for: .weekend, now: wednesday, calendar: calendar)
        let nextWeek = TaskActions.dueDate(for: .nextWeek, now: wednesday, calendar: calendar)

        #expect(calendar.component(.day, from: tomorrow) == 17)
        #expect(calendar.component(.day, from: weekend) == 19)
        #expect(calendar.component(.weekday, from: weekend) == 7)
        #expect(calendar.component(.day, from: nextWeek) == 21)
        #expect(calendar.component(.weekday, from: nextWeek) == 2)
        #expect(calendar.component(.hour, from: tomorrow) == 0, "a moved task is due on a day, not at a time")
    }

    @Test("Weekend from a Saturday means the next Saturday, not today")
    func moveWeekendFromSaturday() throws {
        let calendar = try berlin()
        let saturday = try day(2026, 9, 19, in: calendar)
        let weekend = TaskActions.dueDate(for: .weekend, now: saturday, calendar: calendar)
        #expect(calendar.component(.day, from: weekend) == 26)
    }

    @Test("Move writes a user revision and marks the due date as set by the user")
    @MainActor func moveWritesRevision() async throws {
        let store = try TestStore()
        let calendar = try berlin()
        let task = TaskItem(rawText: "Anruf Zahnarzt")
        task.status = .active
        store.context.insert(task)
        let wednesday = try day(2026, 9, 16, in: calendar)

        let due = TaskActions.move(task, to: .tomorrow, contexts: [], projects: [], now: wednesday, calendar: calendar)
        try store.context.save()

        #expect(task.dueDate == due)
        #expect(task.dueHasTime == false)
        #expect(task.dueSourceRaw == FieldSource.user.rawValue)
        let revision = try #require(task.revisions?.first)
        #expect(revision.author == .user)
        #expect(revision.field == .dueDate)
        #expect(revision.oldValue == nil)
        #expect(revision.newValue == due.ISO8601Format())
    }
}
