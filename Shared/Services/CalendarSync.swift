import Foundation

/// "Show in calendar" (ADR-13): a task with a due date and the switch on is one event in the
/// app's own calendar. Pure planning over the model objects; `CalendarBridge` talks to EventKit.
enum CalendarSync {
    static let calendarTitle = "Loose Ends"

    struct EventPlan: Equatable {
        let title: String
        let start: Date
        let end: Date
        let isAllDay: Bool
        let notes: String?
    }

    /// Nil when the task has no place in the calendar: switch off, no due date, or no longer open.
    /// A due time gives a block as long as the duration says; a bare day gives an all-day event.
    static func plan(for task: TaskItem, calendar: Calendar = .current) -> EventPlan? {
        guard task.showInCalendar, task.isOpen, let due = task.dueDate else { return nil }
        let notes = task.rawText == task.displayTitle ? nil : task.rawText
        if task.dueHasTime {
            let end = due.addingTimeInterval(Double(length(of: task.duration)) * 60)
            return EventPlan(title: task.displayTitle, start: due, end: end, isAllDay: false, notes: notes)
        }
        let day = calendar.startOfDay(for: due)
        let next = calendar.date(byAdding: .day, value: 1, to: day) ?? day.addingTimeInterval(86_400)
        return EventPlan(title: task.displayTitle, start: day, end: next, isAllDay: true, notes: notes)
    }

    /// "14:00–15:00" in the reader's own time format.
    static func timeRange(start: Date, end: Date) -> String {
        "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }

    /// The line under the switch: the day, then the block or "all day" ("Tue, Oct 6 · 14:00–15:00").
    static func appointment(_ plan: EventPlan) -> String {
        let day = plan.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let when = plan.isAllDay ? String(localized: "all day") : timeRange(start: plan.start, end: plan.end)
        return "\(day) · \(when)"
    }

    /// Minutes of the block. Nothing shorter than a quarter hour, an hour when nothing is known.
    static func length(of duration: DurationBucket?) -> Int {
        switch duration {
        case .minutes5, .minutes15: 15
        case .minutes30: 30
        case .hour1, nil: 60
        case .hours2plus: 120
        }
    }

    struct Changes {
        var create: [TaskItem] = []
        var update: [TaskItem] = []
        var remove: [TaskItem] = []
        /// Event ids that belong to no task at all any more (#122): the task was deleted outright,
        /// so there is no `TaskItem` left to carry the id or to clear it from.
        var removeOrphaned: [String] = []
        var isEmpty: Bool { create.isEmpty && update.isEmpty && remove.isEmpty && removeOrphaned.isEmpty }
    }

    /// What the calendar needs so it matches the tasks: a task wanting an event it does not have,
    /// one that has an event to refresh, one whose event has to go, or one nobody's task claims any
    /// more. Nothing else is touched, so the calendar is never asked for until a task asks for it —
    /// `knownEventIDs` (the app's own calendar, read only once access is already established) is
    /// how a deleted task's leftover event is still found without keeping a history of ids.
    static func changes(in tasks: [TaskItem], knownEventIDs: Set<String> = [], calendar: Calendar = .current) -> Changes {
        var changes = Changes()
        var accountedFor: Set<String> = []
        for task in tasks {
            let wanted = plan(for: task, calendar: calendar) != nil
            switch (wanted, task.calendarEventID) {
            case (true, nil): changes.create.append(task)
            case (true, .some(let id)): changes.update.append(task); accountedFor.insert(id)
            case (false, .some(let id)): changes.remove.append(task); accountedFor.insert(id)
            case (false, nil): break
            }
        }
        changes.removeOrphaned = knownEventIDs.subtracting(accountedFor).sorted()
        return changes
    }

    // MARK: Where the app's own calendar is created (#203)

    struct SourceCandidate: Equatable {
        enum Kind { case calDAV, local, exchange, subscribed, birthdays, other }
        let id: String
        let title: String
        let kind: Kind
    }

    /// The accounts to try, in order, when the app's calendar does not exist yet: iCloud, the
    /// device itself, the default calendar's account, then any other CalDAV account. Google is
    /// CalDAV too and refuses new calendars from apps, so a Google default must not come before
    /// iCloud (#203). Exchange, subscriptions and birthdays are never tried.
    static func sourceOrder(_ sources: [SourceCandidate], defaultSourceID: String?) -> [String] {
        let usable = sources.filter { $0.kind == .calDAV || $0.kind == .local }
        let iCloud = usable.filter { $0.kind == .calDAV && $0.title == "iCloud" }
        let local = usable.filter { $0.kind == .local }
        let fallback = usable.filter { $0.id == defaultSourceID }
        let others = usable.filter { $0.kind == .calDAV }
        var seen: Set<String> = []
        return (iCloud + local + fallback + others).map(\.id).filter { seen.insert($0).inserted }
    }

    /// What went wrong on the last sync, as `CalendarBridge` saw it.
    enum Problem: Equatable { case accessDenied, noWritableSource, syncFailed }

    /// The note under the switch.
    enum Note: Equatable { case needsDueDate, accessOff, noWritableSource, syncFailed }

    /// Why nothing shows in the calendar, or nil while the switch is off or all is well.
    static func note(for task: TaskItem, problem: Problem?) -> Note? {
        guard task.showInCalendar else { return nil }
        guard task.dueDate != nil else { return .needsDueDate }
        switch problem {
        case .accessDenied: return .accessOff
        case .noWritableSource: return .noWritableSource
        case .syncFailed: return .syncFailed
        case nil: return nil
        }
    }
}
