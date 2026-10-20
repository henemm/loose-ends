#if canImport(FoundationModels) && !os(watchOS)
import Foundation
import Testing
@testable import LooseEnds

/// The real on-device model on a Mac (#531): an Apple Silicon Mac with Apple Intelligence on runs the
/// same model as the iPhone, so these run there instead of in the lab app. Never in CI: GitHub's
/// macOS runners are virtual machines without Apple Intelligence, and `LOOSEENDS_REAL_MODEL` is
/// set only by `./scripts/sim.sh real-model`. Without the variable the suite is skipped, never red.
/// With the variable but without Apple Intelligence the first test is red and names the reason
/// (2026-10-20: a silent skip looked like an aborted run); the model tests are then skipped.
///
/// The model is not deterministic, so nothing here compares words. Hard checks are only what the
/// pipeline relies on; the title's closeness to the note is a rate over all notes with a threshold.
enum RealModel {
    static var isRequested: Bool {
        ProcessInfo.processInfo.environment["LOOSEENDS_REAL_MODEL"] == "1"
    }

    static var isAvailable: Bool {
        FoundationModelsEnricher().unavailableReason == nil
    }

    /// Invented notes, no personal data; German and English like the captures.
    static let notes = [
        "Morgen Zahnarzt anrufen wegen dem Termin",
        "Rasen mähen bevor es regnet",
        "Mail an Frau Berger wegen der Steuerunterlagen",
        "pick up the dry cleaning on the way home",
        "Fahrradschloss ölen dauert fünf Minuten",
        "Angebote der Schreinerei vergleichen",
    ]
}

@Suite(
    .enabled(if: RealModel.isRequested, "LOOSEENDS_REAL_MODEL=1 is not set (./scripts/sim.sh real-model)"),
    .serialized
)
struct RealModelTests {
    @Test("Apple Intelligence is available on this Mac")
    func modelIsAvailable() {
        let reason = FoundationModelsEnricher().unavailableReason
        #expect(reason == nil, "Apple Intelligence is not available on this Mac: \(reason ?? "")")
    }

    private func input(_ note: String) -> EnrichmentInput {
        EnrichmentInput(
            rawText: note,
            capturedAt: Date(),
            contextVocabulary: ["Computer", "Telefon", "Haus", "Garten", "Unterwegs", "Besorgung"],
            projectNames: [],
            examples: []
        )
    }

    @Test(
        "Every note gets an answer in time, and its title is short enough for a row",
        .enabled(if: RealModel.isAvailable, "Apple Intelligence is not available on this Mac")
    )
    func answersInShape() async throws {
        let enricher = FoundationModelsEnricher()
        for note in RealModel.notes {
            let started = ContinuousClock.now
            let draft = try await enricher.enrich(input(note))
            let took = ContinuousClock.now - started

            #expect(took < .seconds(30), "\(note): \(took), longer than the coordinator waits (#530)")
            let title = try #require(draft.title, "\(note): no title")
            #expect(!title.value.isEmpty)
            #expect(title.value.split(whereSeparator: \.isWhitespace).count <= 12, "\(note): \(title.value)")
            #expect((0...1).contains(title.confidence))
        }
    }

    @Test(
        "Most titles keep a word of their note (the writer drops the rest, #460)",
        .enabled(if: RealModel.isAvailable, "Apple Intelligence is not available on this Mac")
    )
    func titlesStayWithTheNote() async throws {
        let enricher = FoundationModelsEnricher()
        var kept = 0
        var lines: [String] = []
        for note in RealModel.notes {
            let title = try await enricher.enrich(input(note)).title?.value ?? ""
            let fromNote = TitleRule.isFromNote(title, rawText: note)
            if fromNote { kept += 1 }
            lines.append("\(fromNote ? "ok " : "NO ") \(note) → \(title)")
        }
        let rate = Double(kept) / Double(RealModel.notes.count)
        let report = lines.joined(separator: "\n")
        #expect(rate >= 0.8, "\(kept)/\(RealModel.notes.count) titles from the note:\n\(report)")
    }
}
#endif
