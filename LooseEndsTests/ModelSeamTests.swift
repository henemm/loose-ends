import Foundation
import SwiftData
import Testing
@testable import LooseEnds
#if canImport(FoundationModels) && !os(watchOS)
import FoundationModels
#endif

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
