import CloudKit
import CoreData
import Foundation
import Observation

/// What the CloudKit mirroring of the store reports about itself (#377). SwiftData mirrors through
/// `NSPersistentCloudKitContainer`, which posts an event for every setup, import and export, with
/// success or error. The app never showed any of it: a Mac that never reaches CloudKit looked exactly
/// like one that is in sync. The Settings show the summary so the device itself says what it does.
enum CloudSyncEventKind: String, Sendable, CaseIterable {
    case setup, `import`, export
}

struct CloudSyncEvent: Equatable, Sendable {
    var kind: CloudSyncEventKind
    var startedAt: Date
    /// Nil while the event runs.
    var endedAt: Date?
    /// The error's description, nil on success.
    var error: String?

    var isRunning: Bool { endedAt == nil }
    var failed: Bool { endedAt != nil && error != nil }
}

/// The newest event per kind and the one-word state derived from them. Pure, so it is testable.
struct CloudSyncSummary: Equatable, Sendable {
    enum State: Equatable, Sendable {
        /// No event ever arrived: the mirroring never started on this device.
        case neverContacted
        case running(CloudSyncEventKind)
        case failed(CloudSyncEventKind, String)
        /// Everything that ran ended well; the date is the most recent end.
        case ok(Date)
    }

    private(set) var latest: [CloudSyncEventKind: CloudSyncEvent] = [:]

    /// Keeps the newest event per kind; a running event replaces the finished one before it.
    mutating func record(_ event: CloudSyncEvent) {
        if let known = latest[event.kind], known.startedAt > event.startedAt { return }
        latest[event.kind] = event
    }

    func latest(_ kind: CloudSyncEventKind) -> CloudSyncEvent? { latest[kind] }

    var state: State {
        let events = latest.values.sorted { $0.startedAt > $1.startedAt }
        guard !events.isEmpty else { return .neverContacted }
        if let running = events.first(where: \.isRunning) { return .running(running.kind) }
        if let failure = events.first(where: \.failed), let error = failure.error {
            return .failed(failure.kind, error)
        }
        let ended = events.compactMap(\.endedAt).max() ?? events[0].startedAt
        return .ok(ended)
    }
}

extension CloudSyncEvent {
    /// Maps the Core Data event onto the plain value; nil for an event type this app does not know.
    init?(type: NSPersistentCloudKitContainer.EventType, startedAt: Date, endedAt: Date?, error: (any Error)?) {
        let kind: CloudSyncEventKind
        switch type {
        case .setup: kind = .setup
        case .import: kind = .import
        case .export: kind = .export
        @unknown default: return nil
        }
        self.init(kind: kind, startedAt: startedAt, endedAt: endedAt, error: error.map { String(describing: $0) })
    }
}

/// Collects the mirroring events of this process. Start it before the container opens, or the
/// setup event is missed. Under tests the store has no CloudKit database, so nothing ever arrives.
@MainActor
@Observable
final class CloudSyncStatus {
    static let shared = CloudSyncStatus()

    private(set) var summary = CloudSyncSummary()
    private var observer: (any NSObjectProtocol)?

    func start(center: NotificationCenter = .default) {
        guard observer == nil else { return }
        observer = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event,
                let plain = CloudSyncEvent(type: event.type, startedAt: event.startDate, endedAt: event.endDate, error: event.error)
            else { return }
            // The observer runs on the main queue; the compiler cannot see that.
            MainActor.assumeIsolated { CloudSyncStatus.shared.record(plain) }
        }
    }

    func record(_ event: CloudSyncEvent) {
        summary.record(event)
    }
}
