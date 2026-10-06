import Foundation
import SwiftData

/// Revisions instead of undo (ADR-6): a reset writes a new user revision carrying the old value,
/// nothing is deleted, and every user change is a learning example (ADR-5). Pure over the model
/// objects; the caller saves.
enum RevisionService {
    /// Marks every unseen AI or rule revision as seen. Returns how many were marked.
    @discardableResult
    static func markSeen(_ task: TaskItem, now: Date = Date()) -> Int {
        var marked = 0
        for revision in task.revisions ?? [] where revision.author.isAutomatic && revision.seenAt == nil {
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
        set(revision.field, to: restoreValue(of: revision, on: task), on: task,
            contexts: contexts, projects: projects, now: now, force: true)
            ?? revision
    }

    /// Resets every field the AI or a rule touched to its value before the first such revision.
    @discardableResult
    static func revertAll(
        on task: TaskItem,
        contexts: [TaskContext],
        projects: [Project],
        now: Date = Date()
    ) -> [Revision] {
        var written: [Revision] = []
        for field in RevisedField.allCases {
            guard let first = firstAutomaticRevision(of: field, on: task) else { continue }
            if let revision = set(field, to: restoreValue(of: first, on: task), on: task,
                                  contexts: contexts, projects: projects, now: now, force: false) {
                written.append(revision)
            }
        }
        return written
    }

    /// The value a reset puts back. A title from before the AI that was empty (tasks captured before
    /// #202) becomes the rule title of the raw text, so a reset never leaves the title field empty.
    private static func restoreValue(of revision: Revision, on task: TaskItem) -> String? {
        if revision.field == .title, revision.oldValue == nil { return TitleRule.title(from: task.rawText, reference: task.capturedAt) }
        return revision.oldValue
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

    /// The revision a field marker points at: the first one by the AI or a rule, whose old value is
    /// the state before anything automatic touched the field.
    static func firstAutomaticRevision(of field: RevisedField, on task: TaskItem) -> Revision? {
        (task.revisions ?? [])
            .filter { $0.field == field && $0.author.isAutomatic }
            .min { $0.createdAt < $1.createdAt }
    }

    /// Fields whose current value came from the AI or a rule, in display order.
    static func automaticFields(on task: TaskItem) -> [RevisedField] {
        RevisedField.allCases.filter { origin(of: $0, on: task)?.isAutomatic == true }
    }

    /// Who set the field's current value; nil when it is empty or has no origin column (#101).
    static func origin(of field: RevisedField, on task: TaskItem) -> FieldSource? {
        let raw: String? = switch field {
        case .title: task.titleSourceRaw
        case .dueDate: task.dueSourceRaw
        case .importance: task.importanceSourceRaw
        case .urgency: task.urgencySourceRaw
        case .duration: task.durationSourceRaw
        // Set by hand only; a legacy AI "low"/"medium"/"high" reads as empty, so no origin (#112).
        case .energy: task.energy == nil ? nil : task.energySourceRaw
        case .contexts: task.contextsSourceRaw
        case .people: task.peopleSourceRaw
        case .project, .blockedBy, .repeatRule: nil
        }
        return raw.flatMap(FieldSource.init(rawValue:))
    }
}
