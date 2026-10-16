import Foundation
import SwiftData

/// Releases the projects the model guessed (#469, Henning 2026-10-16: "Automatisch lösen"). Until
/// then the model chose a project from the list and put nearly every task into the one project
/// there was. A task whose current project was last set by the model loses it, with a rule revision
/// that the revisions sheet can take back; a project the user, Siri or a rule set stays. Running it
/// again finds nothing: after the release the last project revision is no longer the model's.
enum GuessedProjects {
    static let reason = String(localized: "The project was a guess of the model, not from your words.")

    /// The tasks whose project was released; the caller saves. A release is housekeeping, so it is
    /// written as seen and never puts a confirmed task back into "New" (Henning, 2026-10-16).
    @discardableResult
    static func release(in context: ModelContext, now: Date = Date()) throws -> Int {
        let all = try context.fetch(FetchDescriptor<TaskItem>())
        // Build 70 wrote the release unseen, so confirmed tasks came back into "New": mark those seen.
        for task in all {
            for revision in task.revisions ?? [] where revision.seenAt == nil && isRelease(revision) {
                revision.seenAt = now
            }
        }
        let tasks = all.filter { $0.project != nil }
        var released = 0
        for task in tasks where isGuessed(task) {
            let revision = Revision(task: task, field: .project, oldValue: task.project?.name, newValue: nil,
                                    author: .rule, reason: reason)
            revision.createdAt = now
            // Housekeeping, not news: an unseen automatic revision would put the task back into "New".
            revision.seenAt = now
            task.revisions = (task.revisions ?? []) + [revision]
            task.project = nil
            released += 1
        }
        return released
    }

    static func isRelease(_ revision: Revision) -> Bool {
        revision.field == .project && revision.author == .rule && revision.newValue == nil && revision.reason == reason
    }

    /// The last change of the project was the model's, to the project the task still has.
    static func isGuessed(_ task: TaskItem) -> Bool {
        guard let name = task.project?.name,
              let last = (task.revisions ?? []).filter({ $0.field == .project }).max(by: { $0.createdAt < $1.createdAt })
        else { return false }
        return last.author == .ai && last.newValue == name
    }
}
