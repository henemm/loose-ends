import Foundation
import SwiftData
import UserNotifications

/// Both notification categories in one set: every `setNotificationCategories` call replaces all earlier
/// ones, so the system wiring (#240, Schnitt 2) passes exactly this set, once.
enum NotificationCategories {
    static func all() -> Set<UNNotificationCategory> {
        [
            category(DueReminders.categoryIdentifier, actions: [.done, .next, .tomorrow]),
            category(PlaceNotifications.categoryIdentifier, actions: [.done, .next]),   // a place has no day
        ]
    }

    private static func category(_ identifier: String, actions: [DueReminders.Action]) -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: identifier,
            actions: actions.map { UNNotificationAction(identifier: $0.rawValue, title: title(of: $0), options: []) },
            intentIdentifiers: [],
            options: []
        )
    }

    private static func title(of action: DueReminders.Action) -> String {
        switch action {
        case .done: String(localized: "Complete")
        case .next: String(localized: "Next up")
        case .tomorrow: String(localized: "Tomorrow")
        }
    }
}

/// The platform-neutral decisions of the place notification (#240, Schnitt 1). No system call here;
/// talking to the system comes with Schnitt 2.
enum PlaceNotifications {
    static let categoryIdentifier = "PLACE"
    static let testArgument = "--ui-testing-places"

    /// `CLAuthorizationStatus.authorizedWhenInUse` does not exist on macOS, so the decisions use this.
    enum Permission: Equatable, Sendable { case notDetermined, refused, whenInUse, always }

    /// Region monitoring is off with reduced accuracy, so only full accuracy counts.
    static func isAuthorized(_ permission: Permission, fullAccuracy: Bool) -> Bool {
        fullAccuracy && (permission == .whenInUse || permission == .always)
    }

    /// Only with a place to watch, only while undecided, and only once per device ("allow once" falls back
    /// to undecided and would otherwise ask on every run). Only in the foreground: in the background the
    /// system shows no dialog, so the mark stays unset and the next foreground run asks.
    static func shouldRequestAuthorization(_ permission: Permission, hasWatched: Bool, alreadyAsked: Bool, isActive: Bool) -> Bool {
        permission == .notDetermined && hasWatched && !alreadyAsked && isActive
    }

    /// Silent under unit tests, and under UI tests unless the places argument is passed.
    static func isSilent(runningTests: Bool, uiTesting: Bool, arguments: [String]) -> Bool {
        runningTests || (uiTesting && !arguments.contains(testArgument))
    }

    /// The place reconcile only ever touches `place_` identifiers, never the due ones.
    static func pendingPlaceIdentifiers(_ identifiers: [String]) -> Set<String> {
        Set(identifiers.filter { $0.hasPrefix(PlaceReminders.identifierPrefix) })
    }

    /// A shown or answered notification. A place notification marks its task (once for all devices), then
    /// a button applies like on a due notification; a place has no day, so only Complete and Next up act
    /// there. True only when something changed and needs saving (a mark already set is no change); the
    /// caller saves.
    static func respond(
        identifier: String,
        actionRaw: String?,
        taskID: String?,
        in tasks: [TaskItem],
        contexts: [TaskContext],
        projects: [Project],
        now: Date = Date()
    ) -> Bool {
        guard let taskID, let id = UUID(uuidString: taskID) else { return false }
        var changed = false
        let isPlace = identifier.hasPrefix(PlaceReminders.identifierPrefix)
        if isPlace {
            let wasUnmarked = tasks.first { $0.id == id }?.placeRemindedAt == nil
            changed = PlaceReminders.markDelivered(taskID: id, in: tasks, now: now) && wasUnmarked
        }
        if let actionRaw, let action = DueReminders.Action(rawValue: actionRaw), !(isPlace && action == .tomorrow) {
            changed = DueReminders.handle(action, taskID: id, in: tasks, contexts: contexts, projects: projects, now: now) || changed
        }
        return changed
    }
}

/// One reconcile at a time; triggers that arrive meanwhile cause exactly one rerun. A class, because
/// `#expect` cannot call a mutating method.
final class ReconcileGate {
    private var running = false
    private var rerun = false

    /// False when a run is already going; the trigger is then remembered for one rerun.
    func begin() -> Bool {
        if running {
            rerun = true
            return false
        }
        running = true
        return true
    }

    /// True when the caller has to run once more.
    func end() -> Bool {
        running = false
        defer { rerun = false }
        return rerun
    }
}
