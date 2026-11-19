import Foundation
import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import LooseEnds

/// The app's side of the silent wake-up (#795 S5c-2a): which notification is ours, the wake against its deadline,
/// finished exactly once, the device token through the session, and one registration once signed in.
/// The wire is the stand-in of `DeviceRegistrationTests`; nothing here reaches the network or APNs.
@MainActor final class PushWakeUpTests: XCTestCase {
    typealias Wire = DeviceRegistrationTests.Wire

    /// A wake that hangs until `release()`; counts its calls.
    @MainActor final class HangingWake {
        private var waiters: [CheckedContinuation<Void, Never>] = []
        private(set) var calls = 0
        private(set) var returned = 0

        func wake() async {
            calls += 1
            await withCheckedContinuation { waiters.append($0) }
            returned += 1
        }

        func release() {
            let open = waiters
            waiters = []
            open.forEach { $0.resume() }
        }
    }

    /// Counts the requests for a device token.
    @MainActor final class RemoteRegistrations {
        var count = 0
    }

    private static let tokenBytes = Data((0..<32).map { UInt8($0) })
    private static let tokenHex = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    private static let device = UUID(uuidString: "6F1C2A3B-4D5E-4F60-8A7B-9C0D1E2F3A4B")!

    private func account(_ wire: Wire, token: String? = "session-token") -> AccountState {
        AccountState(client: ServiceClient(baseURL: URL(string: "https://example.test")!, transport: wire),
                     store: InMemorySessionStore(token: token))
    }

    private func node(account: AccountState,
                      wake: @escaping @MainActor () async -> Void = {},
                      remote: RemoteRegistrations = RemoteRegistrations(),
                      deadline: Duration = .seconds(20)) -> PushWakeUp {
        let registration = DeviceRegistration(account: account, device: { Self.device }, environment: .sandbox)
        return PushWakeUp(account: account, registration: registration, wake: wake,
                          registerForRemote: { remote.count += 1 }, deadline: deadline)
    }

