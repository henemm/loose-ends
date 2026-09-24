#if canImport(FoundationModels) && !os(watchOS)
import Foundation
import Testing
@testable import LooseEnds

/// Both files live next to the repo root; `#filePath` at this call site is
/// `LooseEndsTests/FocusBloxCalibrationTests.swift`, so two levels up is the root.
private func repoFile(_ relativePath: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
}
private let focusBloxCorpusURL = repoFile("docs/reference/focusblox-corpus.json")
private let focusBloxCalibrationReportURL = repoFile("docs/reference/focusblox-calibration-report.md")

/// One-time calibration for Issue #23: how well does `FoundationModelsEnricher`'s own confidence
/// predict correctness against the FocusBlox corpus (`scripts/export-focusblox-corpus.swift`)?
/// Calls the real on-device model dozens of times, so it only runs when the exported corpus is
/// present on disk — never in CI, which has no personal FocusBlox data to export. Writes its
/// report to `docs/reference/focusblox-calibration-report.md` (aggregate numbers only, safe to
/// commit; the corpus itself stays gitignored because it holds real task titles).
@Suite(.enabled(if: FileManager.default.fileExists(atPath: focusBloxCorpusURL.path)))
struct FocusBloxCalibrationTests {
    struct CorpusTask: Decodable {
        var rawText: String
        var title: String
        var durationBucket: String?
        var energy: String?
        var capturedAt: Date
        var isCompleted: Bool
    }

    static let thresholds: [Double] = [0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
    static let sampleSize = 60

    /// confidence < 0 stands for "model declined" — never crosses a threshold, so it behaves
    /// exactly like nothing was written, without inflating the count of wrong guesses.
    struct Outcome { var confidence: Double; var correct: Bool }

    static func outcome<T: RawRepresentable>(guess: EnrichmentDraft.Guess<T>?, truth: String?) -> Outcome? where T.RawValue == String {
        guard let truth else { return nil }
        guard let guess else { return Outcome(confidence: -1, correct: false) }
        return Outcome(confidence: guess.confidence, correct: guess.value.rawValue == truth)
    }

    static func table(field: String, outcomes: [Outcome]) -> String {
        var lines = ["### \(field) (\(outcomes.count) Aufgaben mit bekanntem Wert)", "", "| Schwelle | Geschrieben | Precision | Recall |", "|---|---|---|---|"]
        for threshold in thresholds {
            let written = outcomes.filter { $0.confidence >= threshold }
            let correct = written.filter(\.correct).count
            let precision = written.isEmpty ? "–" : String(format: "%.0f%%", 100 * Double(correct) / Double(written.count))
            let recall = String(format: "%.0f%%", 100 * Double(correct) / Double(outcomes.count))
            lines.append("| \(threshold) | \(written.count) | \(precision) | \(recall) |")
        }
        return lines.joined(separator: "\n")
    }

    @Test("Precision/Recall je Schwelle für duration, energy")
    func calibrate() async throws {
        let data = try Data(contentsOf: focusBloxCorpusURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let corpus = try decoder.decode([CorpusTask].self, from: data)

        let enricher = FoundationModelsEnricher()
        try #require(enricher.unavailableReason == nil, "Modell nicht verfügbar: \(enricher.unavailableReason ?? "-")")

        let examples = corpus
            .filter { $0.isCompleted && $0.durationBucket != nil }
            .prefix(5)
            .map { task in
                EnrichmentExample(
                    rawText: task.rawText,
                    title: task.title,
                    duration: task.durationBucket.flatMap(DurationBucket.init(rawValue:)),
                    energy: task.energy.flatMap(Energy.init(rawValue:)),
                    contexts: []
                )
            }
        let sample = corpus.sorted { $0.rawText < $1.rawText }.prefix(Self.sampleSize)

        var durationOutcomes: [Outcome] = []
        var energyOutcomes: [Outcome] = []
        var modelErrors = 0

        for task in sample {
            let input = EnrichmentInput(
                rawText: task.rawText,
                capturedAt: task.capturedAt,
                contextVocabulary: [],
                projectNames: [],
                examples: Array(examples)
            )
            // A guardrail false-positive or transient failure on one note must not lose every
            // other measurement already gathered — skip it like the app's own pipeline would
            // (task stays unprocessed, next run tries again).
            guard let draft = try? await enricher.enrich(input) else {
                modelErrors += 1
                continue
            }
            if let outcome = Self.outcome(guess: draft.duration, truth: task.durationBucket) { durationOutcomes.append(outcome) }
            if let outcome = Self.outcome(guess: draft.energy, truth: task.energy) { energyOutcomes.append(outcome) }
        }

        let report = """
        # FocusBlox-Kalibrierung (Issue #23)

        Stichprobe: \(sample.count) von \(corpus.count) Aufgaben, `FoundationModelsEnricher` gegen die \
        tatsächlich in FocusBlox bestätigten Werte. Aktuelle Schreib-Schwelle: \(EnrichmentWriter.confidenceThreshold). \
        Modellfehler (z. B. Guardrail-Fehlalarm), übersprungen: \(modelErrors).

        \(Self.table(field: "duration", outcomes: durationOutcomes))

        \(Self.table(field: "energy", outcomes: energyOutcomes))
        """
        try report.write(to: focusBloxCalibrationReportURL, atomically: true, encoding: .utf8)
    }
}
#endif
