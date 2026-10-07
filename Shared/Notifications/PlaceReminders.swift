import Foundation

/// Which places the iPhone watches (#226). The system watches at most 20 regions per app, so the
/// open tasks with a place are ranked and cut there; the rest is named, never dropped silently.
/// Pure planning; the system wiring comes with the delivery.
enum PlaceReminders {
    static let limit = 20
    static let identifierPrefix = "place_"

    struct Reminder: Equatable, Sendable {
        let taskID: UUID
        let title: String
        let place: TaskPlace

        var identifier: String { PlaceReminders.identifierPrefix + taskID.uuidString }
    }

    struct Plan: Equatable, Sendable {
        /// At most `limit`, in rank order.
        let watched: [Reminder]
        /// Open, with a place, but beyond the limit.
        let unwatched: [UUID]
    }

    /// Records that the place reminded, so the next plan leaves it out (once, then not again). Returns
    /// false when the task no longer exists. A second call keeps the first time.
    @discardableResult
    static func markDelivered(taskID: UUID, in tasks: [TaskItem], now: Date = Date()) -> Bool {
        guard let task = tasks.first(where: { $0.id == taskID }) else { return false }
        if task.placeRemindedAt == nil { task.placeRemindedAt = now }
        return true
    }

    /// Next up first (by its order), then by due date, then the newest; the id breaks ties so every
    /// run yields the same list. Parked and completed tasks do not remind, nor do places that already
    /// reminded (`placeRemindedAt`).
    static func plan(for tasks: [TaskItem]) -> Plan {
        let ranked = tasks
            .filter { $0.isOpen && $0.place != nil && $0.placeRemindedAt == nil }
            .sorted(by: ranksBefore)
        let watched = ranked.prefix(limit).compactMap { task in
            task.place.map { Reminder(taskID: task.id, title: task.displayTitle, place: $0) }
        }
        return Plan(watched: watched, unwatched: ranked.dropFirst(limit).map(\.id))
    }

    private static func ranksBefore(_ a: TaskItem, _ b: TaskItem) -> Bool {
        switch (a.nextRank, b.nextRank) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }
        switch (a.dueDate, b.dueDate) {
        case let (x?, y?) where x != y: return x < y
        case (_?, nil): return true
        case (nil, _?): return false
        default: break
        }
        if a.capturedAt != b.capturedAt { return a.capturedAt > b.capturedAt }
        return a.id.uuidString < b.id.uuidString
    }
}
