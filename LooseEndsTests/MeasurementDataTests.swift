import Foundation
import Testing
@testable import LooseEnds

/// The lookup of the personal measurement data (#135): a worktree finds the main checkout's copy.
/// Runs on a scratch folder, so it also runs in CI, where the real data never exists.
@Suite("Messdaten: Arbeitsstand findet den Hauptordner")
struct MeasurementDataTests {
    @Test("Ein Worktree unter .claude/worktrees gehört zum Ordner darüber, der Hauptordner zu keinem")
    func mainCheckout() {
        let worktree = URL(fileURLWithPath: "/Users/hem/Developer/loose-ends/.claude/worktrees/wiggly-munching-kay")
        #expect(MeasurementData.mainCheckout(of: worktree)?.path == "/Users/hem/Developer/loose-ends")
        #expect(MeasurementData.mainCheckout(of: URL(fileURLWithPath: "/Users/hem/Developer/loose-ends")) == nil)
        #expect(MeasurementData.mainCheckout(of: URL(fileURLWithPath: "/Users/hem/.claude/worktrees")) == nil,
                "ohne Worktree-Namen ist das kein Arbeitsstand")
    }

    @Test("Eigene Kopie vor der des Hauptordners, ohne beide der eigene Pfad")
    func lookupOrder() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("measurement-data-\(UUID().uuidString)")
        defer {
            do { try FileManager.default.removeItem(at: root) } catch { Issue.record(error, "Testordner blieb liegen") }
        }
        let worktree = root.appendingPathComponent(".claude/worktrees/frisch")
        let mainFile = root.appendingPathComponent("docs/reference/focusblox-corpus.json")
        let ownFile = worktree.appendingPathComponent("docs/reference/focusblox-corpus.json")

        #expect(MeasurementData.reference("focusblox-corpus.json", from: worktree).path == ownFile.path,
                "ohne Daten bleibt es beim eigenen Pfad, die Suite wird übersprungen")

        try FileManager.default.createDirectory(at: mainFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: mainFile)
        #expect(MeasurementData.reference("focusblox-corpus.json", from: worktree).path == mainFile.path,
                "ein frischer Worktree findet den Korpus des Hauptordners ohne Handarbeit")

        try FileManager.default.createDirectory(at: ownFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("[]".utf8).write(to: ownFile)
        #expect(MeasurementData.reference("focusblox-corpus.json", from: worktree).path == ownFile.path)
    }
}
