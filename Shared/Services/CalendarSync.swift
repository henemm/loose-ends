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
        var isEmpty: Bool { create.isEmpty && update.isEmpty && remove.isEmpty }
    }

    /// What the calendar needs so it matches the tasks: a task wanting an event it does not have,
    /// one that has an event to refresh, one whose event has to go. Nothing else is touched, so
    /// the calendar is never asked for until a task asks for it.
    static func changes(in tasks: [TaskItem], calendar: Calendar = .current) -> Changes {
        var changes = Changes()
        for task in tasks {
            let wanted = plan(for: task, calendar: calendar) != nil
            switch (wanted, task.calendarEventID) {
            case (true, nil): changes.create.append(task)
            case (true, .some): changes.update.append(task)
            case (false, .some): changes.remove.append(task)
            case (false, nil): break
            }
        }
        return changes
    }
}
