import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The evening and morning notifications around the loose ends (#414, #518, #550): in the evening what
/// needs a new date (once its deadline is behind, three evenings after, then Mondays), in the morning an
/// invitation to look at them.
@Suite("CarryReminders") struct CarryRemindersTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Thursday, 12 March 2026, 08:00 in Berlin: before the 9:00 reminder time.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 8))!

    static func day(_ offset: Int, hour: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(day: offset, hour: hour), to: calendar.startOfDay(for: now))!
    }

    @MainActor static func task(_ text: String, due: Date?, hasTime: Bool = false, status: TaskStatus = .active,
                                in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.status = status
        task.dueDate = due
        task.dueHasTime = hasTime
        store.context.insert(task)
        return task
    }

    static func plan(_ tasks: [TaskItem], mode: CarryReminders.Mode = .both, now: Date = now) -> [CarryReminders.Reminder] {
        CarryReminders.plan(for: tasks, mode: mode, now: now, calendar: calendar)
    }

    static func evenings(_ tasks: [TaskItem], now: Date = now) -> [CarryReminders.Reminder] {
        plan(tasks, mode: .evening, now: now)
    }

    static func mornings(_ tasks: [TaskItem], now: Date = now) -> [CarryReminders.Reminder] {
        plan(tasks, mode: .morning, now: now)
    }

    @Test("Morning: every day at the morning time, an invitation only: the count, never what needs a new date (#551)")
    @MainActor func morningInvitation() async throws {
        let store = try TestStore()
        let a = Self.task("Steuerbescheid ablegen", due: Self.day(-1), in: store)
        let b = Self.task("Zahnarzt anrufen", due: Self.day(-1, hour: 14), hasTime: true, in: store)
        let later = Self.task("Reifen wechseln", due: Self.day(5), in: store)
        let undated = Self.task("Fahrradlicht", due: nil, in: store)

        let mornings = Self.mornings([a, b, later, undated])
        #expect(mornings.map(\.fireDate) == (0...CarryReminders.daysAhead).map { Self.day($0, hour: 9) })
        #expect(mornings.allSatisfy { $0.kind == .morning && $0.openCount == 4 })
        #expect(mornings.allSatisfy { $0.taskIDs.isEmpty && $0.titles.isEmpty }, "the number of undated belongs to the evening")
        let first = try #require(mornings.first)
        #expect(first.identifier == "carry_2026-03-12")
        // The icon's number for each morning (#584): the two from yesterday today, the later one from its day on.
        #expect(first.badge == 2)
        #expect(mornings[4].badge == 2)
        #expect(mornings[5].badge == 3)
        #expect(Self.evenings([a, b]).allSatisfy { $0.badge == nil }, "the evening carries no number")
    }

    @Test("Morning counts what one can act on: parked and waiting tasks neither count nor are named (#551)")
    @MainActor func morningCountsActionable() async throws {
        let store = try TestStore()
        let old = Self.task("Fotos sortieren", due: nil, in: store)
        old.capturedAt = Self.day(-40)
        let older = Self.task("Fahrradlicht", due: nil, in: store)
        older.capturedAt = Self.day(-60)
        let fresh = Self.task("Brot", due: nil, in: store)
        fresh.capturedAt = Self.day(-1)
        let parked = Self.task("Keller", due: nil, status: .parked, in: store)
        parked.capturedAt = Self.day(-90)
        let blocker = Self.task("Antwort von Anna", due: nil, in: store)
        blocker.capturedAt = Self.day(-5)
        let waiting = Self.task("Vertrag schicken", due: nil, in: store)
        waiting.capturedAt = Self.day(-80)
        waiting.blockedBy = [blocker]

        let first = try #require(Self.mornings([old, older, fresh, parked, blocker, waiting]).first)
        #expect(first.openCount == 4, "three plain ones and the blocker; not the parked, not the waiting")
        #expect(first.longestOpen == ["Fahrradlicht", "Fotos sortieren"])
        #expect(Self.mornings([]).isEmpty)
        #expect(Self.mornings([parked]).isEmpty, "only parked: nothing to invite to")
    }

    @Test("Longest open: a series counts from its last round, a task with a date ahead is not named (#701)")
    @MainActor func longestOpenReadsTheRoundAndSkipsPlanned() async throws {
        let store = try TestStore()
        let series = Self.task("Fußnagel behandeln", due: Self.day(0, hour: 8), hasTime: true, in: store)
        series.capturedAt = Self.day(-60)
        series.repeatRule = RepeatRule(frequency: .weekly)
        series.completions = [CompletionRecord(task: series, completedAt: Self.day(-7), dueDateAtCompletion: Self.day(-7))]
        let planned = Self.task("FindPinguins Buch erstellen", due: Self.day(3), in: store)
        planned.capturedAt = Self.day(-50)
        let missed = Self.task("Reifen wechseln", due: Self.day(-2), in: store)
        missed.capturedAt = Self.day(-20)
        let plain = Self.task("Fotos sortieren", due: nil, in: store)
        plain.capturedAt = Self.day(-10)

        #expect(ViewRules.openSince(series) == Self.day(-7), "the round, not the series")
        #expect(ViewRules.openSince(plain) == Self.day(-10))
        let first = try #require(Self.mornings([series, planned, missed, plain]).first)
        #expect(first.openCount == 4, "the number stays: every loose end counts")
        #expect(first.longestOpen == ["Reifen wechseln", "Fotos sortieren"],
                "a missed date is loose again (#548); the planned one and this week's round are not the longest")
        #expect(!ViewRules.tasks(for: .old, in: [series], now: Self.now, calendar: Self.calendar).contains { $0.id == series.id },
                "a series done last week is not old")
    }

    @Test("Same minute, one notification: the morning at the reminder time names today's day-only tasks (#551)")
    @MainActor func morningCarriesTodayAtTheReminderTime() async throws {
        let store = try TestStore()
        let hedge = Self.task("Hecke schneiden", due: Self.day(0), in: store)
        let call = Self.task("Zahnarzt anrufen", due: Self.day(0, hour: 14), hasTime: true, in: store)
        let tyres = Self.task("Reifen wechseln", due: Self.day(5), in: store)
        let nine = DueReminders.Time(hour: 9, minute: 0)
        let eight = DueReminders.Time(hour: 8, minute: 0)

        #expect(CarryReminders.mergesReminders(mode: .both, time: nine, reminderTime: nine))
        #expect(!CarryReminders.mergesReminders(mode: .both, time: eight, reminderTime: nine))
        #expect(!CarryReminders.mergesReminders(mode: .evening, time: nine, reminderTime: nine))

        let merged = CarryReminders.plan(for: [hedge, call, tyres], mode: .morning, time: nine, reminderTime: nine,
                                         now: Self.now, calendar: Self.calendar)
        #expect(merged.first?.today == ["Hecke schneiden"], "the timed one keeps its own reminder")
        #expect(merged[5].today == ["Reifen wechseln"])
        #expect(merged[1].today.isEmpty)

        let apart = CarryReminders.plan(for: [hedge, call, tyres], mode: .morning, time: eight, reminderTime: nine,
                                        now: Self.now, calendar: Self.calendar)
        #expect(apart.allSatisfy { $0.today.isEmpty }, "different minutes: both come, each for itself")
    }

    @Test("Evening: due that day, then the three evenings after, then Mondays, until a new date")
    @MainActor func eveningThreeDaysThenMondays() async throws {
        let store = try TestStore()
        let task = Self.task("Hecke schneiden", due: Self.day(0), in: store)

        // Thursday: Thu, Fri, Sat, Sun daily, then Monday the 16th; the 23rd is beyond the plan.
        #expect(Self.evenings([task]).map(\.fireDate) == (0...4).map { Self.day($0, hour: 20) })
        #expect(Self.evenings([task]).allSatisfy { $0.kind == .evening && $0.taskIDs == [task.id] })
    }

    @Test("Evening: an older one comes back on Monday only; a passed evening time skips today")
    @MainActor func eveningOlderAndPassed() async throws {
        let store = try TestStore()
        let yesterday = Self.task("Paket", due: Self.day(-1), in: store)
        let week = Self.task("Keller", due: Self.day(-7), in: store)
        let late = Self.day(0, hour: 21)

        let evenings = Self.evenings([yesterday, week], now: late)
        #expect(evenings.map(\.fireDate) == [Self.day(1, hour: 20), Self.day(2, hour: 20), Self.day(4, hour: 20)])
        #expect(evenings.map(\.taskIDs) == [[yesterday.id], [yesterday.id], [week.id, yesterday.id]])
        #expect(evenings[0].identifier == "carry_evening_2026-03-13")
    }

    @Test("A set evening time is used")
    @MainActor func eveningTime() async throws {
        let store = try TestStore()
        let today = Self.task("Steuer", due: Self.day(0), in: store)
        let early = CarryReminders.plan(for: [today], mode: .evening, eveningTime: DueReminders.Time(hour: 18, minute: 30),
                                        now: Self.now, calendar: Self.calendar)
        #expect(early.first?.fireDate == Self.calendar.date(byAdding: .minute, value: 30, to: Self.day(0, hour: 18)))
    }

    @Test("Done, parked, blocked and undated tasks never need a new date; a subtask does, like a task (#550)")
    @MainActor func notCarried() async throws {
        let store = try TestStore()
        let done = Self.task("Erledigt", due: Self.day(-1), status: .done, in: store)
        let parked = Self.task("Geparkt", due: Self.day(-1), status: .parked, in: store)
        let undated = Self.task("Irgendwann", due: nil, in: store)
        let blocker = Self.task("Antwort", due: nil, in: store)
        let blocked = Self.task("Vertrag", due: Self.day(-1), in: store)
        blocked.blockedBy = [blocker]

        #expect(Self.evenings([done, parked, undated, blocker, blocked]).isEmpty)

        let parent = Self.task("Umzug", due: nil, in: store)
        let sub = Self.task("Kartons", due: Self.day(-1), in: store)
        sub.parent = parent
        let evenings = Self.evenings([parent, sub])
        #expect(evenings.first?.taskIDs == [sub.id], "the subtask needs a new date like a task")
    }

    @Test("Evening: a due time counts after it passed, a later one comes the next evening (#550)")
    @MainActor func eveningAfterTheTime() async throws {
        let store = try TestStore()
        let afternoon = Self.task("Buch erstellen", due: Self.day(0, hour: 15), hasTime: true, in: store)
        let cinema = Self.task("Kino", due: Self.day(0, hour: 22), hasTime: true, in: store)
        let exact = Self.task("Punkt acht", due: Self.day(0, hour: 20), hasTime: true, in: store)

        let evenings = Self.evenings([afternoon, cinema, exact])
        #expect(evenings.first?.fireDate == Self.day(0, hour: 20))
        #expect(evenings.first?.taskIDs == [afternoon.id], "15:00 is behind at 20:00; 22:00 and 20:00 sharp are not")
        #expect(evenings[1].fireDate == Self.day(1, hour: 20))
        #expect(Set(evenings[1].taskIDs) == [afternoon.id, exact.id, cinema.id], "the next evening asks for all three")
    }

    @Test("Evening: a day-only date counts after the reminder time; one later than the evening waits a day (#550)")
    @MainActor func eveningAfterTheReminderTime() async throws {
        let store = try TestStore()
        let hedge = Self.task("Hecke schneiden", due: Self.day(0), in: store)

        let early = CarryReminders.plan(for: [hedge], mode: .evening, reminderTime: DueReminders.Time(hour: 9, minute: 0),
                                        now: Self.now, calendar: Self.calendar)
        #expect(early.first?.fireDate == Self.day(0, hour: 20))
        let late = CarryReminders.plan(for: [hedge], mode: .evening, reminderTime: DueReminders.Time(hour: 21, minute: 0),
                                       now: Self.now, calendar: Self.calendar)
        #expect(late.first?.fireDate == Self.day(1, hour: 20), "21:00 is not behind at 20:00: the next evening")
        #expect(late.map(\.fireDate) == [1, 2, 3, 4].map { Self.day($0, hour: 20) }, "three evenings after, then Monday")
    }

    @Test("Switched off plans nothing; each switch plans only its own")
    @MainActor func switches() async throws {
        let store = try TestStore()
        let task = Self.task("Steuer", due: Self.day(-1), in: store)
        #expect(Self.plan([task], mode: .quiet).isEmpty)
        #expect(Self.plan([task], mode: .morning).allSatisfy { $0.kind == .morning })
        #expect(Self.plan([task], mode: .evening).allSatisfy { $0.kind == .evening })
        #expect(Set(Self.plan([task]).map(\.kind)) == [.morning, .evening])
    }

    @Test("The stored choice falls back to both; the switches map onto it")
    func storedMode() {
        #expect(CarryReminders.Mode(stored: nil) == .both)
        #expect(CarryReminders.Mode(stored: "nonsense") == .both)
        #expect(CarryReminders.Mode(stored: "quiet") == .quiet)
        #expect(CarryReminders.Mode(stored: "evening") == .evening)
        #expect(CarryReminders.Mode(morning: true, evening: false) == .morning)
        #expect(CarryReminders.Mode(morning: false, evening: false) == .quiet)
        #expect(CarryReminders.Mode.both.remindsMorning && CarryReminders.Mode.both.remindsEvening)
    }

    @Test("Today again makes every listed open task due today, as a user revision without a time")
    @MainActor func todayAgain() async throws {
        let store = try TestStore()
        let a = Self.task("Steuer", due: Self.day(-1), in: store)
        let b = Self.task("Anruf", due: Self.day(-2, hour: 14), hasTime: true, in: store)
        let done = Self.task("Fertig", due: Self.day(-1), status: .done, in: store)

        let moved = CarryReminders.handle(.today, taskIDs: [a.id, b.id, done.id, UUID()], in: [a, b, done],
                                          contexts: [], projects: [], now: Self.now, calendar: Self.calendar)
        #expect(moved == 2)
        #expect(a.dueDate == Self.day(0))
        #expect(b.dueDate == Self.day(0))
        #expect(b.dueHasTime == false)
        #expect(done.dueDate == Self.day(-1))
        #expect(ViewRules.postponeCount(a) == 1)
    }

    @Test("Anything from before today stays in Now, Due and the badge until it has a new date (#518, #584, #637)")
    @MainActor func weekOldLeavesNow() async throws {
        let store = try TestStore()
        let seven = Self.task("Sieben Tage", due: Self.day(-7), in: store)
        let eight = Self.task("Acht Tage", due: Self.day(-8), in: store)
        let timed = Self.task("Termin", due: Self.day(-20, hour: 10), hasTime: true, in: store)
        let all = [seven, eight, timed]

        let today = ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        #expect(today.isEmpty)
        #expect(Set(ViewRules.leftovers(in: all, now: Self.now, calendar: Self.calendar).map(\.id)) == [seven.id, eight.id, timed.id])
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 3)
        #expect(ViewRules.now(in: all, now: Self.now, calendar: Self.calendar).all.map(\.id) == [timed.id, eight.id, seven.id],
                "last in Now, the oldest deadline first (#637)")
        #expect(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).contains { $0.id == eight.id })
    }

    @Test("Henning's case: the morning's icon number is the number of rows in Now, 5 (#637, one number everywhere)")
    @MainActor func carryReminderBadgeEqualsNow() async throws {
        let store = try TestStore()
        let paper = Self.task("Altpapier", due: Self.day(-2), in: store)
        paper.nextRank = 1
        let friederich = Self.task("Friederich", due: nil, in: store)
        friederich.nextRank = 2
        let all = [paper, friederich, Self.task("Steuer", due: Self.day(-3), in: store),
                   Self.task("Karte", due: Self.day(-1), in: store), Self.task("Kette", due: Self.day(-4), in: store)]

        let first = try #require(Self.mornings(all).first)
        let rows = ViewRules.now(in: all, now: first.fireDate, calendar: Self.calendar).all.count
        #expect(rows == 5)
        #expect(first.badge == rows)
    }

    @Test("All to tomorrow moves what still needs a date; one given a new date meanwhile stays (#550)")
    @MainActor func allToTomorrow() async throws {
        let store = try TestStore()
        let a = Self.task("Steuer", due: Self.day(0), in: store)
        let b = Self.task("Anruf", due: Self.day(0, hour: 14), hasTime: true, in: store)
        let redated = Self.task("Keller", due: Self.day(5), in: store)
        let evening = Self.day(0, hour: 20)

        #expect(CarryReminders.handle(.review, taskIDs: [a.id], in: [a, b], contexts: [], projects: [],
                                      now: evening, calendar: Self.calendar) == 0)
        #expect(a.dueDate == Self.day(0))

        let moved = CarryReminders.handle(.tomorrow, taskIDs: [a.id, b.id, redated.id], in: [a, b, redated], contexts: [], projects: [],
                                          now: evening, calendar: Self.calendar)
        #expect(moved == 2)
        #expect(a.dueDate == Self.day(1))
        #expect(b.dueDate == Self.day(1))
        #expect(b.dueHasTime == false)
        #expect(redated.dueDate == Self.day(5), "already on next week: an old notification does not pull it back")

        let early = CarryReminders.handle(.tomorrow, taskIDs: [a.id], in: [a], contexts: [], projects: [],
                                          now: Self.day(1, hour: 8), calendar: Self.calendar)
        #expect(early == 0, "tomorrow at 8:00 its day has not reached the reminder time")
    }
}
