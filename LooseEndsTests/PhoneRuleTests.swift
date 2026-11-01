import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// A dictated phone number goes to the note, not the title (#439 Schnitt 2).
@Suite("Phone rule") struct PhoneRuleTests {
    static let text = "Hautarzt anrufen +49 251 465560 wegen OP"

    @Test("The number is found as written")
    func finds() {
        #expect(PhoneRule.numbers(in: Self.text).count == 1)
        #expect(PhoneRule.numbers(in: Self.text).first?.hasPrefix("+49") == true)
        #expect(PhoneRule.note(from: "Hecke schneiden") == nil)
    }

    @Test("The title leaves the number out and keeps the rest")
    func titleWithoutNumber() {
        let title = TitleRule.title(from: Self.text)
        #expect(title == "Hautarzt anrufen wegen OP")
    }

    @Test("The rule step writes the number into an empty note, as a rule revision")
    @MainActor func ruleStepWritesNote() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: Self.text)
        store.context.insert(task)
        try store.context.save()

        await EnrichmentCoordinator(enricher: StubEnricher(unavailableReason: "Kein Modell"), container: store.container).processPending()

        #expect(task.notes?.hasPrefix("+49") == true)
        #expect(task.notesSourceRaw == FieldSource.rule.rawValue)
        let revisions = (task.revisions ?? []).filter { $0.field == .notes }
        #expect(revisions.count == 1)
        #expect(revisions.first?.author == .rule)
        #expect(revisions.first?.reason == PhoneRule.reason)
    }

    @Test("A note the user already wrote stays as it is")
    @MainActor func userNoteStays() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: Self.text)
        store.context.insert(task)
        RevisionService.set(.notes, to: "Praxis Dr. Meier", on: task, contexts: [], projects: [])
        try store.context.save()

        await EnrichmentCoordinator(enricher: StubEnricher(unavailableReason: "Kein Modell"), container: store.container).processPending()

        #expect(task.notes == "Praxis Dr. Meier")
        #expect(!(task.revisions ?? []).contains { $0.field == .notes && $0.author == .rule })
    }
}

/// #786: the rule is its own scanner, not `NSDataDetector`, so title and note come out the same on
/// iPhone, iPad and Mac. The iOS detector also took bare digit runs ("Police 30021988") for numbers.
@Suite("Phone rule without the detector") struct PhoneRuleScannerTests {
    static let positive = [
        "+49 251 465560", "0251/465560", "040 1234567", "0151 23456789", "01761234567", "0176 1234 5678",
        "02 51 / 4 65 56", "040-987654-0", "040 987654 - 0", "040 987654\u{2013}0", "+49 (0) 251 465560",
        "0049 251 465560", "0251\u{00A0}465560", "0251\u{202F}465560", "(555) 123-4567", "+1 415 555 0123",
    ]

    static let negative = [
        "30021988", "1234567", "12345678", "2025-0042", "01067 Dresden", "09:14", "15.03.2026", "4711",
        "DE89 3704 0044 0532 0130 00", "7 Kartons", "20 Minuten", "0251.465560",
    ]

    @Test("A real number is found as written", arguments: positive)
    func positiveFormsAreFound(number: String) {
        #expect(PhoneRule.numbers(in: "Bitte \(number) anrufen") == [number])
    }

    @Test("A digit run that is no number stays out", arguments: negative)
    func negativeFormsAreIgnored(text: String) {
        #expect(PhoneRule.numbers(in: "Bitte \(text) prüfen").isEmpty)
    }

    @Test("Digit runs only the iOS detector took for numbers are ignored")
    func detectorOnlyDigitRunsAreIgnored() {
        #expect(PhoneRule.numbers(in: "Kunde 1234567 anrufen").isEmpty)
        #expect(PhoneRule.numbers(in: "Auftrag 12345678 prüfen").isEmpty)
        #expect(PhoneRule.numbers(in: "Die Police 30021988 umschreiben lassen").isEmpty)
    }

    @Test("A policy number stays in the title")
    func policyNumberStaysInTitle() {
        let text = "Die Police 30021988 umschreiben lassen"
        #expect(TitleRule.title(from: text)?.contains("30021988") == true)
        #expect(PhoneRule.numbers(in: text).isEmpty)
    }

    @Test("The range ends at the last digit", arguments: [
        ("Ruf 040 1234567.", "Ruf ."), ("Ruf 040 1234567, bitte", "Ruf , bitte"), ("Ruf 040 1234567 -", "Ruf  -"),
    ])
    func rangeEndsAtLastDigit(text: String, rest: String) {
        #expect(PhoneRule.numbers(in: text) == ["040 1234567"])
        #expect(PhoneRule.removing(from: text) == rest)
    }

    @Test("Two numbers come in order, one per line in the note")
    func twoNumbersInOrder() {
        let text = "Praxis 0251/465560 oder mobil 0151 23456789"
        #expect(PhoneRule.numbers(in: text) == ["0251/465560", "0151 23456789"])
        #expect(PhoneRule.note(from: text) == "0251/465560\n0151 23456789")
    }

    @Test("The rule step leaves a policy number alone: no note")
    @MainActor func ruleStepLeavesPolicyNumberAlone() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Die Police 30021988 umschreiben lassen")
        store.context.insert(task)
        try store.context.save()

        await EnrichmentCoordinator(enricher: StubEnricher(unavailableReason: "Kein Modell"), container: store.container).processPending()

        #expect(task.notes == nil)
        #expect(!(task.revisions ?? []).contains { $0.field == .notes && $0.author == .rule })
    }
}
