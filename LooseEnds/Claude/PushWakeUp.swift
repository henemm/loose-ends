import Foundation
import Observation
import OSLog
import Synchronization
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// The app's side of the silent wake-up (#795 S5c-2a). The app delegates only pass through: the token goes to
/// `DeviceRegistration`, a notification with the key `looseends` runs `wake()` against a deadline, and the request
/// for a device token follows the account's sign-in. Set once by `LooseEndsApp.init`; nil without an account and
/// under tests.
@MainActor final class PushWakeUp {
    enum Result: Equatable, Sendable {
        case woken, deadline, notOurs

        #if os(iOS)
        /// Never `.failed`: the system throttles later wake-ups after it.
        var fetchResult: UIBackgroundFetchResult {
            self == .woken ? .newData : .noData
        }
        #endif
    }

    /// The node the app delegates reach; set once at launch.
    static var current: PushWakeUp?

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "push-wake-up")

    private let account: AccountState
    private let registration: DeviceRegistration
    private let wake: @MainActor () async -> Void
    private let registerForRemote: @MainActor () -> Void
    private let deadline: Duration
    private var observing: Task<Void, Never>?
    /// How many wake-ups were finished; each exactly once.
    private(set) var completions = 0

    init(account: AccountState, registration: DeviceRegistration,
         wake: @escaping @MainActor () async -> Void,
         registerForRemote: @escaping @MainActor () -> Void,
         deadline: Duration = .seconds(20)) {
        self.account = account
        self.registration = registration
        self.wake = wake
        self.registerForRemote = registerForRemote
        self.deadline = deadline
    }

    /// The node of the app, nil when `silent` (tests) or without an account or trigger.
    static func forApp(account: AccountState?, trigger: ClaudeSyncTrigger?, silent: Bool) -> PushWakeUp? {
        guard !silent, let account, let trigger else { return nil }
        let registration = DeviceRegistration(account: account, device: { try DeviceIdentity().current() },
                                              environment: .current)
        return PushWakeUp(account: account, registration: registration,
                          wake: { await trigger.wake() }, registerForRemote: requestDeviceToken)
    }

    /// The one place that asks the system for a device token.
    private static func requestDeviceToken() {
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #elseif os(macOS)
        NSApplication.shared.registerForRemoteNotifications()
        #endif
    }

    /// Ours only with the key `looseends`; checked synchronously in the callback, `userInfo` never leaves it.
    nonisolated static func isWake(_ userInfo: [AnyHashable: Any]) -> Bool {
        userInfo["looseends"] != nil
    }

    /// A foreign notification returns at once; ours runs `wake()` against the deadline, the first to end wins.
    /// `wake()` cannot be cancelled, so a late one keeps running and finishes nothing a second time.
    func handle(isWake: Bool) async -> Result {
        guard isWake else { return .notOurs }
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result, Never>) in
            let once = FinishOnce(continuation)
            let timer = Task { [deadline] in
                do {
                    try await Task.sleep(for: deadline)
                } catch {
                    return
                }
                once.finish(.deadline)
            }
            Task { @MainActor [self] in
                await self.wake()
                timer.cancel()
                once.finish(.woken)
            }
        }
        completions += 1
        Self.logger.info("wake-up ended: \(String(describing: result), privacy: .public)")
        return result
    }

    /// The device token goes to the service, only with a session.
    @discardableResult
    func didReceive(token: Data) async -> DeviceRegistration.Outcome {
        await registration.register(token: token)
    }

    /// Asks for a device token each time the account becomes signed in, at start or later; once per sign-in.
    func observeSignIn() {
        guard observing == nil else { return }
        let account = self.account
        observing = Task { [weak self] in
            var wasSignedIn = false
            for await status in Observations({ account.status }) {
                let signedIn = status == .signedIn
                if signedIn, !wasSignedIn { self?.registerForRemote() }
                wasSignedIn = signedIn
            }
        }
    }
}

/// Hands the result to the waiting caller exactly once; every later `finish` does nothing (pattern `RefreshHandle`).
private final class FinishOnce: Sendable {
    private let continuation: Mutex<CheckedContinuation<PushWakeUp.Result, Never>?>

    init(_ continuation: CheckedContinuation<PushWakeUp.Result, Never>) {
        self.continuation = Mutex(continuation)
    }

    func finish(_ result: PushWakeUp.Result) {
        let open = continuation.withLock { open in
            defer { open = nil }
            return open
        }
        open?.resume(returning: result)
    }
}
