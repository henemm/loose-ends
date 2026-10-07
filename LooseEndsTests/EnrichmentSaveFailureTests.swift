import Foundation
import SQLite3
import SwiftData
import Testing
@testable import LooseEnds

/// A failed save in the catch-up pass stays with its one task (#100, F001 from #95): the pass goes
/// on, the next task is saved, the failed one stays unprocessed for the next pass.
///
/// The in-memory store of the other tests has no constraint a save could break, so this test puts
/// the store on a real SQLite file, past `ModelContainerFactory`, and lets SQLite itself refuse one
/// task: a trigger aborts every revision written for it. Nothing in the product code is injected.
@Suite("Enrichment: save failure (#100)") @MainActor struct EnrichmentSaveFailureTests {
    private static let blockedText = "Steuerbescheid morgen prüfen"
    private static let laterText = "Rasen mähen morgen"

    /// Refuses every revision of the blocked task. Its due-date rule writes one, so its save fails.
    /// An insert, not an update: Core Data reads a refused update as an optimistic-locking conflict,
    /// retries it and ends the process instead of throwing (first CI run of #247).
    private static let refuseBlocked = """
        CREATE TRIGGER refuse_blocked BEFORE INSERT ON ZREVISION
        WHEN NEW.ZTASK = (SELECT Z_PK FROM ZTASKITEM WHERE ZRAWTEXT = '\(blockedText)')
        BEGIN SELECT RAISE(ABORT, 'refused by test'); END;
        """

    /// The container on a file of its own; the URL so SQLite can open the same file.
    private func fileStore() throws -> (container: ModelContainer, url: URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("save-failure-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("store.sqlite")
        let schema = Schema(LooseEndsSchema.models)
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        container.mainContext.autosaveEnabled = false
        return (container, url)
    }

    /// Runs one statement on the store file through a second SQLite connection.
    private func execute(_ sql: String, on url: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw SQLiteFailure(message: "open failed")
        }
        defer { sqlite3_close(db) }
        var message: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &message) == SQLITE_OK else {
            let text = message.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(message)
            throw SQLiteFailure(message: text)
        }
    }

    private struct SQLiteFailure: Error { let message: String }

    private func persisted(_ rawText: String, in container: ModelContainer) throws -> TaskItem? {
        let fresh = ModelContext(container)
        return try fresh.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.rawText == rawText })).first
    }

    @Test("A task whose save fails is skipped; the next one is processed and saved")
    func failedSaveSkipsOnlyThatTask() async throws {
        let store = try fileStore()
        let context = store.container.mainContext
        let blocked = TaskItem(rawText: Self.blockedText)
        blocked.capturedAt = Date(timeIntervalSince1970: 1_790_000_000)
        let later = TaskItem(rawText: Self.laterText)
        later.capturedAt = blocked.capturedAt.addingTimeInterval(60)
        context.insert(blocked)
        context.insert(later)
        try context.save()

        try execute(Self.refuseBlocked, on: store.url)

        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(unavailableReason: "Kein Modell"), container: store.container)
        await coordinator.processPending()

        let savedLater = try #require(try persisted(Self.laterText, in: store.container))
        #expect(savedLater.rulesAppliedAt != nil, "The pass went on and saved the next task")
        #expect(savedLater.dueDate != nil, "The rule step of the next task reached the store")
        let savedBlocked = try #require(try persisted(Self.blockedText, in: store.container))
        #expect(savedBlocked.rulesAppliedAt == nil, "The refused task stays unprocessed in the store")
    }

    @Test("The refused task is processed by the next pass once its save works again")
    func refusedTaskWaitsForTheNextPass() async throws {
        let store = try fileStore()
        let context = store.container.mainContext
        let blocked = TaskItem(rawText: Self.blockedText)
        context.insert(blocked)
        try context.save()
        try execute(Self.refuseBlocked, on: store.url)
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(unavailableReason: "Kein Modell"), container: store.container)
        await coordinator.processPending()
        #expect(try #require(try persisted(Self.blockedText, in: store.container)).rulesAppliedAt == nil)

        try execute("DROP TRIGGER refuse_blocked;", on: store.url)
        await coordinator.processPending()

        #expect(try #require(try persisted(Self.blockedText, in: store.container)).rulesAppliedAt != nil)
    }
}
