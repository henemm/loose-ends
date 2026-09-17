import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("DueReminders") struct DueRemindersTests {
    private func berlin() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        return calendar
    }

    private func date(_ day: Int, hour: Int, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour)))
    }

    @Test("Only active tasks with a reminder time still ahead get a reminder, at the reminder hour")
    @MainActor func plan() async throws {
        let store = try TestStore()
        let calendar = try berlin()
        let now = try date(16, hour: 8, in: calendar)

        let tomorrow = TaskItem(rawText: "Steuer abgeben")
        tomorrow.status = .active
        tomorrow.dueDate = try date(17, hour: 15, in: calendar)
        let today = TaskItem(rawText: "Anruf")
        today.status = .active
        today.dueDate = try date(16, hour: 0, in: calendar)
        let yesterday = TaskItem(rawText: "Zu spät")
        yesterday.status = .active
        yesterday.dueDate = try date(15, hour: 0, in: calendar)
        let done = TaskItem(rawText: "Erledigt")
        done.status = .done
        done.dueDate = try date(17, hour: 0, in: calendar)
        let undated = TaskItem(rawText: "Irgendwann")
        undated.status = .active
        for task in [tomorrow, today, yesterday, done, undated] { store.context.insert(task) }

        let reminders = DueReminders.plan(for: [tomorrow, today, yesterday, done, undated], now: now, calendar: calendar)

        let todayAtNine = try date(16, hour: 9, in: calendar)
        let tomorrowAtNine = try date(17, hour: 9, in: calendar)
        #expect(reminders.map(\.title) == ["Anruf", "Steuer abgeben"], "soonest first")
        #expect(reminders.first?.fireDate == todayAtNine)
        #expect(reminders.last?.fireDate == tomorrowAtNine)
        #expect(reminders.first?.identifier == "due_" + today.id.uuidString)
    }

    @Test("A task due today after the reminder hour has passed is not reminded again")
    @MainActor func planAfterHour() async throws {
        let store = try TestStore()
        let calendar = try berlin()
        let task = TaskItem(rawText: "Anruf")
        task.status = .active
        task.dueDate = try date(16, hour: 0, in: calendar)
        store.context.insert(task)

        let late = try date(16, hour: 10, in: calendar)
        #expect(DueReminders.plan(for: [task], now: late, calendar: calendar).isEmpty)
    }

    @Test("Done, Next up and Tomorrow apply from the notification; an unknown task is reported")
    @MainActor func handleActions() async throws {
        let store = try TestStore()
        let calendar = try berlin()
        let now = try date(16, hour: 9, in: calendar)
        let task = TaskItem(rawText: "Rechnung zahlen")
        task.status = .active
        task.dueDate = try date(16, hour: 0, in: calendar)
        store.context.insert(task)

        #expect(DueReminders.handle(.next, taskID: task.id, in: [task], contexts: [], projects: [], now: now, calendar: calendar))
        #expect(task.nextRank == 1)
        DueReminders.handle(.next, taskID: task.id, in: [task], contexts: [], projects: [], now: now, calendar: calendar)
        #expect(task.nextRank == 1, "Next up from a notification never removes the task again")

        DueReminders.handle(.tomorrow, taskID: task.id, in: [task], contexts: [], projects: [], now: now, calendar: calendar)
        let due = try #require(task.dueDate)
        #expect(calendar.component(.day, from: due) == 17)
        #expect(task.dueSourceRaw == FieldSource.user.rawValue)
        #expect(task.revisions?.count == 1)

        DueReminders.handle(.done, taskID: task.id, in: [task], contexts: [], projects: [], now: now, calendar: calendar)
        try store.context.save()
        #expect(task.status == .done)

        #expect(DueReminders.handle(.done, taskID: UUID(), in: [task], contexts: [], projects: []) == false)
    }
}
