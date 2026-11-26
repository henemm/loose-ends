import Foundation
import SwiftData
import XCTest
@testable import LooseEnds

/// #950: a task the user typed keeps its title. Whoever types has worded the task already (Henning, 2026-11-20), so the
/// model never rewrites the title of a `.keyboard` task, neither on the first run nor on "Analyze again"; like Claude's
/// tasks (#953). The chain runs as on the device: `CaptureService` stores the task, `EnrichmentCoordinator` enriches it.
/// Since #982 (ADR-22) the coordinator runs the rules only; these tests hold that the title stays. XCTest, so the QA gate
/// counts it.
@MainActor final class KeyboardTitleTests: XCTestCase {
    /// A sentence without date, importance or context words: only the title rule touches it, and it keeps every word.
    private static let text = "Angebot für die Gartenhütte bei Müller einholen"
    private func typed(in store: TestStore, via channel: CaptureChannel = .keyboard) throws -> TaskItem {
        let task = try CaptureService.save(Self.text, via: channel, in: store.context)
        try store.context.save()
        XCTAssertEqual(task.capturedVia, channel)
        return task
    }

    private func aiTitleRevisions(on task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.field == .title && $0.author == .ai }
    }

    // MARK: AC-1

    func testFirstRunKeepsTheTitleOfATypedTask() async throws {
        let store = try TestStore()
        let task = try typed(in: store)
        let ruleTitle = task.title
        XCTAssertEqual(ruleTitle, Self.text, "the rule title keeps every word of this sentence")

        await EnrichmentCoordinator(container: store.container).processPending()

        XCTAssertNotNil(task.rulesAppliedAt, "the rule pass ran")
        XCTAssertEqual(task.title, ruleTitle)
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty, "no title revision on a typed task")
    }

    // MARK: AC-2

    func testAnalyzeAgainKeepsTheTitleOfATypedTask() async throws {
        let store = try TestStore()
        let task = try typed(in: store)
        let coordinator = EnrichmentCoordinator(container: store.container)
        await coordinator.processPending()

        _ = await coordinator.reanalyze(task)

        XCTAssertEqual(task.title, Self.text)
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty)
    }

    // MARK: AC-5

    func testSpokenAndWatchTasksKeepTheirRuleTitleToo() async throws {
        let store = try TestStore()
        let spoken = try typed(in: store, via: .app)
        let watch = try typed(in: store, via: .watch)

        await EnrichmentCoordinator(container: store.container).processPending()

        for task in [spoken, watch] {
            XCTAssertEqual(task.title, Self.text, "\(task.capturedVia): without the model (#982) the rule title stays")
            XCTAssertTrue(aiTitleRevisions(on: task).isEmpty)
        }
    }

    func testClaudeTaskStillKeepsItsTitle() async throws {
        let store = try TestStore()
        let json: [String: Any] = ["kind": "capture", "text": Self.text, "version": 1, "id": UUID().uuidString]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        let result = try OrderExecutorTests.run(try TranscriptCodec.decode(Order.self, from: data), in: store)
        let task = try XCTUnwrap(try store.context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == result.taskID })
        XCTAssertEqual(task.capturedVia, .claude)

        await EnrichmentCoordinator(container: store.container).processPending()

        XCTAssertEqual(task.title, Self.text)
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty)
    }

    // MARK: AC-6

    func testKeyboardRawValueRoundTripsAndUnknownReadsAsApp() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: Self.text, capturedVia: .keyboard)
        store.context.insert(task)
        try store.context.save()
        XCTAssertEqual(task.capturedViaRaw, "keyboard")
        XCTAssertEqual(task.capturedVia, .keyboard)

        task.capturedViaRaw = "somethingNewer"
        XCTAssertEqual(task.capturedVia, .app, "an unknown channel from a newer build reads as the app")
    }

    // MARK: AC-7

    func testForTypingTurnsOnlyAnUnheardAppCaptureIntoKeyboard() {
        XCTAssertEqual(CaptureChannel.app.forTyping(heard: false), .keyboard)
        XCTAssertEqual(CaptureChannel.app.forTyping(heard: true), .app, "spoken, then corrected, counts as spoken")
        XCTAssertEqual(CaptureChannel.share.forTyping(heard: false), .share)
        XCTAssertTrue(CaptureChannel.keyboard.keepsWording)
        XCTAssertTrue(CaptureChannel.claude.keepsWording)
        XCTAssertFalse(CaptureChannel.app.keepsWording)
        XCTAssertFalse(CaptureChannel.watch.keepsWording)
    }
}
