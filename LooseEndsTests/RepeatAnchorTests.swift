import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// A new date given for one round does not shift a repeating task's rhythm (#552, Henning 2026-10-18:
/// "Nächster Montag"): the series stands on its anchor, completion counts from there.
@Suite("Repeat anchor (#552)") struct RepeatAnchorTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Monday, 2 March 2026, at the start of the day.
    static let monday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!

    static func day(_ offset: Int, hour: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(day: offset, hour: hour), to: monday)!
    }

    @MainActor static func weekly(in store: TestStore, anchored: Bool = true) -> TaskItem {
        let task = TaskItem(rawText: "Wochenbericht schreiben")
        task.status = .active
        task.dueDate = monday
        var rule = RepeatRule(frequency: .weekly, weekdays: [2])
        if anchored { rule.anchor = monday }
        task.repeatRule = rule
        store.context.insert(task)
        return task
    }

    @Test("Moved to Wednesday and done there: the next round is next Monday, and the anchor moves with it")
    @MainActor func thisRoundOnly() async throws {
        let store = try TestStore()
        let task = Self.weekly(in: store)
        TaskActions.move(task, to: .date(Self.day(2)), contexts: [], projects: [], now: Self.day(0, hour: 20), calendar: Self.calendar)
        #expect(task.dueDate == Self.day(2))
        #expect(task.repeatRule?.anchor == Self.monday, "moving a round leaves the series where it stands")

        TaskActions.complete(task, now: Self.day(2, hour: 10), calendar: Self.calendar)

        #expect(task.dueDate == Self.day(7), "next Monday, not next Wednesday")
        #expect(task.repeatRule?.anchor == Self.day(7))
        #expect(task.status == .active)
    }

    @Test("Moved twice, then done: still the next Monday after the day it was done")
    @MainActor func movedTwice() async throws {
        let store = try TestStore()
        let task = Self.weekly(in: store)
        TaskActions.move(task, to: .date(Self.day(2)), contexts: [], projects: [], now: Self.day(0, hour: 20), calendar: Self.calendar)
        TaskActions.move(task, to: .date(Self.day(9)), contexts: [], projects: [], now: Self.day(2, hour: 20), calendar: Self.calendar)

        TaskActions.complete(task, now: Self.day(9, hour: 10), calendar: Self.calendar)

        #expect(task.dueDate == Self.day(14), "the Monday of the 9th is behind: the one after")
        #expect(task.repeatRule?.anchor == Self.day(14))
    }

    @Test("Counting from completion is untouched: the next round follows the day it was done")
    @MainActor func fromCompletion() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Blumen gießen")
        task.status = .active
        task.dueDate = Self.monday
        task.repeatRule = RepeatRule(frequency: .daily, interval: 3, basis: .fromCompletion, anchor: Self.monday)
        store.context.insert(task)
        TaskActions.move(task, to: .date(Self.day(2)), contexts: [], projects: [], now: Self.day(0, hour: 20), calendar: Self.calendar)

        TaskActions.complete(task, now: Self.day(2, hour: 10), calendar: Self.calendar)

        #expect(task.dueDate == Self.day(5, hour: 10))
    }

    @Test("A rule from before, without an anchor, counts from the due date as it did and gets one")
    @MainActor func legacyRule() async throws {
        let store = try TestStore()
        let task = Self.weekly(in: store, anchored: false)
        #expect(task.repeatRule?.anchor == nil)

        TaskActions.complete(task, now: Self.day(0, hour: 10), calendar: Self.calendar)

        #expect(task.dueDate == Self.day(7))
        #expect(task.repeatRule?.anchor == Self.day(7))
    }

    @Test("A rule with a time keeps it across a round moved without one")
    @MainActor func keepsTheTime() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Montags um 7 Tabletten bestellen")
        task.status = .active
        task.dueDate = Self.day(0, hour: 7)
        task.dueHasTime = true
        task.repeatRule = RepeatRule(frequency: .weekly, weekdays: [2], hour: 7, minute: 0, anchor: Self.day(0, hour: 7))
        store.context.insert(task)
        TaskActions.move(task, to: .tomorrow, contexts: [], projects: [], now: Self.day(0, hour: 20), calendar: Self.calendar)
        #expect(task.dueHasTime == false)

        TaskActions.complete(task, now: Self.day(1, hour: 12), calendar: Self.calendar)

        #expect(task.dueDate == Self.day(7, hour: 7), "the anchor carries the 7:00")
        #expect(task.dueHasTime == true)
    }

    @Test("The anchor rides in the encoding only when set, so old rules encode as before")
    func encoding() throws {
        let plain = RepeatRule(frequency: .daily)
        let encoded = try #require(FieldCodec.encode(plain))
        #expect(!encoded.contains("anchor"))
        #expect(FieldCodec.decodeRepeat(encoded) == plain)

        let anchored = RepeatRule(frequency: .weekly, weekdays: [2], anchor: Self.monday)
        let round = FieldCodec.decodeRepeat(FieldCodec.encode(anchored))
        #expect(round?.anchor == Self.monday)
    }
}
