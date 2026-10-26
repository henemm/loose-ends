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
        #expect(try NextUpWidgetActions.nextUp(in: store.context, limit: 3).lines.isEmpty)
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

        let lines = try NextUpWidgetActions.nextUp(in: store.context, limit: 2).lines

        #expect(lines.map(\.id) == [first.id, second.id])
    }

    @Test("The widget shows what the start screen's Now shows: the Knäuel first, then due today and lined up")
    @MainActor func followsTheStartScreen() throws {
        let store = try TestStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let queued = lined("Vorgemerkt", rank: 1, in: store)
        let due = TaskItem(rawText: "Heute fällig")
        due.status = .active
        due.dueDate = now.addingTimeInterval(60 * 60)
        due.dueHasTime = true
        store.context.insert(due)
        let knaeuel = TaskItem(rawText: "Das Knäuel")
        knaeuel.status = .active
        knaeuel.knaeuelAt = now
        store.context.insert(knaeuel)
        try store.context.save()

        let result = try NextUpWidgetActions.nextUp(in: store.context, limit: 6, now: now, calendar: calendar)

        #expect(result.lines.map(\.id) == [knaeuel.id, due.id, queued.id])
        #expect(result.total == 3)
    }

    @Test("A title tapped in the widget asks the app to open that task")
    @MainActor func openTaskSignalsTheApp() async throws {
        OpenTaskRequest.shared.taskID = nil
        let id = UUID()

        _ = try await OpenTaskIntent(taskID: id).perform()

        #expect(OpenTaskRequest.shared.taskID == id)
        OpenTaskRequest.shared.taskID = nil
    }

    // MARK: Margin, number and the knot (#521)

    private func line(_ title: String) -> NextUpWidgetActions.Line {
        NextUpWidgetActions.Line(id: UUID(), title: title, margin: "", pressing: false)
    }

    @Test("A line carries the margin of the list rows: red for a time today, the duration without a date")
    @MainActor func linesCarryTheMargin() throws {
        let store = try TestStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let timed = lined("Zahnarzt anrufen", rank: 1, in: store)
        timed.dueDate = now.addingTimeInterval(60 * 60)
        timed.dueHasTime = true
        let quick = lined("Fahrradschloss ölen", rank: 2, in: store)
        quick.durationRaw = DurationBucket.minutes15.rawValue
        try store.context.save()

        let lines = try NextUpWidgetActions.nextUp(in: store.context, limit: 3, now: now, calendar: calendar).lines

        #expect(lines.map(\.title) == ["Zahnarzt anrufen", "Fahrradschloss ölen"])
        #expect(lines[0].pressing)
        #expect(lines[0].margin == ViewRules.marginMark(of: timed, now: now, calendar: calendar).text)
        #expect(!lines[1].pressing)
        #expect(lines[1].margin == DurationBucket.minutes15.shortText)
    }

    @Test("The head counts all of Next up, not only the lines shown")
    @MainActor func totalCountsAll() throws {
        let store = try TestStore()
        for rank in 1...8 {
            _ = lined("Aufgabe \(rank)", rank: Double(rank), in: store)
        }
        try store.context.save()

        let result = try NextUpWidgetActions.nextUp(in: store.context, limit: 3)

        #expect(result.lines.count == 3)
        #expect(result.total == 8)
    }

    @Test("Without a mark the widget shows one entry, the list as it is")
    func planWithoutMark() {
        let lines = [line("A"), line("B")]

        let plan = NextUpWidgetActions.plan(lines: lines, total: 2, mark: nil, limit: 3, now: now)

        #expect(plan.count == 1)
        #expect(plan[0].lines == lines)
    }

    @Test("Right after the tap the knot stands in the line's old place, then the list moves up")
    func planTiesTheKnotInPlace() {
        let done = line("Zahnarzt anrufen")
        let rest = [line("B"), line("C"), line("D")]
        let mark = NextUpWidgetActions.CompletionMark(line: done, index: 1, at: now)
        let reload = now.addingTimeInterval(0.3)

        let plan = NextUpWidgetActions.plan(lines: rest, total: 3, mark: mark, limit: 3, now: reload)

        #expect(plan.count == 2)
        #expect(plan[0].date == reload)
        #expect(plan[0].lines.map(\.title) == ["B", "Zahnarzt anrufen", "C"])
        #expect(plan[0].lines[1].done)
        #expect(plan[1].date == now.addingTimeInterval(NextUpWidgetActions.knotDuration))
        #expect(plan[1].lines == rest)
    }

    @Test("A repeating task that stays in Next up shows its knot once, not twice")
    func planReplacesARepeatingLine() {
        let pills = line("Tabletten nehmen")
        let mark = NextUpWidgetActions.CompletionMark(line: pills, index: 0, at: now)

        let plan = NextUpWidgetActions.plan(lines: [pills, line("B")], total: 2, mark: mark, limit: 3, now: now)

        #expect(plan[0].lines.map(\.title) == ["Tabletten nehmen", "B"])
        #expect(plan[0].lines[0].done)
        #expect(plan[1].lines.allSatisfy { !$0.done })
    }

    @Test("A mark from a reload long past shows nothing")
    func planIgnoresAStaleMark() {
        let mark = NextUpWidgetActions.CompletionMark(line: line("Alt"), index: 0, at: now)

        let plan = NextUpWidgetActions.plan(lines: [line("B")], total: 1, mark: mark, limit: 3, now: now.addingTimeInterval(60))

        #expect(plan.count == 1)
        #expect(plan[0].lines.map(\.title) == ["B"])
    }

    @Test("The mark survives the trip through the app group")
    func markRoundTrip() throws {
        let defaults = try #require(UserDefaults(suiteName: "NextUpWidgetTests-\(UUID().uuidString)"))
        let mark = NextUpWidgetActions.CompletionMark(line: line("Rasen mähen"), index: 2, at: now)

        NextUpWidgetActions.store(mark, in: defaults)

        #expect(NextUpWidgetActions.loadMark(from: defaults) == mark)
    }

    @Test("Only the capture link opens capture")
    func captureLink() throws {
        #expect(NextUpWidgetActions.isCaptureLink(NextUpWidgetActions.captureURL))
        #expect(!NextUpWidgetActions.isCaptureLink(try #require(URL(string: "looseends://task/123"))))
        #expect(!NextUpWidgetActions.isCaptureLink(try #require(URL(string: "https://capture"))))
    }
}
