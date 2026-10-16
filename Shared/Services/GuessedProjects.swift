import Foundation
import SwiftData

/// Releases the projects the model guessed (#469, Henning 2026-10-16: "Automatisch lösen"). Until
/// then the model chose a project from the list and put nearly every task into the one project
/// there was. A task whose current project was last set by the model loses it, with a rule revision
/// that the revisions sheet can take back; a project the user, Siri or a rule set stays. Running it
/// again finds nothing: after the release the last project revision is no longer the model's.
enum GuessedProjects {
    static let reason = String(localized: "The project was a guess of the model, not from your words.")

    /// The tasks whose project was released. The caller saves.
    @discardableResult
    static func release(in context: ModelContext, now: Date = Date()) throws -> Int {
        let tasks = try context.fetch(FetchDescriptor<TaskItem>()).filter { $0.project != nil }
        var released = 0
        for task in tasks where isGuessed(task) {
            let revision = Revision(task: task, field: .project, oldValue: task.project?.name, newValue: nil,
                                    author: .rule, reason: reason)
            revision.createdAt = now
            task.revisions = (task.revisions ?? []) + [revision]
            task.project = nil
            released += 1
        }
        return released
    }

    /// The last change of the project was the model's, to the project the task still has.
    static func isGuessed(_ task: TaskItem) -> Bool {
        guard let name = task.project?.name,
              let last = (task.revisions ?? []).filter({ $0.field == .project }).max(by: { $0.createdAt < $1.createdAt })
        else { return false }
        return last.author == .ai && last.newValue == name
    }
}
