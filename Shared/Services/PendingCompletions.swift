import Foundation
import Observation

/// Done waits three seconds before it lands, and a second tap in that time takes it back
/// (data model doc, "Erledigt"; ADR-17, from FocusBlox). Holds only ids and deadlines, the clock
/// comes in from the caller, so the window is testable without waiting. The completion itself is
/// still `TaskActions.complete`; the notification's Done and a subtask's checkbox stay immediate.
@MainActor @Observable
final class PendingCompletions {
    nonisolated static let defaultWindow: TimeInterval = 3

    let window: TimeInterval
    private(set) var deadlines: [UUID: Date] = [:]

    init(window: TimeInterval = defaultWindow) {
        self.window = window
    }

    /// The earliest deadline, nil while nothing waits. The driver sleeps until then.
    var nextDeadline: Date? { deadlines.values.min() }

    func isPending(_ id: UUID) -> Bool {
        deadlines[id] != nil
    }

    /// Starts the window. A second schedule for the same task does not stretch it.
    func schedule(_ id: UUID, now: Date = Date()) {
        guard deadlines[id] == nil else { return }
        deadlines[id] = now.addingTimeInterval(window)
    }

    /// The second tap. Returns whether there was anything left to take back.
    @discardableResult
    func cancel(_ id: UUID) -> Bool {
        deadlines.removeValue(forKey: id) != nil
    }

    /// Completes every task whose window has run out and returns them; the caller saves. A task that
    /// is gone or no longer open by then (deleted, completed elsewhere) is dropped silently: there is
    /// nothing left to complete. With `all`, the windows end now — the app leaves the foreground.
    @discardableResult
    func commitDue(
        in tasks: [TaskItem],
        all: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [TaskItem] {
        let due = Set(deadlines.filter { all || $0.value <= now }.keys)
        guard !due.isEmpty else { return [] }
        for id in due {
            deadlines.removeValue(forKey: id)
        }
        let completed = tasks.filter { due.contains($0.id) && $0.isOpen }
        for task in completed {
            TaskActions.complete(task, now: now, calendar: calendar)
        }
        return completed
    }
}
