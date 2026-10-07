import Foundation

/// What this device hands to the system for its watched places, and what it takes back (#226, Schnitt 2a).
/// The system never reports whether a place notification was delivered, so the app remembers what it
/// handed over (task plus fingerprint) and only passes on the difference. A request that is no longer
/// pending with an unchanged fingerprint counts as fired and is not handed over again. Pure planning.
enum PlaceDelivery {
    /// What the app handed to this device's system. Stored by the system wiring (2b).
    struct Handover: Codable, Equatable, Sendable {
        /// Sorted by `taskID.uuidString`, at most one per task.
        var entries: [Entry]
    }

    struct Entry: Codable, Equatable, Hashable, Sendable {
        let taskID: UUID
        let fingerprint: String
        /// The title handed over, to notice a title change.
        let title: String
    }

    struct Changes: Equatable, Sendable {
        /// Create, sorted by identifier.
        let add: [PlaceReminders.Reminder]
        /// Identifiers to remove, sorted, without duplicates.
        let remove: [String]
        /// Replace only the title, sorted by identifier.
        let updateContent: [PlaceReminders.Reminder]
        /// The new handover list.
        let handover: Handover
    }

    /// `<event>|<latitude>|<longitude>|<cycle>|<name>`. The name comes last, so a separator in it cannot
    /// collide. Coordinates at five decimals (about 1 m); the cycle is the due date of a repeating task,
    /// so ticking it off arms it again; a one-off ignores its due date.
    static func fingerprint(of reminder: PlaceReminders.Reminder, in task: TaskItem?) -> String {
        let place = reminder.place
        let posix = Locale(identifier: "en_US_POSIX")
        // Round first and add 0.0, so a value that rounds to zero loses its sign ("-0.00000").
        let latitude = String(format: "%.5f", locale: posix, (place.latitude * 1e5).rounded() / 1e5 + 0.0)
        let longitude = String(format: "%.5f", locale: posix, (place.longitude * 1e5).rounded() / 1e5 + 0.0)
        var cycle = "-"
        if let task, task.repeatRule != nil, let due = task.dueDate {
            cycle = String(Int(due.timeIntervalSince1970.rounded()))
        }
        return [place.event.rawValue, latitude, longitude, cycle, place.name].joined(separator: "|")
    }

    /// Only the difference between the plan and what was handed over. Without authorization nothing is
    /// handed over or noted, but withdrawing still runs: removing a request needs no authorization.
    static func diff(
        plan: PlaceReminders.Plan,
        tasks: [TaskItem],
        handover: Handover,
        pending: Set<String>,
        authorized: Bool
    ) -> Changes {
        let watchedTasks = Set(plan.watched.map(\.taskID))
        let kept = handover.entries.filter { watchedTasks.contains($0.taskID) }
        var entries = Dictionary(kept.map { ($0.taskID, $0) }, uniquingKeysWith: { first, _ in first })
        var remove = withdrawn(plan: plan, pending: pending)
        guard authorized else {
            return changes(add: [], remove: remove, updateContent: [], entries: entries)
        }
        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var add: [PlaceReminders.Reminder] = []
        var updateContent: [PlaceReminders.Reminder] = []
        for reminder in plan.watched {
            let print = fingerprint(of: reminder, in: byID[reminder.taskID])
            let open = pending.contains(reminder.identifier)
            switch action(for: reminder, entry: entries[reminder.taskID], fingerprint: print, open: open) {
            case .keep: continue
            case .adopt: break
            case .add: add.append(reminder)
            case .replace:
                remove.insert(reminder.identifier)
                add.append(reminder)
            case .updateContent: updateContent.append(reminder)
            }
            entries[reminder.taskID] = Entry(taskID: reminder.taskID, fingerprint: print, title: reminder.title)
        }
        return changes(add: add, remove: remove, updateContent: updateContent, entries: entries)
    }

    private enum Action { case keep, adopt, add, replace, updateContent }

    /// Rules 1–4, 7 and 11 of the spec for one watched reminder.
    private static func action(
        for reminder: PlaceReminders.Reminder,
        entry: Entry?,
        fingerprint: String,
        open: Bool
    ) -> Action {
        guard let entry else { return open ? .adopt : .add }
        if entry.fingerprint != fingerprint { return open ? .replace : .add }
        return open && entry.title != reminder.title ? .updateContent : .keep
    }

    /// Every pending place request without a watched reminder: dropped out of the plan or orphaned.
    /// Other kinds of requests are never touched.
    private static func withdrawn(plan: PlaceReminders.Plan, pending: Set<String>) -> Set<String> {
        let watched = Set(plan.watched.map(\.identifier))
        return pending.filter { $0.hasPrefix(PlaceReminders.identifierPrefix) && !watched.contains($0) }
    }

    private static func changes(
        add: [PlaceReminders.Reminder],
        remove: Set<String>,
        updateContent: [PlaceReminders.Reminder],
        entries: [UUID: Entry]
    ) -> Changes {
        Changes(
            add: add.sorted { $0.identifier < $1.identifier },
            remove: remove.sorted(),
            updateContent: updateContent.sorted { $0.identifier < $1.identifier },
            handover: Handover(entries: entries.values.sorted { $0.taskID.uuidString < $1.taskID.uuidString })
        )
    }
}
