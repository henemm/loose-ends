import Foundation
import SwiftData

/// The helpers the rule step writes with (ADR-4, ADR-6): the run mode, whether a field may be written
/// now, whether the user ever touched it, and the JSON encoding of revision values. The model's draft
/// writer is gone since ADR-22 (#982): no product path calls the model. Pure over the model objects.
enum EnrichmentWriter {
    /// The one run per task (ADR-4), or the second one the user asked for in the detail (#34).
    enum Mode: Sendable {
        case firstRun, reanalysis
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
