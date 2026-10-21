import Foundation

/// The keys a list row answers to on the Mac (#480): the arrows choose, Space finishes, Delete asks.
enum RowKey {
    case up, down, space, delete
}

/// What a key does to the list's rows (#480), pure so the table in the spec is the test.
/// The view carries it out with the actions it already has; nothing here touches a task.
enum RowKeyAction: Equatable {
    case select(UUID)
    case complete(UUID)
    case delete(UUID)
    case ignore

    /// `ids` are the rows as shown, top to bottom. A selection no longer among them counts as none.
    /// At the edges the selection stays; there is no wrapping around. `completes` says whether Space may
    /// finish a row (see `spaceCompletes`); a row it may not finish ignores Space. Delete asks everywhere.
    static func resolve(
        _ key: RowKey, textFocused: Bool, selection: UUID?, ids: [UUID],
        completes: (UUID) -> Bool = { _ in true }
    ) -> RowKeyAction {
        guard !textFocused, let first = ids.first, let last = ids.last else { return .ignore }
        guard let selection, let index = ids.firstIndex(of: selection) else {
            switch key {
            case .down: return .select(first)
            case .up: return .select(last)
            case .space, .delete: return .ignore
            }
        }
        switch key {
        case .down: return .select(ids[min(index + 1, ids.count - 1)])
        case .up: return .select(ids[max(index - 1, 0)])
        case .space: return completes(selection) ? .complete(selection) : .ignore
        case .delete: return .delete(selection)
        }
    }

    /// The row a list remembered comes back only while it is still shown; else nothing is chosen.
    static func restored(_ remembered: UUID?, ids: [UUID]) -> UUID? {
        remembered.flatMap { ids.contains($0) ? $0 : nil }
    }

    /// Space finishes only where the swipe offers Done: never in Completed (only Restore; it would set
    /// the completion again), New (the inbox only confirms, #318) or Parked (only Activate), and never a
    /// parked task, the parked block of "All open" included.
    static func spaceCompletes(in kind: ViewKind?, status: TaskStatus) -> Bool {
        switch kind {
        case .done?, .new?, .parked?: false
        default: status != .parked && status != .done
        }
    }
}
