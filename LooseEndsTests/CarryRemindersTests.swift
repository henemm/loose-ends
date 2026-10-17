import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The evening and morning notifications around the loose ends (#414, #518): in the evening what needs
/// a new date (its day, three days after, then Mondays), in the morning an invitation to look at them.
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

    @Test("Morning: every day at the reminder time, the loose ends counted and what needs a new date listed")
    @MainActor func morningInvitation() async throws {
        let store = try TestStore()
        let a = Self.task("Steuerbescheid ablegen", due: Self.day(-1), in: store)
        let b = Self.task("Zahnarzt anrufen", due: Self.day(-1, hour: 14), hasTime: true, in: store)
        let later = Self.task("Reifen wechseln", due: Self.day(5), in: store)
        let undated = Self.task("Fahrradlicht", due: nil, in: store)

        let mornings = Self.mornings([a, b, later, undated])
        #expect(mornings.map(\.fireDate) == (0...CarryReminders.daysAhead).map { Self.day($0, hour: 9) })
        #expect(mornings.allSatisfy { $0.kind == .morning && $0.openCount == 4 })
        let first = try #require(mornings.first)
        #expect(Set(first.taskIDs) == [a.id, b.id])
        #expect(first.identifier == "carry_2026-03-12")
        #expect(mornings[6].taskIDs.contains(later.id), "five days on, the tyres need a new date too")
    }

    @Test("Morning without anything to date names the longest open; nothing open, no morning")
    @MainActor func morningLongestOpen() async throws {
        let store = try TestStore()
        let old = Self.task("Fotos sortieren", due: nil, in: store)
        old.capturedAt = Self.day(-40)
        let older = Self.task("Fahrradlicht", due: nil, in: store)
        older.capturedAt = Self.day(-60)
        let fresh = Self.task("Brot", due: nil, in: store)
        fresh.capturedAt = Self.day(-1)

        let first = try #require(Self.mornings([old, older, fresh]).first)
        #expect(first.taskIDs.isEmpty)
        #expect(first.longestOpen == ["Fahrradlicht", "Fotos sortieren"])
        #expect(Self.mornings([]).isEmpty)
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

    @Test("Done, parked, blocked, subtasks and undated tasks never need a new date")
    @MainActor func notCarried() async throws {
        let store = try TestStore()
        let done = Self.task("Erledigt", due: Self.day(-1), status: .done, in: store)
        let parked = Self.task("Geparkt", due: Self.day(-1), status: .parked, in: store)
        let undated = Self.task("Irgendwann", due: nil, in: store)
        let parent = Self.task("Umzug", due: nil, in: store)
        let sub = Self.task("Kartons", due: Self.day(-1), in: store)
        sub.parent = parent

        let all = [done, parked, undated, parent, sub]
        #expect(Self.evenings(all).isEmpty)
        #expect(Self.mornings(all).allSatisfy { $0.taskIDs.isEmpty })
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

    @Test("Anything from before today leaves Now and the badge until it has a new date, not Due (#518)")
    @MainActor func weekOldLeavesNow() async throws {
        let store = try TestStore()
        let seven = Self.task("Sieben Tage", due: Self.day(-7), in: store)
        let eight = Self.task("Acht Tage", due: Self.day(-8), in: store)
        let timed = Self.task("Termin", due: Self.day(-20, hour: 10), hasTime: true, in: store)
        let all = [seven, eight, timed]

        let today = ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        #expect(today.isEmpty)
        #expect(Set(ViewRules.leftovers(in: all, now: Self.now, calendar: Self.calendar).map(\.id)) == [seven.id, eight.id, timed.id])
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 0)
        #expect(ViewRules.now(in: all, now: Self.now, calendar: Self.calendar).all.contains { $0.id == eight.id } == false)
        #expect(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).contains { $0.id == eight.id })
    }

    @Test("All to tomorrow moves every listed open task to tomorrow; Look over changes nothing")
    @MainActor func allToTomorrow() async throws {
        let store = try TestStore()
        let a = Self.task("Steuer", due: Self.day(0), in: store)
        let b = Self.task("Anruf", due: Self.day(0, hour: 14), hasTime: true, in: store)

        #expect(CarryReminders.handle(.review, taskIDs: [a.id], in: [a, b], contexts: [], projects: [],
                                      now: Self.now, calendar: Self.calendar) == 0)
        #expect(a.dueDate == Self.day(0))

        let moved = CarryReminders.handle(.tomorrow, taskIDs: [a.id, b.id], in: [a, b], contexts: [], projects: [],
                                          now: Self.now, calendar: Self.calendar)
        #expect(moved == 2)
        #expect(a.dueDate == Self.day(1))
        #expect(b.dueDate == Self.day(1))
        #expect(b.dueHasTime == false)
    }
}
