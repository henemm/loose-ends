import Foundation

/// The place a user sets in the detail (#241, Schnitt 3a): set, switch arrive/leave, remove. Every
/// change is one user revision on `.place`; the same input again writes nothing. Pure over the
/// model objects; the caller saves.
enum PlaceEditing {
    /// The grey line under the place row, one at a time: not watched, then location off, then Mac.
    enum Note: Equatable, Sendable {
        /// Open with a place, but beyond the 20 places the system watches.
        case notWatched
        /// The location permission is refused in Settings: the place is kept but cannot remind (#241, Schnitt 3b).
        case locationOff
        /// The Mac does not deliver location reminders (`UNLocationNotificationTrigger` is iOS and watchOS only).
        case macOnly
    }

    @discardableResult
    static func set(_ place: TaskPlace, on task: TaskItem, now: Date = Date()) -> Revision? {
        RevisionService.set(.place, to: FieldCodec.encode(place), on: task, contexts: [], projects: [], now: now)
    }

    /// Arrive or leave; name and coordinate stay. Nothing without a place.
    @discardableResult
    static func setEvent(_ event: TaskPlace.Event, on task: TaskItem, now: Date = Date()) -> Revision? {
        guard let place = task.place,
              let changed = TaskPlace(name: place.name, latitude: place.latitude, longitude: place.longitude, event: event)
        else { return nil }
        return set(changed, on: task, now: now)
    }

    @discardableResult
    static func remove(from task: TaskItem, now: Date = Date()) -> Revision? {
        guard task.place != nil else { return nil }
        return RevisionService.set(.place, to: nil, on: task, contexts: [], projects: [], now: now)
    }

    /// `all` is every task, for the 20-place ranking. Beyond the limit wins over everything: it is true
    /// on every device. The Mac never reminds, so its note stands there instead of "location off".
    /// Undecided says nothing: the reconcile asks.
    static func note(for task: TaskItem, among all: [TaskItem], isMac: Bool,
                     permission: PlaceNotifications.Permission = .notDetermined) -> Note? {
        guard task.place != nil else { return nil }
        if PlaceReminders.plan(for: all).unwatched.contains(task.id) { return .notWatched }
        if isMac { return .macOnly }
        return permission == .refused ? .locationOff : nil
    }

    /// The current location as the task's place (#241, Schnitt 3b): the event stays, a new place arrives.
    @discardableResult
    static func setCurrent(_ fix: LocationFix, name: String, on task: TaskItem, now: Date = Date()) -> Revision? {
        guard let place = TaskPlace(name: name, latitude: fix.latitude, longitude: fix.longitude,
                                    event: task.place?.event ?? .arrive)
        else { return nil }
        return set(place, on: task, now: now)
    }

    /// The Mac has no current location to offer: it never reminds by place.
    static func offersCurrentLocation(isMac: Bool) -> Bool { !isMac }

    /// Beyond this reported accuracy a fix says nothing about being there.
    static let maxAccuracy: Double = 100

    /// Distance (haversine) within the radius plus the reported accuracy. Nil when the accuracy is
    /// invalid or too coarse to tell: unknown, never a guessed yes.
    static func isAlreadyThere(_ place: TaskPlace, at fix: LocationFix) -> Bool? {
        guard fix.accuracy >= 0, fix.accuracy <= maxAccuracy else { return nil }
        return fix.distance(toLatitude: place.latitude, longitude: place.longitude) <= TaskPlace.radius + fix.accuracy
    }

    /// "You're already here. Reminds you the next time you arrive.": only on arrive, only with a granted
    /// permission, and only when a fix says yes.
    static func showsAlreadyThere(_ place: TaskPlace, permission: PlaceNotifications.Permission, fix: LocationFix?) -> Bool {
        guard place.event == .arrive, permission == .whenInUse || permission == .always, let fix else { return false }
        return isAlreadyThere(place, at: fix) == true
    }
}

/// One location reading: coordinate and the reported horizontal accuracy in meters (negative = invalid).
struct LocationFix: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double

    private static let earthRadius: Double = 6_371_000

    /// Great-circle distance in meters (haversine).
    func distance(toLatitude otherLatitude: Double, longitude otherLongitude: Double) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = otherLatitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (otherLongitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * Self.earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }
}
