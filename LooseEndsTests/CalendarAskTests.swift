import Foundation
import Testing
@testable import LooseEnds

/// "Add to calendar" asks only for what the event lacks, and writes the answer as the user's own
/// change (#203, Teil B).
@Suite("CalendarAsk (#203)") struct CalendarAskTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        return calendar
    }

    private func day(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day)) ?? Date()
    }

    private func time(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: hour, minute: minute)) ?? Date()
    }

    private func makeTask(due: Date? = nil, hasTime: Bool = false, duration: DurationBucket? = nil) -> TaskItem {
        let task = TaskItem(rawText: "Zahnarzt")
        task.status = .active
        task.dueDate = due
        task.dueHasTime = hasTime
        task.duration = duration
        return task
    }

    @Test("Nothing set: date, time kind and no duration yet; a day without time: time kind only; a time without duration: duration only; all set: no question")
    func gaps() {
        #expect(CalendarAsk.gaps(for: makeTask()) == .init(date: true, timing: true, duration: false))
        #expect(CalendarAsk.gaps(for: makeTask(due: day(8))) == .init(date: false, timing: true, duration: false))
        #expect(CalendarAsk.gaps(for: makeTask(due: day(8), hasTime: true)) == .init(date: false, timing: false, duration: true))
        #expect(CalendarAsk.gaps(for: makeTask(due: day(8), hasTime: true, duration: .hour1)) == nil)
    }

    @Test("Add stays off until every open question is answered")
    func completeness() {
        let all = CalendarAsk.Gaps(date: true, timing: true, duration: false)
        #expect(!CalendarAsk.isComplete(.init(), for: all))
        #expect(!CalendarAsk.isComplete(.init(date: day(8)), for: all))
        #expect(CalendarAsk.isComplete(.init(date: day(8), timing: .allDay), for: all))
        #expect(!CalendarAsk.isComplete(.init(date: day(8), timing: .timed, time: time(hour: 14)), for: all))
        #expect(CalendarAsk.isComplete(.init(date: day(8), timing: .timed, time: time(hour: 14), duration: .hour1), for: all))

        let durationOnly = CalendarAsk.Gaps(date: false, timing: false, duration: true)
        #expect(!CalendarAsk.isComplete(.init(), for: durationOnly))
        #expect(CalendarAsk.isComplete(.init(duration: .minutes30), for: durationOnly))
    }

    @Test("A time and a duration become the user's own revisions and switch the calendar on")
    @MainActor func appliesTimed() throws {
        let store = try TestStore()
        let task = makeTask()
        store.context.insert(task)
        let gaps = try #require(CalendarAsk.gaps(for: task))

        CalendarAsk.apply(.init(date: day(8), timing: .timed, time: time(hour: 14, minute: 30), duration: .hour1),
                          gaps: gaps, to: task, contexts: [], projects: [], calendar: calendar)

        #expect(task.showInCalendar)
        #expect(task.dueHasTime)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: try #require(task.dueDate))
        #expect(components.year == 2026 && components.month == 10 && components.day == 8)
        #expect(components.hour == 14 && components.minute == 30)
        #expect(task.duration == .hour1)
        let fields = Set((task.revisions ?? []).map(\.field))
        #expect(fields == [.dueDate, .duration])
        #expect((task.revisions ?? []).allSatisfy { $0.author == .user })
    }

    @Test("All day sets only a missing day and keeps an existing one as it is")
    @MainActor func appliesAllDay() throws {
        let store = try TestStore()
        let fresh = makeTask()
        let dated = makeTask(due: day(9))
        store.context.insert(fresh)
        store.context.insert(dated)

        for task in [fresh, dated] {
            let gaps = try #require(CalendarAsk.gaps(for: task))
            CalendarAsk.apply(.init(date: day(8), timing: .allDay), gaps: gaps, to: task, contexts: [], projects: [], calendar: calendar)
        }

        #expect(fresh.showInCalendar && !fresh.dueHasTime)
        #expect(fresh.dueDate == day(8))
        #expect(dated.showInCalendar && !dated.dueHasTime)
        #expect(dated.dueDate == day(9))
        #expect((dated.revisions ?? []).isEmpty)
        #expect(fresh.duration == nil)
    }

    @Test("A time that is already set only asks for the duration, and keeps the time")
    @MainActor func appliesDurationOnly() throws {
        let store = try TestStore()
        let start = calendar.date(from: DateComponents(year: 2026, month: 10, day: 8, hour: 14)) ?? Date()
        let task = makeTask(due: start, hasTime: true)
        store.context.insert(task)
        let gaps = try #require(CalendarAsk.gaps(for: task))

        CalendarAsk.apply(.init(duration: .minutes30), gaps: gaps, to: task, contexts: [], projects: [], calendar: calendar)

        #expect(task.showInCalendar && task.dueHasTime)
        #expect(task.dueDate == start)
        #expect(task.duration == .minutes30)
        #expect(Set((task.revisions ?? []).map(\.field)) == [.duration])
    }

    @Test("An incomplete answer changes nothing")
    @MainActor func incompleteChangesNothing() throws {
        let store = try TestStore()
        let task = makeTask()
        store.context.insert(task)
        let gaps = try #require(CalendarAsk.gaps(for: task))

        CalendarAsk.apply(.init(date: day(8), timing: .timed, time: time(hour: 14)), gaps: gaps, to: task, contexts: [], projects: [], calendar: calendar)

        #expect(!task.showInCalendar)
        #expect(task.dueDate == nil)
        #expect((task.revisions ?? []).isEmpty)
    }
}
