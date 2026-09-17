import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// What the field editor writes: every change is a user revision, the source becomes "user".
@Suite("Field edits") struct FieldEditTests {
    @Test("Setting importance writes a user revision from empty to high")
    @MainActor func setImportance() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Reifen wechseln")
        store.context.insert(task)

        let revision = try #require(RevisionService.set(.importance, to: "high", on: task, contexts: [], projects: []))
        try store.context.save()

        #expect(task.importance == .high)
        #expect(task.importanceSourceRaw == FieldSource.user.rawValue)
        #expect(task.importanceConfidence == nil)
        #expect(revision.author == .user)
        #expect(revision.oldValue == nil)
        #expect(revision.newValue == "high")
    }

    @Test("Clearing the due date records the old value and drops the source")
    @MainActor func clearDueDate() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zahnarzt")
        store.context.insert(task)
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        RevisionService.set(.dueDate, to: day.ISO8601Format(), on: task, contexts: [], projects: [])
        #expect(task.dueDate == day)

        let cleared = try #require(RevisionService.set(.dueDate, to: nil, on: task, contexts: [], projects: []))
        try store.context.save()

        #expect(task.dueDate == nil)
        #expect(task.dueSourceRaw == nil)
        #expect(task.dueHasTime == false)
        #expect(cleared.oldValue == day.ISO8601Format())
        #expect(cleared.newValue == nil)
        #expect((task.revisions ?? []).count == 2)
    }

    @Test("Contexts are set by name from the available ones; unknown names are ignored")
    @MainActor func setContexts() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten")
        let phone = TaskContext(name: "Telefon")
        let task = TaskItem(rawText: "Gärtner anrufen")
        store.context.insert(garden)
        store.context.insert(phone)
        store.context.insert(task)

        RevisionService.set(.contexts, to: FieldCodec.encode(["Telefon", "Auto"]), on: task, contexts: [garden, phone], projects: [])
        try store.context.save()

        #expect((task.contexts ?? []).map(\.name) == ["Telefon"])
        #expect(task.contextsSourceRaw == FieldSource.user.rawValue)
    }

    @Test("A project is set by name and cleared with nil; the same value again writes nothing")
    @MainActor func setProject() async throws {
        let store = try TestStore()
        let house = Project(name: "Haus")
        let task = TaskItem(rawText: "Dachrinne")
        store.context.insert(house)
        store.context.insert(task)

        let first = RevisionService.set(.project, to: "Haus", on: task, contexts: [], projects: [house])
        let again = RevisionService.set(.project, to: "Haus", on: task, contexts: [], projects: [house])
        #expect(task.project?.name == "Haus")
        #expect(first != nil)
        #expect(again == nil)

        RevisionService.set(.project, to: nil, on: task, contexts: [], projects: [house])
        try store.context.save()
        #expect(task.project == nil)
        #expect((task.revisions ?? []).count == 2)
    }
}
