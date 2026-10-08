import Foundation
import SwiftData

enum CatalogError: Error, Equatable {
    case emptyName
    /// Another context already carries this name (#157): contexts are matched by name.
    case duplicateName
}

/// Create, rename and delete contexts and projects (design briefing, screen 7). Deleting either
/// keeps its tasks; they only lose the tag. Pure over the model objects; the caller saves.
enum CatalogService {
    @discardableResult
    static func addProject(named raw: String, in context: ModelContext, existing: [Project]) throws -> Project {
        let project = Project(name: try cleaned(raw), sortOrder: nextSortOrder(after: existing.map(\.sortOrder)))
        context.insert(project)
        return project
    }

    @discardableResult
    static func addContext(
        named raw: String, in context: ModelContext, existing: [TaskContext], defaults: UserDefaults = .standard
    ) throws -> TaskContext {
        let name = try cleaned(raw)
        guard !existing.contains(where: { sameName($0.name, name) }) else { throw CatalogError.duplicateName }
        let item = TaskContext(name: name, sortOrder: nextSortOrder(after: existing.map(\.sortOrder)))
        context.insert(item)
        ContextSeeder.noteCatalog(remaining: existing.count + 1, defaults: defaults)
        return item
    }

    static func rename(_ project: Project, to raw: String) throws {
        project.name = try cleaned(raw)
    }

    /// `contexts` are all contexts; only another one carrying the name blocks the rename.
    static func rename(_ taskContext: TaskContext, to raw: String, among contexts: [TaskContext]) throws {
        let name = try cleaned(raw)
        let taken = contexts.contains { $0.id != taskContext.id && sameName($0.name, name) }
        guard !taken else { throw CatalogError.duplicateName }
        taskContext.name = name
    }

    /// Folds contexts with the same name into one (#157). CloudKit has no unique constraints, so
    /// duplicates can arrive from another device; every device picks the same survivor. The tasks
    /// of the duplicates move to the survivor, the duplicates are deleted. Returns how many were
    /// deleted. The caller saves.
    @discardableResult
    static func mergeDuplicateContexts(in context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<TaskContext>())
        let groups = Dictionary(grouping: all) { nameKey($0.name) }
        var removed = 0
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted(by: survivesBefore)
            let survivor = ordered[0]
            for duplicate in ordered.dropFirst() {
                fold(duplicate, into: survivor, in: context)
                removed += 1
            }
        }
        return removed
    }

    /// The English default names with their German translation (`TaskContext.defaultNameKeys`,
    /// `Localizable.xcstrings`). Fixed here, not localized at run time: every device must reach the
    /// same result whatever its language. "Computer" is the same in both and falls under #157.
    static let englishDefaultsToGerman: [String: String] = [
        "Phone": "Telefon", "Home": "Haus", "Garden": "Garten", "Errands": "Besorgung",
        "Out and about": "Unterwegs",
    ]

    /// Folds the English seeded defaults into their German counterparts (#267): until #250 the
    /// tests synced their English seeds into the user's iCloud. Only a system default with an English
    /// default name counts — a context the user added is never one — and only while the German one
    /// exists; without it the English one stays. Tasks move along, the English one is deleted.
    /// Returns how many were deleted. The caller saves.
    @discardableResult
    static func mergeEnglishDefaults(in context: ModelContext) throws -> Int {
        let all = try context.fetch(FetchDescriptor<TaskContext>())
        let germanFor = Dictionary(
            uniqueKeysWithValues: englishDefaultsToGerman.map { (nameKey($0.key), nameKey($0.value)) }
        )
        var removed = 0
        for english in all where english.isSystemDefault {
            guard let german = germanFor[nameKey(english.name)],
                  let target = all.filter({ nameKey($0.name) == german }).sorted(by: survivesBefore).first
            else { continue }
            fold(english, into: target, in: context)
            removed += 1
        }
        return removed
    }

    /// Moves every task of `duplicate` to `survivor` (once per task) and deletes `duplicate`.
    private static func fold(_ duplicate: TaskContext, into survivor: TaskContext, in context: ModelContext) {
        for task in duplicate.tasks ?? [] {
            var tags = (task.contexts ?? []).filter { $0.id != duplicate.id }
            if !tags.contains(where: { $0.id == survivor.id }) { tags.append(survivor) }
            task.contexts = tags
        }
        context.delete(duplicate)
    }

    /// System default first, then the smallest sort order, then the smallest id string.
    static func survivesBefore(_ lhs: TaskContext, _ rhs: TaskContext) -> Bool {
        if lhs.isSystemDefault != rhs.isSystemDefault { return lhs.isSystemDefault }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func sameName(_ lhs: String, _ rhs: String) -> Bool {
        nameKey(lhs) == nameKey(rhs)
    }

    /// Trimmed, case- and accent-insensitive: "garden " and "Gärden" are "Garden", "Garten" is not.
    static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// The project's tasks stay and lose the project. Each loss is a user revision carrying the
    /// project's name (#140, "Revisions, not undo"): the task shows it was there, and the field
    /// counts as touched by the user.
    static func delete(_ project: Project, in context: ModelContext, now: Date = Date()) {
        for task in project.tasks ?? [] {
            RevisionService.set(.project, to: nil, on: task, contexts: [], projects: [], now: now)
        }
        context.delete(project)
    }

    /// The context's tasks stay and lose the tag, each as a user revision from the old list to
    /// the remaining one (#140). The remaining contexts are passed as the vocabulary, so the
    /// codec keeps exactly them. `contexts` are all contexts: deleting the last one tells the
    /// seeder the catalog was emptied on purpose (#146).
    static func delete(
        _ taskContext: TaskContext,
        in context: ModelContext,
        among contexts: [TaskContext],
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        ContextSeeder.noteCatalog(remaining: contexts.filter { $0.id != taskContext.id }.count, defaults: defaults)
        for task in taskContext.tasks ?? [] {
            let remaining = (task.contexts ?? []).filter { $0.id != taskContext.id }
            RevisionService.set(
                .contexts, to: FieldCodec.encode(remaining.map(\.name)), on: task,
                contexts: remaining, projects: [], now: now
            )
        }
        context.delete(taskContext)
    }

    private static func nextSortOrder(after orders: [Int]) -> Int {
        (orders.max() ?? -1) + 1
    }

    private static func cleaned(_ raw: String) throws -> String {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CatalogError.emptyName }
        return name
    }
}
