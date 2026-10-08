import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("CatalogService") struct CatalogServiceTests {
    /// A suite of its own per test: deleting the last context writes a marker (#146).
    private func scratchDefaults() throws -> UserDefaults {
        let name = "CatalogServiceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

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

        CatalogService.delete(garden, in: store.context, among: [garden, phone], defaults: try scratchDefaults())
        try store.context.save()

        let contextCount = try store.context.fetchCount(FetchDescriptor<TaskContext>())
        #expect(contextCount == 1)
        #expect((task.contexts ?? []).map(\.name) == ["Telefon"])
    }

    // MARK: - #140: deleting from the catalog leaves a revision

    private func names(_ encoded: String?) throws -> Set<String> {
        let data = try #require(encoded?.data(using: .utf8))
        return Set(try JSONDecoder().decode([String].self, from: data))
    }

    @Test("Deleting a context records a user revision on every task that carried it (#140)")
    @MainActor func deleteContextWritesRevision() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten")
        let phone = TaskContext(name: "Telefon")
        let task = TaskItem(rawText: "Gärtner anrufen")
        store.context.insert(garden)
        store.context.insert(phone)
        store.context.insert(task)
        task.contexts = [garden, phone]
        task.contextsSourceRaw = FieldSource.ai.rawValue
        try store.context.save()

        CatalogService.delete(garden, in: store.context, among: [garden, phone], defaults: try scratchDefaults())
        try store.context.save()

        #expect((task.contexts ?? []).map(\.name) == ["Telefon"], "the other tag stays")
        let revision = try #require(task.revisions?.first { $0.field == .contexts })
        #expect(revision.author == .user)
        #expect(try names(revision.oldValue) == ["Garten", "Telefon"], "the removed tag is kept in the history")
        #expect(try names(revision.newValue) == ["Telefon"])
        #expect(EnrichmentWriter.userHasTouched(.contexts, on: task), "the field now counts as the user's")
    }

    @Test("A task losing its only context records the emptying as a user revision (#140)")
    @MainActor func deleteOnlyContextWritesRevision() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten")
        let task = TaskItem(rawText: "Rasen mähen")
        store.context.insert(garden)
        store.context.insert(task)
        task.contexts = [garden]
        try store.context.save()

        CatalogService.delete(garden, in: store.context, among: [garden], defaults: try scratchDefaults())
        try store.context.save()

        #expect((task.contexts ?? []).isEmpty)
        #expect(task.contextsSourceRaw == nil)
        let revision = try #require(task.revisions?.first { $0.field == .contexts })
        #expect(try names(revision.oldValue) == ["Garten"])
        #expect(try names(revision.newValue).isEmpty)
        #expect(EnrichmentWriter.userHasTouched(.contexts, on: task))
    }

    @Test("Deleting a project records a user revision on every task in it (#140)")
    @MainActor func deleteProjectWritesRevision() async throws {
        let store = try TestStore()
        let house = Project(name: "Haus")
        let task = TaskItem(rawText: "Dachrinne reinigen")
        let untouched = TaskItem(rawText: "Steuer")
        store.context.insert(house)
        store.context.insert(task)
        store.context.insert(untouched)
        task.project = house
        try store.context.save()

        CatalogService.delete(house, in: store.context)
        try store.context.save()

        let revision = try #require(task.revisions?.first { $0.field == .project })
        #expect(revision.author == .user)
        #expect(revision.oldValue == "Haus")
        #expect(revision.newValue == nil)
        #expect((untouched.revisions ?? []).isEmpty, "a task outside the project gets no revision")
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

        let garten = try CatalogService.addContext(named: "Garten", in: store.context, existing: [garden], defaults: scratchDefaults())
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

    @Test("English seeded defaults fold into their German counterparts with their tasks (#267)")
    @MainActor func mergeEnglishDefaults() async throws {
        let store = try TestStore()
        let garten = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        let telefon = TaskContext(name: "Telefon", sortOrder: 1)
        let garden = TaskContext(name: "Garden", isSystemDefault: true, sortOrder: 9)
        let phone = TaskContext(name: " phone", isSystemDefault: true, sortOrder: 7)
        let computer = TaskContext(name: "Computer", isSystemDefault: true, sortOrder: 0)
        let lawn = TaskItem(rawText: "Rasen mähen")
        let both = TaskItem(rawText: "Gärtner anrufen")
        let mixed = TaskItem(rawText: "Hecke schneiden")
        for item in [garten, telefon, garden, phone, computer] { store.context.insert(item) }
        for item in [lawn, both, mixed] { store.context.insert(item) }
        lawn.contexts = [garden]
        both.contexts = [garden, garten, phone]
        mixed.contexts = [computer, garden]
        try store.context.save()

        let removed = try CatalogService.mergeEnglishDefaults(in: store.context)
        try store.context.save()

        #expect(removed == 2)
        let left = try store.context.fetch(FetchDescriptor<TaskContext>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(left.map(\.name) == ["Computer", "Telefon", "Garten"])
        #expect((lawn.contexts ?? []).map(\.name) == ["Garten"])
        #expect(Set((both.contexts ?? []).map(\.name)) == ["Garten", "Telefon"])
        #expect((both.contexts ?? []).count == 2)
        #expect(Set((mixed.contexts ?? []).map(\.name)) == ["Computer", "Garten"])
        #expect(try store.context.fetchCount(FetchDescriptor<TaskItem>()) == 3)
    }

    @Test("A second English merge and a clean catalog change nothing (#267)")
    @MainActor func mergeEnglishDefaultsIsIdempotent() async throws {
        let store = try TestStore()
        let garten = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 0)
        let garden = TaskContext(name: "Garden", isSystemDefault: true, sortOrder: 1)
        let task = TaskItem(rawText: "Rasen mähen")
        store.context.insert(garten)
        store.context.insert(garden)
        store.context.insert(task)
        task.contexts = [garden]
        try store.context.save()

        #expect(try CatalogService.mergeEnglishDefaults(in: store.context) == 1)
        try store.context.save()
        #expect(try CatalogService.mergeEnglishDefaults(in: store.context) == 0)
        try store.context.save()

        #expect(try store.context.fetch(FetchDescriptor<TaskContext>()).map(\.name) == ["Garten"])
        #expect((task.contexts ?? []).map(\.name) == ["Garten"])
    }

    @Test("An English context the user added stays, and so does an English default without its German pair (#267)")
    @MainActor func mergeEnglishDefaultsKeepsOwnAndUnpaired() async throws {
        let store = try TestStore()
        let garten = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 0)
        let ownGarden = TaskContext(name: "Garden", sortOrder: 1)
        let errands = TaskContext(name: "Errands", isSystemDefault: true, sortOrder: 2)
        let task = TaskItem(rawText: "Rasen mähen")
        for item in [garten, ownGarden, errands] { store.context.insert(item) }
        store.context.insert(task)
        task.contexts = [ownGarden, errands]
        try store.context.save()

        #expect(try CatalogService.mergeEnglishDefaults(in: store.context) == 0)
        try store.context.save()

        let left = try store.context.fetch(FetchDescriptor<TaskContext>(sortBy: [SortDescriptor(\.sortOrder)]))
        #expect(left.map(\.name) == ["Garten", "Garden", "Errands"])
        #expect(Set((task.contexts ?? []).map(\.name)) == ["Garden", "Errands"])
    }

    @Test("With two German candidates the English default folds into the one that survives first (#267)")
    @MainActor func mergeEnglishDefaultsPicksDeterministicTarget() async throws {
        let store = try TestStore()
        let own = TaskContext(name: "Garten", sortOrder: 0)
        let seeded = TaskContext(name: "garten", isSystemDefault: true, sortOrder: 5)
        let garden = TaskContext(name: "Garden", isSystemDefault: true, sortOrder: 1)
        let task = TaskItem(rawText: "Rasen mähen")
        for item in [own, seeded, garden] { store.context.insert(item) }
        store.context.insert(task)
        task.contexts = [garden]
        try store.context.save()
        let seededID = seeded.id

        try CatalogService.mergeEnglishDefaults(in: store.context)
        try store.context.save()

        #expect((task.contexts ?? []).map(\.id) == [seededID])
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
