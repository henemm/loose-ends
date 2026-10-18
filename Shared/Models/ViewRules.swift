import Foundation

/// The computation rules of the system views (docs/project/02-datenmodell-und-ansichten.md).
/// Pure functions over fetched tasks so they are trivially unit-testable.
enum ViewRules {
    static let oldAfterDays = 30

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

    /// Sits in "New": open, top level, and not sorted, not vouched for, or changed unseen.
    static func isInNew(_ task: TaskItem) -> Bool {
        task.parent == nil && task.isOpen
            && (task.status == .unprocessed || task.status == .unverified || task.hasUnseenAutomaticRevisions)
    }

    /// "Looks right" in the detail (#349): any task in "New" with something to vouch for. An
    /// unchecked or unsorted task needs a title; one confirmed before its model step still gets
    /// that run (`EnrichmentCoordinator`, #318).
    static func canConfirm(_ task: TaskItem) -> Bool {
        isInNew(task) && (task.status == .active || task.title != nil)
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

    /// The views before Tags and Projects in the iPhone index (#421): Next up, Due and New always,
    /// then the occasional ones that hold a task, Quick among them (it was a chip until #421).
    static func indexViews(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [ViewKind] {
        [.next, .due, .new]
            + occasionalViews.filter { !tasks(for: $0, in: all, now: now, calendar: calendar).isEmpty }
    }

    /// What stands for today (Henning, 2026-10-11, #299): open top-level tasks due today, earliest
    /// first. Blocked tasks stay out, as in "Due". What is left from earlier days is not today's: it
    /// waits in `leftovers` until it has a new date (Henning, 2026-10-17, #518), so a day no longer
    /// starts full. The "Due" view keeps showing it.
    static func dueToday(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        return all.filter { $0.parent == nil && $0.isOpen && !$0.isBlocked && ($0.dueDate.map { $0 >= today && $0 < end } ?? false) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    /// Left from earlier days (#518): open top-level tasks due before today, oldest first. Not carried
    /// on: each needs a new date (or parking, or Done). Until then they count neither in "Now" nor on
    /// the app icon; "Due" and "Loose ends" show them on top, the evening notification asks for them.
    static func leftovers(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        let today = calendar.startOfDay(for: now)
        return all.filter { $0.parent == nil && $0.isOpen && !$0.isBlocked && ($0.dueDate.map { $0 < today } ?? false) }
            .sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }
    }

    /// How a due date reads in a row (#414, ADR-14): red only for time pressure. A task due today is
    /// red; once its day is over, only a task with a due time stays red (`missed`). A day-only date is
    /// mostly a spoken intention ("tomorrow", "on Friday"), so it turns grey and shows how long it has
    /// been carried along. Done and parked tasks read as `later`: no pressure on them.
    enum DueState: Equatable {
        case later
        case today
        case missed
        case carried(days: Int)
    }

    static func dueState(of task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> DueState {
        guard task.isOpen, let due = task.dueDate else { return .later }
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), due < tomorrow else { return .later }
        if due >= today { return .today }
        if task.dueHasTime { return .missed }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: today).day ?? 1
        return .carried(days: max(days, 1))
    }

    /// What stands in the margin of a row (#424, Henning 2026-10-15): the one time that counts, like
    /// a diary. Red only for time pressure (`pressing`). Done and parked tasks leave it empty.
    enum MarginMark: Equatable {
        /// Due today at this time.
        case time(Date)
        /// Due today, no time.
        case today
        /// A time that has passed, `days` calendar days ago.
        case missed(days: Int)
        /// A day-only date carried along (#414).
        case carried(days: Int)
        case tomorrow
        /// Within the coming six days: the weekday.
        case weekday(Date)
        /// Later: day and month.
        case date(Date)
        /// No due date: the duration instead.
        case duration(DurationBucket)
        case none

        var pressing: Bool {
            switch self {
            case .time, .today, .missed: true
            default: false
            }
        }
    }

    static func marginMark(of task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> MarginMark {
        guard task.isOpen else { return .none }
        guard let due = task.dueDate else { return task.duration.map(MarginMark.duration) ?? .none }
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: due)).day ?? 0
        switch days {
        case ..<0: return task.dueHasTime ? .missed(days: -days) : .carried(days: -days)
        case 0: return task.dueHasTime ? .time(due) : .today
        case 1: return .tomorrow
        case 2...6: return .weekday(due)
        default: return .date(due)
        }
    }

    /// The number on the app icon (#299): "Next up" plus "Due today", each task once. On the start
    /// screen a task in both stands in both lists (Henning, 2026-10-11); the count does not double it.
    /// What is left from earlier days counts only once it has a new date (#518).
    static func badgeCount(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> Int {
        self.now(in: all, now: now, calendar: calendar).all.count
    }

    /// "Now" on the iPhone start screen (#368), split by time pressure.
    struct NowTasks {
        let today: [TaskItem]
        let lined: [TaskItem]
        var all: [TaskItem] { today + lined }
    }

    /// "Now" (#368): "Due today" and "Next up" as one list, each task once — the same sets
    /// `badgeCount` counts. Due today first (earliest first), then the rest of "Next up" by rank. A
    /// task lined up and due stands with the due ones: time pressure wins. A task left from an
    /// earlier day stays out, lined up or not, until it has a new date (#518).
    static func now(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> NowTasks {
        let left = Set(leftovers(in: all, now: now, calendar: calendar).map(\.id))
        var seen = Set<UUID>()
        let union = (dueToday(in: all, now: now, calendar: calendar)
            + tasks(for: .next, in: all, now: now, calendar: calendar))
            .filter { !left.contains($0.id) && seen.insert($0.id).inserted }
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let dueNow = union.filter { ($0.dueDate.map { $0 >= today && $0 < end } ?? false) }
        let timed = Set(dueNow.map(\.id))
        let lined = union.filter { !timed.contains($0.id) }
        return NowTasks(today: dueNow.sorted(by: byDueThenRank), lined: lined.sorted(by: byRank))
    }

    /// Due date first, then rank (none last), then capture time (#368).
    private static func byDueThenRank(_ a: TaskItem, _ b: TaskItem) -> Bool {
        let (da, db) = (a.dueDate ?? .distantFuture, b.dueDate ?? .distantFuture)
        return da != db ? da < db : byRank(a, b)
    }

    /// Rank first (none last), then capture time (#368).
    private static func byRank(_ a: TaskItem, _ b: TaskItem) -> Bool {
        let (ra, rb) = (a.nextRank ?? .infinity, b.nextRank ?? .infinity)
        return ra != rb ? ra < rb : a.capturedAt < b.capturedAt
    }

    /// The place of each task in "Next up": 1, 2, 3 … in that view's order (#509). Lists show it as a
    /// star with the number at the row's end, so a task already lined up is seen in every list.
    static func nextRanks(in all: [TaskItem]) -> [UUID: Int] {
        var ranks: [UUID: Int] = [:]
        for (index, task) in tasks(for: .next, in: all).enumerated() {
            ranks[task.id] = index + 1
        }
        return ranks
    }

    static func tasks(for kind: ViewKind, in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        let topLevel = all.filter { $0.parent == nil }
        switch kind {
        case .next:
            return topLevel.filter { $0.isOpen && $0.nextRank != nil && !$0.isBlocked }
                .sorted { ($0.nextRank ?? 0) < ($1.nextRank ?? 0) }
        case .new:
            return topLevel.filter(isInNew)
                .sorted { $0.capturedAt > $1.capturedAt }
        case .due:
            // Today and overdue (Henning, 2026-10-15): tomorrow or "Monday" is not due yet.
            let today = calendar.startOfDay(for: now)
            let limit = calendar.date(byAdding: .day, value: 1, to: today) ?? now
            return topLevel.filter { $0.isOpen && ($0.dueDate.map { $0 < limit } ?? false) && !$0.isBlocked }
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
        case .open:
            // Not `isOpen`: that leaves parked tasks out, and "Loose ends" means all of them (#319);
            // since #545 the parked ones close the list as a block of their own.
            return topLevel.filter { $0.status != .done }
                .sorted(by: byPressureThenWeight)
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

    /// "Loose ends" (#545, Henning 2026-10-18: "Erst was drängt"): what presses stands first, what rests
    /// stands last. A dated task before an undated one, dated by due date (overdue and today on top,
    /// then the coming days), undated by urgency, importance and capture time as before. Parked
    /// tasks close the list as one block in the order of "Parked" (last parked first), whatever
    /// their weight: parked means no pressure. The same logic as "Now" on the start screen, without
    /// the rank limit; #319 holds by half, parked tasks stay visible, at the end.
    static func byPressureThenWeight(_ a: TaskItem, _ b: TaskItem) -> Bool {
        let (parkedA, parkedB) = (a.status == .parked, b.status == .parked)
        if parkedA != parkedB { return parkedB }
        if parkedA {
            let (pa, pb) = (a.parkedAt ?? .distantPast, b.parkedAt ?? .distantPast)
            return pa != pb ? pa > pb : a.capturedAt < b.capturedAt
        }
        switch (a.dueDate, b.dueDate) {
        case let (da?, db?): return da != db ? da < db : a.capturedAt < b.capturedAt
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return byUrgencyThenImportance(a, b)
        }
    }

    static func byUrgencyThenImportance(_ a: TaskItem, _ b: TaskItem) -> Bool {
        func rank(_ u: Urgency?) -> Int { switch u { case .high: 0; case .medium: 1; case .low: 2; case nil: 3 } }
        func rank(_ i: Importance?) -> Int { switch i { case .high: 0; case .medium: 1; case .low: 2; case nil: 3 } }
        if rank(a.urgency) != rank(b.urgency) { return rank(a.urgency) < rank(b.urgency) }
        if rank(a.importance) != rank(b.importance) { return rank(a.importance) < rank(b.importance) }
        return a.capturedAt < b.capturedAt
    }
}
