#if os(iOS)
import CoreLocation
import Foundation
import MapKit
import OSLog

/// "Current location" in the place sheet (#241, Schnitt 3b-1): one location on request, named by
/// MapKit's reverse lookup. iPhone and iPad only: the Mac would need its own location key in
/// `project.yml` and does not remind anyway. Under `--ui-testing` a fixed answer, no Core Location.
enum CurrentPlace {
    enum Failure: Error, Equatable, Sendable {
        case locationOff
        case preciseOff
        case notFound
    }

    /// A fix this close is a place; a coarser one would watch the wrong street.
    static let accuracy: CLLocationAccuracy = 100
    static let fixed = PlaceHit(id: "current", name: "Teststraße 1", locality: "Hamburg", latitude: 53.5503, longitude: 9.9930)
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Place")

    /// The permission as the place notes read it; the status belongs to the system, not to a manager.
    static var permission: PlaceNotifications.Permission {
        ModelContainerFactory.isUITesting ? .whenInUse : .init(CLLocationManager().authorizationStatus)
    }

    static var fullAccuracy: Bool {
        ModelContainerFactory.isUITesting || CLLocationManager().accuracyAuthorization == .fullAccuracy
    }

    /// Asks "while using the app" when not asked yet, waits for one precise fix (10 s, 30 s while the
    /// question is open) and names it. Without a name the place is still set, as "Current location".
    static func locate() async throws -> PlaceHit {
        if ModelContainerFactory.isUITesting { return fixed }
        let asking = permission == .notDetermined
        if permission == .refused { throw Failure.locationOff }
        if !asking, !fullAccuracy { throw Failure.preciseOff }
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }
        let fix = try await firstFix(within: .seconds(asking ? 30 : 10))
        return await named(fix)
    }

    /// A coordinate that crosses task boundaries; `CLLocation` is not guaranteed `Sendable`.
    private struct Fix: Sendable {
        let latitude: Double
        let longitude: Double
    }

    private static func firstFix(within limit: Duration) async throws -> Fix {
        try await withThrowingTaskGroup(of: Fix.self) { group in
            group.addTask {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if update.authorizationDenied || update.authorizationDeniedGlobally { throw Failure.locationOff }
                    if let location = update.location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= Self.accuracy {
                        return Fix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
                    }
                }
                throw Failure.notFound
            }
            group.addTask {
                try await Task.sleep(for: limit)
                throw Failure.notFound
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw Failure.notFound }
            return first
        }
    }

    private static func named(_ fix: Fix) async -> PlaceHit {
        var name = String(localized: "Current location")
        var locality: String?
        if let request = MKReverseGeocodingRequest(location: CLLocation(latitude: fix.latitude, longitude: fix.longitude)) {
            do {
                if let item = try await request.mapItems.first {
                    if let found = item.name, !found.isEmpty { name = found }
                    locality = item.addressRepresentations?.cityName
                }
            } catch {
                logger.error("Naming the current location failed: \(error, privacy: .public)")
            }
        }
        return PlaceHit(
            id: "current", name: name, locality: locality,
            latitude: fix.latitude, longitude: fix.longitude
        )
    }
}
#endif
