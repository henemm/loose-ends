import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// "Das Knäuel" (#643): one open task marked by hand, a user revision per change, the mark falls with
/// Done, Park, Restore and Delete, and the start screen's "Now" does not show it again.
@Suite("Das Knäuel (#643)") struct KnaeuelTests {
    static func task(_ text: String) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.status = .active
        return task
    }

    @Test("Setting the Knäuel writes a user revision; a second task takes the mark off the first, with a revision on each")
    @MainActor func setAndMove() async throws {
        let store = try TestStore()
        let steuer = Self.task("Steuerberater anrufen")
        let hecke = Self.task("Hecke schneiden")
        store.context.insert(steuer)
        store.context.insert(hecke)
        let at = Date()

        let previous = TaskActions.setKnaeuel(steuer, among: [steuer, hecke], contexts: [], projects: [], now: at)
        try store.context.save()
        #expect(previous == nil)
        #expect(steuer.knaeuelAt?.ISO8601Format() == at.ISO8601Format(), "the codec keeps whole seconds")
        #expect(steuer.isKnaeuel)
        #expect(ViewRules.knaeuel(in: [steuer, hecke])?.id == steuer.id)
        let first = try #require(steuer.revisions?.first)
        #expect(first.field == .knaeuel)
        #expect(first.author == .user)
        #expect(first.oldValue == nil)
        #expect(first.newValue == at.ISO8601Format())

        let from = TaskActions.setKnaeuel(hecke, among: [steuer, hecke], contexts: [], projects: [])
        try store.context.save()
        #expect(from?.id == steuer.id)
        #expect(steuer.knaeuelAt == nil)
        #expect(hecke.isKnaeuel)
        #expect(ViewRules.knaeuel(in: [steuer, hecke])?.id == hecke.id)
        #expect(steuer.revisions?.count == 2, "the release is a revision too")
        #expect(steuer.revisions?.last?.newValue == nil)

        // The same task again changes nothing.
        let again = TaskActions.setKnaeuel(hecke, among: [steuer, hecke], contexts: [], projects: [])
        #expect(again == nil)
        #expect(hecke.revisions?.count == 1)
    }

    @Test("Release takes the mark and writes a revision; Park and Restore do the same, Done keeps it on the done task")
    @MainActor func releaseParkDone() async throws {
        let store = try TestStore()
        let task = Self.task("Keller aufräumen")
        store.context.insert(task)
        TaskActions.setKnaeuel(task, among: [task], contexts: [], projects: [])

        TaskActions.releaseKnaeuel(task, contexts: [], projects: [])
        #expect(task.knaeuelAt == nil)
        #expect(task.revisions?.count == 2)

        TaskActions.setKnaeuel(task, among: [task], contexts: [], projects: [])
        TaskActions.park(task)
        #expect(task.knaeuelAt == nil, "a parked task is not the one being avoided")
        #expect(task.revisions?.last?.field == .knaeuel)

        TaskActions.activate(task)
        TaskActions.setKnaeuel(task, among: [task], contexts: [], projects: [])
        TaskActions.complete(task)
        #expect(task.knaeuelAt != nil, "the week's string still reads the mark")
        #expect(!task.isKnaeuel)
        #expect(ViewRules.knaeuel(in: [task]) == nil)
        #expect(task.counts, "the Knäuel always counts")

        TaskActions.restore(task)
        #expect(task.knaeuelAt == nil, "the mark does not come back with the task")
        try store.context.save()
    }

    @Test("Delete takes the mark too: a task with subtasks is only marked removed")
    @MainActor func deleteWithSubtasks() async throws {
        let store = try TestStore()
        let task = Self.task("Umzug planen")
        let line = TaskItem(rawText: "Kartons besorgen")
        store.context.insert(task)
        store.context.insert(line)
        line.parent = task
        TaskActions.setKnaeuel(task, among: [task], contexts: [], projects: [])
        try store.context.save()

        try TaskActions.delete(task, in: store.context)
        #expect(task.status == .removed)
        #expect(task.knaeuelAt == nil)
        #expect(ViewRules.knaeuel(in: [task, line]) == nil)
    }

    @Test("Now leaves the Knäuel out: it stands under the date; the badge still counts it")
    @MainActor func nowLeavesItOut() async throws {
        let store = try TestStore()
        let knaeuel = Self.task("Steuerberater anrufen")
        knaeuel.nextRank = 1
        let other = Self.task("Mama zurückrufen")
        other.nextRank = 2
        store.context.insert(knaeuel)
        store.context.insert(other)
        TaskActions.setKnaeuel(knaeuel, among: [knaeuel, other], contexts: [], projects: [])

        #expect(ViewRules.now(in: [knaeuel, other]).all.map(\.id) == [other.id])
        #expect(ViewRules.badgeCount(in: [knaeuel, other]) == 2)
        #expect(ViewRules.tasks(for: .next, in: [knaeuel, other]).map(\.id) == [knaeuel.id, other.id])
    }

    @Test("Two marks after a sync: the latest wins, on every device alike; a subtask never is the Knäuel")
    @MainActor func latestWins() async throws {
        let store = try TestStore()
        let older = Self.task("Fenster putzen")
        let newer = Self.task("Dachrinne reinigen")
        let line = TaskItem(rawText: "Leiter holen")
        store.context.insert(older)
        store.context.insert(newer)
        store.context.insert(line)
        line.parent = newer
        line.status = .active
        older.knaeuelAt = Date(timeIntervalSinceNow: -100)
        newer.knaeuelAt = Date()
        line.knaeuelAt = Date(timeIntervalSinceNow: 100)

        #expect(ViewRules.knaeuel(in: [older, newer, line])?.id == newer.id)
    }

    @Test("The field round-trips through the codec and is off in the standard settings")
    @MainActor func codecAndSettings() async throws {
        let store = try TestStore()
        let task = Self.task("Garage ausmisten")
        store.context.insert(task)
        let at = Date()
        #expect(FieldCodec.encode(.knaeuel, of: task) == nil)
        FieldCodec.apply(at.ISO8601Format(), to: .knaeuel, of: task, as: .user, contexts: [], projects: [])
        #expect(task.knaeuelAt?.ISO8601Format() == at.ISO8601Format())
        FieldCodec.apply(nil, to: .knaeuel, of: task, as: .user, contexts: [], projects: [])
        #expect(task.knaeuelAt == nil)
        #expect(!DetailFieldSettings.standard.isOn(.knaeuel))
        #expect(DetailField.knaeuel.topLevelOnly)
        #expect(DetailField(revised: .knaeuel) == .knaeuel)
    }

    @Test("Since: today, yesterday, N days, counted by day")
    func since() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 23, hour: 9)))
        let lastNight = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 23)))
        let elevenDays = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 15)))
        #expect(KnaeuelSince.days(from: now, now: now, calendar: calendar) == 0)
        #expect(KnaeuelSince.days(from: lastNight, now: now, calendar: calendar) == 1)
        #expect(KnaeuelSince.days(from: elevenDays, now: now, calendar: calendar) == 11)
        #expect(KnaeuelSince.days(from: now.addingTimeInterval(86_400), now: now, calendar: calendar) == 0, "never negative")
    }

    @Test("The Knäuel's curve is the canvas drawing: starts at the left, ends at the flat tail on the right, inside 40 × 20")
    func curve() {
        let points = ThreadShape.curvePoints(form: .knaeuel)
        #expect(points.first == ThreadShape.knaeuelStart)
        #expect(points.last == CGPoint(x: 26, y: 11))
        #expect(points.count == 1 + 6 * 24)
        #expect(points.allSatisfy { (0...40).contains($0.x) && (0...20).contains($0.y) })
        let path = ThreadShape(form: .knaeuel).path(in: CGRect(x: 0, y: 0, width: 36, height: 18))
        #expect(!path.isEmpty)
    }
}

