import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// "Ergänzen" (#441): a sentence on an existing task, read by the rules, written as user revisions.
@Suite("Supplement") struct SupplementTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Thursday, 15 October 2026, 10:00 in Berlin.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 10))!
    static let catalog = ["Computer", "Telefon", "Haus", "Garten", "Besorgung", "Unterwegs"]

    static func read(_ text: String, current: [String] = []) -> Supplement {
        Supplement.read(text, available: catalog, current: current, reference: now, calendar: calendar)
    }

    @Test("Due date with time, duration, urgency and context from one sentence")
    func readsAll() throws {
        let read = Self.read("morgen um 15 Uhr dringend, dauert 20 Minuten, Gärtner anrufen")
        let due = try #require(read.due)
        #expect(due.hasTime)
        #expect(due.guess.value == Self.calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 15)))
        #expect(read.duration == .minutes30)
        #expect(read.urgency == .high)
        #expect(read.importance == nil)
        #expect(read.contexts == ["Telefon"])
        #expect(read.rest == "dauert Gärtner")
    }

    @Test("Nothing read: everything stays as rest, nothing is guessed")
    func nothingRead() {
        let read = Self.read("mit Petra absprechen")
        #expect(read.isEmpty)
        #expect(read.rest == "mit Petra absprechen")
    }

    @Test("A context the task already carries is not added twice")
    func knownContext() {
        #expect(Self.read("anrufen", current: ["Telefon"]).contexts.isEmpty)
    }

    @Test("Apply writes user revisions, keeps contexts and leaves the raw text alone")
    @MainActor func apply() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten")
        let phone = TaskContext(name: "Telefon")
        let task = TaskItem(rawText: "Hecke schneiden")
        store.context.insert(garden)
        store.context.insert(phone)
        store.context.insert(task)
        RevisionService.set(.contexts, to: FieldCodec.encode(["Garten"]), on: task, contexts: [garden, phone], projects: [])

        let read = Self.read("Freitag, eine Stunde, vorher anrufen", current: ["Garten"])
        let changed = read.apply(to: task, contexts: [garden, phone], projects: [], now: Self.now, calendar: Self.calendar)
        try store.context.save()

        #expect(changed == [.dueDate, .duration, .contexts])
        #expect(task.rawText == "Hecke schneiden")
        #expect(task.dueDate == Self.calendar.date(from: DateComponents(year: 2026, month: 10, day: 16)))
        #expect(task.dueHasTime == false)
        #expect(task.duration == .hour1)
        #expect(Set((task.contexts ?? []).map(\.name)) == ["Garten", "Telefon"])
        #expect(task.dueSourceRaw == FieldSource.user.rawValue)
        #expect((task.revisions ?? []).allSatisfy { $0.author == .user })
    }
}
