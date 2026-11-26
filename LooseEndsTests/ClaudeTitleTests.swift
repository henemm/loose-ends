import Foundation
import SwiftData
import XCTest
@testable import LooseEnds

/// #953: a task Claude captured keeps its title. Claude is an input channel (Henning, 2026-11-19): what arrives is already
/// worded, so the model never rewrites the title, neither on the first run nor on "Analyze again". The chain runs as on the
/// device: `OrderExecutor` stores the order, `EnrichmentCoordinator` enriches it. Since #982 (ADR-22) the coordinator
/// runs the rules only, so these tests hold that the rule pass keeps the title as well. XCTest, so the QA gate counts it.
@MainActor final class ClaudeTitleTests: XCTestCase {
    /// A sentence without date, importance or context words: only the title rule touches it, and it keeps every word.
    private static let text = "Angebot für die Gartenhütte bei Müller einholen"
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

        await EnrichmentCoordinator(container: store.container).processPending()

        XCTAssertNotNil(task.rulesAppliedAt, "the rule pass ran")
        XCTAssertEqual(task.title, ruleTitle)
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty, "no title revision on a Claude task")
    }

    // MARK: AC-2

    func testAnalyzeAgainKeepsTheTitleOfAClaudeTask() async throws {
        let store = try TestStore()
        let task = try capture(in: store)
        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()

        _ = await coordinator.reanalyze(task)

        XCTAssertEqual(task.title, Self.text)
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty)
    }

    // MARK: AC-5

    func testTaskFromTheAppKeepsItsRuleTitleToo() async throws {
        let store = try TestStore()
        let task = try CaptureService.save(Self.text, via: .app, in: store.context)

        await EnrichmentCoordinator(container: store.container).processPending()

        XCTAssertEqual(task.title, Self.text, "without the model (#982) no channel gets a rewritten title")
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty)
    }

    // MARK: AC-6

    func testTitleClaudeSetKeepsThroughFirstRunAndAnalyzeAgain() async throws {
        let store = try TestStore()
        let task = try capture(["fields": ["title": "Gartenhütte bei Müller anfragen"]], in: store)
        XCTAssertEqual(task.titleSourceRaw, FieldSource.user.rawValue)

        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()
        _ = await coordinator.reanalyze(task)

        XCTAssertEqual(task.title, "Gartenhütte bei Müller anfragen")
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty)
    }
}
