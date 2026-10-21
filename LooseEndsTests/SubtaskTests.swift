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
        #expect(milk.title == "Milch", "the typed line is the subtask's title, so its own detail is not untitled (#565)")
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

    @Test("A subtask without a date of its own never shows in a view of its own, open or done (#565)")
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
        // Lined up, but no date of its own: with one it stands in "Due" (#565, SubtaskListsTests).
        milk.nextRank = 2
        let bread = try Subtasks.add("Brot", to: parent, in: store.context)
        Subtasks.toggle(bread)
        try store.context.save()

        let all = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(all.count == 3)
        for kind in [ViewKind.next, .new, .due, .quick, .old, .waiting, .repeating, .parked, .open, .done] {
            let ids = ViewRules.tasks(for: kind, in: all).map(\.id)
            #expect(!ids.contains(milk.id), "\(kind) listed an open subtask")
            #expect(!ids.contains(bread.id), "\(kind) listed a done subtask")
        }
        #expect(ViewRules.tasks(for: .next, in: all).map(\.id) == [parent.id])
        #expect(ViewRules.tasks(for: .done, in: all).isEmpty)
        #expect(ViewRules.tasks(inProject: project, in: all).map(\.id) == [parent.id])
    }

    @Test("A bare line carries no traits; its own due date, tags, place, duration and note come in that order (#565)")
    @MainActor func traitsInOrder() async throws {
        let store = try TestStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9)))
        let parent = TaskItem(rawText: "Einkaufen")
        parent.status = .active
        store.context.insert(parent)
        let garden = TaskContext(name: "Garten", sortOrder: 2)
        let phone = TaskContext(name: "Telefon", sortOrder: 1)
        store.context.insert(garden)
        store.context.insert(phone)
        let bare = try Subtasks.add("Brot", to: parent, in: store.context, now: now)
        let milk = try Subtasks.add("Milch", to: parent, in: store.context, now: now)
        let due = try #require(calendar.date(byAdding: .hour, value: 6, to: now))
        milk.dueDate = due
        milk.dueHasTime = true
        milk.contexts = [garden, phone]
        milk.place = try #require(TaskPlace(name: "Markt", latitude: 53.55, longitude: 9.93, event: .arrive))
        milk.duration = .minutes15
        milk.notes = "  fettarm "
        try store.context.save()

        #expect(Subtasks.traits(of: bare, now: now, calendar: calendar).isEmpty)
        let traits = Subtasks.traits(of: milk, now: now, calendar: calendar)
        #expect(traits == [.due(.time(due)), .tag("Telefon"), .tag("Garten"), .place("Markt"), .duration(.minutes15), .note])
        if case .due(let mark) = traits.first { #expect(mark.pressing, "due today should read as time pressure") }

        milk.notes = "   "
        Subtasks.toggle(milk, now: now)
        #expect(Subtasks.traits(of: milk, now: now, calendar: calendar)
            == [.tag("Telefon"), .tag("Garten"), .place("Markt"), .duration(.minutes15)],
            "a done line keeps its traits but no due date, and a blank note is no note")
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

    @Test("Deleting a task lifts its subtasks one level: they stay, as tasks of their own, with what they carry (#605)")
    @MainActor func deletingParentLiftsSubtasks() async throws {
        let store = try TestStore()
        let phone = TaskContext(name: "Telefon", sortOrder: 0)
        store.context.insert(phone)
        let parent = TaskItem(rawText: "Umzug")
        parent.status = .active
        store.context.insert(parent)
        let call = try Subtasks.add("Vermieter anrufen", to: parent, in: store.context)
        call.contexts = [phone]
        let boxes = try Subtasks.add("Kartons holen", to: parent, in: store.context)
        Subtasks.toggle(boxes)
        try store.context.save()
        let parentID = parent.id

        store.context.delete(parent)
        try store.context.save()

        let left = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(!left.contains { $0.id == parentID }, "the task itself is gone")
        #expect(Set(left.map(\.rawText)) == ["Vermieter anrufen", "Kartons holen"], "its subtasks stay")
        #expect(left.allSatisfy { $0.parent == nil }, "they stand on their own now")
        #expect(call.contexts?.map(\.name) == ["Telefon"], "a lifted subtask keeps what it carries")
        #expect(boxes.status == .done, "a done one stays done")
        #expect(ViewRules.tasks(for: .open, in: left).map(\.id) == [call.id], "the open one stands in Loose ends")
    }
}
