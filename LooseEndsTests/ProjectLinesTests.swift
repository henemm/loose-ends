import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("Project view with subtasks (#28)") struct ProjectLinesTests {
    private func ids(_ lines: [ViewRules.ProjectLine]) -> [UUID] { lines.map(\.id) }

    @MainActor
    private func fixture(in store: TestStore) throws -> (project: Project, parent: TaskItem, first: TaskItem, second: TaskItem, other: TaskItem) {
        let project = Project(name: "Haus")
        store.context.insert(project)
        let parent = TaskItem(rawText: "Keller entrümpeln")
        parent.status = .active
        parent.urgency = .high
        store.context.insert(parent)
        parent.project = project
        let other = TaskItem(rawText: "Dachrinne reinigen")
        other.status = .active
        store.context.insert(other)
        other.project = project
        let start = Date(timeIntervalSince1970: 1_790_000_000)
        let first = try Subtasks.add("Regal abbauen", to: parent, in: store.context, now: start)
        let second = try Subtasks.add("Sperrmüll anmelden", to: parent, in: store.context, now: start.addingTimeInterval(60))
        try store.context.save()
        return (project, parent, first, second, other)
    }

    @Test("Folded by default: only top-level tasks, subtasks never on their own")
    @MainActor func foldedByDefault() async throws {
        let store = try TestStore()
        let f = try fixture(in: store)
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        let lines = ViewRules.lines(inProject: f.project, in: all, unfolded: [])

        #expect(ids(lines) == [f.parent.id, f.other.id])
    }

    @Test("An unfolded parent shows its subtasks right below it, in capture order")
    @MainActor func unfoldedParent() async throws {
        let store = try TestStore()
        let f = try fixture(in: store)
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        let lines = ViewRules.lines(inProject: f.project, in: all, unfolded: [f.parent.id])

        #expect(ids(lines) == [f.parent.id, f.first.id, f.second.id, f.other.id])
        if case .subtask(_, let parent) = lines[1] {
            #expect(parent.id == f.parent.id)
        } else {
            Issue.record("the second line should be a subtask")
        }
    }

    @Test("A checked subtask stays in place, as in the detail")
    @MainActor func checkedSubtaskStays() async throws {
        let store = try TestStore()
        let f = try fixture(in: store)
        Subtasks.toggle(f.first)
        try store.context.save()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        let lines = ViewRules.lines(inProject: f.project, in: all, unfolded: [f.parent.id])

        #expect(ids(lines) == [f.parent.id, f.first.id, f.second.id, f.other.id])
    }

    @Test("Unfolding a task without subtasks, or a finished parent, adds nothing")
    @MainActor func nothingToUnfold() async throws {
        let store = try TestStore()
        let f = try fixture(in: store)
        TaskActions.complete(f.parent)
        try store.context.save()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        let lines = ViewRules.lines(inProject: f.project, in: all, unfolded: [f.parent.id, f.other.id])

        #expect(ids(lines) == [f.other.id], "a done parent leaves the view with its subtasks")
    }
}
