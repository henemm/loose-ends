import Foundation
import SwiftData
import XCTest
@testable import LooseEnds

/// #953: a task Claude captured keeps its title. Claude is an input channel (Henning, 2026-11-19): what arrives is already
/// worded, so the model never rewrites the title, neither on the first run nor on "Analyze again". The chain runs as on the
/// device: `OrderExecutor` stores the order, `EnrichmentCoordinator` enriches it; only the model is the stub.
/// XCTest, so the QA gate counts it.
@MainActor final class ClaudeTitleTests: XCTestCase {
    /// A sentence without date, importance or context words: only the title rule touches it, and it keeps every word.
    private static let text = "Angebot für die Gartenhütte bei Müller einholen"
    /// What the real model regularly returns for it (#202): almost the same text, shortened.
    private static let modelTitle = "Angebot Gartenhütte einholen"

    private func draft(title: String?, duration: DurationBucket? = nil) -> EnrichmentDraft {
        var draft = EnrichmentDraft()
        draft.title = title.map { EnrichmentDraft.Guess($0, confidence: 0.9, reason: "Stub.") }
        draft.duration = duration.map { EnrichmentDraft.Guess($0, confidence: 0.9, reason: "Stub.") }
        return draft
    }

    private func capture(_ json: [String: Any] = [:], in store: TestStore) throws -> TaskItem {
        var json = json
        json["kind"] = "capture"
        json["text"] = json["text"] ?? Self.text
        json["version"] = 1
        json["id"] = UUID().uuidString
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        let order = try TranscriptCodec.decode(Order.self, from: data)
        let result = try OrderExecutorTests.run(order, in: store)
        XCTAssertEqual(result.outcome, .done)
        let task = try XCTUnwrap(try store.context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == result.taskID })
        XCTAssertEqual(task.capturedVia, .claude)
        return task
    }

    private func aiTitleRevisions(on task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.field == .title && $0.author == .ai }
    }

    // MARK: AC-1

    func testFirstRunKeepsTheTitleOfAClaudeTask() async throws {
        let store = try TestStore()
        let task = try capture(in: store)
        let ruleTitle = task.title
        XCTAssertEqual(ruleTitle, Self.text, "the rule title keeps every word of this sentence")

        let stub = StubEnricher(draft: draft(title: Self.modelTitle))
        await EnrichmentCoordinator(enricher: stub, container: store.container).processPending()

        XCTAssertEqual(stub.calls, 1, "the task still goes to the model, only the title is not its own")
        XCTAssertEqual(task.title, ruleTitle)
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty, "the model writes no title revision on a Claude task")
    }

    // MARK: AC-2

    func testAnalyzeAgainKeepsTheTitleOfAClaudeTask() async throws {
        let store = try TestStore()
        let task = try capture(in: store)
        let stub = StubEnricher(draft: draft(title: Self.modelTitle))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()

        stub.draft = draft(title: "Gartenhütte: Angebot einholen")
        _ = await coordinator.reanalyze(task)

        XCTAssertEqual(stub.calls, 2)
        XCTAssertEqual(task.title, Self.text)
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty)
    }

    // MARK: AC-3

    func testClaudeTaskEndsActiveEvenWithoutAModelTitle() async throws {
        let store = try TestStore()
        let task = try capture(in: store)
        XCTAssertEqual(task.status, .unprocessed)

        let stub = StubEnricher(draft: draft(title: nil))
        await EnrichmentCoordinator(enricher: stub, container: store.container).processPending()

        XCTAssertEqual(task.status, .active, "a Claude task has its title already, it never hangs in unverified")
        XCTAssertEqual(task.title, Self.text)
    }

    // MARK: AC-4

    func testModelStillSetsTheDurationOfAClaudeTask() async throws {
        let store = try TestStore()
        let task = try capture(in: store)
        XCTAssertNil(task.duration)

        let stub = StubEnricher(draft: draft(title: Self.modelTitle, duration: .minutes30))
        await EnrichmentCoordinator(enricher: stub, container: store.container).processPending()

        XCTAssertEqual(task.duration, .minutes30, "only the title is taken from the model, the duration stays its own")
        XCTAssertEqual(task.durationSourceRaw, FieldSource.ai.rawValue)
        XCTAssertEqual(task.title, Self.text)
        XCTAssertEqual(task.status, .active)
    }

    // MARK: AC-5

    func testTaskFromTheAppIsStillRefinedByTheModel() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: Self.text, capturedVia: .app)
        store.context.insert(task)
        try store.context.save()

        let stub = StubEnricher(draft: draft(title: Self.modelTitle))
        await EnrichmentCoordinator(enricher: stub, container: store.container).processPending()

        XCTAssertEqual(task.title, Self.modelTitle, "the exception is the channel Claude, the app keeps the model's title")
        XCTAssertEqual(aiTitleRevisions(on: task).count, 1)
        XCTAssertEqual(task.status, .active)
    }

    // MARK: AC-6

    func testTitleClaudeSetKeepsAgainstTheModel() async throws {
        let store = try TestStore()
        let task = try capture(["fields": ["title": "Gartenhütte bei Müller anfragen"]], in: store)
        XCTAssertEqual(task.titleSourceRaw, FieldSource.user.rawValue)

        let stub = StubEnricher(draft: draft(title: Self.modelTitle))
        let coordinator = EnrichmentCoordinator(enricher: stub, container: store.container)
        await coordinator.processPending()
        _ = await coordinator.reanalyze(task)

        XCTAssertEqual(task.title, "Gartenhütte bei Müller anfragen")
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty)
    }
}
