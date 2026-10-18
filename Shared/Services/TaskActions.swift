import Foundation
import SwiftData

/// The actions on a task (data model doc, "Aktionen auf einer Aufgabe"). Pure over the model
/// objects; the caller saves.
enum TaskActions {
    enum MoveTarget: Hashable, Sendable {
        case tomorrow, weekend, nextWeek
        case date(Date)
    }

    /// Done. A repeating task does not end: it records the completion and rolls forward (ADR-7). The
    /// next round counts from the series' anchor (#552), not from a due date moved for one round, and
    /// lands on the first round after now, so a round moved past its successor does not roll back.
    static func complete(_ task: TaskItem, now: Date = Date(), calendar: Calendar = .current) {
        if var rule = task.repeatRule {
            let record = CompletionRecord(task: task, completedAt: now, dueDateAtCompletion: task.dueDate)
            task.completions = (task.completions ?? []) + [record]
            var next = rule.nextDueDate(previousDue: rule.anchor ?? task.dueDate, completedOn: now, calendar: calendar)
            var rounds = 0
            while next <= now, rounds < 1000 {
                next = rule.nextDueDate(previousDue: next, completedOn: now, calendar: calendar)
                rounds += 1
            }
            task.dueDate = next
            if rule.hour != nil { task.dueHasTime = true }   // the anchor carries the rule's time back after a day-only move
            rule.anchor = next
            task.repeatRule = rule
            task.placeRemindedAt = nil   // the place is armed again for the next round (#226)
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

    /// Drag in Next up: the rows land in their new place and every rank is renumbered 1...n.
    static func moveNext(_ ordered: [TaskItem], from source: IndexSet, to destination: Int) {
        var items = ordered
        items.move(fromOffsets: source, toOffset: destination)
        for (index, task) in items.enumerated() {
            task.nextRank = Double(index + 1)
        }
    }

    /// "Looks right" from the detail (#318): the user vouches for the task as it stands, title
    /// included, so it leaves New. Opening alone only marks the AI's changes as seen; an unchecked
    /// or not yet sorted title kept the task in New until the title was edited. Without a title
    /// there is nothing to vouch for, so the status stays. A task confirmed before its model step
    /// still gets that one run: `EnrichmentCoordinator` also picks up active tasks without
    /// `processedAt` (Henning, 2026-10-11).
    static func confirmReview(_ task: TaskItem, now: Date = Date()) {
        _ = RevisionService.markSeen(task, now: now)
        if task.status == .unprocessed || task.status == .unverified, task.title != nil {
            task.status = .active
        }
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

    /// A due date with or without a time, as a user revision (#548): a day-only date is stored at the
    /// start of its day, like the due editor does. Nil clears the date.
    static func setDue(
        _ task: TaskItem,
        to date: Date?,
        hasTime: Bool,
        contexts: [TaskContext],
        projects: [Project],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let stored = date.map { hasTime ? $0 : calendar.startOfDay(for: $0) }
        RevisionService.set(.dueDate, to: stored?.ISO8601Format(), on: task, contexts: contexts, projects: projects, now: now)
        task.dueHasTime = stored != nil && hasTime
    }

    /// Where the date picker of "Move → Date…" starts (#33): the current due day while it lies
    /// ahead, otherwise tomorrow — moving to today or into the past is never the likely intent.
    static func suggestedMoveDate(for task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> Date {
        let tomorrow = dueDate(for: .tomorrow, now: now, calendar: calendar)
        guard let due = task.dueDate else { return tomorrow }
        let day = calendar.startOfDay(for: due)
        return day >= tomorrow ? day : tomorrow
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
