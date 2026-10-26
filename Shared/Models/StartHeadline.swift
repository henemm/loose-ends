import Foundation

/// The big line above "Now" on the iPhone start screen (#426, Henning 2026-10-15): each day the one
/// fact that stands out, from 16:00 a look back at what got done. Pure over the tasks and the clock;
/// the words live in the app (`StartHeadlineText`). No model: every rung is a count or a date.
/// Every title is quoted, a long one cut at a word with "…" (#585): a sentence without the task
/// ("The fixed time at 11:00 has passed.") said nothing.
enum StartHeadline: Equatable {
    /// A, A+: from 16:00 with something done today. Titles are the latest first, at most two;
    /// `next` is a fixed time within the next two hours.
    case doneToday(count: Int, titles: [String], next: Upcoming?)
    /// Sunday from 16:00 until midnight (#646): "This week: four beads." with
    /// the string and the titles under it. Without a bead no sentence, the ladder goes on.
    case week(count: Int, titles: [String])
    /// A with the Knäuel among what got done (#644): "Today untangled: <title>." comes first; `count`
    /// is everything done today, `next` as in `doneToday`.
    case untangled(title: String, count: Int, next: Upcoming?)
    /// 1: fixed times today have passed; `title` and `at` are the latest, `count` how many.
    case missed(title: String, at: Date, count: Int)
    /// 2: fixed times still ahead today; `title` and `at` are the first.
    case upcoming(title: String, at: Date, count: Int)
    /// 2b: tasks due today without a time (Henning, 2026-10-16): the day-only date is today's fact;
    /// `title` is the first by rank, spoken only when it is the only one.
    case dueToday(title: String, count: Int)
    /// 3: deadlines from earlier days that passed (#633, Henning 2026-10-23: "nur weil die fälligen
    /// Dinge noch nicht neu terminiert sind, heißt es ja nicht, dass heute nichts drängt"). `title` is
    /// the oldest, spoken only when it is the only one.
    case needsNewDate(title: String, count: Int)
    /// 4: a tag (label) holding many open tasks.
    case pile(label: String, count: Int)
    /// 5: tasks older than a month.
    case old(count: Int)
    /// 6: before 16:00, what got done yesterday.
    case doneYesterday(count: Int)
    /// 7: open tasks, nothing stands out.
    case calm
    /// 8: nothing open.
    case allDone

    struct Upcoming: Equatable {
        let title: String
        let at: Date
    }

    static let lookBackHour = 16
    static let titleLimit = 32
    static let pileCount = 4
    static let oldCount = 3

    static func of(_ all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> StartHeadline {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? now
        let open = all.filter { $0.parent == nil && $0.isOpen }
        // What is due today counts by date, a subtask with its own among it (#565).
        let dated = all.filter { ViewRules.listedByDate($0) && $0.isOpen }
        let timedToday = dated.filter { $0.dueHasTime && ($0.dueDate.map { $0 >= today && $0 < tomorrow } ?? false) }
            .sorted { ($0.dueDate ?? now) < ($1.dueDate ?? now) }
        let ahead = timedToday.filter { ($0.dueDate ?? now) >= now }

        // The week's string speaks first on Sunday evening (#646).
        if let beads = ViewRules.weekToSpeakOf(in: all, now: now, calendar: calendar) {
            return .week(count: beads.count, titles: beads.map { short($0.title) })
        }
        // A, A+: the look back wins once the afternoon has come and something got done.
        let doneToday = completions(in: all, from: today, to: tomorrow)
        if calendar.component(.hour, from: now) >= lookBackHour, !doneToday.isEmpty {
            let soon = ahead.first { ($0.dueDate ?? now) <= now.addingTimeInterval(2 * 3600) }
            let next = soon.map { Upcoming(title: short($0), at: $0.dueDate ?? now) }
            // The Knäuel done today speaks first (#644): it keeps its mark once done.
            if let knaeuel = doneToday.first(where: { $0.knaeuelAt != nil }) {
                return .untangled(title: short(knaeuel), count: doneToday.count, next: next)
            }
            return .doneToday(count: doneToday.count, titles: doneToday.prefix(2).map(short), next: next)
        }
        // 1, 2: time pressure.
        let passed = timedToday.filter { ($0.dueDate ?? now) < now }
        if let missed = passed.last, let at = missed.dueDate {
            return .missed(title: short(missed), at: at, count: passed.count)
        }
        if let first = ahead.first, let at = first.dueDate {
            return .upcoming(title: short(first), at: at, count: ahead.count)
        }
        // 2b: due today, no time of day.
        let dayOnlyToday = dated.filter {
            !$0.isBlocked && !$0.dueHasTime && ($0.dueDate.map { $0 >= today && $0 < tomorrow } ?? false)
        }.sorted { ($0.nextRank ?? .infinity) < ($1.nextRank ?? .infinity) }
        if let first = dayOnlyToday.first {
            return .dueToday(title: short(first), count: dayOnlyToday.count)
        }
        // 3: what needs a new date. A fixed time passed today has spoken as 1 already.
        let leftovers = NewDateRule.tasks(in: all, now: now, calendar: calendar)
        if let oldest = leftovers.first {
            return .needsNewDate(title: short(oldest), count: leftovers.count)
        }
        // 4 to 6: the quiet rungs take turns by day.
        var quiet: [StartHeadline] = []
        var perLabel: [String: Int] = [:]
        for task in open where !task.isBlocked {
            for context in task.contexts ?? [] { perLabel[context.name, default: 0] += 1 }
        }
        if let biggest = perLabel.filter({ $0.value >= pileCount }).max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) {
            quiet.append(.pile(label: biggest.key, count: biggest.value))
        }
        let monthAgo = calendar.date(byAdding: .day, value: -ViewRules.oldAfterDays, to: today) ?? now
        let oldCount = open.filter { ViewRules.openSince($0) < monthAgo }.count
        if oldCount >= Self.oldCount {
            quiet.append(.old(count: oldCount))
        }
        let doneYesterday = completions(in: all, from: yesterday, to: today)
        if !doneYesterday.isEmpty {
            quiet.append(.doneYesterday(count: doneYesterday.count))
        }
        if !quiet.isEmpty {
            let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
            return quiet[day % quiet.count]
        }
        return open.isEmpty ? .allDone : .calm
    }

    /// Everything completed in [from, to), latest first: done tasks by `completedAt`, repeating ones
    /// by their records (they stay open and roll forward).
    private static func completions(in all: [TaskItem], from: Date, to: Date) -> [TaskItem] {
        var hits: [(Date, TaskItem)] = []
        for task in all where task.parent == nil {
            if task.repeatRule != nil {
                for record in task.completions ?? [] where record.completedAt >= from && record.completedAt < to {
                    hits.append((record.completedAt, task))
                }
            } else if task.status == .done, let at = task.completedAt, at >= from, at < to {
                hits.append((at, task))
            }
        }
        return hits.sorted { $0.0 > $1.0 }.map(\.1)
    }

    /// A title short enough to quote: up to `titleLimit` characters as it is, a longer one cut after
    /// the last whole word that fits before " …" (#585). A first word longer than the limit is cut in
    /// the middle, so there is always something to say.
    static func short(_ task: TaskItem) -> String { short(task.displayTitle) }

    static func short(_ title: String) -> String {
        guard title.count > titleLimit else { return title }
        let room = titleLimit - 2
        var cut = ""
        for word in title.split(separator: " ") {
            let next = cut.isEmpty ? String(word) : cut + " " + word
            if next.count > room { break }
            cut = next
        }
        if cut.isEmpty { cut = String(title.prefix(room)) }
        return cut + " …"
    }
}
