import Foundation
import SwiftData

enum SubtaskError: Error, Equatable {
    case emptyText
    case nested
}

/// Subtasks (ADR-8): the model allows any depth, the app shows one level. A subtask is a plain
/// line under its parent: active from the start, so the AI leaves it alone, and never listed in a
/// view of its own. Pure over the model objects; the caller saves.
enum Subtasks {
    /// Adds a line under a top-level task. The text is trimmed once and never touched again (ADR-3).
    @discardableResult
    static func add(_ text: String, to parent: TaskItem, in context: ModelContext, now: Date = Date()) throws -> TaskItem {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SubtaskError.emptyText }
        guard parent.parent == nil else { throw SubtaskError.nested }
        let subtask = TaskItem(rawText: trimmed, capturedVia: .app, ownerID: parent.ownerID)
        subtask.capturedAt = now
        subtask.status = .active
        context.insert(subtask)
        subtask.parent = parent
        subtask.project = parent.project
        return subtask
    }

    /// In capture order. A checked line stays where it is, so nothing jumps under the finger.
    static func ordered(of parent: TaskItem) -> [TaskItem] {
        (parent.subtasks ?? []).sorted { $0.capturedAt < $1.capturedAt }
    }

    struct Progress: Equatable {
        let done: Int
        let total: Int
    }

    static func progress(of parent: TaskItem) -> Progress {
        let all = parent.subtasks ?? []
        return Progress(done: all.filter { $0.status == .done }.count, total: all.count)
    }

    /// Checks a line off, or reopens it.
    static func toggle(_ subtask: TaskItem, now: Date = Date()) {
        if subtask.status == .done {
            TaskActions.restore(subtask)
        } else {
            TaskActions.complete(subtask, now: now)
        }
    }
}
