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
///
/// A run that could not measure writes nothing (#133, #147): the checked-in report is the device
/// measurement from #23, and a Mac or Simulator without a usable model used to replace it with
/// "skipped: 60" and empty tables — green, and only noticed when someone read the diff. Such a run
/// now fails and leaves the file as it is (`CalibrationGate`).
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

    @Test("Precision/Recall je Schwelle für duration (Energie verließ das Modell mit #112)")
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
                    contexts: []
                )
            }
        let sample = corpus.sorted { $0.rawText < $1.rawText }.prefix(Self.sampleSize)

        var durationOutcomes: [Outcome] = []
        var modelErrors = 0
        var errorKinds: Set<String> = []

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
            let draft: EnrichmentDraft
            do {
                draft = try await enricher.enrich(input)
            } catch {
                modelErrors += 1
                errorKinds.insert(String(describing: type(of: error)))
                continue
            }
            if let outcome = Self.outcome(guess: draft.duration, truth: task.durationBucket) { durationOutcomes.append(outcome) }
        }

        let report = """
        # FocusBlox-Kalibrierung (Issue #23)

        Stichprobe: \(sample.count) von \(corpus.count) Aufgaben, `FoundationModelsEnricher` gegen die \
        tatsächlich in FocusBlox bestätigten Werte. Aktuelle Schreib-Schwelle: \(EnrichmentWriter.confidenceThreshold). \
        Modellfehler (z. B. Guardrail-Fehlalarm), übersprungen: \(modelErrors).

        \(Self.table(field: "duration", outcomes: durationOutcomes))
        """
        guard CalibrationGate.measured(sample: sample.count, modelErrors: modelErrors) else {
            Issue.record("""
            Nicht gemessen: \(modelErrors) von \(sample.count) Stichproben scheiterten am Modell \
            (\(errorKinds.sorted().joined(separator: ", "))). Der Bericht bleibt unverändert.
            """)
            return
        }
        try report.write(to: focusBloxCalibrationReportURL, atomically: true, encoding: .utf8)
    }
}

/// When a calibration run counts as a measurement (#133, #147): at least half of the sample got an
/// answer from the model. Below that the tables would describe the failures, not the model, and
/// would overwrite the device measurement with them.
enum CalibrationGate {
    static func measured(sample: Int, modelErrors: Int) -> Bool {
        sample > 0 && (sample - modelErrors) * 2 >= sample
    }
}

/// Runs without the corpus, so it also runs in CI, where the gated suite above never does.
@Suite("Kalibrierbericht: nur echte Messungen")
struct CalibrationGateTests {
    @Test("Ein Lauf ohne Modell überschreibt den Bericht nicht")
    func withoutModelNothingIsWritten() {
        #expect(!CalibrationGate.measured(sample: 60, modelErrors: 60), "der Fall aus #133 und #147")
        #expect(!CalibrationGate.measured(sample: 0, modelErrors: 0), "ohne Stichprobe gibt es nichts zu berichten")
    }

    @Test("Ein Lauf mit Antworten schreibt, auch mit einzelnen Fehlschlägen")
    func measurementIsWritten() {
        #expect(CalibrationGate.measured(sample: 60, modelErrors: 1), "der Stand aus #23")
        #expect(CalibrationGate.measured(sample: 60, modelErrors: 30))
        #expect(!CalibrationGate.measured(sample: 60, modelErrors: 31))
    }
}
#endif
