import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Gelernte Wörter im Regelschritt (#233 Schnitt 2a): Was der Nutzer selbst etikettiert hat, lehrt
/// seine Wörter; eine neu formulierte Aufgabe mit so einem Wort bekommt das Etikett mit Ursprung
/// Regel, Begründung und Revision — zusammen mit der festen Wortliste (#232), nie aus Regel- oder
/// Modellwerten (#244).
@Suite("Gelernte Wortliste im Coordinator (#233 Schnitt 2a)")
struct ContextWordLearningCoordinatorTests {
    /// Eine frühere Aufgabe, die der Regelschritt gesehen hat, mit Etiketten aus der angegebenen Quelle.
    @MainActor
    private func makeTagged(_ rawText: String, _ contexts: [TaskContext], source: FieldSource = .user,
                            in context: ModelContext) {
        let task = TaskItem(rawText: rawText)
        task.status = .active
        task.rulesAppliedAt = Date(timeIntervalSince1970: 1_700_000_000)
        task.contexts = contexts
        task.contextsSourceRaw = source.rawValue
        task.contextsConfidence = 1.0
        context.insert(task)
    }

    private func silentStub() -> StubEnricher {
        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess("Titel", confidence: 0.9, reason: "Stub.")
        return StubEnricher(draft: draft)
    }

    @Test("Ein von Hand gesetztes Etikett lehrt seine Wörter (AC-1)")
    @MainActor func learnedWordSetsContext() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        context.insert(garden)
        makeTagged("Kirschbaum schneiden", [garden], in: context)
        let fresh = TaskItem(rawText: "Kirschbaum gießen")
        context.insert(fresh)
        try context.save()

        await EnrichmentCoordinator(enricher: silentStub(), container: store.container).processPending()

        #expect((fresh.contexts ?? []).map(\.name) == ["Garten"])
        #expect(fresh.contextsSourceRaw == FieldSource.rule.rawValue)
        #expect(fresh.contextsConfidence == 1.0)
        let revision = try #require((fresh.revisions ?? []).first { $0.field == .contexts })
        #expect(revision.author == .rule)
        #expect(revision.newValue == EnrichmentWriter.encode(["Garten"]))
        #expect(revision.reason?.contains("Kirschbaum") == true, "die Begründung nennt das gelernte Wort")
    }

    @Test("Feste Liste und gelernte Wörter ergänzen sich; die feste begründet")
    @MainActor func fixedAndLearnedCombine() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        let errands = TaskContext(name: "Besorgung", isSystemDefault: true, sortOrder: 4)
        context.insert(garden)
        context.insert(errands)
        makeTagged("Kirschbaum schneiden", [garden], in: context)
        let fresh = TaskItem(rawText: "Kirschbaum kaufen")
        context.insert(fresh)
        try context.save()

        await EnrichmentCoordinator(enricher: silentStub(), container: store.container).processPending()

        #expect(Set((fresh.contexts ?? []).map(\.name)) == ["Garten", "Besorgung"])
        let revision = try #require((fresh.revisions ?? []).first { $0.field == .contexts })
        #expect(revision.reason?.contains("kaufen") == true)
    }

    @Test("Regelwerte lehren nichts, und ein Wort zweier Etiketten gehört keinem (AC-3, #244)")
    @MainActor func ruleValuesAndConflictsTeachNothing() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        let computer = TaskContext(name: "Computer", isSystemDefault: true, sortOrder: 0)
        context.insert(garden)
        context.insert(computer)
        makeTagged("Apfelbaum schneiden", [garden], source: .rule, in: context)
        makeTagged("Kirschbaum schneiden", [garden], in: context)
        makeTagged("Kirschbaum Rechnung ablegen", [computer], in: context)
        let fromRule = TaskItem(rawText: "Apfelbaum gießen")
        let conflict = TaskItem(rawText: "Kirschbaum gießen")
        context.insert(fromRule)
        context.insert(conflict)
        try context.save()

        await EnrichmentCoordinator(enricher: silentStub(), container: store.container).processPending()

        #expect((fromRule.contexts ?? []).isEmpty, "ein Regelwert kann eine kopierte Schätzung sein")
        #expect((conflict.contexts ?? []).isEmpty, "Kirschbaum steht bei Garten und Computer")
    }

    @Test("Eine Zeile unter einer Aufgabe liest gelernte Wörter wie eine Aufgabe (#565)")
    @MainActor func subtaskReadsLearnedWords() async throws {
        let store = try TestStore()
        let context = store.context
        let garden = TaskContext(name: "Garten", isSystemDefault: true, sortOrder: 3)
        context.insert(garden)
        makeTagged("Kirschbaum schneiden", [garden], in: context)
        let parent = TaskItem(rawText: "Herbst im Garten vorbereiten")
        parent.status = .active
        parent.processedAt = Date()
        parent.rulesAppliedAt = Date()
        context.insert(parent)
        let line = try Subtasks.add("Kirschbaum gießen", to: parent, in: context)
        try context.save()

        await EnrichmentCoordinator(enricher: silentStub(), container: store.container).processPending()

        #expect((line.contexts ?? []).map(\.name) == ["Garten"])
        #expect(line.contextsSourceRaw == FieldSource.rule.rawValue)
    }
}
