import Foundation
import SwiftData

/// Writes a draft onto a task. Fields at or above the threshold get value, source and confidence
/// plus one AI revision each (ADR-6). Runs exactly once per task (ADR-4): `processedAt` is set
/// even when nothing crossed the threshold. A second run only on the user's request (#34), in
/// `Mode.reanalysis`. Pure over the model objects; the caller saves.
enum EnrichmentWriter {
    static let confidenceThreshold = 0.6

    /// The one run per task (ADR-4), or the second one the user asked for in the detail (#34).
    enum Mode: Sendable {
        case firstRun, reanalysis
    }

    /// Returns the number of fields written.
    @discardableResult
    static func apply(
        _ draft: EnrichmentDraft,
        to task: TaskItem,
        contexts available: [TaskContext],
        projects: [Project],
        threshold: Double = confidenceThreshold,
        mode: Mode = .firstRun,
        ruleFields: Set<RevisedField> = [],
        now: Date = Date()
    ) -> Int {
        var written = 0
        let ai = FieldSource.ai.rawValue

        // Rules before the model: a field a rule matched in this run is the rule's, even where the
        // re-analysis lifts the first run's "only while empty" guard (#34).
        func may(_ field: RevisedField, firstRun: Bool, changes: Bool) -> Bool {
            !ruleFields.contains(field) && mayWrite(field, on: task, mode: mode, firstRun: firstRun, changes: changes)
        }

        func record(_ field: RevisedField, old: String?, new: String?, reason: String) {
            let revision = Revision(task: task, field: field, oldValue: old, newValue: new, author: .ai, reason: reason)
            task.revisions = (task.revisions ?? []) + [revision]
            written += 1
        }

        if let title = draft.title, title.confidence >= threshold, !title.value.isEmpty {
            // The model may refine the rule title, but not bring back what the rules struck (#217):
            // its title goes through the same rule. Equal to the rule title means nothing to write.
            let value = TitleRule.title(from: title.value, reference: task.capturedAt) ?? title.value
            if value != task.title, may(.title, firstRun: true, changes: true) {
                record(.title, old: task.title, new: value, reason: title.reason)
                task.title = value
                task.titleSourceRaw = ai
                task.titleConfidence = title.confidence
            }
            // Unverified means the first run found no title; a re-analysis that finds one lifts it.
            if task.status == .unprocessed || task.status == .unverified, task.title != nil { task.status = .active }
        } else if task.status == .unprocessed {
            task.status = .unverified
        }

        if let due = draft.dueDate, due.confidence >= threshold,
           may(.dueDate, firstRun: true, changes: due.value != task.dueDate || draft.dueHasTime != task.dueHasTime) {
            record(.dueDate, old: task.dueDate?.ISO8601Format(), new: due.value.ISO8601Format(), reason: due.reason)
            task.dueDate = due.value
            task.dueHasTime = draft.dueHasTime
            task.dueSourceRaw = ai
            task.dueConfidence = due.confidence
        }

        // Only while the field is still empty and the user never touched it (#136 AC-9): the rule step
        // runs before the model in the same pass, and without this guard the model would silently
        // overwrite a recognised value and hang a second revision on the same field. Due date,
        // importance and urgency need no guard — they left the model schema with #95/#117, energy
        // with #112.
        if let duration = draft.duration, duration.confidence >= threshold,
           may(.duration, firstRun: task.duration == nil && !userHasTouched(.duration, on: task),
               changes: duration.value != task.duration) {
            record(.duration, old: task.durationRaw, new: duration.value.rawValue, reason: duration.reason)
            task.duration = duration.value
            task.durationSourceRaw = ai
            task.durationConfidence = duration.confidence
        }

        // Same guard, and an empty relationship counts as unset: SwiftData hands a to-many
        // relationship back as an empty array as readily as `nil`.
        if let contexts = draft.contexts, contexts.confidence >= threshold {
            let matched = available.filter { context in
                contexts.value.contains { $0.compare(context.name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            }
            let current = Set((task.contexts ?? []).map(\.id))
            if !matched.isEmpty,
               may(.contexts, firstRun: current.isEmpty && !userHasTouched(.contexts, on: task),
                   changes: Set(matched.map(\.id)) != current) {
                record(.contexts, old: encode((task.contexts ?? []).map(\.name)), new: encode(matched.map(\.name)), reason: contexts.reason)
                task.contexts = matched
                task.contextsSourceRaw = ai
                task.contextsConfidence = contexts.confidence
            }
        }

        if let people = draft.people, people.confidence >= threshold, !people.value.isEmpty,
           may(.people, firstRun: true, changes: people.value != task.people) {
            record(.people, old: encode(task.people), new: encode(people.value), reason: people.reason)
            task.people = people.value
            task.peopleSourceRaw = ai
            task.peopleConfidence = people.confidence
        }

        if let project = draft.project, project.confidence >= threshold,
           let matched = projects.first(where: { $0.name.compare(project.value, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }),
           may(.project, firstRun: true, changes: matched.id != task.project?.id) {
            record(.project, old: task.project?.name, new: matched.name, reason: project.reason)
            task.project = matched
        }

        task.processedAt = now
        return written
    }

    /// Whether a rule or the model may write `field` now. First run (ADR-4): what the caller's own
    /// guard says. Re-analysis (#34): every field the user never touched — AI-set or still empty —
    /// but only to a different value; the same value again is no change and gets no revision. What
    /// the user set stays theirs, the same reason the first run guards duration and contexts (#136).
    static func mayWrite(_ field: RevisedField, on task: TaskItem, mode: Mode, firstRun: Bool, changes: Bool) -> Bool {
        switch mode {
        case .firstRun: firstRun
        case .reanalysis: changes && !userHasTouched(field, on: task)
        }
    }

    /// Whether the user ever set this field himself — including setting it to empty. The origin marker
    /// cannot answer that: `FieldCodec` clears `durationSourceRaw` (`FieldCodec.swift:56`) and
    /// `contextsSourceRaw` (`FieldCodec.swift:65`) whenever the value becomes empty, so a field the
    /// user deliberately emptied looks exactly like one that was never set. A user `Revision` is the
    /// reliable marker, because revisions are never deleted ("Revisions, not undo").
    static func userHasTouched(_ field: RevisedField, on task: TaskItem) -> Bool {
        (task.revisions ?? []).contains { $0.field == field && $0.author == .user }
    }

    /// Revisions store values as JSON strings so arrays and scalars share one column.
    static func encode(_ names: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(names) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
