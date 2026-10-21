import Foundation
import SwiftData
import Testing
@testable import LooseEnds
#if canImport(FoundationModels) && !os(watchOS)
import FoundationModels
#endif

/// The model seam in CI (#530): what a real model can do to the pipeline — hang, answer empty,
/// answer differently per note, refuse — played by `StubEnricher`, since Apple Intelligence does
/// not run on the CI's virtual Macs. Notes carry no rule signal, so only the model path is tested.
@Suite("Model seam") struct ModelSeamTests {
    private func titled(_ title: String) -> EnrichmentDraft {
        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess(title, confidence: 0.9, reason: "Stub.")
        return draft
    }

    @Test("A model call that hangs ends at its limit; the pass goes on with the next note")
    @MainActor func hangingCallTimesOut() async throws {
        let store = try TestStore()
        let slow = TaskItem(rawText: "Zettel sortieren")
        slow.capturedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let fast = TaskItem(rawText: "Kabel aufrollen")
        fast.capturedAt = Date(timeIntervalSince1970: 1_790_000_060)
        store.context.insert(slow)
        store.context.insert(fast)
        try store.context.save()
        let stub = StubEnricher()
        stub.delayFor = { $0.rawText == "Zettel sortieren" ? .seconds(30) : nil }
        stub.respond = { _ in EnrichmentDraft() }
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container, modelTimeout: .milliseconds(200))

        let started = ContinuousClock.now
        await coordinator.processPending()

        #expect(ContinuousClock.now - started < .seconds(10), "the hang does not hold the pass")
        #expect(stub.notes == ["Zettel sortieren", "Kabel aufrollen"])
        #expect(slow.processedAt == nil, "a timed-out note waits for the next pass, like any failure")
        #expect(slow.rulesAppliedAt != nil, "the rule step ran anyway (#144)")
        #expect(fast.processedAt != nil)
    }

    @Test("A re-analysis whose model call hangs reports that the model did not run")
    @MainActor func reanalysisTimesOut() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(draft: titled("Zettel ordnen"))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container, modelTimeout: .milliseconds(200))
        await coordinator.processPending()

        stub.delay = .seconds(30)
        let result = await coordinator.reanalyze(task)

        #expect(result == .finished(changed: 0, modelRan: false))
        #expect(task.title == "Zettel ordnen")
    }

    @Test("An empty answer marks the note as seen by the model and writes nothing")
    @MainActor func emptyAnswer() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(), container: store.container)

        await coordinator.processPending()

        #expect(task.processedAt != nil, "the model ran once; an empty answer is an answer (ADR-4)")
        #expect((task.revisions ?? []).isEmpty)
    }

    @Test("Each note gets its own answer")
    @MainActor func answerPerNote() async throws {
        let store = try TestStore()
        let first = TaskItem(rawText: "Zettel sortieren")
        let second = TaskItem(rawText: "Kabel aufrollen")
        store.context.insert(first)
        store.context.insert(second)
        try store.context.save()
        let stub = StubEnricher()
        stub.respond = { input in
            var draft = EnrichmentDraft()
            draft.title = EnrichmentDraft.Guess("\(input.rawText) erledigen", confidence: 0.9, reason: "Stub.")
            return draft
        }
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)

        await coordinator.processPending()

        #expect(first.title == "Zettel sortieren erledigen")
        #expect(second.title == "Kabel aufrollen erledigen")
    }

    #if canImport(FoundationModels) && !os(watchOS)
    /// One note, the model fails with `failure`, two passes (#535). Returns the stub and the note.
    @MainActor private func twoPasses(in store: TestStore, failing failure: Error) async throws -> (StubEnricher, TaskItem, EnrichmentCoordinator) {
        let task = TaskItem(rawText: "Zettel sortieren")
        store.context.insert(task)
        try store.context.save()
        let stub = StubEnricher(failure: failure)
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()
        await coordinator.processPending()
        return (stub, task, coordinator)
    }

    @Test("A guardrail refusal is permanent: rules stay, the note is marked, no revision (#535)")
    @MainActor func guardrailRefusal() async throws {
        let store = try TestStore()
        let (stub, task, _) = try await twoPasses(in: store, failing: LanguageModelError.guardrailViolation(.init(debugDescription: "test")))

        #expect(task.processedAt != nil)
        #expect(task.rulesAppliedAt != nil)
        #expect((task.revisions ?? []).isEmpty)
        #expect(stub.calls == 1, "the second pass does not send it to the model again")
    }

    @Test("An exceeded context window is permanent too (#535)")
    @MainActor func contextWindow() async throws {
        let store = try TestStore()
        let (stub, task, _) = try await twoPasses(
            in: store, failing: LanguageModelError.contextSizeExceeded(.init(contextSize: 10, tokenCount: 20, debugDescription: "test")))

        #expect(task.processedAt != nil)
        #expect((task.revisions ?? []).isEmpty)
        #expect(stub.calls == 1)
    }

    @Test("Transient failures stay retryable: the note is tried again on the next pass (#535)",
          arguments: [0, 1, 2])
    @MainActor func transientFailures(kind: Int) async throws {
        let failure: Error = switch kind {
        case 0: LanguageModelError.timeout(.init(debugDescription: "test"))
        case 1: LanguageModelError.rateLimited(.init(resetDate: nil, debugDescription: "test"))
        default: StubFailure()
        }
        let store = try TestStore()
        let (stub, task, _) = try await twoPasses(in: store, failing: failure)

        #expect(task.processedAt == nil)
        #expect(task.rulesAppliedAt != nil)
        #expect(stub.calls == 2)
    }

    @Test("A re-analysis still calls the model for a note it permanently refused (#535)")
    @MainActor func reanalysisAfterPermanentFailure() async throws {
        let store = try TestStore()
        let (stub, task, coordinator) = try await twoPasses(in: store, failing: LanguageModelError.guardrailViolation(.init(debugDescription: "test")))
        let before = stub.calls

        _ = await coordinator.reanalyze(task)

        #expect(stub.calls == before + 1)
    }

    @Test("Only guardrail and context window are permanent")
    func classification() {
        let text = "test"
        #expect(ModelFailure.isPermanent(LanguageModelError.guardrailViolation(.init(debugDescription: text))))
        #expect(ModelFailure.isPermanent(LanguageModelError.contextSizeExceeded(.init(contextSize: 10, tokenCount: 20, debugDescription: text))))
        #expect(!ModelFailure.isPermanent(LanguageModelError.rateLimited(.init(resetDate: nil, debugDescription: text))))
        #expect(!ModelFailure.isPermanent(LanguageModelError.refusal(.init(explanation: text, debugDescription: text))))
        #expect(!ModelFailure.isPermanent(LanguageModelError.timeout(.init(debugDescription: text))))
        #expect(!ModelFailure.isPermanent(LanguageModelError.unsupportedGenerationGuide(.init(schemaName: nil, debugDescription: text))))
        #expect(!ModelFailure.isPermanent(ModelDeadline.Exceeded(limit: .seconds(1))))
        #expect(!ModelFailure.isPermanent(StubFailure()))
    }
    #endif
}

