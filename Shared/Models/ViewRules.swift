import Foundation

/// The computation rules of the system views (docs/project/02-datenmodell-und-ansichten.md).
/// Pure functions over fetched tasks so they are trivially unit-testable.
enum ViewRules {
    static let oldAfterDays = 30
    static let dueWithinDays = 7

    /// Why a task sits in "New", the review tray (#188).
    enum ReviewReason: Equatable {
        /// The model rewrote the title; the raw text is the value before.
        case titleChanged(from: String)
        /// The model or a rule set fields the user has not seen yet.
        case sortedByAI
        /// Enrichment ran, the title stayed below the confidence threshold.
        case titleNotChecked
        /// Enrichment has not run yet.
        case notSortedYet
    }

    /// Needs a look rather than a nod: nothing sorted yet, or a title nobody vouched for. Only
    /// the other tasks can be confirmed with one swipe, so an unchecked title never slips through.
    static func needsLook(_ task: TaskItem) -> Bool {
        task.status == .unprocessed || task.status == .unverified
    }

    static func reviewReason(of task: TaskItem) -> ReviewReason {
        switch task.status {
        case .unprocessed: return .notSortedYet
        case .unverified: return .titleNotChecked
        default:
            if task.titleSourceRaw == FieldSource.ai.rawValue, let title = task.title, title != task.rawText {
                return .titleChanged(from: task.rawText)
            }
            return .sortedByAI
        }
    }

    /// The three views a day starts from; the start screen shows them even when empty.
    static let dailyViews: [ViewKind] = [.next, .new, .due]
    /// Every other view of the start screen, in its order; Done sits apart at the bottom.
    static let occasionalViews: [ViewKind] = [.quick, .old, .waiting, .repeating, .parked]

    /// The system views of the start screen (Henning, 2026-10-05): the daily three always, the
    /// others only while they hold a task, so the screen does not open on a column of empty rows.
    static func startViews(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [ViewKind] {
        dailyViews + occasionalViews.filter { !tasks(for: $0, in: all, now: now, calendar: calendar).isEmpty }
    }

    static func tasks(for kind: ViewKind, in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        let topLevel = all.filter { $0.parent == nil }
        switch kind {
        case .next:
            return topLevel.filter { $0.isOpen && $0.nextRank != nil && !$0.isBlocked }
                .sorted { ($0.nextRank ?? 0) < ($1.nextRank ?? 0) }
        case .new:
            return topLevel.filter { $0.isOpen && ($0.status == .unprocessed || $0.status == .unverified || $0.hasUnseenAIRevisions) }
                .sorted { $0.capturedAt > $1.capturedAt }
        case .due:
            let limit = calendar.date(byAdding: .day, value: dueWithinDays, to: now) ?? now
            return topLevel.filter { $0.isOpen && ($0.dueDate.map { $0 <= limit } ?? false) && !$0.isBlocked }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .quick:
            return topLevel.filter { $0.isOpen && ($0.duration?.isQuick ?? false) && !$0.isBlocked }
                .sorted(by: byUrgencyThenImportance)
        case .old:
            let cutoff = calendar.date(byAdding: .day, value: -oldAfterDays, to: now) ?? now
            return topLevel.filter { $0.isOpen && $0.capturedAt < cutoff }
                .sorted { $0.capturedAt < $1.capturedAt }
        case .waiting:
            return topLevel.filter { $0.isOpen && $0.isBlocked }
        case .repeating:
            return topLevel.filter { $0.isOpen && $0.repeatRule != nil }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .parked:
            return topLevel.filter { $0.status == .parked }
                .sorted { ($0.parkedAt ?? .distantPast) > ($1.parkedAt ?? .distantPast) }
        case .done:
            return topLevel.filter { $0.status == .done }
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .context, .project:
            return [] // resolved by the caller with the concrete context or project
        }
    }

    /// Open top-level tasks carrying the context, urgency then importance.
    static func tasks(inContext context: TaskContext, in all: [TaskItem]) -> [TaskItem] {
        all.filter { $0.parent == nil && $0.isOpen && ($0.contexts ?? []).contains { $0.id == context.id } }
            .sorted(by: byUrgencyThenImportance)
    }

    /// Open top-level tasks of the project, urgency then importance (manual order comes later).
    static func tasks(inProject project: Project, in all: [TaskItem]) -> [TaskItem] {
        all.filter { $0.parent == nil && $0.isOpen && $0.project?.id == project.id }
            .sorted(by: byUrgencyThenImportance)
    }

    /// One line of the project view (#28): a task, or one of its subtasks folded out below it.
    enum ProjectLine: Identifiable {
        case task(TaskItem)
        case subtask(TaskItem, parent: TaskItem)

        var id: UUID {
            switch self {
            case .task(let task): task.id
            case .subtask(let subtask, _): subtask.id
            }
        }
    }

    /// The project view with its subtasks (#28, design briefing open question 3): folded by default,
    /// so the list stays one level and does not read as a checklist. An unfolded parent shows its
    /// subtasks right below it, in capture order and checked ones included, as in the detail.
    static func lines(inProject project: Project, in all: [TaskItem], unfolded: Set<UUID>) -> [ProjectLine] {
        tasks(inProject: project, in: all).flatMap { task -> [ProjectLine] in
            guard unfolded.contains(task.id) else { return [.task(task)] }
            return [.task(task)] + Subtasks.ordered(of: task).map { .subtask($0, parent: task) }
        }
    }

    /// How often the user pushed the due date to a later day. The first due date, pulling a task
    /// forward and the AI's guesses do not count (design briefing, screen 11).
    static func postponeCount(_ task: TaskItem) -> Int {
        let formatter = ISO8601DateFormatter()
        return (task.revisions ?? []).filter { revision in
            guard revision.field == .dueDate, revision.author == .user,
                  let old = revision.oldValue.flatMap(formatter.date(from:)),
                  let new = revision.newValue.flatMap(formatter.date(from:)) else { return false }
            return new > old
        }.count
    }

    struct DayGroup {
        let day: Date
        let tasks: [TaskItem]
    }

    /// Completed tasks by day, newest day first; the order within a day is the caller's.
    static func groupedByCompletionDay(_ tasks: [TaskItem], calendar: Calendar = .current) -> [DayGroup] {
        let groups = Dictionary(grouping: tasks) { calendar.startOfDay(for: $0.completedAt ?? .distantPast) }
        return groups.keys.sorted(by: >).map { DayGroup(day: $0, tasks: groups[$0] ?? []) }
    }

    static func byUrgencyThenImportance(_ a: TaskItem, _ b: TaskItem) -> Bool {
        func rank(_ u: Urgency?) -> Int { switch u { case .high: 0; case .medium: 1; case .low: 2; case nil: 3 } }
        func rank(_ i: Importance?) -> Int { switch i { case .high: 0; case .medium: 1; case .low: 2; case nil: 3 } }
        if rank(a.urgency) != rank(b.urgency) { return rank(a.urgency) < rank(b.urgency) }
        if rank(a.importance) != rank(b.importance) { return rank(a.importance) < rank(b.importance) }
        return a.capturedAt < b.capturedAt
    }
}