/// "Zählt" and the week's string (#645): a mark by hand with a budget of five open, the beads read
/// from the completions of the week, Monday to Sunday.
@Suite("Perlen (#645)") struct BeadsTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        // The locale's first weekday must not matter: the week runs Monday to Sunday regardless.
        calendar.firstWeekday = 1
        return calendar
    }

    /// Thursday, 22 October 2026, 10:00 in Berlin.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 10))!

    static func date(_ day: Int, _ month: Int = 10, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test("Counts is a user revision; the budget is five open tasks; the sixth cannot be set; taking the mark frees a place")
    @MainActor func budget() async throws {
        let store = try TestStore()
        let tasks = (1...6).map { KnaeuelTests.task("Aufgabe \($0)") }
        tasks.forEach(store.context.insert)

        for task in tasks.prefix(5) {
            #expect(TaskActions.canCount(task, among: tasks))
            TaskActions.toggleCounts(task, among: tasks, contexts: [], projects: [])
            #expect(task.countsAt != nil)
            #expect(task.revisions?.first?.field == .counts)
            #expect(task.revisions?.first?.author == .user)
        }
        #expect(ViewRules.counting(in: tasks).count == 5)
        let sixth = tasks[5]
        #expect(!TaskActions.canCount(sixth, among: tasks))
        TaskActions.toggleCounts(sixth, among: tasks, contexts: [], projects: [])
        #expect(sixth.countsAt == nil, "over the budget nothing changes")
        #expect(sixth.revisions?.isEmpty ?? true)

        // A counting task that is already marked can always be unmarked.
        #expect(TaskActions.canCount(tasks[0], among: tasks))
        TaskActions.toggleCounts(tasks[0], among: tasks, contexts: [], projects: [])
        #expect(tasks[0].countsAt == nil)
        #expect(tasks[0].revisions?.count == 2)
        #expect(TaskActions.canCount(sixth, among: tasks))

        // Done tasks leave the budget; the Knäuel is not in it.
        TaskActions.toggleCounts(sixth, among: tasks, contexts: [], projects: [])
        TaskActions.complete(tasks[1])
        #expect(ViewRules.counting(in: tasks).count == 4)
        let knaeuel = KnaeuelTests.task("Steuer")
        store.context.insert(knaeuel)
        TaskActions.setKnaeuel(knaeuel, among: tasks + [knaeuel], contexts: [], projects: [])
        #expect(knaeuel.counts)
        #expect(ViewRules.counting(in: tasks + [knaeuel]).count == 4)
        try store.context.save()
    }

    @Test("The week runs Monday to Sunday whatever the locale's first weekday")
    func week() {
        let week = ViewRules.week(containing: Self.now, calendar: Self.calendar)
        #expect(week.lowerBound == Self.calendar.startOfDay(for: Self.date(19)), "Monday, 19 October")
        #expect(week.upperBound == Self.calendar.startOfDay(for: Self.date(26)), "Monday, 26 October")
        let sunday = Self.date(25, hour: 23)
        #expect(ViewRules.week(containing: sunday, calendar: Self.calendar) == week)
        let monday = Self.date(26, hour: 0)
        #expect(ViewRules.week(containing: monday, calendar: Self.calendar).lowerBound == week.upperBound)
    }

    @Test("The beads: completions of counting tasks in the week, oldest first; the Knäuel among them; last week's stay out; a repeating task once per record")
    @MainActor func beads() async throws {
        let store = try TestStore()
        let counting = KnaeuelTests.task("Hecke schneiden")
        counting.countsAt = Self.date(19)
        let knaeuel = KnaeuelTests.task("Steuerberater anrufen")
        knaeuel.knaeuelAt = Self.date(12)
        let plain = KnaeuelTests.task("Mama zurückrufen")
        let lastWeek = KnaeuelTests.task("Fenster putzen")
        lastWeek.countsAt = Self.date(10)
        let repeating = KnaeuelTests.task("Rasen mähen")
        repeating.countsAt = Self.date(1)
        repeating.repeatRule = RepeatRule(frequency: .weekly, weekdays: [3])
        repeating.dueDate = Self.date(20)
        let open = KnaeuelTests.task("Keller aufräumen")
        open.countsAt = Self.date(20)
        let all = [counting, knaeuel, plain, lastWeek, repeating, open]
        all.forEach(store.context.insert)

        TaskActions.complete(counting, now: Self.date(21, hour: 18))
        TaskActions.complete(knaeuel, now: Self.date(22, hour: 9))
        TaskActions.complete(plain, now: Self.date(22, hour: 8))
        TaskActions.complete(lastWeek, now: Self.date(17))
        TaskActions.complete(repeating, now: Self.date(20, hour: 7), calendar: Self.calendar)
        TaskActions.complete(repeating, now: Self.date(13, hour: 7), calendar: Self.calendar)
        try store.context.save()

        let beads = ViewRules.weekBeads(in: all, now: Self.now, calendar: Self.calendar)
        #expect(beads.map(\.title) == ["Rasen mähen", "Hecke schneiden", "Steuerberater anrufen"])
        #expect(beads.map(\.isKnaeuel) == [false, false, true])
        #expect(beads[2].at == Self.date(22, hour: 9))
        #expect(Set(beads.map(\.id)).count == 3)

        // Next week starts empty; last week keeps its beads.
        #expect(ViewRules.weekBeads(in: all, now: Self.date(26), calendar: Self.calendar).isEmpty)
        #expect(ViewRules.weekBeads(in: all, now: Self.date(15), calendar: Self.calendar).map(\.title) == ["Rasen mähen", "Fenster putzen"])
    }

    @Test("The beads sit from the left at 40 pt apart on the sagging string, closer only once the string is full")
    func centers() {
        #expect(WeekString.centers(count: 0, width: 350).isEmpty)
        let three = WeekString.centers(count: 3, width: 350)
        #expect(three.map(\.x) == [40, 80, 120])
        #expect(three.allSatisfy { $0.y > 14 && $0.y <= 20 }, "on the curve, below the ends")
        let many = WeekString.centers(count: 12, width: 350)
        #expect(many.count == 12)
        #expect((many.last?.x ?? 0) <= 350 - 10 - 6 + 0.01)
        #expect(many[1].x - many[0].x < 40)
    }
}
