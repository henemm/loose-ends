import Foundation
import OSLog
import SwiftData
import WidgetKit
#if canImport(CoreData)
import CoreData
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Reloads the "Next up" widget for every save, every finished CloudKit import and every move to the foreground
/// (#883). It lives with the
/// process, not with a window: on the Mac the app runs with its window closed, and an import from another
/// device never saves through the app's context. Before, only `ContentView` reloaded (#307).
@MainActor final class WidgetReload {
    /// The widget's kind, in one place.
    static let kind = "NextUp"
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Widget")

    private let debounce: Duration
    private let reload: @MainActor () -> Void
    private var pending: Task<Void, Never>?
    private var saveObserver: (any NSObjectProtocol)?
    private var importObserver: (any NSObjectProtocol)?
    private var activeObserver: (any NSObjectProtocol)?

    /// The process-wide signal that the app became active; `scenePhase` is per window.
    private static var becameActive: Notification.Name {
        #if canImport(UIKit)
        UIApplication.didBecomeActiveNotification
        #else
        NSApplication.didBecomeActiveNotification
        #endif
    }

    /// Unit and UI tests never reach WidgetKit unless they hand in their own reload.
    private static var suppressed: Bool {
        ModelContainerFactory.isRunningTests || ModelContainerFactory.isUITesting
    }

    init(debounce: Duration = .seconds(1), reload: (@MainActor () -> Void)? = nil) {
        self.debounce = debounce
        if let reload {
            self.reload = reload
        } else if Self.suppressed {
            self.reload = {}
        } else {
            self.reload = {
                WidgetReload.logger.info("Widget reload requested")
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetReload.kind)
            }
        }
    }

    /// Call once at launch; a second call changes nothing.
    func start() {
        guard saveObserver == nil else { return }
        saveObserver = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadSoon() }
        }
        #if canImport(CoreData)
        // A change from another device arrives as a CloudKit import, not as a save of this process.
        importObserver = NotificationCenter.default.addObserver(
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
        }
        #endif
        // A widget may have missed a change while the app was away; coming back draws it fresh (Schnitt 2).
        activeObserver = NotificationCenter.default.addObserver(
            forName: Self.becameActive, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadSoon() }
        }
        Self.logger.info("Widget reload listens for saves, imports and becoming active")
    }

    /// One mirroring event; only a finished, successful import reloads.
    func handle(_ event: SyncStatus.Event) {
        guard Self.isFinishedImport(event) else { return }
        reloadSoon()
    }

    /// The rule of #553: an import that ended without an error.
    static func isFinishedImport(_ event: SyncStatus.Event) -> Bool {
        event.kind == .imported && event.endDate != nil && event.errorMessage == nil
    }

    /// Saves and imports come in bursts; one reload shortly after the last.
    func reloadSoon() {
        pending?.cancel()
        pending = Task { [weak self, debounce] in
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }
            self?.reload()
        }
    }
}
