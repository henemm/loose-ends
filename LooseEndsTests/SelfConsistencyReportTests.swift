import Foundation
import Testing
@testable import LooseEnds

/// Writes the self-consistency report for Spike #65 Schritt 2 (#108): does agreement across five
/// repeated runs of the same FocusBlox note track whether the majority answer is actually right?
/// Reads two files that already sit locally — the FocusBlox truth export and a `MeasurementRun`
/// result file fetched from the device (`sim.sh lab-fetch`) — and calls no model, unlike
/// `FocusBloxCalibrationTests`. Gated because both are personal, gitignored data
/// ([[feedback-phone-is-not-a-test-bench]]); never runs in CI.
private func repoFile(_ relativePath: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
}
private let focusBloxTruthURL = repoFile("docs/reference/focusblox-corpus.json")
private let selfConsistencyRunURL = repoFile("docs/reference/selfconsistency-run.json")
private let selfConsistencyReportURL = repoFile("docs/reference/uncertainty-signal-selfconsistency-report.md")

@Suite(.enabled(if: FileManager.default.fileExists(atPath: focusBloxTruthURL.path)
                  && FileManager.default.fileExists(atPath: selfConsistencyRunURL.path)))
struct SelfConsistencyReportTests {
    @Test("Schreibt den Selbstkonsistenz-Bericht aus zwei bereits vorhandenen Dateien, ohne Modellaufruf (AC-9)")
    func writesReport() throws {
        let entries = try JSONDecoder().decode([Corpus.Entry].self, from: Data(contentsOf: focusBloxTruthURL))
        let entryByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        let run = try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: Data(contentsOf: selfConsistencyRunURL))
        let byEntry = Dictionary(grouping: run.succeeded, by: \.entryID)

        func outcomes(_ value: (MeasurementResult) -> String?, truth: (Corpus.Entry) -> String?) -> [SelfConsistency.Outcome] {
            byEntry.compactMap { entryID, results in
                guard let entry = entryByID[entryID], let expected = truth(entry) else { return nil }
                let values = results.map(value)
                guard let majority = SelfConsistency.majority(values) else { return nil }
                return SelfConsistency.Outcome(agreement: SelfConsistency.agreement(values), correct: majority == expected)
            }
        }

        var sections = [
            SelfConsistency.table(field: "importance", outcomes: outcomes({ $0.importance }, truth: { $0.importanceTruth })),
            SelfConsistency.table(field: "urgency", outcomes: outcomes({ $0.urgency }, truth: { $0.urgencyTruth })),
            SelfConsistency.table(field: "duration", outcomes: outcomes({ $0.duration }, truth: { $0.durationTruth })),
            SelfConsistency.table(field: "energy", outcomes: outcomes({ $0.energy }, truth: { $0.energyTruth })),
        ]

        let contextsOutcomes: [SelfConsistency.Outcome] = byEntry.compactMap { entryID, results in
            guard let entry = entryByID[entryID], let expected = entry.contextsTruth else { return nil }
            let values = results.map(\.contexts)
            guard let majority = SelfConsistency.majoritySet(values) else { return nil }
            return SelfConsistency.Outcome(agreement: SelfConsistency.agreementSet(values), correct: majority == Set(expected))
        }
        sections.append(SelfConsistency.table(field: "contexts", outcomes: contextsOutcomes))

        let report = """
        # Selbstkonsistenz-Signal (Spike #65 Schritt 2, #108)

        Einstimmigkeit über 5 Läufe je Satz gegen die tatsächliche FocusBlox-Wahrheit, für die fünf \
        Felder mit bekanntem Wert im Export.

        \(sections.joined(separator: "\n\n"))
        """
        try report.write(to: selfConsistencyReportURL, atomically: true, encoding: .utf8)
        #expect(!sections.isEmpty)
    }
}
