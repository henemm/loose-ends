import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Its bundle has no `de` translations, so `String(localized:bundle:)` falls back to the (English) key —
/// deterministic regardless of the host machine's system language.
private final class UntranslatedBundleMarker {}

@Suite("Repeat rule edits") struct RepeatEditTests {
    private func posix() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private var untranslatedBundle: Bundle { Bundle(for: UntranslatedBundleMarker.self) }

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

    /// Nachstellung des Editor-Ablaufs (#102): Der User wählt zum ersten Mal eine Frequenz, die
    /// Aufgabe hat noch keine `repeatRule`. `RepeatRule.selecting` ist die reine Fassung dessen,
    /// was `FieldEditorView.repeatControl` in der Picker-Closure tut — direkt an
    /// `RevisionService.set` gereicht wie im Editor auch.
    @Test("Erstmaliges Wählen einer Frequenz übernimmt die im Rohtext erkannte Uhrzeit (AC-2)")
    @MainActor func firstFrequencyPickPrefillsTime() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Jeden Tag um 7 Uhr die Tabletten nehmen")
        task.status = .active
        store.context.insert(task)

        let chosen = RepeatRule.selecting(.daily, existing: task.repeatRule, rawText: task.rawText)
        _ = RevisionService.set(.repeatRule, to: FieldCodec.encode(chosen), on: task, contexts: [], projects: [])
        try store.context.save()

        #expect(task.repeatRule?.hour == 7)
        #expect(task.repeatRule?.minute == 0)
    }

    /// Ändert der User danach die Frequenz einer bereits bestehenden Regel, wird der Rohtext nicht
    /// erneut befragt — die Uhrzeit bleibt, wie sie war (AC-3).
    @Test("Ändern der Frequenz einer bestehenden Regel lässt die Uhrzeit unverändert (AC-3)")
    @MainActor func changingFrequencyKeepsStoredTime() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Jeden Tag um 7 Uhr die Tabletten nehmen")
        task.status = .active
        store.context.insert(task)

        var existing = RepeatRule(frequency: .daily)
        existing.hour = 7
        existing.minute = 0
        _ = RevisionService.set(.repeatRule, to: FieldCodec.encode(existing), on: task, contexts: [], projects: [])
        try store.context.save()

        let changed = RepeatRule.selecting(.weekly, existing: task.repeatRule, rawText: task.rawText)
        _ = RevisionService.set(.repeatRule, to: FieldCodec.encode(changed), on: task, contexts: [], projects: [])
        try store.context.save()

        #expect(task.repeatRule?.frequency == .weekly)
        #expect(task.repeatRule?.hour == 7)
        #expect(task.repeatRule?.minute == 0)
    }

    @Test("Rules read as people say them")
    func descriptions() {
        let calendar = posix()
        let bundle = untranslatedBundle
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .daily), calendar: calendar, bundle: bundle) == "Daily")
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .daily, interval: 3), calendar: calendar, bundle: bundle) == "Every 3 days")
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .weekly, weekdays: [2, 7]), calendar: calendar, bundle: bundle) == "Weekly · Mon, Sat")
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .monthly, interval: 2, basis: .fromCompletion), calendar: calendar, bundle: bundle) == "Every 2 months · after completion")
        #expect(FieldFormatting.repeatDescription(RepeatRule(frequency: .yearly), calendar: calendar, bundle: bundle) == "Yearly")
    }
}
