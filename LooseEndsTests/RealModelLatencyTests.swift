#if canImport(FoundationModels) && !os(watchOS)
import Foundation
import OSLog
import Testing
@testable import LooseEnds

/// Latency of the real on-device model on a Mac (#534, Schnitt 1): one cold call (the first after the
/// process started) and ten warm calls, each timed with `ContinuousClock`. Same gates as
/// `RealModelTests`: skipped without `LOOSEENDS_REAL_MODEL=1`, never in CI. The raw probes go as JSON to
/// the path in `LOOSEENDS_LATENCY_OUT` (set by `./scripts/sim.sh real-model-latency`); without it nothing
/// is written. A failed call is kept as a probe with `fehler` and does not stop the series.
@Suite(
    .enabled(if: RealModel.isRequested, "LOOSEENDS_REAL_MODEL=1 is not set (./scripts/sim.sh real-model-latency)"),
    .serialized
)
struct RealModelLatencyTests {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "RealModelLatency")
    private static let warmCalls = 10

    struct Probe: Codable {
        let gruppe: String
        let note: String
        let sekunden: Double
        let fehler: String?
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

    /// One call with a fresh enricher, as in the product; an error becomes the probe's `fehler`.
    private func probe(_ group: String, _ note: String) async -> Probe {
        let started = ContinuousClock.now
        var failure: String?
        do {
            _ = try await FoundationModelsEnricher().enrich(input(note))
        } catch {
            failure = String(describing: error)
        }
        let took = ContinuousClock.now - started
        let seconds = Double(took.components.seconds) + Double(took.components.attoseconds) / 1e18
        Self.logger.info("\(group, privacy: .public) \(seconds, privacy: .public) s \(failure ?? "ok", privacy: .public)")
        return Probe(gruppe: group, note: note, sekunden: seconds, fehler: failure)
    }

    @Test(
        "One cold and ten warm calls, timed and written as raw probes",
        .enabled(if: RealModel.isAvailable, "Apple Intelligence is not available on this Mac")
    )
    func coldThenWarm() async throws {
        var probes = [await probe("kalt", RealModel.notes[0])]
        for index in 0..<Self.warmCalls {
            let note = RealModel.notes[index % RealModel.notes.count]
            probes.append(await probe("warm", note))
        }
        #expect(probes.count == 1 + Self.warmCalls)

        guard let path = ProcessInfo.processInfo.environment["LOOSEENDS_LATENCY_OUT"], !path.isEmpty else {
            Self.logger.info("LOOSEENDS_LATENCY_OUT not set, probes not written")
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(probes).write(to: url, options: .atomic)
        Self.logger.info("Probes written to \(path, privacy: .public)")
    }
}
#endif
