import Foundation
import SwiftData

/// The actions on a task (data model doc, "Aktionen auf einer Aufgabe"). Pure over the model
/// objects; the caller saves.
enum TaskActions {
    enum MoveTarget: Hashable, Sendable {
        case tomorrow, weekend, nextWeek
        case date(Date)
    }

    /// Done. A repeating task does not end: it records the completion and rolls forward (ADR-7).
    static func complete(_ task: TaskItem, now: Date = Date(), calendar: Calendar = .current) {
        if let rule = task.repeatRule {
            let record = CompletionRecord(task: task, completedAt: now, dueDateAtCompletion: task.dueDate)
            task.completions = (task.completions ?? []) + [record]
            task.dueDate = rule.nextDueDate(previousDue: task.dueDate, completedOn: now, calendar: calendar)
            return
        }
        task.status = .done
        task.completedAt = now
        task.nextRank = nil
    }

    /// Back from Done. Completion records stay.
    static func restore(_ task: TaskItem) {
        task.status = .active
        task.completedAt = nil
    }

    /// Into Next up at the end of the list, or out of it.
    static func toggleNext(_ task: TaskItem, among all: [TaskItem]) {
        if task.nextRank != nil {
            task.nextRank = nil
            return
        }
        let highest = all.compactMap(\.nextRank).max() ?? 0
        task.nextRank = highest + 1
    }

    static func park(_ task: TaskItem, now: Date = Date()) {
        task.status = .parked
        task.parkedAt = now
        task.nextRank = nil
    }

    static func activate(_ task: TaskItem) {
        task.status = .active
        task.parkedAt = nil
    }

    /// Moves the due date to a day. Written as a user revision, so the correction is a learning
    /// example (ADR-5). Returns the new due date.
    @discardableResult
    static func move(
        _ task: TaskItem,
        to target: MoveTarget,
        contexts: [TaskContext],
        projects: [Project],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        let day = dueDate(for: target, now: now, calendar: calendar)
        RevisionService.set(.dueDate, to: day.ISO8601Format(), on: task, contexts: contexts, projects: projects, now: now)
        task.dueHasTime = false
        return day
    }

    /// Tomorrow, the coming Saturday, the coming Monday, or a chosen day; always at start of day.
    static func dueDate(for target: MoveTarget, now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        switch target {
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        case .weekend:
            return next(weekday: 7, after: today, calendar: calendar)
        case .nextWeek:
            return next(weekday: 2, after: today, calendar: calendar)
        case .date(let date):
            return calendar.startOfDay(for: date)
        }
    }

    /// The next `weekday` (Calendar numbering, 1 = Sunday) strictly after `day`.
    private static func next(weekday: Int, after day: Date, calendar: Calendar) -> Date {
        let current = calendar.component(.weekday, from: day)
        var delta = (weekday - current + 7) % 7
        if delta == 0 { delta = 7 }
        return calendar.date(byAdding: .day, value: delta, to: day) ?? day
    }
}
