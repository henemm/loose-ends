import Foundation

/// The inbox as a drawer on the start page (#601, Henning 2026-10-21, form 2): the writing line sits
/// right under the "New" button; the first Return opens the button into a drawer that holds what
/// this sitting typed, the line as its last row. Each typed sentence is a task the moment Return is
/// pressed (same write path as the capture sheet, the rules read it at once), so the number on the
/// button counts it honestly and the row shows it sorted. Ending the entry (keyboard down, a tap
/// beside, Escape, leaving the page, the background) folds the drawer back into the button: no
/// timer, no draft, nothing to lose. Pure; the view animates.
struct InboxDrawer: Equatable, Sendable {
    /// The tasks this sitting typed, oldest first.
    private(set) var captured: [UUID] = []
    private(set) var isOpen = false

    /// Return: the sentence is a task now; the drawer opens on the first one and keeps the order.
    mutating func didCapture(_ id: UUID) {
        captured.append(id)
        isOpen = true
    }

    /// The entry ended: the drawer folds and the sitting is over. The next Return starts a new one.
    mutating func close() {
        isOpen = false
        captured.removeAll()
    }

    /// The rows the open drawer shows: this sitting's tasks that still exist and are not done, oldest
    /// first. A task deleted or completed from its detail leaves the drawer on the way back.
    func rows(in tasks: [TaskItem]) -> [TaskItem] {
        guard isOpen else { return [] }
        let byID = Dictionary(tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return captured.compactMap { byID[$0] }.filter { $0.status != .done }
    }
}
