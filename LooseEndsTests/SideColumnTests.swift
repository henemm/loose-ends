import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The right column of the wide start page (#473): Quick, recently captured, next days.
@Suite("Start page side column") struct SideColumnTests {
    static var calendar: Calendar { DueTodayTests.calendar }
    static var now: Date { DueTodayTests.now }

    @MainActor private func task(
        _ text: String, duration: DurationBucket? = nil, urgency: Urgency? = nil, captured: Date = SideColumnTests.now,
        due: Date? = nil, store: TestStore
    ) -> TaskItem {
        let item = TaskItem(rawText: text)
        item.status = .active
        item.duration = duration
        item.urgency = urgency
        item.capturedAt = captured
        item.dueDate = due
        store.context.insert(item)
        return item
    }

    @Test("Quick: 15 minutes at most, blocked ones out, urgent first, three at most")
    @MainActor func quick() throws {
        let store = try TestStore()
        let calm = task("Ruhig", duration: .minutes5, store: store)
        let urgent = task("Dringend", duration: .minutes15, urgency: .high, store: store)
        let long = task("Lang", duration: .minutes30, store: store)
        let extra1 = task("Extra eins", duration: .minutes5, store: store)
        let extra2 = task("Extra zwei", duration: .minutes5, store: store)
        let blocker = task("Blocker", store: store)
        let blocked = task("Wartet", duration: .minutes5, store: store)
        blocked.blockedBy = [blocker]
        let result = SideColumn.quick(in: [calm, urgent, long, extra1, extra2, blocked, blocker])
        #expect(result.count == 3)
        #expect(result.first?.rawText == "Dringend")
        #expect(!result.contains { $0.rawText == "Lang" || $0.rawText == "Wartet" })
    }

    @Test("Recently captured: newest first, three at most, done and subtasks out")
    @MainActor func recent() throws {
        let store = try TestStore()
        let old = task("Alt", captured: Self.now.addingTimeInterval(-4 * 86_400), store: store)
        let a = task("A", captured: Self.now.addingTimeInterval(-3 * 86_400), store: store)
        let b = task("B", captured: Self.now.addingTimeInterval(-2 * 86_400), store: store)
        let c = task("C", captured: Self.now.addingTimeInterval(-86_400), store: store)
        let done = task("Fertig", captured: Self.now, store: store)
        done.status = .done
        let sub = task("Unter", captured: Self.now, store: store)
        sub.parent = c
        let result = SideColumn.recent(in: [old, a, b, c, done, sub])
        #expect(result.map(\.rawText) == ["C", "B", "A"])
    }

    @Test("Next days: five tiles, earlier needs a new date first (#518), the day limits are midnight")
    @MainActor func days() throws {
        let store = try TestStore()
        let overdue = task("Überfällig", due: DueTodayTests.day(-2), store: store)
        let tonight = task("Heute Abend", due: DueTodayTests.day(0, hour: 23), store: store)
        let tomorrowStart = task("Morgen früh", due: DueTodayTests.day(1, hour: 0), store: store)
        let tomorrowLate = task("Morgen spät", due: DueTodayTests.day(1, hour: 23), store: store)
        let fourth = task("Vierter Tag", due: DueTodayTests.day(4), store: store)
        let beyond = task("Später", due: DueTodayTests.day(5), store: store)
        let done = task("Fertig", due: DueTodayTests.day(0), store: store)
        done.status = .done
        let days = SideColumn.days(
            in: [overdue, tonight, tomorrowStart, tomorrowLate, fourth, beyond, done], now: Self.now, calendar: Self.calendar
        )
        #expect(days.count == 5)
        #expect(days.map(\.count) == [1, 2, 0, 0, 1])
        #expect(days.map(\.isToday) == [true, false, false, false, false])
    }
}
