import CryptoKit
import Foundation
import SQLite3
import SwiftData
import Testing
@testable import LooseEnds

/// #88 Schnitt B1b: the export of Henning's own raw sentences. The store is a throwaway file that the real
/// model layer writes (SwiftData, on disk), so the chain "model writes -> export reads -> evaluation loads"
/// is closed by the real thing, not by a setup that hand-writes its starting state. Synthetic texts only.
@Suite("Rohsatz-Export")
struct RawTextExportTests {
    /// What a fixture task carries: raw text, capture time, the current title and duration, and the revisions.
    struct Seed {
        var rawText: String
        var capturedAt: Date
        var title: String?
        var duration: DurationBucket?
        var revisions: [(field: RevisedField, old: String?, new: String?, author: FieldSource, at: Date)] = []
    }

    static let base = Date(timeIntervalSinceReferenceDate: 800_000_000)

    static func at(_ seconds: Double) -> Date { base.addingTimeInterval(seconds) }

    static func scratchDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("rawtext-export-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Writes the seeds through the model layer into `fixture.store` and lets the container go before returning,
    /// so SQLite closes the file cleanly and the export reads a settled store.
    @discardableResult
    static func makeStore(_ seeds: [Seed], in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent("fixture.store")
        let schema = Schema(LooseEndsSchema.models)
        let configuration = ModelConfiguration("fixture", schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        for seed in seeds {
            let task = TaskItem(rawText: seed.rawText)
            task.capturedAt = seed.capturedAt
            task.title = seed.title
            task.duration = seed.duration
            context.insert(task)
            for revision in seed.revisions {
                let entry = Revision(task: task, field: revision.field, oldValue: revision.old,
                                     newValue: revision.new, author: revision.author)
                entry.createdAt = revision.at
                context.insert(entry)
            }
        }
        try context.save()
        withExtendedLifetime(container) {}
        return url
    }

    static func titleEdit(_ old: String?, _ new: String?, by author: FieldSource = .user, at: Double = 10) -> (field: RevisedField, old: String?, new: String?, author: FieldSource, at: Date) {
        (.title, old, new, author, Self.at(at))
    }

    static func durationEdit(_ new: String?, by author: FieldSource = .user, at: Double = 10) -> (field: RevisedField, old: String?, new: String?, author: FieldSource, at: Date) {
        (.duration, nil, new, author, Self.at(at))
    }

    static func rows(_ seeds: [Seed]) throws -> [RawTextExport.Row] {
        let directory = try scratchDirectory()
        let store = try makeStore(seeds, in: directory)
        return try RawTextExport.sentences(fromStoreAt: store)
    }

    // MARK: - AC-1: the chain

    @Test("Kette: Modell schreibt, Export liest, Auswertung lädt")
    func exportLoadsWithRawSentenceDecoderAndCorpusEntries() throws {
        let directory = try Self.scratchDirectory()
        let store = try Self.makeStore([
            Seed(rawText: "Alpha Kiste räumen", capturedAt: Self.at(1), title: "Kiste räumen",
                 revisions: [Self.titleEdit("Alpha Kiste", "Kiste räumen")]),
            Seed(rawText: "Beta Regal streichen", capturedAt: Self.at(2), title: "Beta Regal streichen"),
            Seed(rawText: "Gamma Fenster putzen", capturedAt: Self.at(3), title: nil, duration: .minutes30,
                 revisions: [Self.durationEdit("minutes30")]),
        ], in: directory)
        let out = directory.appendingPathComponent("rawtexts.json")
        let root = directory.appendingPathComponent("repo", isDirectory: true)

        _ = try RawTextExport.run(store: store, out: out, root: root)

        let data = try Data(contentsOf: out)
        let sentences = try RawSentenceColumn.decode(data)
        #expect(sentences.count == 3, "one sentence per task")
        let entries = try Corpus.entries(from: data)
        #expect(entries.count == 3, "the format recognizer takes the file as a raw-sentence list")
    }

    // MARK: - AC-2 to AC-6: the derivation

    @Test("Korrigierter Titel trägt vorher und nachher")
    func correctedTitleCarriesBeforeAndAfter() throws {
        let result = try Self.rows([
            Seed(rawText: "Gamma Fenster putzen morgen", capturedAt: Self.at(1), title: "Fenster putzen",
                 revisions: [Self.titleEdit("Gamma Fenster putzen morgen", "Fenster putzen")]),
        ])
        let row = try #require(result.first)
        #expect(row.titleBefore == "Gamma Fenster putzen morgen")
        #expect(row.titleUser == "Fenster putzen")
        let json = try RawTextExport.encode(result)
        let sentence = try #require(try RawSentenceColumn.decode(json).first)
        #expect(sentence.titleCorrected)
    }

    @Test("Mehrere Korrekturen: erstes alt, letztes neu, nach createdAt statt Speicherreihenfolge")
    func severalRevisionsUseFirstOldAndLastNew() throws {
        // Inserted in the opposite order of their times.
        let result = try Self.rows([
            Seed(rawText: "Delta Garage fegen", capturedAt: Self.at(1), title: "Garage kehren", revisions: [
                Self.titleEdit("Garage fegen", "Garage kehren", at: 30),
                Self.titleEdit("Delta Garage fegen", "Garage fegen", at: 20),
            ]),
        ])
        let row = try #require(result.first)
        #expect(row.titleBefore == "Delta Garage fegen")
        #expect(row.titleUser == "Garage kehren")
    }

    @Test("Unkorrigiert: aktueller Titel, Revisionen anderer Autoren zählen nicht")
    func uncorrectedTaskKeepsCurrentTitleAndIgnoresNonUserRevisions() throws {
        let result = try Self.rows([
            Seed(rawText: "Epsilon Müll rausbringen", capturedAt: Self.at(1), title: "Müll rausbringen", revisions: [
                Self.titleEdit("Epsilon Müll rausbringen", "Müll rausbringen", by: .ai),
                Self.titleEdit("Müll", "Müll rausbringen", by: .rule, at: 20),
            ]),
        ])
        let row = try #require(result.first)
        #expect(row.titleBefore == "Müll rausbringen")
        #expect(row.titleUser == nil)
    }

    @Test("Dauer: letzter Nutzerwert; andere Autoren und leerer Wert lassen das Feld weg")
    func durationFromLastUserRevision() throws {
        let result = try Self.rows([
            Seed(rawText: "Zeta eins", capturedAt: Self.at(1), title: "eins", duration: .hour1, revisions: [
                Self.durationEdit("minutes15", at: 10), Self.durationEdit("hour1", at: 20),
            ]),
        ])
        #expect(try #require(result.first).durationUser == "hour1")
    }

    @Test("Dauer: Modell, Regel und geleerter Wert ergeben kein durationUser")
    func nonUserOrEmptyDurationIsOmitted() throws {
        let result = try Self.rows([
            Seed(rawText: "Eta zwei", capturedAt: Self.at(1), title: "zwei", revisions: [Self.durationEdit("minutes5", by: .ai)]),
            Seed(rawText: "Theta drei", capturedAt: Self.at(2), title: "drei", revisions: [Self.durationEdit("minutes5", by: .rule)]),
            Seed(rawText: "Iota vier", capturedAt: Self.at(3), title: "vier", revisions: [Self.durationEdit(nil)]),
        ])
        #expect(result.count == 3)
        #expect(result.allSatisfy { $0.durationUser == nil })
    }

    @Test("Geleerter Titel: leerer Text statt weggelassen, aber keine Korrektur")
    func clearedTitleIsEmptyTextAndNoCorrection() throws {
        let result = try Self.rows([
            Seed(rawText: "Kappa Wäsche falten", capturedAt: Self.at(1), title: nil,
                 revisions: [Self.titleEdit("Wäsche falten", nil)]),
        ])
        let row = try #require(result.first)
        #expect(row.titleUser == "")
        let sentence = try #require(try RawSentenceColumn.decode(try RawTextExport.encode(result)).first)
        #expect(!sentence.titleCorrected, "an empty title is no correction")
    }

    // MARK: - AC-7: order and ids

    @Test("Sätze nach capturedAt geordnet, Ids 1, 2, 3")
    func sentencesAreOrderedAndNumbered() throws {
        let result = try Self.rows([
            Seed(rawText: "Spät", capturedAt: Self.at(300), title: "Spät"),
            Seed(rawText: "Früh", capturedAt: Self.at(100), title: "Früh"),
            Seed(rawText: "Mitte", capturedAt: Self.at(200), title: "Mitte"),
        ])
        #expect(result.map(\.rawText) == ["Früh", "Mitte", "Spät"])
        #expect(result.map(\.id) == ["1", "2", "3"])
    }

    @Test("Keine App-Id und keine Uuid in der Datei")
    func outputHasNoApplicationIds() throws {
        let result = try Self.rows([
            Seed(rawText: "Lambda eins", capturedAt: Self.at(1), title: "eins"),
            Seed(rawText: "My zwei", capturedAt: Self.at(2), title: "zwei"),
        ])
        let text = try #require(String(data: try RawTextExport.encode(result), encoding: .utf8))
        let uuid = try Regex("[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
        #expect(text.firstMatch(of: uuid) == nil)
    }

    // MARK: - AC-8: read only

    @Test("Der Speicher bleibt unverändert, es entstehen keine Nebendateien")
    func exportLeavesStoreUntouched() throws {
        let directory = try Self.scratchDirectory()
        let store = try Self.makeStore([Seed(rawText: "Ny eins", capturedAt: Self.at(1), title: "eins")], in: directory)
        func digest() throws -> String {
            SHA256.hash(data: try Data(contentsOf: store)).map { String(format: "%02x", $0) }.joined()
        }
        let before = try digest()
        let listing = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()

        _ = try RawTextExport.sentences(fromStoreAt: store)

        #expect(try digest() == before)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted() == listing,
                "no -journal, -wal or -shm file appears")
    }

    // MARK: - AC-9: loud instead of empty

    @Test("Fehlende Datei, keine Datenbank, fehlende Tabellen und keine Aufgaben brechen laut ab")
    func missingFileNotADatabaseMissingTablesAndNoTasksFailLoudly() throws {
        let directory = try Self.scratchDirectory()
        let root = directory.appendingPathComponent("repo", isDirectory: true)
        let out = directory.appendingPathComponent("out.json")
        let existing = Data("alte Datei".utf8)

        // 1 missing file
        let missing = directory.appendingPathComponent("gibt-es-nicht.store")
        try existing.write(to: out)
        #expect(throws: RawTextExport.Failure.self) { try RawTextExport.run(store: missing, out: out, root: root) }
        #expect(try Data(contentsOf: out) == existing, "an existing target stays as it is")

        // 2 not a database
        let notDatabase = directory.appendingPathComponent("text.store")
        try Data("das ist keine Datenbank".utf8).write(to: notDatabase)
        #expect(throws: RawTextExport.Failure.self) { try RawTextExport.run(store: notDatabase, out: out, root: root) }

        // 3 a database without the expected tables
        let foreign = directory.appendingPathComponent("fremd.store")
        try Self.makeForeignDatabase(at: foreign)
        #expect(throws: RawTextExport.Failure.self) { try RawTextExport.run(store: foreign, out: out, root: root) }

        // 4 a store without tasks: no empty list, an error
        let emptyDirectory = try Self.scratchDirectory()
        let empty = try Self.makeStore([], in: emptyDirectory)
        try FileManager.default.removeItem(at: out)
        #expect(throws: RawTextExport.Failure.self) { try RawTextExport.run(store: empty, out: out, root: root) }
        #expect(!FileManager.default.fileExists(atPath: out.path), "no output file after a failure")
    }

    /// A valid SQLite file that has none of the app's tables.
    static func makeForeignDatabase(at url: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
        defer { sqlite3_close(db) }
        guard sqlite3_exec(db, "CREATE TABLE ZSOMETHINGELSE (ZVALUE TEXT); INSERT INTO ZSOMETHINGELSE VALUES ('x');", nil, nil, nil) == SQLITE_OK else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    // MARK: - AC-10: protected target

    @Test("Ziel: docs/reference und außerhalb erlaubt, sonst unter root verweigert")
    func outputPathGuard() throws {
        let directory = try Self.scratchDirectory()
        let root = directory.appendingPathComponent("repo", isDirectory: true)
        let reference = root.appendingPathComponent("docs/reference", isDirectory: true)
        let other = root.appendingPathComponent("other", isDirectory: true)
        let outside = directory.appendingPathComponent("outside", isDirectory: true)
        for folder in [reference, other, outside] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        try FileManager.default.createSymbolicLink(at: reference.appendingPathComponent("escape"), withDestinationURL: other)
        try FileManager.default.createSymbolicLink(at: outside.appendingPathComponent("into-repo"), withDestinationURL: other)

        try RawTextExport.checkTarget(reference.appendingPathComponent("loose-ends-rawtexts.json"), root: root)
        try RawTextExport.checkTarget(outside.appendingPathComponent("x.json"), root: root)

        for refused in [
            other.appendingPathComponent("x.json"),
            root.appendingPathComponent("x.json"),
            reference.appendingPathComponent("../other/x.json"),
            reference.appendingPathComponent("escape/x.json"),
            outside.appendingPathComponent("into-repo/x.json"),
        ] {
            #expect(throws: RawTextExport.Failure.self, "\(refused.path) is refused") {
                try RawTextExport.checkTarget(refused, root: root)
            }
        }

        // run writes nothing when the target is refused
        let store = try Self.makeStore([Seed(rawText: "Xi eins", capturedAt: Self.at(1), title: "eins")], in: directory)
        let target = other.appendingPathComponent("x.json")
        #expect(throws: RawTextExport.Failure.self) { try RawTextExport.run(store: store, out: target, root: root) }
        #expect(!FileManager.default.fileExists(atPath: target.path))
    }

    // MARK: - AC-11: no sentences in messages

    @Test("Fehlertexte und Zusammenfassung tragen keine Sätze")
    func messagesCarryNoSentences() throws {
        let marker = "ZEBRAKUCHEN"
        let directory = try Self.scratchDirectory()
        let root = directory.appendingPathComponent("repo", isDirectory: true)
        let out = directory.appendingPathComponent("out.json")

        let notDatabase = directory.appendingPathComponent("text.store")
        try Data("\(marker) \(marker)".utf8).write(to: notDatabase)
        do {
            _ = try RawTextExport.run(store: notDatabase, out: out, root: root)
            Issue.record("a text file must not export")
        } catch let failure as RawTextExport.Failure {
            #expect(!failure.message.contains(marker))
        }

        let rows = try Self.rows([
            Seed(rawText: "\(marker) räumen", capturedAt: Self.at(1), title: "\(marker)",
                 revisions: [Self.titleEdit("\(marker) räumen", "\(marker)"), Self.durationEdit("minutes5")]),
        ])
        let summary = RawTextExport.summary(rows)
        #expect(!summary.contains(marker))
        #expect(summary.contains("1"), "the numbers are in")
    }

    // MARK: - Helpers for the stage 2 run (active only with the variables set)

    static let fixtureDirectory = ProcessInfo.processInfo.environment["LOOSEENDS_EXPORT_FIXTURE_DIR"]
    static let scriptResult = ProcessInfo.processInfo.environment["LOOSEENDS_EXPORT_RESULT"]

    @Test("Hilfstest: legt den Kunst-Speicher fixture.store für den Skriptlauf ab",
          .enabled(if: RawTextExportTests.fixtureDirectory != nil))
    func writeFixtureStoreForScriptRun() throws {
        let directory = URL(fileURLWithPath: try #require(Self.fixtureDirectory), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try Self.makeStore([
            Seed(rawText: "Omikron Kisten stapeln morgen", capturedAt: Self.at(1), title: "Kisten stapeln",
                 revisions: [Self.titleEdit("Omikron Kisten stapeln morgen", "Kisten stapeln"), Self.durationEdit("minutes15")]),
            Seed(rawText: "Pi Lampe wechseln", capturedAt: Self.at(2), title: "Lampe wechseln"),
        ], in: directory)
        #expect(FileManager.default.fileExists(atPath: store.path))
    }

    @Test("Hilfstest: lädt die vom Skript geschriebene Datei mit dem echten Leser",
          .enabled(if: RawTextExportTests.scriptResult != nil))
    func readScriptResult() throws {
        let file = URL(fileURLWithPath: try #require(Self.scriptResult))
        let sentences = try RawSentenceColumn.decode(try Data(contentsOf: file))
        #expect(sentences.count == 2)
        #expect(sentences.first?.durationUser == "minutes15")
    }
}
