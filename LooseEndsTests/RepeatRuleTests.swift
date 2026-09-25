import Foundation
import Testing
@testable import LooseEnds

/// Die freistehende Uhrzeit einer Wiederholung (#102): "Jeden Tag um 7 Uhr die Tabletten nehmen"
/// liefert eine Uhrzeit, die `DueDateRule` bewusst verwirft (kein Fälligkeitsdatum aus
/// Wiederholungstext, #95 AC-6) und die bisher nirgends sonst einen Platz hatte. `timeGuess` ist
/// ein reiner Pass-Through auf den bereits zu 100 % gemessenen `TimeExpressionParser` (#92) — kein
/// neues Erkennungsrisiko. `selecting` ist die reine, testbare Fassung dessen, was
/// `FieldEditorView.repeatControl` beim Wählen einer Frequenz tut (Picker-Closure lässt sich in
/// SwiftUI ohne ViewInspector nicht direkt treiben; dasselbe Muster wie
/// `FieldFormatting.repeatDescription`, das ebenfalls als reine Funktion aus der View heraus
/// aufgerufen und direkt getestet wird).
@Suite("Regelschritt: Wiederholungs-Uhrzeit")
struct RepeatRuleTests {
    private func berlin() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        return calendar
    }

    private func date(_ day: Int, hour: Int, minute: Int = 0, in calendar: Calendar) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute)))
    }

    @Test("Eine im Rohtext erkannte Uhrzeit wird geliefert (AC-1)")
    func timeGuessFindsTime() {
        let guess = RepeatRule.timeGuess(from: "Jeden Tag um 7 Uhr die Tabletten nehmen")
        #expect(guess?.hour == 7)
        #expect(guess?.minute == 0)
    }

    @Test("Ohne erkennbares Zeit-Signal liefert timeGuess nichts (AC-1)")
    func timeGuessYieldsNothingWithoutSignal() {
        #expect(RepeatRule.timeGuess(from: "Wöchentlich den Müll rausbringen") == nil)
    }

    @Test("Eine neu gewählte Frequenz übernimmt die erkannte Uhrzeit (AC-2)")
    func selectingNewRulePrefillsTime() {
        let rule = RepeatRule.selecting(.daily, existing: nil, rawText: "Jeden Tag um 7 Uhr die Tabletten nehmen")
        #expect(rule.frequency == .daily)
        #expect(rule.hour == 7)
        #expect(rule.minute == 0)
    }

    @Test("Eine neu gewählte Frequenz ohne Zeit-Signal bleibt ohne Uhrzeit (AC-2)")
    func selectingNewRuleWithoutSignalStaysNil() {
        let rule = RepeatRule.selecting(.weekly, existing: nil, rawText: "Wöchentlich den Müll rausbringen")
        #expect(rule.frequency == .weekly)
        #expect(rule.hour == nil)
        #expect(rule.minute == nil)
    }

    @Test("Eine bestehende Regel behält ihre Uhrzeit beim Wechsel der Frequenz (AC-3)")
    func selectingExistingRuleKeepsStoredTime() {
        var existing = RepeatRule(frequency: .daily)
        existing.hour = 7
        existing.minute = 0

        // Der Rohtext nennt jetzt eine andere Uhrzeit — sie darf nicht erneut gezogen werden,
        // weil `existing` bereits gesetzt ist. Der Rohtext wird nur einmal befragt, beim Entstehen
        // der Regel.
        let next = RepeatRule.selecting(.weekly, existing: existing, rawText: "Um 20 Uhr erinnern")

        #expect(next.frequency == .weekly)
        #expect(next.hour == 7)
        #expect(next.minute == 0)
    }

    @Test("Eine RepeatRule mit gesetzter Uhrzeit läuft verlustfrei durch den Codec (AC-4)")
    func codecRoundTripKeepsTime() throws {
        var rule = RepeatRule(frequency: .daily)
        rule.hour = 7
        rule.minute = 30
        let encoded = try #require(FieldCodec.encode(rule))
        #expect(FieldCodec.decodeRepeat(encoded) == rule)
    }

    @Test("Eine RepeatRule ohne Uhrzeit bleibt nach dem Codec-Round-Trip ohne Uhrzeit (AC-4)")
    func codecRoundTripWithoutTimeStaysNil() throws {
        let rule = RepeatRule(frequency: .weekly, weekdays: [2, 4])
        let encoded = try #require(FieldCodec.encode(rule))
        let decoded = try #require(FieldCodec.decodeRepeat(encoded))
        #expect(decoded.hour == nil)
        #expect(decoded.minute == nil)
        #expect(decoded == rule)
    }

    /// Der Baustein muss ohne Modell und ohne Plattform-Klammer kompilieren: `Shared/` geht in
    /// App, Watch, Widgets und Share-Erweiterung. Liegt der Typ im Produktmodul, ist das bewiesen
    /// (analog `DueDateRuleTests.ruleLivesInProductModule`).
    @Test("Der Regelschritt liegt im Produktmodul")
    func ruleLivesInProductModule() {
        #expect(String(reflecting: RepeatRule.self).hasPrefix("LooseEnds."))
    }

    // MARK: - #127: implizites erstes Fälligkeitsdatum

    @Test("firstDueDate kombiniert den nächsten Termin mit der gespeicherten Uhrzeit (AC-1)")
    func firstDueDateUsesStoredTime() throws {
        let calendar = try berlin()
        var rule = RepeatRule(frequency: .daily)
        rule.hour = 19
        rule.minute = 0
        let now = try date(24, hour: 8, in: calendar)

        let due = rule.firstDueDate(now: now, calendar: calendar)

        #expect(due == (try date(25, hour: 19, in: calendar)))
    }

    @Test("firstDueDate faellt ohne gespeicherte Uhrzeit auf den Tagesbeginn zurueck (AC-1)")
    func firstDueDateWithoutTimeFallsBackToStartOfDay() throws {
        let calendar = try berlin()
        let rule = RepeatRule(frequency: .weekly, weekdays: [2, 4])
        let now = try date(24, hour: 8, in: calendar)

        let due = rule.firstDueDate(now: now, calendar: calendar)
        let expectedNext = rule.nextDueDate(previousDue: nil, completedOn: now, calendar: calendar)

        #expect(due == calendar.startOfDay(for: expectedNext))
    }

    @Test("firstDueDate reicht den bestehenden Wochentag-losen Ruecksprung von nextDueDate unveraendert durch (AC-1, Risiko 3)")
    func firstDueDateWeeklyWithoutWeekdaysReusesFallback() throws {
        let calendar = try berlin()
        var rule = RepeatRule(frequency: .weekly)
        rule.hour = 8
        rule.minute = 0
        let now = try date(24, hour: 8, in: calendar)

        let due = rule.firstDueDate(now: now, calendar: calendar)
        let expectedNext = rule.nextDueDate(previousDue: nil, completedOn: now, calendar: calendar)

        #expect(due == expectedNext, "gleiche Uhrzeit wie der Anker macht das Setzen der Stunde zum No-Op — belegt den unveraenderten +7x-Ruecksprung")
    }
}
