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
        return all.filter { listedByDate($0) && $0.isOpen && !$0.isBlocked && ($0.dueDate.map { $0 >= today && $0 < end } ?? false) }
            .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    /// Stands in a list by its date (#565, concept D): a top-level task, or a subtask with a due date
    /// of its own. A subtask stands outside its task only with something of its own, and then
    /// wherever a dated task stands: Due, Now, Loose ends, the Mac's Next days.
    static func listedByDate(_ task: TaskItem) -> Bool {
        task.parent == nil || task.dueDate != nil
    }

    /// Whose deadline passed (#518, #548): open tasks, subtasks among them, whose due time is behind
    /// or whose day is over, oldest first. Not carried on: each needs a new date (or parking, or Done).
    /// Until then "Now" shows them last (lined up ones by rank, #637), "Due" and "Loose ends" on top,
    /// all with the "New date" button; the app icon counts them (#584), the evening notification asks for them.
    static func leftovers(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        NewDateRule.tasks(in: all, now: now, calendar: calendar)
    }

    /// How a due date reads (#414, #548): `today` while the deadline lies ahead today, `missed` once a
    /// due time passed, `carried(days:)` once a day-only date's day is over. Done and parked tasks
    /// read as `later`: no pressure on them. The margin itself comes from `marginMark`.
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
        if task.dueHasTime { return due < now ? .missed : .today }
        if due >= today { return .today }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: due), to: today).day ?? 1
        return .carried(days: max(days, 1))
    }

    /// What stands in the margin of a row (#424, Henning 2026-10-15): the one time that counts, like
    /// a diary. Red only for time pressure (`pressing`). Done and parked tasks leave it empty.
    enum MarginMark: Equatable {
        /// Due today at this time, still ahead.
        case time(Date)
        /// Due today, no time.
        case today
        /// The deadline passed (#548): the row offers "New date", the trace says what was planned.
        case passed(NewDateRule.Trace)
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
            case .time, .today: true
            default: false
            }
        }
    }

    static func marginMark(of task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> MarginMark {
        guard task.isOpen else { return .none }
        guard let due = task.dueDate else { return task.duration.map(MarginMark.duration) ?? .none }
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: today, to: calendar.startOfDay(for: due)).day ?? 0
        // Behind, blocked or not: a waiting task shows its trace too.
        if days < 0 || (task.dueHasTime && due < now), let trace = NewDateRule.trace(of: task, now: now, calendar: calendar) {
            return .passed(trace)
        }
        switch days {
        case ...0: return task.dueHasTime ? .time(due) : .today
        case 1: return .tomorrow
        case 2...6: return .weekday(due)
        default: return .date(due)
        }
    }

    /// The number on the app icon (#299, #584, #637): the number over "Now", `nowCount` and nowhere else.
    /// Henning, 2026-10-23: "Die Zahl aus der Badge muss sich IMMER genauso in der App wiederfinden".
    /// It is "Due" plus "Next up", each task once; a passed time or an earlier day keeps counting until
    /// the task has a new date. So the number changes only with an edit or a new day, and the morning
    /// notification carries its day's number (`CarryReminders`).
    static func badgeCount(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> Int {
        nowCount(in: all, now: now, calendar: calendar)
    }

    /// The number over "Now" (#637), on every platform: every task "Now" shows, the Knäuel included
    /// whatever its date (#703; Henning, 2026-10-26: the Knäuel always counts and stands as the first
    /// row under "Now"). Nobody adds: the number is the rows.
    static func nowCount(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> Int {
        Self.now(in: all, now: now, calendar: calendar).count
    }

    /// "Now" as one list, the Knäuel first (#699): the watch has no start page header, so the Knäuel
    /// stands among the rows there. Its length is `nowCount`.
    static func nowRows(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        let now = Self.now(in: all, now: now, calendar: calendar)
        return (now.knaeuel.map { [$0] } ?? []) + now.all
    }

    /// Since when the task is open (#701): a repeating one since its last round was completed, not
    /// since the series was captured; everything else since capture. "Old", "longest open" and the
    /// headline's old count all read this.
    static func openSince(_ task: TaskItem) -> Date {
        guard task.repeatRule != nil, let last = task.completions?.map(\.completedAt).max() else {
            return task.capturedAt
        }
        return max(last, task.capturedAt)
    }

    /// "Now" on the start screen (#368), split by time pressure.
    struct NowTasks {
        /// The Knäuel (#643, #703): the first row of "Now", with or without a date; it has its own row,
        /// so it is not in `all`.
        var knaeuel: TaskItem?
        /// Due today, deadline still ahead.
        let today: [TaskItem]
        /// Lined up, by rank, left ones with a rank among them (#637).
        let lined: [TaskItem]
        /// Left from earlier without a rank, oldest deadline first (#637).
        var waiting: [TaskItem] = []
        /// The rows under the Knäuel.
        var all: [TaskItem] { today + lined + waiting }
        /// Every task "Now" shows, the Knäuel first: the number over "Now" and on the icon (#637, #703).
        var count: Int { all.count + (knaeuel == nil ? 0 : 1) }
    }

    /// "Now" (#368, #637): "Due today", "Next up" and what needs a new date as one list, each task once,
    /// the same set the app icon counts. Due today first (earliest first), then everything lined up by
    /// rank (a task left from earlier that the user lined up stands there), then what was left from
    /// earlier without a rank, oldest deadline first; it asks for a new date (#518). A task lined up and
    /// due today stands with the due ones: time pressure wins. A due time passed today makes it a left one.
    /// The Knäuel leads, on its own row and never again among the others (#643, #703).
    static func now(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> NowTasks {
        let knaeuelTask = knaeuel(in: all)
        let knaeuel = knaeuelTask?.id
        let left = leftovers(in: all, now: now, calendar: calendar).filter { $0.id != knaeuel }
        let leftIDs = Set(left.map(\.id))
        let today = dueToday(in: all, now: now, calendar: calendar).filter { !leftIDs.contains($0.id) && $0.id != knaeuel }
        let todayIDs = Set(today.map(\.id))
        var seen = todayIDs
        let lined = (tasks(for: .next, in: all, now: now, calendar: calendar) + left.filter { $0.nextRank != nil })
            .filter { $0.id != knaeuel && seen.insert($0.id).inserted }
        let waiting = left.filter { seen.insert($0.id).inserted }
        return NowTasks(knaeuel: knaeuelTask, today: today.sorted(by: byDueThenRank), lined: lined.sorted(by: byRank),
                        waiting: waiting)
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

    // MARK: - Das Knäuel and the beads (#643, #645)

    /// "Das Knäuel" (#643): the one open top-level task marked by hand. Should two carry the mark (a
    /// second device set it before the sync), the latest mark wins on every device alike.
    static func knaeuel(in all: [TaskItem]) -> TaskItem? {
        all.filter { $0.parent == nil && $0.isKnaeuel }
            .max { ($0.knaeuelAt ?? .distantPast, $0.id.uuidString) < ($1.knaeuelAt ?? .distantPast, $1.id.uuidString) }
    }

    /// The open tasks marked "Zählt" (#645), against the budget of five. The Knäuel counts on its own
    /// and is not among them unless marked too.
    static func counting(in all: [TaskItem]) -> [TaskItem] {
        all.filter { $0.isOpen && $0.countsAt != nil }
    }

    /// One bead on the week's string (#645): a completion of a counting task.
    struct Bead: Equatable, Identifiable {
        let id: String
        let taskID: UUID
        let title: String
        let at: Date
        /// The task was the Knäuel: "Completed" shows it with the small grey Knäuel (Schnitt 4).
        let isKnaeuel: Bool
    }

    /// Monday to Sunday around `now`, whatever the locale's first weekday: [start, end).
    static func week(containing now: Date, calendar: Calendar = .current) -> Range<Date> {
        let today = calendar.startOfDay(for: now)
        let sinceMonday = (calendar.component(.weekday, from: today) + 5) % 7
        let start = calendar.date(byAdding: .day, value: -sinceMonday, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? today
        return start..<end
    }

    /// The beads of the week `now` lies in (#645), oldest first: every completion of a task that counts
    /// (marked "Perle sammeln", or the Knäuel), a done task by `completedAt`, a repeating one by each
    /// `CompletionRecord` in the week. Nothing is stored for this: the string is read from the tasks.
    static func weekBeads(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [Bead] {
        beads(in: all, within: week(containing: now, calendar: calendar))
    }

    /// How many beads fill a string (Henning, 2026-10-24, #655): five, like the budget of open bead
    /// tasks. A full string is the win: the sentence "Für die Perlen" is due. No calendar in it.
    static let stringLength = 5

    /// The string on the start page (#655): the beads since the last full string, oldest first, and
    /// whether it is full right now. Counted from all beads ever, in rounds of `stringLength`: with
    /// five, ten, fifteen beads the string stands full until the next bead starts a new one. Nothing
    /// is stored for this; a deleted bead task shifts the rounds, which is the price of no table.
    struct BeadString: Equatable {
        let beads: [Bead]
        let isFull: Bool
        /// How many strings were filled before this one.
        let filled: Int
        static let empty = BeadString(beads: [], isFull: false, filled: 0)
    }

    static func currentString(in all: [TaskItem], length: Int = stringLength) -> BeadString {
        let every = beads(in: all, within: nil)
        guard !every.isEmpty, length > 0 else { return .empty }
        let rest = every.count % length
        if rest == 0 {
            return BeadString(beads: Array(every.suffix(length)), isFull: true, filled: every.count / length - 1)
        }
        return BeadString(beads: Array(every.suffix(rest)), isFull: false, filled: every.count / length)
    }

    /// The last `limit` beads of all time, oldest first.
    static func recentBeads(in all: [TaskItem], limit: Int = stringLength) -> [Bead] {
        Array(beads(in: all, within: nil).suffix(limit))
    }

    /// Every bead inside `range`, or every bead at all with nil, oldest first.
    static func beads(in all: [TaskItem], within range: Range<Date>?) -> [Bead] {
        func inside(_ date: Date) -> Bool { range?.contains(date) ?? true }
        var beads: [Bead] = []
        for task in all where task.counts && task.isPresent {
            if task.repeatRule != nil {
                for record in task.completions ?? [] where inside(record.completedAt) {
                    beads.append(Bead(id: "\(task.id.uuidString)-\(record.completedAt.timeIntervalSinceReferenceDate)",
                                      taskID: task.id, title: task.displayTitle, at: record.completedAt,
                                      isKnaeuel: task.knaeuelAt != nil))
                }
            } else if task.status == .done, let at = task.completedAt, inside(at) {
                beads.append(Bead(id: task.id.uuidString, taskID: task.id, title: task.displayTitle, at: at,
                                  isKnaeuel: task.knaeuelAt != nil))
            }
        }
        return beads.sorted { ($0.at, $0.id) < ($1.at, $1.id) }
    }

    /// "Completed" by weeks (#646): Monday to Sunday, newest week first, the days inside as before
    /// (newest day first, the caller's order within a day), the week's beads with it. A week without
    /// a bead shows its empty string, so it is in here too.
    struct WeekGroup {
        let week: Range<Date>
        let days: [DayGroup]
        let beads: [Bead]
        /// The week `now` lies in: its head reads "This week · …".
        let isCurrent: Bool
    }

    static func groupedByCompletionWeek(_ tasks: [TaskItem], all: [TaskItem], now: Date = Date(),
                                        calendar: Calendar = .current) -> [WeekGroup] {
        let current = week(containing: now, calendar: calendar)
        let byWeek = Dictionary(grouping: tasks) { week(containing: $0.completedAt ?? .distantPast, calendar: calendar).lowerBound }
        return byWeek.keys.sorted(by: >).map { start in
            let week = week(containing: start, calendar: calendar)
            return WeekGroup(week: week, days: groupedByCompletionDay(byWeek[start] ?? [], calendar: calendar),
                             beads: weekBeads(in: all, now: start, calendar: calendar), isCurrent: week == current)
        }
    }

    /// The beads the Sunday sentence speaks of (#646): this week's, on Sunday from 16:00 only
    /// (Henning, 2026-10-26: on Monday "This week" meant the one just over, and the sentence kept the
    /// time-pressure ones from speaking); nil otherwise or without a bead.
    static func weekToSpeakOf(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [Bead]? {
        guard calendar.component(.weekday, from: now) == 1,
              calendar.component(.hour, from: now) >= StartHeadline.lookBackHour else { return nil }
        let beads = weekBeads(in: all, now: now, calendar: calendar)
        return beads.isEmpty ? nil : beads
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
        // What a subtask carries of its own is the entry to these views (#565, Henning 2026-10-27: lined
        // up as next, it did not stand in "Now"): a rank, a duration, a repeat, a park. Only the views
        // that ask for nothing of the task itself (New, Old, Waiting) stay top level. Done lists a checked line
        // that carried something of its own: it stood in a list before, so it stands in "Done" after.
        switch kind {
        case .next:
            return all.filter { $0.isOpen && $0.nextRank != nil && !$0.isBlocked }
                .sorted { ($0.nextRank ?? 0) < ($1.nextRank ?? 0) }
        case .new:
            return topLevel.filter(isInNew)
                .sorted { $0.capturedAt > $1.capturedAt }
        case .due:
            // Today and overdue (Henning, 2026-10-15): tomorrow or "Monday" is not due yet.
            let today = calendar.startOfDay(for: now)
            let limit = calendar.date(byAdding: .day, value: 1, to: today) ?? now
            // A subtask with a date of its own stands here too (#565).
            return all.filter { listedByDate($0) && $0.isOpen && ($0.dueDate.map { $0 < limit } ?? false) && !$0.isBlocked }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .quick:
            // In the blocks of "Loose ends" (#657, Henning 2026-10-27): a far date does not stand first.
            return all.filter { $0.isOpen && ($0.duration?.isQuick ?? false) && !$0.isBlocked }
                .sorted(by: byPressureThenWeight(now: now, calendar: calendar))
        case .old:
            let cutoff = calendar.date(byAdding: .day, value: -oldAfterDays, to: now) ?? now
            return topLevel.filter { $0.isOpen && openSince($0) < cutoff }
                .sorted { openSince($0) < openSince($1) }
        case .waiting:
            return topLevel.filter { $0.isOpen && $0.isBlocked }
        case .repeating:
            return all.filter { $0.isOpen && $0.repeatRule != nil }
                .sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
        case .parked:
            return all.filter { $0.status == .parked }
                .sorted { ($0.parkedAt ?? .distantPast) > ($1.parkedAt ?? .distantPast) }
        case .open:
            // Not `isOpen`: that leaves parked tasks out, and "Loose ends" means all of them (#319);
            // since #545 the parked ones close the list as a block of their own. A subtask with a
            // date of its own stands among the dated ones (Henning, 2026-10-21, #565): moved to
            // tomorrow, it had vanished from every list until its day.
            return all.filter { listedByDate($0) && $0.status != .done && $0.status != .removed }
                .sorted(by: byPressureThenWeight(now: now, calendar: calendar))
        case .done:
            return all.filter { $0.status == .done && ($0.parent == nil || Subtasks.carriesOwn($0)) }
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        case .context, .project:
            return [] // resolved by the caller with the concrete context or project
        }
    }

    /// Open tasks carrying the context in the blocks of "Loose ends" (#657: today, no date by weight,
    /// later); a subtask with that tag of its own among them (#565).
    static func tasks(inContext context: TaskContext, in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        all.filter { $0.isOpen && ($0.contexts ?? []).contains { $0.id == context.id } }
            .sorted(by: byPressureThenWeight(now: now, calendar: calendar))
    }

    /// Open top-level tasks of the project in the blocks of "Loose ends" (#657; manual order comes later).
    static func tasks(inProject project: Project, in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [TaskItem] {
        all.filter { $0.parent == nil && $0.isOpen && $0.project?.id == project.id }
            .sorted(by: byPressureThenWeight(now: now, calendar: calendar))
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

        /// The project's task the line belongs to: its block decides where a subtask stands (#657).
        var owner: TaskItem {
            switch self {
            case .task(let task): task
            case .subtask(_, let parent): parent
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

    /// The blocks of "Loose ends" (#657, Henning 2026-10-24): a deadline counts only while it is
    /// today. Due today or before stands on top, the undated follow, a date from tomorrow on rests in
    /// "Later" below them: who set a far date said "not yet", an undated task may weigh more.
    /// Parked closes the list (#545). Since 2026-10-27 "Quick", tags and projects stand in them too.
    enum LooseEndsStage: Int, Comparable {
        case today, undated, later, parked

        static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
    }

    static func looseEndsStage(_ task: TaskItem, now: Date = Date(), calendar: Calendar = .current) -> LooseEndsStage {
        if task.status == .parked { return .parked }
        guard let due = task.dueDate else { return .undated }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return due < tomorrow ? .today : .later
    }

    /// "Loose ends" (#545, Henning 2026-10-18: "Erst was drängt"; #657): the stages above in order.
    /// Today and Later by due date, the undated by urgency, importance and capture time, parked
    /// in the order of "Parked" (last parked first), whatever their weight: parked means no pressure.
    /// #319 holds by half, parked tasks stay visible, at the end.
    static func byPressureThenWeight(now: Date = Date(), calendar: Calendar = .current) -> (TaskItem, TaskItem) -> Bool {
        { a, b in
            let (stageA, stageB) = (looseEndsStage(a, now: now, calendar: calendar), looseEndsStage(b, now: now, calendar: calendar))
            if stageA != stageB { return stageA < stageB }
            switch stageA {
            case .parked:
                let (pa, pb) = (a.parkedAt ?? .distantPast, b.parkedAt ?? .distantPast)
                return pa != pb ? pa > pb : a.capturedAt < b.capturedAt
            case .undated:
                return byUrgencyThenImportance(a, b)
            case .today, .later:
                let (da, db) = (a.dueDate ?? .distantFuture, b.dueDate ?? .distantFuture)
                return da != db ? da < db : a.capturedAt < b.capturedAt
            }
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
