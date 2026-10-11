import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The people field is gone (Henning, 2026-10-09, #105 → #301): the model is not asked for it any
/// more, and a value or revision from before shows nowhere and keeps no task in New.
@Suite("People retired") struct PeopleRetiredTests {
    #if canImport(FoundationModels) && !os(watchOS)
    @Test("The model schema has no people")
    func schemaHasNoPeople() {
        let sample = ModelEnrichment(
            title: "x", titleConfidence: 1, titleReason: "x",
            duration: "x", durationConfidence: 1, durationReason: "x",
            contexts: [], contextsConfidence: 1, contextsReason: "x",
            project: "x", projectConfidence: 1, projectReason: "x"
        )
        let labels = Mirror(reflecting: sample).children.compactMap(\.label)
        #expect(!labels.contains { $0.lowercased().contains("people") })
    }
    #endif

    @Test("An old AI people value carries no marker and keeps the task out of New")
    @MainActor func oldValueStaysQuiet() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Mit Andrea den Umzug besprechen")
        task.title = "Mit Andrea den Umzug besprechen"
        task.status = .active
        task.people = ["Andrea"]
        task.peopleSourceRaw = FieldSource.ai.rawValue
        store.context.insert(task)
        let revision = Revision(task: task, field: .people, oldValue: nil, newValue: "[\"Andrea\"]", author: .ai)
        store.context.insert(revision)
        try store.context.save()

        #expect(RevisionService.origin(of: .people, on: task) == nil)
        #expect(!RevisionService.automaticFields(on: task).contains(.people))
        #expect(!task.hasUnseenAutomaticRevisions)
        #expect(ViewRules.tasks(for: .new, in: [task]).isEmpty)
        #expect((task.revisions ?? []).first?.field == .people, "the old revision still decodes as what it was")
    }
}