    /// Waits for a condition with a deadline, never a fixed long sleep.
    private func waitUntil(_ what: String, timeout: Duration = .seconds(3),
                           _ condition: @MainActor () async -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !(await condition()) {
            guard clock.now < deadline else {
                XCTFail("timed out waiting for: \(what)")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: AC-1

    func testIsWakeOnlyWithLooseendsKey() {
        XCTAssertTrue(PushWakeUp.isWake(["aps": ["content-available": 1], "looseends": ["v": 1]]))
        XCTAssertTrue(PushWakeUp.isWake(["looseends": ["v": 2]]))
        XCTAssertFalse(PushWakeUp.isWake(["aps": ["content-available": 1]]))
        XCTAssertFalse(PushWakeUp.isWake(["ck": ["ce": 2], "aps": ["content-available": 1]]))
        XCTAssertFalse(PushWakeUp.isWake([:]))
        XCTAssertFalse(PushWakeUp.isWake(["LooseEnds": ["v": 1]]))
    }

    // MARK: AC-2

    func testWakeWinsMapsToNewData() async throws {
        var woken = 0
        let push = node(account: account(Wire()), wake: { woken += 1 })
        let result = await push.handle(isWake: true)
        XCTAssertEqual(result, .woken)
        XCTAssertEqual(woken, 1)
        XCTAssertEqual(push.completions, 1)
        #if os(iOS)
        XCTAssertEqual(result.fetchResult, .newData)
        #endif
    }

    // MARK: AC-3

    func testDeadlineWinsMapsToNoData() async throws {
        let hanging = HangingWake()
        let push = node(account: account(Wire()), wake: { await hanging.wake() }, deadline: .milliseconds(100))
        let clock = ContinuousClock()
        let started = clock.now
        let result = await push.handle(isWake: true)
        XCTAssertEqual(result, .deadline)
        XCTAssertLessThan(clock.now - started, .seconds(2), "the deadline did not end the wait")
        XCTAssertEqual(hanging.calls, 1)
        #if os(iOS)
        XCTAssertEqual(result.fetchResult, .noData)
        for each in [PushWakeUp.Result.woken, .deadline, .notOurs] {
            XCTAssertNotEqual(each.fetchResult, .failed, "\(each) would throttle later wake-ups")
        }
        #endif
        hanging.release()
    }

    // MARK: AC-4

    func testLateWakeDoesNotCompleteTwice() async throws {
        let hanging = HangingWake()
        let push = node(account: account(Wire()), wake: { await hanging.wake() }, deadline: .milliseconds(50))
        let result = await push.handle(isWake: true)
        XCTAssertEqual(result, .deadline)
        XCTAssertEqual(push.completions, 1)
        hanging.release()
        try await waitUntil("late wake returned") { hanging.returned == 1 }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(push.completions, 1, "the late wake completed a second time")
    }

    // MARK: AC-5

    func testForeignNotificationReturnsImmediately() async throws {
        var woken = 0
        let push = node(account: account(Wire()), wake: { woken += 1 }, deadline: .seconds(20))
        let clock = ContinuousClock()
        let started = clock.now
        let result = await push.handle(isWake: false)
        XCTAssertEqual(result, .notOurs)
        XCTAssertLessThan(clock.now - started, .milliseconds(500))
        XCTAssertEqual(woken, 0)
        #if os(iOS)
        XCTAssertEqual(result.fetchResult, .noData)
        #endif
    }

    // MARK: AC-6

    func testTokenForwardedOnlyWithSession() async throws {
        let wire = Wire([.status(204)])
        let signedIn = node(account: account(wire))
        let outcome = await signedIn.didReceive(token: Self.tokenBytes)
        XCTAssertEqual(outcome, .registered)
        let requests = await wire.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.path, "/app/device")
        let body = try XCTUnwrap(requests.first?.httpBody)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["token"], Self.tokenHex)

        let silentWire = Wire([.status(204)])
        let signedOut = node(account: account(silentWire, token: nil))
        let none = await signedOut.didReceive(token: Self.tokenBytes)
        XCTAssertEqual(none, .notSignedIn)
        let nothing = await silentWire.requests
        XCTAssertTrue(nothing.isEmpty, "a token went out without a session")
    }

    // MARK: AC-7

    func testSignInTriggersOneRegistration() async throws {
        let atStart = RemoteRegistrations()
        let signed = node(account: account(Wire()), remote: atStart)
        signed.observeSignIn()
        try await waitUntil("registration at start") { atStart.count == 1 }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(atStart.count, 1, "registered more than once while signed in")

        let later = RemoteRegistrations()
        let state = account(Wire([.status(200, #"{"sessionToken":"fresh"}"#)]), token: nil)
        let push = node(account: state, remote: later)
        push.observeSignIn()
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(later.count, 0, "registered without an account")
        _ = try state.beginSignIn()
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(later.count, 0, "registered while only signing in")
        await state.completeSignIn(identityToken: "id", code: "c")
        XCTAssertEqual(state.status, .signedIn)
        try await waitUntil("registration after a later sign-in") { later.count == 1 }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(later.count, 1)
    }

    // MARK: AC-8

    func testSilentUnderTests() async throws {
        let state = account(Wire())
        let trigger = ClaudeSyncTrigger()
        XCTAssertNil(PushWakeUp.forApp(account: state, trigger: trigger, silent: true))
        XCTAssertNil(PushWakeUp.forApp(account: nil, trigger: trigger, silent: false))
        XCTAssertNil(PushWakeUp.forApp(account: state, trigger: nil, silent: false))
        XCTAssertNotNil(PushWakeUp.forApp(account: state, trigger: trigger, silent: false))
        // The unit test host itself starts under tests: nothing is installed there.
        XCTAssertNil(PushWakeUp.current)
    }
}
