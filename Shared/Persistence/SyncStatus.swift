import Foundation
import Observation
import OSLog
#if canImport(CoreData)
import CoreData
#endif

/// Whether this device mirrors its store with iCloud (#377). The Mac showed other tasks than iPhone and iPad,
/// and nothing in the app said whether it mirrors at all. The rule (`reduce`, `summary`) is pure; the shell
/// around `NSPersistentCloudKitContainer.eventChangedNotification` only feeds it.
@MainActor @Observable final class SyncStatus {
    enum Kind: Sendable, Equatable { case setup, imported, exported }
    enum FallbackReason: Sendable, Equatable { case appGroupMissing, containerFailed }

    enum State: Sendable, Equatable {
        /// Mirroring is starting, no event yet.
        case waiting
        /// The last finished event had no error.
        case alive(Kind, at: Date)
        /// The last finished event had an error.
        case failed(message: String, at: Date)
        /// The store fell back to a local one without sync; final for the process.
        case localOnly(FallbackReason)
    }

    /// One mirroring event, read from the system notification. `endDate == nil` means still running.
    struct Event: Sendable, Equatable {
        var kind: Kind
        var endDate: Date?
        var errorMessage: String?
    }

    enum Headline: Sendable, Equatable { case waiting, active, disturbed, localOnly }
    /// The color budget: accent only while it lives, grey for everything else; never red.
    enum Role: Sendable, Equatable, CaseIterable { case accent, secondary }

    struct Summary: Sendable, Equatable {
        var headline: Headline
        var symbol: String
        var role: Role
        var detail: String?
        var activity: Kind?
        var ageMinutes: Int?
    }

    static let shared = SyncStatus()
    private nonisolated static let logger = Logger(subsystem: "com.henning.looseends", category: "Sync")

    private(set) var state: State = .waiting
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init() {}

    func fellBack(reason: FallbackReason) {
        state = .localOnly(reason)
    }

    func apply(_ event: Event) {
        state = Self.reduce(state, event: event)
    }

    // MARK: - Rule

    static func reduce(_ state: State, event: Event) -> State {
        if case .localOnly = state { return state }
        guard let end = event.endDate else { return state }
        if let message = event.errorMessage { return .failed(message: message, at: end) }
        return .alive(event.kind, at: end)
    }

    static func summary(for state: State, now: Date) -> Summary {
        switch state {
        case .waiting:
            Summary(headline: .waiting, symbol: "icloud", role: .secondary)
        case let .alive(kind, at):
            Summary(headline: .active, symbol: "checkmark.icloud", role: .accent,
                    detail: String(localized: "Your tasks are kept in sync with your other devices."), activity: kind, ageMinutes: max(0, Int(now.timeIntervalSince(at) / 60)))
        case let .failed(message, _):
            Summary(headline: .disturbed, symbol: "exclamationmark.icloud", role: .secondary, detail: message)
        case .localOnly:
            Summary(headline: .localOnly, symbol: "icloud.slash", role: .secondary,
                    detail: String(localized: "This device only sees its own tasks. Restart the app. If that doesn’t help, sign in to iCloud."))
        }
    }

    // MARK: - Shell

    /// For callers off the main actor (`ModelContainerFactory.make()` runs in intents and extensions too).
    nonisolated static func reportFallBack(_ reason: FallbackReason) {
        onMain { shared.fellBack(reason: reason) }
    }

    /// Starts listening before the container exists, so the setup event is not missed.
    nonisolated static func startShared() {
        onMain { shared.start() }
    }

    private nonisolated static func onMain(_ work: @escaping @MainActor @Sendable () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { work() }
        } else {
            Task { @MainActor in work() }
        }
    }

    func start() {
        #if canImport(CoreData)
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let raw = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
            let kind: Kind = switch raw.type {
            case .setup: .setup
            case .import: .imported
            case .export: .exported
            @unknown default: .setup
            }
            let failure = raw.succeeded ? nil : (raw.error?.localizedDescription ?? String(localized: "Unknown error"))
            let event = Event(kind: kind, endDate: raw.endDate, errorMessage: failure)
            Self.logger.info(
                "CloudKit event \(String(describing: kind), privacy: .public) succeeded=\(raw.succeeded, privacy: .public) ended=\(raw.endDate != nil, privacy: .public) error=\(event.errorMessage ?? "-", privacy: .public)"
            )
            MainActor.assumeIsolated { self?.apply(event) }
        }
        Self.logger.info("Listening for CloudKit mirroring events")
        #endif
    }
}
