import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("CatalogService") struct CatalogServiceTests {
    @Test("A new project trims its name and sorts after the existing ones")
    @MainActor func addProject() async throws {
        let store = try TestStore()
        let first = Project(name: "Haus", sortOrder: 4)
        store.context.insert(first)

        let second = try CatalogService.addProject(named: "  Garten  ", in: store.context, existing: [first])
        try store.context.save()

        #expect(second.name == "Garten")
        #expect(second.sortOrder == 5)
        let count = try store.context.fetchCount(FetchDescriptor<Project>())
        #expect(count == 2)
    }

    @Test("A blank name is rejected and nothing is inserted")
    @MainActor func blankNameRejected() async throws {
        let store = try TestStore()
        var thrown: CatalogError?
        do {
            try CatalogService.addContext(named: "   ", in: store.context, existing: [])
        } catch let error as CatalogError {
            thrown = error
        }
        #expect(thrown == .emptyName)
        let count = try store.context.fetchCount(FetchDescriptor<TaskContext>())
        #expect(count == 0)
    }

    @Test("Renaming a context keeps its identity")
    @MainActor func renameContext() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten")
        store.context.insert(garden)
        let id = garden.id

        try CatalogService.rename(garden, to: " Draußen ")
        try store.context.save()

        #expect(garden.name == "Draußen")
        #expect(garden.id == id)
    }

    @Test("Deleting a project keeps its tasks, which lose the project")
    @MainActor func deleteProjectKeepsTasks() async throws {
        let store = try TestStore()
        let house = Project(name: "Haus")
        let task = TaskItem(rawText: "Dachrinne reinigen")
        store.context.insert(house)
        store.context.insert(task)
        task.project = house
        try store.context.save()

        CatalogService.delete(house, in: store.context)
        try store.context.save()

        let projectCount = try store.context.fetchCount(FetchDescriptor<Project>())
        #expect(projectCount == 0)
        let tasks = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        #expect(tasks.first?.project == nil)
    }

    @Test("Deleting a context removes the tag from its tasks and keeps the other tags")
    @MainActor func deleteContextKeepsTasks() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten")
        let phone = TaskContext(name: "Telefon")
        let task = TaskItem(rawText: "Gärtner anrufen")
        store.context.insert(garden)
        store.context.insert(phone)
        store.context.insert(task)
        task.contexts = [garden, phone]
        try store.context.save()

        CatalogService.delete(garden, in: store.context)
        try store.context.save()

        let contextCount = try store.context.fetchCount(FetchDescriptor<TaskContext>())
        #expect(contextCount == 1)
        #expect((task.contexts ?? []).map(\.name) == ["Telefon"])
    }
}

@Suite("ViewRules for contexts and projects") struct ContextProjectViewTests {
    @Test("A context view lists open top-level tasks with that tag only")
    @MainActor func contextView() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten")
        let open = TaskItem(rawText: "Rasen mähen")
        open.status = .active
        let done = TaskItem(rawText: "Hecke schneiden")
        done.status = .done
        let untagged = TaskItem(rawText: "Steuer")
        untagged.status = .active
        let child = TaskItem(rawText: "Benzin holen")
        child.status = .active
        for item in [garden] { store.context.insert(item) }
        for item in [open, done, untagged, child] { store.context.insert(item) }
        open.contexts = [garden]
        done.contexts = [garden]
        child.contexts = [garden]
        child.parent = open
        try store.context.save()

        let shown = ViewRules.tasks(inContext: garden, in: [open, done, untagged, child])
        #expect(shown.map(\.rawText) == ["Rasen mähen"])
    }

    @Test("A project view lists open top-level tasks of that project, urgent first")
    @MainActor func projectView() async throws {
        let store = try TestStore()
        let house = Project(name: "Haus")
        let calm = TaskItem(rawText: "Bilder aufhängen")
        calm.status = .active
        calm.urgency = .low
        let urgent = TaskItem(rawText: "Wasserrohr")
        urgent.status = .active
        urgent.urgency = .high
        let other = TaskItem(rawText: "Auto waschen")
        other.status = .active
        store.context.insert(house)
        for item in [calm, urgent, other] { store.context.insert(item) }
        calm.project = house
        urgent.project = house
        try store.context.save()

        let shown = ViewRules.tasks(inProject: house, in: [calm, urgent, other])
        #expect(shown.map(\.rawText) == ["Wasserrohr", "Bilder aufhängen"])
    }
}
