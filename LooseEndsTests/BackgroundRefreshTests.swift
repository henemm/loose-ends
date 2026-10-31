#if os(iOS)
import XCTest
@testable import LooseEnds

/// #780: iOS calls the refresh handler on a background queue. The handler must not inherit the main actor;
/// it hops there itself for the work. XCTest, so the QA gate counts the run.
@MainActor
final class BackgroundRefreshTests: XCTestCase {
    func testLaunchHandlerCalledFromBackgroundQueueReschedulesOnceAndCompletesWithSuccess() async {
        let task = FakeRefreshTask()
        let done = expectation(description: "completed")
        task.onComplete = { done.fulfill() }
        let counter = Counter()
        let handler = BackgroundRefresh.launchHandler(reschedule: { counter.count += 1 })

        DispatchQueue.global().async { handler(task) }
        await fulfillment(of: [done], timeout: 5)

        XCTAssertEqual(counter.count, 1)
        XCTAssertEqual(task.completions, [true])
    }

    func testExpirationHandlerCalledFromBackgroundQueueCompletesWithoutSuccess() async {
        let task = FakeRefreshTask()
        let gate = Gate()
        // The work hangs until the test lets go: the expiration ends the task first.
        let handler = BackgroundRefresh.launchHandler(reschedule: { await gate.wait() })
        let installed = expectation(description: "handler installed")
        DispatchQueue.global().async {
            handler(task)
            installed.fulfill()
        }
        await fulfillment(of: [installed], timeout: 5)

        let expired = expectation(description: "expired")
        task.onComplete = { expired.fulfill() }
        let expiration = task.expirationHandler
        XCTAssertNotNil(expiration)
        DispatchQueue.global().async { expiration?() }
        await fulfillment(of: [expired], timeout: 5)

        XCTAssertEqual(task.completions.first, false)
        task.onComplete = nil
        gate.open()
    }
}

@MainActor
private final class Gate {
    private var waiting: CheckedContinuation<Void, Never>?
    private var isOpen = false

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiting = $0 }
    }

    func open() {
        isOpen = true
        waiting?.resume()
        waiting = nil
    }
}

@MainActor
private final class Counter {
    var count = 0
}

/// Stands in for `BGTask`, which has no public initializer and no scheduler in the simulator.
private final class FakeRefreshTask: RefreshTask, @unchecked Sendable {
    private let lock = NSLock()
    private var _completions: [Bool] = []
    private var _expirationHandler: (() -> Void)?
    private var _onComplete: (() -> Void)?

    var expirationHandler: (() -> Void)? {
        get { lock.withLock { _expirationHandler } }
        set { lock.withLock { _expirationHandler = newValue } }
    }

    var onComplete: (() -> Void)? {
        get { lock.withLock { _onComplete } }
        set { lock.withLock { _onComplete = newValue } }
    }

    var completions: [Bool] { lock.withLock { _completions } }

    func setTaskCompleted(success: Bool) {
        let callback = lock.withLock {
            _completions.append(success)
            return _onComplete
        }
        callback?()
    }
}
#endif
