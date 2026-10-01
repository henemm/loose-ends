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

        try CatalogService.rename(garden, to: " Draußen ", among: [garden])
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

    // MARK: - #157: context names are unique

    private func thrownError(_ body: () throws -> Void) -> CatalogError? {
        do {
            try body()
        } catch let error as CatalogError {
            return error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        return nil
    }

    @Test("Adding a context whose name exists is rejected, regardless of casing, spaces and accents",
          arguments: ["Garden", "garden ", "  GARDEN", "Gärden"])
    @MainActor func addDuplicateContextRejected(name: String) async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garden", sortOrder: 0)
        store.context.insert(garden)
        try store.context.save()

        let error = thrownError {
            try CatalogService.addContext(named: name, in: store.context, existing: [garden])
        }
        #expect(error == .duplicateName)
        let count = try store.context.fetchCount(FetchDescriptor<TaskContext>())
        #expect(count == 1)
    }

    @Test("Garden and Garten are different names")
    @MainActor func similarNameAllowed() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garden", sortOrder: 0)
        store.context.insert(garden)

        let garten = try CatalogService.addContext(named: "Garten", in: store.context, existing: [garden])
        try store.context.save()

        #expect(garten.name == "Garten")
        let count = try store.context.fetchCount(FetchDescriptor<TaskContext>())
        #expect(count == 2)
    }

    @Test("Renaming a context to its own name in other casing is allowed")
    @MainActor func renameToOwnNameAllowed() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garden", sortOrder: 0)
        let phone = TaskContext(name: "Phone", sortOrder: 1)
        store.context.insert(garden)
        store.context.insert(phone)

        try CatalogService.rename(garden, to: " garden ", among: [garden, phone])

        #expect(garden.name == "garden")
    }

    @Test("Renaming a context to another context's name is rejected and keeps the old name")
    @MainActor func renameToOtherNameRejected() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garden", sortOrder: 0)
        let phone = TaskContext(name: "Phone", sortOrder: 1)
        store.context.insert(garden)
        store.context.insert(phone)

        let error = thrownError {
            try CatalogService.rename(phone, to: "GARDEN ", among: [garden, phone])
        }

        #expect(error == .duplicateName)
        #expect(phone.name == "Phone")
    }

    @Test("Merging moves every task of the duplicates to the survivor once and deletes the duplicates")
    @MainActor func mergeDuplicates() async throws {
        let store = try TestStore()
        let survivor = TaskContext(name: "Garden", sortOrder: 1)
        let duplicate = TaskContext(name: "garden", sortOrder: 4)
        let third = TaskContext(name: " Garden", sortOrder: 7)
        let garten = TaskContext(name: "Garten", sortOrder: 2)
        let phone = TaskContext(name: "Phone", sortOrder: 3)
        let both = TaskItem(rawText: "Rasen mähen")
        let onlyDuplicate = TaskItem(rawText: "Hecke schneiden")
        let withOthers = TaskItem(rawText: "Gärtner anrufen")
        let untagged = TaskItem(rawText: "Steuer")
        for item in [survivor, duplicate, third, garten, phone] { store.context.insert(item) }
        for item in [both, onlyDuplicate, withOthers, untagged] { store.context.insert(item) }
        both.contexts = [survivor, duplicate, third]
        onlyDuplicate.contexts = [duplicate]
        withOthers.contexts = [third, phone, garten]
        try store.context.save()
        let survivorID = survivor.id

        let removed = try CatalogService.mergeDuplicateContexts(in: store.context)
        try store.context.save()

        #expect(removed == 2)
        let left = try store.context.fetch(FetchDescriptor<TaskContext>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(left.map(\.name) == ["Garden", "Garten", "Phone"])
        #expect(left.first?.id == survivorID)
        let tasks = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 4)
        #expect((both.contexts ?? []).map(\.id) == [survivorID])
        #expect((onlyDuplicate.contexts ?? []).map(\.id) == [survivorID])
        #expect(Set((withOthers.contexts ?? []).map(\.name)) == ["Garden", "Phone", "Garten"])
        #expect((withOthers.contexts ?? []).count == 3)
        #expect((untagged.contexts ?? []).isEmpty)
        #expect(Set((survivor.tasks ?? []).map(\.rawText)) == ["Rasen mähen", "Hecke schneiden", "Gärtner anrufen"])
    }

    @Test("Merging without duplicates changes nothing, and a second merge is a no-op")
    @MainActor func mergeIsIdempotent() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garden", sortOrder: 0)
        let copy = TaskContext(name: "Garden", sortOrder: 1)
        let phone = TaskContext(name: "Phone", sortOrder: 2)
        let task = TaskItem(rawText: "Rasen mähen")
        for item in [garden, copy, phone] { store.context.insert(item) }
        store.context.insert(task)
        task.contexts = [copy, phone]
        try store.context.save()

        #expect(try CatalogService.mergeDuplicateContexts(in: store.context) == 1)
        try store.context.save()
        #expect(try CatalogService.mergeDuplicateContexts(in: store.context) == 0)
        try store.context.save()

        let count = try store.context.fetchCount(FetchDescriptor<TaskContext>())
        #expect(count == 2)
        #expect(Set((task.contexts ?? []).map(\.name)) == ["Garden", "Phone"])
    }

    @Test("The system default survives, even with a larger sort order")
    @MainActor func survivorPrefersSystemDefault() async throws {
        let store = try TestStore()
        let own = TaskContext(name: "Garden", sortOrder: 0)
        let seeded = TaskContext(name: "Garden", isSystemDefault: true, sortOrder: 9)
        store.context.insert(own)
        store.context.insert(seeded)
        try store.context.save()
        let seededID = seeded.id

        try CatalogService.mergeDuplicateContexts(in: store.context)
        try store.context.save()

        let left = try store.context.fetch(FetchDescriptor<TaskContext>())
        #expect(left.map(\.id) == [seededID])
    }

    @Test("Without a system default the smallest sort order survives")
    @MainActor func survivorPrefersSmallestSortOrder() async throws {
        let store = try TestStore()
        let later = TaskContext(name: "Garden", sortOrder: 8)
        let earlier = TaskContext(name: "Garden", sortOrder: 3)
        store.context.insert(later)
        store.context.insert(earlier)
        try store.context.save()
        let earlierID = earlier.id

        try CatalogService.mergeDuplicateContexts(in: store.context)
        try store.context.save()

        let left = try store.context.fetch(FetchDescriptor<TaskContext>())
        #expect(left.map(\.id) == [earlierID])
    }

    @Test("With equal flag and sort order the smallest id string survives")
    @MainActor func survivorPrefersSmallestID() async throws {
        let store = try TestStore()
        let high = TaskContext(name: "Garden", sortOrder: 2)
        high.id = try #require(UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000000"))
        let low = TaskContext(name: "Garden", sortOrder: 2)
        low.id = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000A"))
        store.context.insert(high)
        store.context.insert(low)
        try store.context.save()

        try CatalogService.mergeDuplicateContexts(in: store.context)
        try store.context.save()

        let left = try store.context.fetch(FetchDescriptor<TaskContext>())
        #expect(left.map(\.id.uuidString) == ["00000000-0000-0000-0000-00000000000A"])
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
