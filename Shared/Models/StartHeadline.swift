import Foundation

/// The big line above "Now" on the iPhone start screen (#426, Henning 2026-10-15): each day the one
/// fact that stands out, from 16:00 a look back at what got done. Pure over the tasks and the clock;
/// the words live in the app (`StartHeadlineText`). No model: every rung is a count or a date.
enum StartHeadline: Equatable {
    /// A, A+: from 16:00 with something done today. Titles are the latest first, at most two;
    /// `next` is a fixed time within the next two hours.
    case doneToday(count: Int, titles: [String?], next: Upcoming?)
    /// 1: a fixed time today has passed.
    case missed(title: String?, at: Date)
    /// 2: fixed times still ahead today; `at` is the first.
    case upcoming(title: String?, at: Date, count: Int)
    /// 2b: tasks due today without a time (Henning, 2026-10-16): the day-only date is today's fact.
    case dueToday(title: String?, count: Int)
    /// 3: a day-only date carried for days.
    case waiting(title: String?, days: Int)
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
        let title: String?
        let at: Date
    }

    static let lookBackHour = 16
    static let titleLimit = 32
    static let waitingDays = 2
    static let pileCount = 4
    static let oldCount = 3

    static func of(_ all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> StartHeadline {
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? now
        let open = all.filter { $0.parent == nil && $0.isOpen }
        let timedToday = open.filter { $0.dueHasTime && ($0.dueDate.map { $0 >= today && $0 < tomorrow } ?? false) }
            .sorted { ($0.dueDate ?? now) < ($1.dueDate ?? now) }
        let ahead = timedToday.filter { ($0.dueDate ?? now) >= now }

        // A, A+: the look back wins once the afternoon has come and something got done.
        let doneToday = completions(in: all, from: today, to: tomorrow)
        if calendar.component(.hour, from: now) >= lookBackHour, !doneToday.isEmpty {
            let soon = ahead.first { ($0.dueDate ?? now) <= now.addingTimeInterval(2 * 3600) }
            return .doneToday(count: doneToday.count, titles: doneToday.prefix(2).map(short),
                              next: soon.map { Upcoming(title: short($0), at: $0.dueDate ?? now) })
        }
        // 1, 2: time pressure.
        if let missed = timedToday.last(where: { ($0.dueDate ?? now) < now }), let at = missed.dueDate {
            return .missed(title: short(missed), at: at)
        }
        if let first = ahead.first, let at = first.dueDate {
            return .upcoming(title: short(first), at: at, count: ahead.count)
        }
        // 2b: due today, no time of day.
        let dayOnlyToday = open.filter {
            !$0.isBlocked && !$0.dueHasTime && ($0.dueDate.map { $0 >= today && $0 < tomorrow } ?? false)
        }.sorted { ($0.nextRank ?? .infinity) < ($1.nextRank ?? .infinity) }
        if let first = dayOnlyToday.first {
            return .dueToday(title: dayOnlyToday.count == 1 ? short(first) : nil, count: dayOnlyToday.count)
        }
        // 3 to 6: the quiet rungs take turns by day.
        var quiet: [StartHeadline] = []
        let carried = open.compactMap { task -> (TaskItem, Int)? in
            if case .carried(let days) = ViewRules.dueState(of: task, now: now, calendar: calendar), days >= waitingDays {
                return (task, days)
            }
            return nil
        }
        if let longest = carried.max(by: { $0.1 < $1.1 }) {
            quiet.append(.waiting(title: short(longest.0), days: longest.1))
        }
        var perLabel: [String: Int] = [:]
        for task in open where !task.isBlocked {
            for context in task.contexts ?? [] { perLabel[context.name, default: 0] += 1 }
        }
        if let biggest = perLabel.filter({ $0.value >= pileCount }).max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) {
            quiet.append(.pile(label: biggest.key, count: biggest.value))
        }
        let monthAgo = calendar.date(byAdding: .day, value: -ViewRules.oldAfterDays, to: today) ?? now
        let oldCount = open.filter { $0.capturedAt < monthAgo }.count
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

    /// A title short enough to quote; a longer one is left out of the sentence.
    private static func short(_ task: TaskItem) -> String? {
        let title = task.displayTitle
        return title.count <= titleLimit ? title : nil
    }
}
