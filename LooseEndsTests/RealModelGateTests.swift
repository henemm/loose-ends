import Foundation
import Testing

/// Guards the gate of `RealModelTests` (#531) where those tests never run: in CI. Like
/// `MeasurementFieldScopeTests`, a source-text check, since the gated suite's own assertions never
/// execute here.
struct RealModelGateTests {
    private static let testsFolder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

    @Test("The real-model suite is gated on the variable and on the model")
    func suiteIsGated() throws {
        let text = try String(contentsOf: Self.testsFolder.appendingPathComponent("RealModelTests.swift"), encoding: .utf8)
        #expect(text.contains(".enabled(if: RealModel.isRequested"))
        #expect(text.contains(".enabled(if: RealModel.isAvailable"))
    }

    @Test("No CI workflow sets LOOSEENDS_REAL_MODEL")
    func ciNeverAsksForTheRealModel() throws {
        let workflows = Self.testsFolder.deletingLastPathComponent().appendingPathComponent(".github/workflows")
        let files = try FileManager.default.contentsOfDirectory(at: workflows, includingPropertiesForKeys: nil)
            .filter { ["yml", "yaml"].contains($0.pathExtension) }
        #expect(!files.isEmpty)
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(!text.contains("LOOSEENDS_REAL_MODEL"), "\(file.lastPathComponent)")
        }
    }
}
