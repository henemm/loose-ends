import Foundation

/// The question "Add to calendar" (#203, Teil B): switching the calendar on asks only for what the
/// event still lacks, so nothing is assumed silently. Pure over the model objects; the sheet
/// collects the answer, `apply` writes it, the caller saves.
enum CalendarAsk {
    /// What is missing. A due day without a time is the normal state of a task, so "no time" is a
    /// question (all day or at a time?), not a default.
    struct Gaps: Equatable, Sendable, Identifiable {
        let date: Bool
        let timing: Bool
        let duration: Bool

        var id: String { "\(date)-\(timing)-\(duration)" }
    }

    enum Timing: Equatable, Sendable { case allDay, timed }

    struct Answer: Equatable, Sendable {
        var date: Date?
        var timing: Timing?
        var time: Date?
        var duration: DurationBucket?
    }

    /// Nil when the event has everything: a day, a time and a duration, or nothing to ask.
    static func gaps(for task: TaskItem) -> Gaps? {
        let gaps = Gaps(
            date: task.dueDate == nil,
            timing: !task.dueHasTime,
            duration: task.dueHasTime && task.duration == nil
        )
        return gaps.date || gaps.timing || gaps.duration ? gaps : nil
    }

    /// "Add" stays off until every open question has its answer.
    static func isComplete(_ answer: Answer, for gaps: Gaps) -> Bool {
        if gaps.date, answer.date == nil { return false }
        if gaps.timing {
            switch answer.timing {
            case nil: return false
            case .allDay: return true
            case .timed: return answer.time != nil && answer.duration != nil
            }
        }
        if gaps.duration { return answer.duration != nil }
        return true
    }

    /// Writes the answer as the user's own change (revisions) and switches the calendar on.
    /// An incomplete answer changes nothing.
    static func apply(
        _ answer: Answer,
        gaps: Gaps,
        to task: TaskItem,
        contexts: [TaskContext],
        projects: [Project],
        calendar: Calendar = .current
    ) {
        guard isComplete(answer, for: gaps) else { return }
        let day = calendar.startOfDay(for: task.dueDate ?? answer.date ?? Date())
        if gaps.timing {
            switch answer.timing {
            case .timed:
                let time = calendar.dateComponents([.hour, .minute], from: answer.time ?? day)
                let start = calendar.date(bySettingHour: time.hour ?? 0, minute: time.minute ?? 0, second: 0, of: day) ?? day
                RevisionService.set(.dueDate, to: start.ISO8601Format(), on: task, contexts: contexts, projects: projects)
                task.dueHasTime = true
            case .allDay, nil:
                if gaps.date {
                    RevisionService.set(.dueDate, to: day.ISO8601Format(), on: task, contexts: contexts, projects: projects)
                    task.dueHasTime = false
                }
            }
        }
        if let duration = answer.duration, task.dueHasTime {
            RevisionService.set(.duration, to: duration.rawValue, on: task, contexts: contexts, projects: projects)
        }
        task.showInCalendar = true
    }
}
