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
    static func addContext(named raw: String, in context: ModelContext, existing: [TaskContext]) throws -> TaskContext {
        let name = try cleaned(raw)
        guard !existing.contains(where: { sameName($0.name, name) }) else { throw CatalogError.duplicateName }
        let item = TaskContext(name: name, sortOrder: nextSortOrder(after: existing.map(\.sortOrder)))
        context.insert(item)
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
                for task in duplicate.tasks ?? [] {
                    var tags = (task.contexts ?? []).filter { $0.id != duplicate.id }
                    if !tags.contains(where: { $0.id == survivor.id }) { tags.append(survivor) }
                    task.contexts = tags
                }
                context.delete(duplicate)
                removed += 1
            }
        }
        return removed
    }

    /// System default first, then the smallest sort order, then the smallest id string.
    private static func survivesBefore(_ lhs: TaskContext, _ rhs: TaskContext) -> Bool {
        if lhs.isSystemDefault != rhs.isSystemDefault { return lhs.isSystemDefault }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func sameName(_ lhs: String, _ rhs: String) -> Bool {
        nameKey(lhs) == nameKey(rhs)
    }

    /// Trimmed, case- and accent-insensitive: "garden " and "Gärden" are "Garden", "Garten" is not.
    private static func nameKey(_ name: String) -> String {
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
    /// codec keeps exactly them.
    static func delete(_ taskContext: TaskContext, in context: ModelContext, now: Date = Date()) {
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
