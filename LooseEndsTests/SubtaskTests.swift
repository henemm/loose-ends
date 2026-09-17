import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("Subtasks, one level") struct SubtaskTests {
    @Test("A line is trimmed, linked to its parent, active and inherits the project; empty and nested lines are refused")
    @MainActor func addLinksAndTrims() async throws {
        let store = try TestStore()
        let project = Project(name: "Haushalt", sortOrder: 0)
        store.context.insert(project)
        let parent = TaskItem(rawText: "Einkaufen")
        parent.status = .active
        parent.project = project
        store.context.insert(parent)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)

        let milk = try Subtasks.add("  Milch \n", to: parent, in: store.context, now: t0)
        let bread = try Subtasks.add("Brot", to: parent, in: store.context, now: t0.addingTimeInterval(60))
        try store.context.save()

        #expect(milk.rawText == "Milch")
        #expect(milk.status == .active)
        #expect(milk.parent?.id == parent.id)
        #expect(milk.project?.id == project.id)
        #expect(Subtasks.ordered(of: parent).map(\.rawText) == ["Milch", "Brot"])
        #expect(bread.parent?.id == parent.id)
        #expect(throws: SubtaskError.emptyText) { try Subtasks.add("   ", to: parent, in: store.context) }
        #expect(throws: SubtaskError.nested) { try Subtasks.add("Vollmilch", to: milk, in: store.context) }
        #expect(Subtasks.progress(of: parent) == Subtasks.Progress(done: 0, total: 2))
    }

    @Test("Checking a line off and reopening it moves the progress and keeps the order")
    @MainActor func toggleAndProgress() async throws {
        let store = try TestStore()
        let parent = TaskItem(rawText: "Einkaufen")
        parent.status = .active
        store.context.insert(parent)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let milk = try Subtasks.add("Milch", to: parent, in: store.context, now: t0)
        try Subtasks.add("Brot", to: parent, in: store.context, now: t0.addingTimeInterval(60))
        let now = Date()

        Subtasks.toggle(milk, now: now)
        try store.context.save()
        #expect(milk.status == .done)
        #expect(milk.completedAt == now)
        #expect(Subtasks.progress(of: parent) == Subtasks.Progress(done: 1, total: 2))
        #expect(Subtasks.ordered(of: parent).map(\.rawText) == ["Milch", "Brot"])

        Subtasks.toggle(milk)
        try store.context.save()
        #expect(milk.status == .active)
        #expect(milk.completedAt == nil)
        #expect(Subtasks.progress(of: parent) == Subtasks.Progress(done: 0, total: 2))
    }

    @Test("A subtask never shows in a view of its own, open or done")
    @MainActor func staysOutOfViews() async throws {
        let store = try TestStore()
        let project = Project(name: "Haushalt", sortOrder: 0)
        store.context.insert(project)
        let parent = TaskItem(rawText: "Einkaufen")
        parent.status = .active
        parent.nextRank = 1
        parent.dueDate = Date()
        parent.project = project
        store.context.insert(parent)
        let milk = try Subtasks.add("Milch", to: parent, in: store.context)
        milk.nextRank = 2
        milk.dueDate = Date()
        let bread = try Subtasks.add("Brot", to: parent, in: store.context)
        Subtasks.toggle(bread)
        try store.context.save()

        let all = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(all.count == 3)
        for kind in [ViewKind.next, .new, .due, .quick, .old, .waiting, .repeating, .parked, .done] {
            let ids = ViewRules.tasks(for: kind, in: all).map(\.id)
            #expect(!ids.contains(milk.id), "\(kind) listed an open subtask")
            #expect(!ids.contains(bread.id), "\(kind) listed a done subtask")
        }
        #expect(ViewRules.tasks(for: .next, in: all).map(\.id) == [parent.id])
        #expect(ViewRules.tasks(for: .done, in: all).isEmpty)
        #expect(ViewRules.tasks(inProject: project, in: all).map(\.id) == [parent.id])
    }

    @Test("Deleting the parent takes its subtasks with it")
    @MainActor func deleteCascades() async throws {
        let store = try TestStore()
        let parent = TaskItem(rawText: "Einkaufen")
        parent.status = .active
        store.context.insert(parent)
        try Subtasks.add("Milch", to: parent, in: store.context)
        try Subtasks.add("Brot", to: parent, in: store.context)
        try store.context.save()
        let before = try store.context.fetchCount(FetchDescriptor<TaskItem>())
        #expect(before == 3)

        store.context.delete(parent)
        try store.context.save()

        let remaining = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(remaining.isEmpty, "left behind: \(remaining.map(\.rawText))")
    }
}