@Suite("Model deadline") struct ModelDeadlineTests {
    @Test("A call within its limit returns its value")
    func withinLimit() async throws {
        let value = try await ModelDeadline.run(within: .seconds(5)) { 42 }
        #expect(value == 42)
    }

    @Test("A call past its limit throws Exceeded and is cancelled")
    func pastLimit() async throws {
        await #expect(throws: ModelDeadline.Exceeded(limit: .milliseconds(50))) {
            try await ModelDeadline.run(within: .milliseconds(50)) {
                try await Task.sleep(for: .seconds(30))
                return 0
            }
        }
    }

    @Test("A call that fails throws its own error, not a timeout")
    func ownError() async throws {
        await #expect(throws: StubFailure.self) {
            try await ModelDeadline.run(within: .seconds(5)) { () async throws -> Int in throw StubFailure() }
        }
    }
}

#if canImport(FoundationModels) && !os(watchOS)
/// What `FoundationModelsEnricher.draft(from:)` makes of a model answer (#530): the mapping runs
/// without the model, so CI checks it.
@Suite("Model answer mapping") struct ModelAnswerMappingTests {
    private func answer(
        title: String = "Zettel sortieren", titleConfidence: Double = 0.9,
        duration: String = "", durationConfidence: Double = 0.9,
        contexts: [String] = [], project: String = ""
    ) -> ModelEnrichment {
        ModelEnrichment(
            title: title, titleConfidence: titleConfidence, titleReason: "r",
            duration: duration, durationConfidence: durationConfidence, durationReason: "r",
            contexts: contexts, contextsConfidence: 0.9, contextsReason: "r",
            project: project, projectConfidence: 0.9, projectReason: "r"
        )
    }

    @Test("Blank strings, an unknown duration and empty contexts mean not set")
    func blanksAreDropped() {
        let draft = FoundationModelsEnricher.draft(
            from: answer(title: "   ", duration: "minutes20", contexts: [" ", ""], project: " "),
            capturedAt: Date()
        )
        #expect(draft.title == nil)
        #expect(draft.duration == nil)
        #expect(draft.contexts == nil)
        #expect(draft.project == nil)
    }

    @Test("Values are trimmed and every confidence is clamped to 0…1")
    func trimmedAndClamped() {
        let draft = FoundationModelsEnricher.draft(
            from: answer(title: " Zettel sortieren ", titleConfidence: 1.7, duration: "minutes15", durationConfidence: -0.2,
                         contexts: [" Garten ", ""]),
            capturedAt: Date()
        )
        #expect(draft.title?.value == "Zettel sortieren")
        #expect(draft.title?.confidence == 1)
        #expect(draft.duration?.value == .minutes15)
        #expect(draft.duration?.confidence == 0)
        #expect(draft.contexts?.value == ["Garten"])
    }
}
#endif
