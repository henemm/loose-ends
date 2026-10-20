import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("PendingCompletions") struct PendingCompletionsTests {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    @MainActor
    private func openTask(_ text: String, in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.status = .active
        store.context.insert(task)
        return task
    }

    @Test("Within the three seconds nothing is completed; after them the task is done (#32)")
    @MainActor func completesOnlyAfterTheWindow() async throws {
        let store = try TestStore()
        let task = openTask("Fenster putzen", in: store)
        let pending = PendingCompletions()

        pending.schedule(task.id, now: start)
        #expect(pending.isPending(task.id))
        #expect(pending.nextDeadline == start.addingTimeInterval(3))

        let early = pending.commitDue(in: [task], now: start.addingTimeInterval(2.9))
        #expect(early.isEmpty)
        #expect(task.status == .active, "inside the window the task stays open")
        #expect(pending.isPending(task.id))

        let due = pending.commitDue(in: [task], now: start.addingTimeInterval(3))
        try store.context.save()
        #expect(due.map(\.id) == [task.id])
        #expect(task.status == .done)
        #expect(task.completedAt == start.addingTimeInterval(3))
        #expect(!pending.isPending(task.id))
        #expect(pending.nextDeadline == nil)
    }

    @Test("A second tap inside the window takes Done back; the task never completes (#32)")
    @MainActor func cancelInsideTheWindow() async throws {
        let store = try TestStore()
        let task = openTask("Steuer", in: store)
        let pending = PendingCompletions()

        pending.schedule(task.id, now: start)
        #expect(pending.cancel(task.id))
        let later = pending.commitDue(in: [task], now: start.addingTimeInterval(10))

        #expect(later.isEmpty)
        #expect(task.status == .active)
        #expect(task.completedAt == nil)
        #expect(!pending.isPending(task.id))
    }

    @Test("A tap after the window has nothing left to take back (#32)")
    @MainActor func cancelAfterTheWindow() async throws {
        let store = try TestStore()
        let task = openTask("Keller", in: store)
        let pending = PendingCompletions()

        pending.schedule(task.id, now: start)
        pending.commitDue(in: [task], now: start.addingTimeInterval(3.5))

        #expect(!pending.cancel(task.id))
        #expect(task.status == .done, "a late tap does not undo the completion")
    }

    @Test("Scheduling twice does not stretch the window")
    @MainActor func secondScheduleKeepsTheDeadline() async throws {
        let store = try TestStore()
        let task = openTask("Rasen", in: store)
        let pending = PendingCompletions()

        pending.schedule(task.id, now: start)
        pending.schedule(task.id, now: start.addingTimeInterval(2))

        #expect(pending.nextDeadline == start.addingTimeInterval(3))
    }

    @Test("Each task has its own window; the earliest deadline drives the next commit")
    @MainActor func independentWindows() async throws {
        let store = try TestStore()
        let first = openTask("Eins", in: store)
        let second = openTask("Zwei", in: store)
        let pending = PendingCompletions()

        pending.schedule(first.id, now: start)
        pending.schedule(second.id, now: start.addingTimeInterval(1))

        let due = pending.commitDue(in: [first, second], now: start.addingTimeInterval(3))
        #expect(due.map(\.id) == [first.id])
        #expect(second.status == .active)
        #expect(pending.nextDeadline == start.addingTimeInterval(4))
    }

    @Test("Leaving the foreground ends every window at once")
    @MainActor func commitAllEndsEveryWindow() async throws {
        let store = try TestStore()
        let task = openTask("Mülltonne", in: store)
        let pending = PendingCompletions()

        pending.schedule(task.id, now: start)
        let due = pending.commitDue(in: [task], all: true, now: start.addingTimeInterval(0.5))

        #expect(due.map(\.id) == [task.id])
        #expect(task.status == .done)
        #expect(pending.nextDeadline == nil)
    }

    @Test("A task gone or finished elsewhere meanwhile is dropped, not completed twice")
    @MainActor func goneOrFinishedTaskIsDropped() async throws {
        let store = try TestStore()
        let finished = openTask("Schon erledigt", in: store)
        let gone = openTask("Gelöscht", in: store)
        let pending = PendingCompletions()

        pending.schedule(finished.id, now: start)
        pending.schedule(gone.id, now: start)
        TaskActions.complete(finished, now: start.addingTimeInterval(1))

        let due = pending.commitDue(in: [finished], now: start.addingTimeInterval(3))
        #expect(due.isEmpty)
        #expect(finished.completedAt == start.addingTimeInterval(1), "the earlier completion stands")
        #expect(pending.nextDeadline == nil, "both windows are cleared")
    }

    @Test("A repeating task rolls forward once the window has run out")
    @MainActor func repeatingTaskRollsForward() async throws {
        let store = try TestStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let task = openTask("Tabletten nehmen", in: store)
        task.repeatRule = RepeatRule(frequency: .daily)
        let pending = PendingCompletions()

        pending.schedule(task.id, now: start)
        pending.commitDue(in: [task], now: start.addingTimeInterval(3), calendar: calendar)
        try store.context.save()

        #expect(task.status == .active, "a repeating task never ends")
        #expect(task.completions?.count == 1)
        #expect(task.dueDate != nil)
    }

    // MARK: - Open subtasks (#565, Schnitt 3)

    @Test("Complete all: the open subtasks finish with their task once the window ran out, a done one keeps its time")
    @MainActor func completeAllTakesOpenSubtasksAlong() async throws {
        let store = try TestStore()
        let task = openTask("Umzug", in: store)
        let boxes = try Subtasks.add("Kartons holen", to: task, in: store.context, now: start)
        let keys = try Subtasks.add("Schlüssel abgeben", to: task, in: store.context, now: start)
        let earlier = start.addingTimeInterval(-60)
        Subtasks.toggle(keys, now: earlier)
        #expect(Subtasks.open(of: task).map(\.id) == [boxes.id])
        let pending = PendingCompletions()

        pending.schedule(task.id, now: start, withSubtasks: true)
        _ = pending.commitDue(in: [task], now: start.addingTimeInterval(2))
        #expect(boxes.status == .active, "inside the window the subtask stays open too")

        _ = pending.commitDue(in: [task], now: start.addingTimeInterval(3))
        try store.context.save()
        #expect(task.status == .done)
        #expect(boxes.status == .done)
        #expect(boxes.completedAt == start.addingTimeInterval(3))
        #expect(keys.completedAt == earlier, "a line done before keeps its own time")
        #expect(Subtasks.open(of: task).isEmpty)
    }

    @Test("Keep open ones: the task finishes, its open subtasks stay open")
    @MainActor func keepOpenLeavesSubtasks() async throws {
        let store = try TestStore()
        let task = openTask("Umzug", in: store)
        let boxes = try Subtasks.add("Kartons holen", to: task, in: store.context, now: start)
        let pending = PendingCompletions()

        pending.schedule(task.id, now: start)
        _ = pending.commitDue(in: [task], now: start.addingTimeInterval(3))
        try store.context.save()
        #expect(task.status == .done)
        #expect(boxes.status == .active)
    }

    @Test("Undo after Complete all takes back the task and its subtasks; a new Done asks afresh")
    @MainActor func undoForgetsCompleteAll() async throws {
        let store = try TestStore()
        let task = openTask("Umzug", in: store)
        let boxes = try Subtasks.add("Kartons holen", to: task, in: store.context, now: start)
        let pending = PendingCompletions()

        pending.schedule(task.id, now: start, withSubtasks: true)
        #expect(pending.cancel(task.id))
        #expect(!pending.withSubtasks.contains(task.id))
        pending.schedule(task.id, now: start.addingTimeInterval(5))
        _ = pending.commitDue(in: [task], now: start.addingTimeInterval(8))
        try store.context.save()
        #expect(task.status == .done)
        #expect(boxes.status == .active, "the second Done was without its subtasks")
    }
}
