import Foundation
import SwiftData
import XCTest
@testable import LooseEnds
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The occasions for the pass for Claude (#795 S3b-1): start and becoming active send then pull, saves and finished
/// imports only send, debounced, and a send never overlaps another. The actions are handed in and counted; the
/// notifications are the system's own names, posted by hand. Only AC-11 builds a real `ClaudeSync`, without a session.
@MainActor final class ClaudeSyncTriggerTests: XCTestCase {
    /// Every call of the handed-in actions in order: `send` when a send begins, `sent` when it ends, `pull` when a
    /// pull begins. A send is held open for `sendDelay`.
    @MainActor final class Calls {
        var entries: [String] = []
        var sendDelay: Duration = .zero
        private(set) var running = 0
        private(set) var overlapped = false

        var sends: Int { entries.filter { $0 == "send" }.count }
        var pulls: Int { entries.filter { $0 == "pull" }.count }

        func send() async {
            running += 1
            if running > 1 { overlapped = true }
            entries.append("send")
            if sendDelay > .zero {
                do {
                    try await Task.sleep(for: sendDelay)
                } catch {
                    entries.append("cancelled")
                }
            }
            entries.append("sent")
            running -= 1
        }

        func pull() async {
            entries.append("pull")
        }
    }

    private static let debounce: Duration = .milliseconds(50)
    private static let startPass = ["send", "sent", "pull"]

    private static var becameActive: Notification.Name {
        #if canImport(UIKit)
        UIApplication.didBecomeActiveNotification
        #else
        NSApplication.didBecomeActiveNotification
        #endif
    }

    private func make(_ calls: Calls) -> ClaudeSyncTrigger {
        ClaudeSyncTrigger(send: { await calls.send() }, pull: { await calls.pull() }, debounce: Self.debounce)
    }

    private func becomeActive() {
        NotificationCenter.default.post(name: Self.becameActive, object: nil)
    }

    /// A real save of an in-memory store posts `ModelContext.didSave` the way the app does.
    private func save(_ store: TestStore, _ text: String = "Milch kaufen") throws {
        store.context.insert(TaskItem(rawText: text))
        try store.context.save()
    }

    private func importEvent(ended: Date?, error: String? = nil, kind: SyncStatus.Kind = .imported) -> SyncStatus.Event {
        SyncStatus.Event(kind: kind, endDate: ended, errorMessage: error)
    }

    /// Waits for a condition with a deadline, never a fixed long sleep.
    private func waitUntil(_ what: String, timeout: Duration = .seconds(3),
                           _ condition: @MainActor () -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("timed out waiting for: \(what)")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Long enough past the debounce that a call still to come would have come.
    private func settle() async throws {
        try await Task.sleep(for: .milliseconds(300))
    }

    private func started(_ calls: Calls) async throws -> ClaudeSyncTrigger {
        let trigger = make(calls)
        trigger.start()
        try await waitUntil("start pass") { calls.entries == Self.startPass }
        return trigger
    }

    // MARK: AC-1 bis AC-3

    func testStartSendsThenPullsOnce() async throws {
        let calls = Calls()
        let trigger = try await started(calls)
        try await settle()
        XCTAssertEqual(calls.entries, Self.startPass)
        _ = trigger
    }

    func testPullWaitsForSendToFinish() async throws {
        let calls = Calls()
        calls.sendDelay = .milliseconds(200)
        let trigger = make(calls)
        trigger.start()
        try await waitUntil("send began") { calls.entries == ["send"] }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(calls.entries, ["send"], "pull began while send was still running")
        try await waitUntil("start pass") { calls.entries == Self.startPass }
    }

    func testSecondStartChangesNothing() async throws {
        let calls = Calls()
        let trigger = try await started(calls)
        trigger.start()
        try await settle()
        XCTAssertEqual(calls.entries, Self.startPass)
        becomeActive()
        try await waitUntil("one more pass") { calls.entries.count == 6 }
        try await settle()
        XCTAssertEqual(calls.entries, Self.startPass + Self.startPass)
    }

    // MARK: AC-4

    func testBecomingActiveSendsThenPulls() async throws {
        let calls = Calls()
        let trigger = try await started(calls)
        becomeActive()
        try await waitUntil("pass after becoming active") { calls.entries.count == 6 }
        try await settle()
        XCTAssertEqual(calls.entries, Self.startPass + Self.startPass)
        _ = trigger
    }

    // MARK: AC-5, AC-6

    func testSavesAreDebouncedToOneSendAndNeverPull() async throws {
        let calls = Calls()
        let store = try TestStore()
        let trigger = try await started(calls)
        for index in 1...5 { try save(store, "Aufgabe \(index)") }
        try await waitUntil("debounced send") { calls.sends == 2 }
        try await settle()
        XCTAssertEqual(calls.entries, Self.startPass + ["send", "sent"])
        XCTAssertEqual(calls.pulls, 1)
        _ = trigger
    }

    func testSaveSendsOnlyAfterTheDebounce() async throws {
        let calls = Calls()
        let store = try TestStore()
        let trigger = ClaudeSyncTrigger(send: { await calls.send() }, pull: { await calls.pull() },
                                        debounce: .milliseconds(250))
        trigger.start()
        try await waitUntil("start pass") { calls.entries == Self.startPass }
        try save(store)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(calls.sends, 1, "the save sent before the debounce ran out")
        try save(store, "Noch eine")
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(calls.sends, 1, "a second save inside the debounce did not move the send")
        try await waitUntil("debounced send") { calls.sends == 2 }
        try await settle()
        XCTAssertEqual(calls.sends, 2)
        XCTAssertEqual(calls.pulls, 1)
    }

    // MARK: AC-7

    func testOnlyAFinishedImportSends() async throws {
        let silentEvents: [(String, SyncStatus.Event)] = [
            ("unfinished import", importEvent(ended: nil)),
            ("failed import", importEvent(ended: Date(), error: "offline")),
            ("export", importEvent(ended: Date(), kind: .exported)),
        ]
        for (name, event) in silentEvents {
            let calls = Calls()
            let trigger = try await started(calls)
            trigger.handle(event)
            try await settle()
            XCTAssertEqual(calls.entries, Self.startPass, "\(name) reached an action")
        }

        let calls = Calls()
        let trigger = try await started(calls)
        trigger.handle(importEvent(ended: Date()))
        try await waitUntil("send after a finished import") { calls.sends == 2 }
        try await settle()
        XCTAssertEqual(calls.entries, Self.startPass + ["send", "sent"])
    }

    // MARK: AC-8

    func testWithoutStartNothingReacts() async throws {
        let calls = Calls()
        let store = try TestStore()
        let trigger = make(calls)
        becomeActive()
        try save(store)
        trigger.handle(importEvent(ended: Date()))
        try await settle()
        XCTAssertEqual(calls.entries, [])
    }

    // MARK: AC-9

    func testPullNeverFollowsSaveOrImport() async throws {
        let calls = Calls()
        let store = try TestStore()
        let trigger = try await started(calls)
        try save(store)
        trigger.handle(importEvent(ended: Date()))
        try save(store, "Zweite")
        try await waitUntil("debounced send") { calls.sends >= 2 }
        trigger.handle(importEvent(ended: Date()))
        try await waitUntil("send after the import") { calls.sends >= 3 }
        try await settle()
        XCTAssertEqual(calls.pulls, 1, "a pull followed a save or an import")
    }

    // MARK: AC-10

    func testWithoutClosuresItIsSilentUnderTests() async throws {
        XCTAssertTrue(ModelContainerFactory.isRunningTests)
        let store = try TestStore()
        let trigger = ClaudeSyncTrigger(debounce: Self.debounce)
        trigger.start()
        becomeActive()
        try save(store)
        trigger.handle(importEvent(ended: Date()))
        try await settle()
    }

    // MARK: AC-14

    func testSaveDuringASendSendsOnceMoreAfterIt() async throws {
        let calls = Calls()
        let store = try TestStore()
        let trigger = try await started(calls)
        calls.sendDelay = .milliseconds(300)
        try save(store)
        try await waitUntil("slow send running") { calls.running == 1 }
        for index in 1...3 { try save(store, "Während \(index)") }
        try await waitUntil("send queued after the running one") { calls.sends == 3 && calls.running == 0 }
        try await settle()
        XCTAssertFalse(calls.overlapped, "two sends ran at the same time")
        XCTAssertEqual(calls.entries, Self.startPass + ["send", "sent", "send", "sent"])

        let before = calls.entries.count
        try save(store, "Noch einmal")
        try await waitUntil("slow send running again") { calls.running == 1 }
        becomeActive()
        try await waitUntil("pull after the queued send") { calls.pulls == 2 }
        try await settle()
        XCTAssertFalse(calls.overlapped, "two sends ran at the same time")
        XCTAssertEqual(Array(calls.entries.dropFirst(before)), ["send", "sent", "send", "sent", "pull"])
    }

    // MARK: AC-11

    func testWiringRuleNeedsAnAccount() async throws {
        let store = try TestStore()
        XCTAssertNil(ClaudeSyncTrigger.forApp(account: nil, container: store.container))

        for silent in [false, true] {
            let wire = ClaudeSyncTests.FakeTransport()
            let account = AccountState(client: ServiceClient(baseURL: ClaudeSyncTests.base, transport: wire),
                                       store: InMemorySessionStore())
            XCTAssertEqual(account.status, .signedOut)
            let trigger = try XCTUnwrap(
                ClaudeSyncTrigger.forApp(account: account, container: store.container, silent: silent)
            )
            trigger.start()
            becomeActive()
            try save(store, "Ohne Sitzung \(silent)")
            try await Task.sleep(for: .milliseconds(2_400))
            let requests = await wire.requests
            XCTAssertTrue(requests.isEmpty, "silent: \(silent) sent \(requests.count) requests without a session")
        }
    }
}
