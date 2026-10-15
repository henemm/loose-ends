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
