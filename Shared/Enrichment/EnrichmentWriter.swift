import Foundation
import SwiftData

/// Writes a draft onto a task. Fields at or above the threshold get value, source and confidence
/// plus one AI revision each (ADR-6). Runs exactly once per task (ADR-4): `processedAt` is set
/// even when nothing crossed the threshold. Pure over the model objects; the caller saves.
enum EnrichmentWriter {
    static let confidenceThreshold = 0.6

    /// Returns the number of fields written.
    @discardableResult
    static func apply(
        _ draft: EnrichmentDraft,
        to task: TaskItem,
        contexts available: [TaskContext],
        projects: [Project],
        threshold: Double = confidenceThreshold,
        now: Date = Date()
    ) -> Int {
        var written = 0
        let ai = FieldSource.ai.rawValue

        func record(_ field: RevisedField, old: String?, new: String?, reason: String) {
            let revision = Revision(task: task, field: field, oldValue: old, newValue: new, author: .ai, reason: reason)
            task.revisions = (task.revisions ?? []) + [revision]
            written += 1
        }

        if let title = draft.title, title.confidence >= threshold, !title.value.isEmpty {
            record(.title, old: task.title, new: title.value, reason: title.reason)
            task.title = title.value
            task.titleSourceRaw = ai
            task.titleConfidence = title.confidence
            if task.status == .unprocessed { task.status = .active }
        } else if task.status == .unprocessed {
            task.status = .unverified
        }

        if let due = draft.dueDate, due.confidence >= threshold {
            record(.dueDate, old: task.dueDate?.ISO8601Format(), new: due.value.ISO8601Format(), reason: due.reason)
            task.dueDate = due.value
            task.dueHasTime = draft.dueHasTime
            task.dueSourceRaw = ai
            task.dueConfidence = due.confidence
        }

        if let importance = draft.importance, importance.confidence >= threshold {
            record(.importance, old: task.importanceRaw, new: importance.value.rawValue, reason: importance.reason)
            task.importance = importance.value
            task.importanceSourceRaw = ai
            task.importanceConfidence = importance.confidence
        }

        if let urgency = draft.urgency, urgency.confidence >= threshold {
            record(.urgency, old: task.urgencyRaw, new: urgency.value.rawValue, reason: urgency.reason)
            task.urgency = urgency.value
            task.urgencySourceRaw = ai
            task.urgencyConfidence = urgency.confidence
        }

        if let duration = draft.duration, duration.confidence >= threshold {
            record(.duration, old: task.durationRaw, new: duration.value.rawValue, reason: duration.reason)
            task.duration = duration.value
            task.durationSourceRaw = ai
            task.durationConfidence = duration.confidence
        }

        if let energy = draft.energy, energy.confidence >= threshold {
            record(.energy, old: task.energyRaw, new: energy.value.rawValue, reason: energy.reason)
            task.energy = energy.value
            task.energySourceRaw = ai
            task.energyConfidence = energy.confidence
        }

        if let contexts = draft.contexts, contexts.confidence >= threshold {
            let matched = available.filter { context in
                contexts.value.contains { $0.compare(context.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            }
            if !matched.isEmpty {
                record(.contexts, old: encode((task.contexts ?? []).map(\.name)), new: encode(matched.map(\.name)), reason: contexts.reason)
                task.contexts = matched
                task.contextsSourceRaw = ai
                task.contextsConfidence = contexts.confidence
            }
        }

        if let people = draft.people, people.confidence >= threshold, !people.value.isEmpty {
            record(.people, old: encode(task.people), new: encode(people.value), reason: people.reason)
            task.people = people.value
            task.peopleSourceRaw = ai
            task.peopleConfidence = people.confidence
        }

        if let project = draft.project, project.confidence >= threshold,
           let matched = projects.first(where: { $0.name.compare(project.value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            record(.project, old: task.project?.name, new: matched.name, reason: project.reason)
            task.project = matched
        }

        task.processedAt = now
        return written
    }

    /// Revisions store values as JSON strings so arrays and scalars share one column.
    static func encode(_ names: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(names) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
