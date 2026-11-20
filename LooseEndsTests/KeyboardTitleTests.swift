import Foundation
import SwiftData
import XCTest
@testable import LooseEnds

/// #950: a task the user typed keeps its title. Whoever types has worded the task already (Henning, 2026-11-20), so the
/// model never rewrites the title of a `.keyboard` task, neither on the first run nor on "Analyze again"; like Claude's
/// tasks (#953). The chain runs as on the device: `CaptureService` stores the task, `EnrichmentCoordinator` enriches it;
/// only the model is the stub. XCTest, so the QA gate counts it.
@MainActor final class KeyboardTitleTests: XCTestCase {
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

        let stub = StubEnricher(draft: draft(title: Self.modelTitle))
        await EnrichmentCoordinator(enricher: stub, container: store.container).processPending()

        XCTAssertEqual(stub.calls, 1, "the task still goes to the model, only the title is not its own")
        XCTAssertEqual(task.title, ruleTitle)
        XCTAssertTrue(aiTitleRevisions(on: task).isEmpty, "the model writes no title revision on a typed task")
    }

    // MARK: AC-2

    func testAnalyzeAgainKeepsTheTitleOfATypedTask() async throws {
        let store = try TestStore()
        let task = try typed(in: store)
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

    func testTypedTaskEndsActive() async throws {
        let store = try TestStore()
        let task = try typed(in: store)
        XCTAssertEqual(task.status, .unprocessed)

        let stub = StubEnricher(draft: draft(title: Self.modelTitle))
        await EnrichmentCoordinator(enricher: stub, container: store.container).processPending()

        XCTAssertEqual(task.status, .active, "a typed task has its title already, it never hangs in unverified")
        XCTAssertEqual(task.title, Self.text)
    }

    // MARK: AC-4

    func testModelStillSetsTheDurationOfATypedTask() async throws {
        let store = try TestStore()
        let task = try typed(in: store)
        XCTAssertNil(task.duration)

        let stub = StubEnricher(draft: draft(title: Self.modelTitle, duration: .minutes30))
        await EnrichmentCoordinator(enricher: stub, container: store.container).processPending()

        XCTAssertEqual(task.duration, .minutes30, "only the title is taken from the model, the duration stays its own")
        XCTAssertEqual(task.durationSourceRaw, FieldSource.ai.rawValue)
        XCTAssertEqual(task.title, Self.text)
        XCTAssertEqual(task.status, .active)
    }

    // MARK: AC-5

    func testSpokenAndWatchTasksAreStillRefinedByTheModel() async throws {
        let store = try TestStore()
        let spoken = try typed(in: store, via: .app)
        let watch = try typed(in: store, via: .watch)

        let stub = StubEnricher(draft: draft(title: Self.modelTitle))
        await EnrichmentCoordinator(enricher: stub, container: store.container).processPending()

        for task in [spoken, watch] {
            XCTAssertEqual(task.title, Self.modelTitle, "\(task.capturedVia) keeps the model's title")
            XCTAssertEqual(aiTitleRevisions(on: task).count, 1)
            XCTAssertEqual(task.status, .active)
        }
    }

    func testClaudeTaskStillKeepsItsTitle() async throws {
        let store = try TestStore()
        let json: [String: Any] = ["kind": "capture", "text": Self.text, "version": 1, "id": UUID().uuidString]
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        let result = try OrderExecutorTests.run(try TranscriptCodec.decode(Order.self, from: data), in: store)
        let task = try XCTUnwrap(try store.context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == result.taskID })
        XCTAssertEqual(task.capturedVia, .claude)

        let stub = StubEnricher(draft: draft(title: Self.modelTitle))
        await EnrichmentCoordinator(enricher: stub, container: store.container).processPending()

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
