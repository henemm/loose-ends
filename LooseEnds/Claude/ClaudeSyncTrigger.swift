import Foundation
import OSLog
import SwiftData
#if canImport(CoreData)
import CoreData
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The occasions for the pass for Claude (#795 S3b-1). Start and becoming active send, then pull; a save and a
/// finished CloudKit import only send, debounced. Pulling never follows a save or an import: running orders saves.
/// It lives with the process like `WidgetReload` (#883), not with a window. Sends are lined up here, so two never
/// overlap and none is lost on `ClaudeSync`'s busy lock.
@MainActor final class ClaudeSyncTrigger {
    typealias Action = @MainActor () async -> Void

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "claude-sync")

    /// The process-wide signal that the app became active; `scenePhase` is per window.
    private static var becameActive: Notification.Name {
        #if canImport(UIKit)
        UIApplication.didBecomeActiveNotification
        #else
        NSApplication.didBecomeActiveNotification
        #endif
    }

    private let send: Action
    private let pull: Action
    private let debounce: Duration
    private var started = false
    private var observers: [any NSObjectProtocol] = []
    private var pending: Task<Void, Never>?
    private var sending = false
    private var sendAgain = false
    private var pullAfterSend = false

    /// A missing action is an empty one: unit and UI tests never reach a real pass unless they hand in their own,
    /// and the app builds the trigger only through `forApp`, which hands in both outside tests.
    init(send: Action? = nil, pull: Action? = nil, debounce: Duration = .seconds(2)) {
        self.send = send ?? {}
        self.pull = pull ?? {}
        self.debounce = debounce
    }

    /// The one place of the rule "only with an account". Under tests (`silent`) the trigger gets no actions and never
    /// calls the `ClaudeSync` it builds.
    static func forApp(
        account: AccountState?,
        container: ModelContainer,
        silent: Bool = ModelContainerFactory.isRunningTests || ModelContainerFactory.isUITesting
    ) -> ClaudeSyncTrigger? {
        guard let account else { return nil }
        let sync = ClaudeSync(account: account, container: container,
                              device: { try DeviceIdentity().current() }, now: { Date() }, calendar: .current)
        if silent { return ClaudeSyncTrigger() }
        return ClaudeSyncTrigger(
            send: { log("send", await sync.sendTranscript()) },
            pull: { log("pull", await sync.pullOrders()) }
        )
    }

    /// Call once at launch; a second call changes nothing.
    func start() {
        guard !started else { return }
        started = true
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: Self.becameActive, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sendThenPull() }
        })
        observers.append(center.addObserver(forName: ModelContext.didSave, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sendSoon() }
        })
        #if canImport(CoreData)
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            let kind: SyncStatus.Kind = switch raw.type {
            case .import: .imported
            case .export: .exported
            default: .setup
            }
            let event = SyncStatus.Event(kind: kind, endDate: raw.endDate,
                                         errorMessage: raw.succeeded ? nil : (raw.error?.localizedDescription ?? "failed"))
            MainActor.assumeIsolated { self?.handle(event) }
        })
        #endif
        sendThenPull()
    }

    /// One mirroring event; only a finished, successful import sends (the rule lives in `WidgetReload`).
    func handle(_ event: SyncStatus.Event) {
        guard started, WidgetReload.isFinishedImport(event) else { return }
        sendSoon()
    }

    /// Start and becoming active: send, then pull once the send and any queued resend have ended.
    private func sendThenPull() {
        pullAfterSend = true
        requestSend()
    }

    /// Saves and imports come in bursts; one send `debounce` after the last. Only the waiting is cancelled.
    private func sendSoon() {
        pending?.cancel()
        pending = Task { [weak self, debounce] in
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }
            self?.requestSend()
        }
    }

    /// A send while one runs only marks "send once more"; never two at a time.
    private func requestSend() {
        if sending {
            sendAgain = true
            return
        }
        sending = true
        Task { [weak self] in await self?.drain() }
    }

    private func drain() async {
        repeat {
            sendAgain = false
            await send()
        } while sendAgain
        sending = false
        guard pullAfterSend else { return }
        pullAfterSend = false
        await pull()
    }

    /// Only the case name of the ending reaches the log.
    private static func log(_ kind: String, _ ending: ClaudeSync.Ending) {
        let name: String = switch ending {
        case .notSignedIn: "notSignedIn"
        case .busy: "busy"
        case .done: "done"
        case .limitReached: "limitReached"
        case .stopped(let stop): "stopped." + stop.rawValue
        }
        logger.info("\(kind, privacy: .public) ended: \(name, privacy: .public)")
    }
}
