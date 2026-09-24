import Foundation
import Testing

/// Guards the #118 field-scope cut: importance/urgency left the model's output in #117, so the two
/// gated Measurement report tests (personal corpus data, never run in CI — see their own doc
/// comments) must not evaluate those fields either. Precedent: `dueDate` left the same two files'
/// scope in #95 without a replacement check, and #117 nearly regressed silently as a result.
///
/// Unlike the tests it guards, this one needs no personal data and runs in CI every time — a
/// source-text check on the guarded files themselves, since their `@Suite(.enabled(if:))` gate
/// means their own assertions never execute here.
struct MeasurementFieldScopeTests {
    private static func source(_ fileName: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("FocusBloxCalibrationTests wertet importance/urgency nicht mehr aus (#118)")
    func focusBloxCalibrationDropsImportanceUrgency() throws {
        let text = try Self.source("FocusBloxCalibrationTests.swift")
        #expect(!text.contains("importanceOutcomes"))
        #expect(!text.contains("urgencyOutcomes"))
    }

    @Test("SelfConsistencyReportTests wertet importance/urgency nicht mehr aus (#118)")
    func selfConsistencyReportDropsImportanceUrgency() throws {
        let text = try Self.source("SelfConsistencyReportTests.swift")
        #expect(!text.contains(#"field: "importance""#))
        #expect(!text.contains(#"field: "urgency""#))
    }
}
