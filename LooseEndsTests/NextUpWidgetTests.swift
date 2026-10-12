import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The check mark in the "Next up" widget (#307), against an in-memory store.
@Suite("Next up widget") struct NextUpWidgetTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @MainActor
    private func lined(_ text: String, rank: Double, in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.status = .active
        task.nextRank = rank
        store.context.insert(task)
        return task
    }

    @Test("The check mark completes the task and it leaves Next up")
    @MainActor func completesTask() throws {
        let store = try TestStore()
        let task = lined("Rechnung bezahlen", rank: 1, in: store)
        try store.context.save()

        let completed = try NextUpWidgetActions.complete(task.id, in: store.context, now: now)

        #expect(completed)
        #expect(task.status == .done)
        #expect(task.completedAt == now)
        #expect(task.nextRank == nil)
        #expect(try NextUpWidgetActions.nextUp(in: store.context, limit: 3).isEmpty)
    }

    @Test("A repeating task rolls forward with a completion record and stays in Next up")
    @MainActor func repeatingRollsForward() throws {
        let store = try TestStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let task = lined("Tabletten nehmen", rank: 1, in: store)
        task.repeatRule = RepeatRule(frequency: .daily)
        try store.context.save()

        try NextUpWidgetActions.complete(task.id, in: store.context, now: now, calendar: calendar)

        #expect(task.status == .active, "a repeating task never ends")
        #expect(task.completions?.count == 1)
        #expect(task.dueDate != nil)
    }

    @Test("A stale line from before the reload completes nothing twice")
    @MainActor func doneTaskIsLeftAlone() throws {
        let store = try TestStore()
        let task = lined("Auto waschen", rank: 1, in: store)
        try NextUpWidgetActions.complete(task.id, in: store.context, now: now)

        let again = try NextUpWidgetActions.complete(task.id, in: store.context, now: now.addingTimeInterval(60))

        #expect(!again)
        #expect(task.completedAt == now, "the first completion stands")
    }

    @Test("A task that no longer exists is no error")
    @MainActor func unknownTask() throws {
        let store = try TestStore()
        let completed = try NextUpWidgetActions.complete(UUID(), in: store.context)
        #expect(!completed)
    }

    @Test("The widget lists Next up in its order, at most the limit")
    @MainActor func listsNextUp() throws {
        let store = try TestStore()
        let second = lined("Zweite", rank: 2, in: store)
        let first = lined("Erste", rank: 1, in: store)
        _ = lined("Dritte", rank: 3, in: store)
        try store.context.save()

        let lines = try NextUpWidgetActions.nextUp(in: store.context, limit: 2)

        #expect(lines.map(\.id) == [first.id, second.id])
    }

    @Test("A title tapped in the widget asks the app to open that task")
    @MainActor func openTaskSignalsTheApp() async throws {
        OpenTaskRequest.shared.taskID = nil
        let id = UUID()

        _ = try await OpenTaskIntent(taskID: id).perform()

        #expect(OpenTaskRequest.shared.taskID == id)
        OpenTaskRequest.shared.taskID = nil
    }
}
