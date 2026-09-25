import Foundation

/// The convention-test corpus for Annahme B1 (Spike #69, Ticket A): ten word→context patterns,
/// each with three prior corrections and one unseen probe.
///
/// The sentences are newly written, never copied from the gitignored FocusBlox export — only the
/// *shape* of the pairings (which core word Henning kept filing under which context) comes from it.
/// Word→project patterns are deliberately absent: `ZLOCALTASK` has no project column, so there is
/// no truth for them (see the spec, "Zentraler Befund").
///
/// Compiled into the test bundles and the lab app; the JSON sits next to this file and is bundled
/// as a resource.
enum ConventionCorpus {
    static let fileName = "convention-corpus"

    struct Pattern: Decodable, Sendable, Identifiable {
        /// The core word of the pattern, which is what the report names per row.
        var id: String
        var corrections: [Correction]
        var probe: Probe

        /// One past note whose context Henning already settled.
        struct Correction: Decodable, Sendable {
            var text: String
            var context: String
        }

        /// The fourth, unseen note and the context a correct prediction has to name.
        struct Probe: Decodable, Sendable {
            var text: String
            var expectedContext: String
        }
    }

    // MARK: - Loading

    /// Bundled as a test resource on device; on the Mac the file next to this source also works,
    /// which keeps the corpus usable from a plain script run (same fallback as `Corpus.load`).
    static func load(fileName: String = ConventionCorpus.fileName) throws -> [Pattern] {
        let bundled = Bundle(for: CorpusAnchor.self).url(forResource: fileName, withExtension: "json")
        let onDisk = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("\(fileName).json")
        guard let url = bundled ?? (FileManager.default.fileExists(atPath: onDisk.path) ? onDisk : nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Pattern].self, from: Data(contentsOf: url))
    }
}
