import Foundation
import SwiftData
import Testing
@testable import LooseEnds
#if canImport(FoundationModels) && !os(watchOS)
import FoundationModels
#endif

/// The model seam in CI (#530, #535). Since #982 (ADR-22) the coordinator calls no model, so its pipeline cases are
/// gone; what stays is the classification of model failures, which `ModelFailure` still provides (cleanup in #982
/// Schnitt 3).
@Suite("Model seam") struct ModelSeamTests {
    #if canImport(FoundationModels) && !os(watchOS)
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
