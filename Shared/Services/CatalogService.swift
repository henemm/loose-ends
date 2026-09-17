import Foundation
import SwiftData

enum CatalogError: Error, Equatable {
    case emptyName
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
        let item = TaskContext(name: try cleaned(raw), sortOrder: nextSortOrder(after: existing.map(\.sortOrder)))
        context.insert(item)
        return item
    }

    static func rename(_ project: Project, to raw: String) throws {
        project.name = try cleaned(raw)
    }

    static func rename(_ taskContext: TaskContext, to raw: String) throws {
        taskContext.name = try cleaned(raw)
    }

    /// The project's tasks stay and lose the project.
    static func delete(_ project: Project, in context: ModelContext) {
        for task in project.tasks ?? [] {
            task.project = nil
        }
        context.delete(project)
    }

    /// The context's tasks stay and lose the tag.
    static func delete(_ taskContext: TaskContext, in context: ModelContext) {
        for task in taskContext.tasks ?? [] {
            task.contexts = (task.contexts ?? []).filter { $0.id != taskContext.id }
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
