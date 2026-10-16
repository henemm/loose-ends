import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// A project only from its name in the note, never guessed (Henning, 2026-10-16, #469).
@Suite("Project from its name") struct ProjectNameRuleTests {
    @Test("The project whose name stands in the note, also as the start of a compound")
    func match() {
        let projects = ["Umzug", "Garten", "Erstes"]
        #expect(ProjectNameRule.match(in: "Kartons für den Umzug kaufen", projects: projects)?.value == "Umzug")
        #expect(ProjectNameRule.match(in: "Umzugskartons bestellen", projects: projects)?.value == "Umzug")
        #expect(ProjectNameRule.match(in: "Termin beim Hautarzt für OP", projects: projects) == nil)
    }

    @Test("A model guess is released at start, a project the user set stays")
    @MainActor func release() async throws {
        let store = try TestStore()
        let first = Project(name: "Erstes")
        store.context.insert(first)
        let guessed = TaskItem(rawText: "Termin beim Hautarzt")
        let chosen = TaskItem(rawText: "Fenster putzen")
        store.context.insert(guessed)
        store.context.insert(chosen)
        guessed.project = first
        // Confirmed long ago: the model's revision was seen.
        let guess = Revision(task: guessed, field: .project, oldValue: nil, newValue: "Erstes", author: .ai)
        guess.seenAt = Date(timeIntervalSince1970: 0)
        guess.createdAt = Date(timeIntervalSince1970: 0)
        guessed.revisions = [guess]
        RevisionService.set(.project, to: "Erstes", on: chosen, contexts: [], projects: [first])

        #expect(try GuessedProjects.release(in: store.context) == 1)
        try store.context.save()
        #expect(guessed.project == nil)
        #expect(chosen.project?.name == "Erstes")
        // The stored order of a relationship is not fixed: look for the release, not at the end.
        let release = try #require((guessed.revisions ?? []).first { $0.author == .rule })
        #expect(release.field == .project && release.oldValue == "Erstes" && release.newValue == nil)
        #expect(try GuessedProjects.release(in: store.context) == 0, "a second start finds nothing")
        #expect(!guessed.hasUnseenAutomaticRevisions, "the release does not put the task back into New")
    }

    @Test("A release written unseen by build 70 is marked seen at the next start")
    @MainActor func repairsUnseenRelease() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Fenster putzen")
        store.context.insert(task)
        task.status = .active
        task.revisions = [Revision(task: task, field: .project, oldValue: "Erstes", newValue: nil, author: .rule,
                                   reason: GuessedProjects.reason)]
        #expect(task.hasUnseenAutomaticRevisions)
        #expect(try GuessedProjects.release(in: store.context) == 0)
        #expect(!task.hasUnseenAutomaticRevisions)
        #expect(!ViewRules.isInNew(task))
    }

    @Test("The rule step sets the project named in the note, with the rule as its origin")
    @MainActor func ruleStep() async throws {
        let store = try TestStore()
        store.context.insert(Project(name: "Umzug", sortOrder: 0))
        let task = TaskItem(rawText: "Kartons für den Umzug kaufen")
        store.context.insert(task)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(draft: EnrichmentDraft()), container: store.container)
        await coordinator.processPending()
        #expect(task.project?.name == "Umzug")
        #expect((task.revisions ?? []).contains { $0.field == .project && $0.author == .rule })
    }
}
