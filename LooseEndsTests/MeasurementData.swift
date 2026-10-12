import Foundation
import Testing

/// The personal, gitignored measurement data, found from any checkout (#135, #149).
///
/// The files live in the main checkout (`docs/reference/` of `/Users/hem/Developer/loose-ends`). A
/// worktree under `.claude/worktrees/<name>` reads them from there when it has no copy of its own:
/// until #135 every worktree needed its own copy, so a new worktree measured nothing, and the only
/// copy once lived in a worktree that `git worktree remove` would have deleted with it.
///
/// `scripts/measurement_status.py` mirrors this lookup and lists the gated suites; it prints after
/// every `sim.sh unit` and in the CI summary which measurements ran and which were skipped for lack
/// of data, because a skipped suite still reads as "Test Succeeded".
enum MeasurementData {
    /// The repository this test file was compiled from: a worktree or the main checkout.
    static var checkout: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// The main checkout a worktree belongs to, or nil when this already is the main checkout.
    static func mainCheckout(of checkout: URL) -> URL? {
        let parts = checkout.standardizedFileURL.pathComponents
        guard let index = parts.lastIndex(of: ".claude"), index > 0,
              index + 2 < parts.count, parts[index + 1] == "worktrees" else { return nil }
        return URL(fileURLWithPath: NSString.path(withComponents: Array(parts[..<index])))
    }

    /// The file under `docs/reference/`: this checkout's own copy first, then the main checkout's.
    /// Without either, the own path, so `fileExists` is false and the gated suite is skipped.
    static func reference(_ name: String, from checkout: URL = checkout) -> URL {
        let own = checkout.appendingPathComponent("docs/reference/\(name)")
        guard !FileManager.default.fileExists(atPath: own.path),
              let main = mainCheckout(of: checkout)?.appendingPathComponent("docs/reference/\(name)"),
              FileManager.default.fileExists(atPath: main.path) else { return own }
        return main
    }

    static var focusBloxCorpus: URL { reference("focusblox-corpus.json") }
    static var selfConsistencyRun: URL { reference("selfconsistency-run.json") }

    static func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }

    /// Why a gated suite did not run, shown next to the skip in the test log.
    static let corpusMissing: Comment = "focusblox-corpus.json fehlt (weder in diesem Arbeitsstand noch im Hauptordner): Messung nicht gelaufen, nicht bestanden (#149)"
}
