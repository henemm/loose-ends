import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("Model") struct ModelTests {
    @Test("A captured task round-trips through the store as unprocessed")
    func roundTrip() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        context.insert(TaskItem(rawText: "Rasenmäher Ölwechsel am Wochenende", capturedVia: .siri))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<TaskItem>())
        let task = try #require(fetched.first)
        #expect(fetched.count == 1)
        #expect(task.status == .unprocessed)
        #expect(task.displayTitle == "Rasenmäher Ölwechsel am Wochenende")
        #expect(task.capturedVia == .siri)
    }

    @Test("Blocked tasks stay out of Next up and show up in Waiting")
    func blockedHiddenFromNext() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        let blocker = TaskItem(rawText: "Heckenschere holen")
        blocker.status = .active
        let blocked = TaskItem(rawText: "Hecke schneiden")
        blocked.status = .active
        blocked.nextRank = 1
        context.insert(blocker)
        context.insert(blocked)
        blocked.blockedBy = [blocker]
        try context.save()

        let all = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(ViewRules.tasks(for: .next, in: all).isEmpty)
        #expect(ViewRules.tasks(for: .waiting, in: all).map(\.rawText) == ["Hecke schneiden"])
    }
}

@Suite("RepeatRule") struct RepeatRuleTests {
    @Test("Weekly on Saturday from due date rolls to the next Saturday")
    func weeklySaturday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        let saturday = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 19)))
        let rule = RepeatRule(frequency: .weekly, interval: 1, weekdays: [7], basis: .fromDueDate)
        let next = rule.nextDueDate(previousDue: saturday, completedOn: saturday, calendar: calendar)
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 26)))
        #expect(calendar.isDate(next, inSameDayAs: expected))
    }

    @Test("Monthly from completion anchors on the completion date")
    func monthlyFromCompletion() throws {
        let calendar = Calendar(identifier: .gregorian)
        let due = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)))
        let done = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 14)))
        let rule = RepeatRule(frequency: .monthly, basis: .fromCompletion)
        let next = rule.nextDueDate(previousDue: due, completedOn: done, calendar: calendar)
        #expect(calendar.component(.month, from: next) == 10)
        #expect(calendar.component(.day, from: next) == 14)
    }
}
