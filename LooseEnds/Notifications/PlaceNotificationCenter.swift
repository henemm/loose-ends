#if os(iOS)
import CoreLocation
import Foundation
import OSLog
import SwiftData
import UIKit
import UserNotifications

/// What the place reconcile needs from Core Location and the app state (#240): the app asks the
/// system, unit tests hand in a stand-in.
@MainActor
protocol PlaceLocating: AnyObject {
    var permission: PlaceNotifications.Permission { get }
    var fullAccuracy: Bool { get }
    /// The app is in the foreground; only then the system shows the permission dialog.
    var isActive: Bool { get }
    func requestWhenInUseAuthorization()
}

extension PlaceNotifications.Permission {
    init(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse: self = .whenInUse
        case .authorizedAlways: self = .always
        case .denied, .restricted: self = .refused
        default: self = .notDetermined
        }
    }
}

/// The system side of `PlaceLocating`. A change of the permission runs `onChange` (a reconcile).
@MainActor
final class SystemPlaceLocation: NSObject, PlaceLocating, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onChange: (@MainActor () -> Void)?

    override init() {
        super.init()
        manager.delegate = self
    }

    var permission: PlaceNotifications.Permission { .init(manager.authorizationStatus) }
    var fullAccuracy: Bool { manager.accuracyAuthorization == .fullAccuracy }
    var isActive: Bool { UIApplication.shared.applicationState == .active }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.onChange?() }
    }
}

/// Hands the watched places to the system as location notifications (#240, Schnitt 2): only the
/// difference to what this device handed over before (`PlaceDelivery`), and asks for "while using the
/// app" once there is a place to watch. `DueNotificationCenter` runs it after every reschedule and stays
/// the only notification delegate. Silent under tests unless a scheduler is handed in.
@MainActor
final class PlaceNotificationCenter: PlaceReconciling {
    private let container: ModelContainer
    private let scheduler: (any PlaceScheduling)?
    private let location: (any PlaceLocating)?
    private let defaults: UserDefaults
    private let gate = ReconcileGate()
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "PlaceNotifications")
    static let handoverKey = "placeHandover"
    static let askedKey = "placeAuthorizationAsked"

    init(
        container: ModelContainer,
        scheduler: (any PlaceScheduling)? = nil,
        location: (any PlaceLocating)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.container = container
        let silent = PlaceNotifications.isSilent(
            runningTests: ModelContainerFactory.isRunningTests,
            uiTesting: ModelContainerFactory.isUITesting,
            arguments: ProcessInfo.processInfo.arguments
        )
        self.scheduler = scheduler ?? (silent ? nil : SystemDueScheduler())
        self.defaults = defaults
        if let location {
            self.location = location
        } else if self.scheduler != nil {
            let system = SystemPlaceLocation()
            self.location = system
            system.onChange = { [weak self] in
                Task { await self?.reconcile() }
            }
        } else {
            self.location = nil
        }
    }

    func reconcile() async {
        guard let scheduler, let location, gate.begin() else { return }
        repeat {
            await reconcileOnce(scheduler: scheduler, location: location)
        } while gate.end() && gate.begin()
    }

    private func reconcileOnce(scheduler: any PlaceScheduling, location: any PlaceLocating) async {
        do {
            let tasks = try container.mainContext.fetch(FetchDescriptor<TaskItem>())
            let plan = PlaceReminders.plan(for: tasks)
            if !plan.unwatched.isEmpty {
                Self.logger.notice("\(plan.unwatched.count, privacy: .public) places beyond the limit are not watched")
            }
            askIfNeeded(location, hasWatched: !plan.watched.isEmpty)
            let authorized = PlaceNotifications.isAuthorized(location.permission, fullAccuracy: location.fullAccuracy)
            let pending = await scheduler.pendingIdentifiers()
            let previous = loadHandover()
            let changes = PlaceDelivery.diff(
                plan: plan, tasks: tasks, handover: previous,
                pending: PlaceNotifications.pendingPlaceIdentifiers(pending), authorized: authorized
            )
            if !changes.remove.isEmpty { scheduler.remove(changes.remove) }
            let failed = await hand(changes.add + changes.updateContent, to: scheduler)
            // Without permission nothing was handed over, so nothing is noted.
            guard authorized else { return }
            let noted = Self.handover(changes.handover, failed: failed, previous: previous)
            if noted != previous { try saveHandover(noted) }
        } catch {
            Self.logger.error("Reconciling place reminders failed: \(error, privacy: .public)")
        }
    }

    /// Hands each request over on its own, so one that fails for good does not block the rest (#418).
    /// The same identifier replaces the open request, so a new title is simply added again.
    /// Returns the tasks whose request failed.
    private func hand(_ reminders: [PlaceReminders.Reminder], to scheduler: any PlaceScheduling) async -> Set<UUID> {
        var failed: Set<UUID> = []
        for reminder in reminders {
            do {
                try await scheduler.add(Self.request(for: reminder))
            } catch {
                Self.logger.error(
                    "Handing over place reminder \(reminder.identifier, privacy: .public) failed: \(error, privacy: .public)"
                )
                failed.insert(reminder.taskID)
            }
        }
        return failed
    }

    /// The list notes only what went over: a failed task keeps its previous entry, or none (#418).
    nonisolated static func handover(
        _ planned: PlaceDelivery.Handover, failed: Set<UUID>, previous: PlaceDelivery.Handover
    ) -> PlaceDelivery.Handover {
        guard !failed.isEmpty else { return planned }
        let kept = planned.entries.filter { !failed.contains($0.taskID) }
        let restored = previous.entries.filter { failed.contains($0.taskID) }
        return .init(entries: (kept + restored).sorted { $0.taskID.uuidString < $1.taskID.uuidString })
    }

    /// The mark is set only after asking, so a run in the background leaves it for the next one in front.
    private func askIfNeeded(_ location: any PlaceLocating, hasWatched: Bool) {
        guard PlaceNotifications.shouldRequestAuthorization(
            location.permission, hasWatched: hasWatched,
            alreadyAsked: defaults.bool(forKey: Self.askedKey), isActive: location.isActive
        ) else { return }
        location.requestWhenInUseAuthorization()
        defaults.set(true, forKey: Self.askedKey)
    }

    private func loadHandover() -> PlaceDelivery.Handover {
        guard let data = defaults.data(forKey: Self.handoverKey) else { return .init(entries: []) }
        do {
            return try JSONDecoder().decode(PlaceDelivery.Handover.self, from: data)
        } catch {
            Self.logger.error("Reading the place handover failed: \(error, privacy: .public)")
            return .init(entries: [])
        }
    }

    private func saveHandover(_ handover: PlaceDelivery.Handover) throws {
        defaults.set(try JSONEncoder().encode(handover), forKey: Self.handoverKey)
    }

    nonisolated static func request(for reminder: PlaceReminders.Reminder) -> UNNotificationRequest {
        let place = reminder.place
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = String(localized: "You're at \(place.name).")
        content.sound = .default
        content.categoryIdentifier = PlaceNotifications.categoryIdentifier
        content.userInfo = ["taskID": reminder.taskID.uuidString]
        let center = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        let region = CLCircularRegion(center: center, radius: TaskPlace.radius, identifier: reminder.identifier)
        region.notifyOnEntry = place.event == .arrive
        region.notifyOnExit = place.event == .depart
        let trigger = UNLocationNotificationTrigger(region: region, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }
}
#endif
