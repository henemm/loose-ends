import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("Repeat rule edits") struct RepeatEditTests {
    private func posix() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    @Test("A rule survives the encode-decode round trip and encodes deterministically")
    func codecRoundTrip() throws {
        let rule = RepeatRule(frequency: .weekly, interval: 2, weekdays: [2, 4], basis: .fromCompletion)
        let encoded = try #require(FieldCodec.encode(rule))
        #expect(FieldCodec.encode(rule) == encoded, "same rule, same text, so unchanged edits write no revision")
        #expect(FieldCodec.decodeRepeat(encoded) == rule)
        #expect(FieldCodec.decodeRepeat("not json") == nil)
        #expect(FieldCodec.decodeRepeat(nil) == nil)
    }

    @Test("Setting a rule writes a user revision, the same rule again writes nothing, nil clears it")
    @MainActor func setRule() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Rasen mähen")
        task.status = .active
        store.context.insert(task)
        let rule = RepeatRule(frequency: .weekly, weekdays: [7])
        let encoded = FieldCodec.encode(rule)

        let first = try #require(RevisionService.set(.repeatRule, to: encoded, on: task, contexts: [], projects: []))
        let again = RevisionService.set(.repeatRule, to: encoded, on: task, contexts: [], projects: [])
        try store.context.save()

        #expect(task.repeatRule == rule)
        #expect(first.field == .repeatRule)
        #expect(first.author == .user)
        #expect(first.oldValue == nil)
        #expect(first.newValue == encoded)
        #expect(again == nil)
        #expect(ViewRules.tasks(for: .repeating, in: [task]).map(\.id) == [task.id])

        RevisionService.set(.repeatRule, to: nil, on: task, contexts: [], projects: [])
        try store.context.save()
        #expect(task.repeatRule == nil)
        #expect(ViewRules.tasks(for: .repeating, in: [task]).isEmpty)
        #expect(task.revisions?.count == 2)
    }

    @Test("Rules read as people say them")
    func descriptions() {
        let calendar = posix()
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .daily), calendar: calendar) == "Daily")
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .daily, interval: 3), calendar: calendar) == "Every 3 days")
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .weekly, weekdays: [2, 7]), calendar: calendar) == "Weekly · Mon, Sat")
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .monthly, interval: 2, basis: .fromCompletion), calendar: calendar) == "Every 2 months · after completion")
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .yearly), calendar: calendar) == "Yearly")
    }
}
