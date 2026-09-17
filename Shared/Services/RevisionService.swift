import Foundation
import SwiftData

/// Revisions instead of undo (ADR-6): a reset writes a new user revision carrying the old value,
/// nothing is deleted, and every user change is a learning example (ADR-5). Pure over the model
/// objects; the caller saves.
enum RevisionService {
    /// Marks every unseen AI revision as seen. Returns how many were marked.
    @discardableResult
    static func markSeen(_ task: TaskItem, now: Date = Date()) -> Int {
        var marked = 0
        for revision in task.revisions ?? [] where revision.author == .ai && revision.seenAt == nil {
            revision.seenAt = now
            marked += 1
        }
        return marked
    }

    /// Puts the value from before `revision` back and records that as a user revision.
    @discardableResult
    static func revert(
        _ revision: Revision,
        on task: TaskItem,
        contexts: [TaskContext],
        projects: [Project],
        now: Date = Date()
    ) -> Revision {
        set(revision.field, to: revision.oldValue, on: task, contexts: contexts, projects: projects, now: now, force: true)
            ?? revision
    }

    /// Resets every field the AI touched to its value before the first AI revision, newest first.
    @discardableResult
    static func revertAll(
        on task: TaskItem,
        contexts: [TaskContext],
        projects: [Project],
        now: Date = Date()
    ) -> [Revision] {
        var written: [Revision] = []
        for field in RevisedField.allCases {
            guard let first = firstAIRevision(of: field, on: task) else { continue }
            if let revision = set(field, to: first.oldValue, on: task, contexts: contexts, projects: projects, now: now, force: false) {
                written.append(revision)
            }
        }
        return written
    }

    /// A user change to one field. Returns nil when the value did not change (no revision written).
    @discardableResult
    static func set(
        _ field: RevisedField,
        to encoded: String?,
        on task: TaskItem,
        contexts: [TaskContext],
        projects: [Project],
        now: Date = Date(),
        force: Bool = false
    ) -> Revision? {
        let current = FieldCodec.encode(field, of: task)
        guard force || current != encoded else { return nil }
        FieldCodec.apply(encoded, to: field, of: task, as: .user, contexts: contexts, projects: projects)
        let revision = Revision(task: task, field: field, oldValue: current, newValue: encoded, author: .user)
        revision.createdAt = now
        revision.seenAt = now
        task.revisions = (task.revisions ?? []) + [revision]
        return revision
    }

    /// The AI revision a field marker points at: the first one, whose old value is the pre-AI state.
    static func firstAIRevision(of field: RevisedField, on task: TaskItem) -> Revision? {
        (task.revisions ?? [])
            .filter { $0.field == field && $0.author == .ai }
            .min { $0.createdAt < $1.createdAt }
    }

    /// Fields whose current value came from the AI, in display order.
    static func aiSetFields(on task: TaskItem) -> [RevisedField] {
        let ai = FieldSource.ai.rawValue
        var fields: [RevisedField] = []
        if task.titleSourceRaw == ai { fields.append(.title) }
        if task.dueSourceRaw == ai { fields.append(.dueDate) }
        if task.importanceSourceRaw == ai { fields.append(.importance) }
        if task.urgencySourceRaw == ai { fields.append(.urgency) }
        if task.durationSourceRaw == ai { fields.append(.duration) }
        if task.energySourceRaw == ai { fields.append(.energy) }
        if task.contextsSourceRaw == ai { fields.append(.contexts) }
        if task.peopleSourceRaw == ai { fields.append(.people) }
        return fields
    }
}
