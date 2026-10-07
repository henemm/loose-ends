import Foundation

/// The place a user sets in the detail (#241, Schnitt 3a): set, switch arrive/leave, remove. Every
/// change is one user revision on `.place`; the same input again writes nothing. Pure over the
/// model objects; the caller saves.
enum PlaceEditing {
    /// The grey line under the place row. The location permission note comes with Schnitt 3b.
    enum Note: Equatable, Sendable {
        /// Open with a place, but beyond the 20 places the system watches.
        case notWatched
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

    /// `all` is every task, for the 20-place ranking. Beyond the limit wins over the Mac note: it is
    /// true on every device.
    static func note(for task: TaskItem, among all: [TaskItem], isMac: Bool) -> Note? {
        guard task.place != nil else { return nil }
        if PlaceReminders.plan(for: all).unwatched.contains(task.id) { return .notWatched }
        return isMac ? .macOnly : nil
    }
}
