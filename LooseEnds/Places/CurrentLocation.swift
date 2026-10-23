import Foundation
import OSLog
#if os(iOS)
import CoreLocation
import MapKit
#endif

/// One reading of where the device is, for "Current location" and "you're already here" (#241,
/// Schnitt 3b). The app asks Core Location, UI tests a fixed stand-in, unit tests their own. The Mac
/// has none: it never reminds by place, so the row is not offered there.
@MainActor
protocol CurrentLocating: AnyObject {
    var permission: PlaceNotifications.Permission { get }
    /// Asks "while using the app" if still undecided; returns the permission after the answer.
    func requestPermissionIfNeeded() async -> PlaceNotifications.Permission
    func currentFix() async throws -> LocationFix
    /// A readable name for the fix; nil falls back to "Current location".
    func placeName(for fix: LocationFix) async -> String?
}

extension CurrentLocating {
    func placeName(for fix: LocationFix) async -> String? { nil }
}

@MainActor
enum CurrentLocation {
    nonisolated static let hereArgument = "--ui-testing-location-here"
    nonisolated static let refusedArgument = "--ui-testing-location-refused"

    /// Nil on the Mac. Under the UI tests a fixed location, made once per launch.
    static var current: (any CurrentLocating)? { provider }

    private static let provider: (any CurrentLocating)? = {
        if ModelContainerFactory.isUITesting { return FixedCurrentLocation(arguments: ProcessInfo.processInfo.arguments) }
        #if os(iOS)
        return SystemCurrentLocation()
        #else
        return nil
        #endif
    }()

    /// The name a place gets when the lookup finds none.
    static var fallbackName: String { String(localized: "Current location") }
}

/// The steps behind a tap on "Current location": ask once while undecided, then one fix.
enum CurrentLocationLookup {
    enum Outcome: Equatable, Sendable {
        case fix(LocationFix)
        /// The permission is refused (or was refused at the prompt): no fix asked for.
        case refused
        /// Granted, but no fix came (error, timeout), or the prompt went unanswered.
        case unavailable
    }

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Place")

    @MainActor
    static func run(_ location: any CurrentLocating) async -> Outcome {
        var permission = location.permission
        if permission == .notDetermined {
            permission = await location.requestPermissionIfNeeded()
        }
        switch permission {
        case .refused: return .refused
        case .notDetermined: return .unavailable
        case .whenInUse, .always:
            do {
                return .fix(try await location.currentFix())
            } catch {
                logger.error("Current location failed: \(error, privacy: .public)")
                return .unavailable
            }
        }
    }
}

/// Under `--ui-testing`: granted and far from the fixed search hits, on the Altona hit with
/// `--ui-testing-location-here`, refused with `--ui-testing-location-refused`.
@MainActor
final class FixedCurrentLocation: CurrentLocating {
    static let altona = LocationFix(latitude: 53.5561, longitude: 9.9285, accuracy: 10)
    static let elsewhere = LocationFix(latitude: 53.6304, longitude: 9.9882, accuracy: 10)

    let permission: PlaceNotifications.Permission
    private let fix: LocationFix

    init(arguments: [String]) {
        permission = arguments.contains(CurrentLocation.refusedArgument) ? .refused : .whenInUse
        fix = arguments.contains(CurrentLocation.hereArgument) ? Self.altona : Self.elsewhere
    }

    func requestPermissionIfNeeded() async -> PlaceNotifications.Permission { permission }
    func currentFix() async throws -> LocationFix { fix }
}

#if os(iOS)
/// The system side: one `requestLocation`, the "while using the app" prompt when undecided, the name
/// by reverse geocoding (`MKReverseGeocodingRequest`, which replaces `CLGeocoder` since iOS 26).
@MainActor
final class SystemCurrentLocation: NSObject, CurrentLocating, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var permissionWaiters: [CheckedContinuation<PlaceNotifications.Permission, Never>] = []
    private var fixWaiters: [CheckedContinuation<LocationFix, Error>] = []
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Place")

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var permission: PlaceNotifications.Permission { .init(manager.authorizationStatus) }

    func requestPermissionIfNeeded() async -> PlaceNotifications.Permission {
        guard permission == .notDetermined else { return permission }
        return await withCheckedContinuation { continuation in
            permissionWaiters.append(continuation)
            if permissionWaiters.count == 1 { manager.requestWhenInUseAuthorization() }
        }
    }

    func currentFix() async throws -> LocationFix {
        try await withCheckedThrowingContinuation { continuation in
            fixWaiters.append(continuation)
            if fixWaiters.count == 1 { manager.requestLocation() }
        }
    }

    func placeName(for fix: LocationFix) async -> String? {
        let location = CLLocation(latitude: fix.latitude, longitude: fix.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else { return nil }
        do {
            guard let item = try await request.mapItems.first else { return nil }
            return item.address?.shortAddress ?? item.name
        } catch {
            Self.logger.error("Reverse geocoding failed: \(error, privacy: .public)")
            return nil
        }
    }

    private func answerPermission(_ permission: PlaceNotifications.Permission) {
        guard permission != .notDetermined else { return }   // the first callback comes before any answer
        let waiters = permissionWaiters
        permissionWaiters = []
        waiters.forEach { $0.resume(returning: permission) }
    }

    private func answerFix(_ result: Result<LocationFix, Error>) {
        let waiters = fixWaiters
        fixWaiters = []
        waiters.forEach { $0.resume(with: result) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let permission = PlaceNotifications.Permission(manager.authorizationStatus)
        Task { @MainActor in self.answerPermission(permission) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let fix = LocationFix(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude,
                              accuracy: last.horizontalAccuracy)
        Task { @MainActor in self.answerFix(.success(fix)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let failure = error as NSError
        Task { @MainActor in self.answerFix(.failure(failure)) }
    }
}
#endif
