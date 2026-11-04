import Foundation

/// Where "Back" leads from a task opened by the sidebar's selection (#830): the start page's rows, the writing
/// line under "New", the side column, the widget and a notification open a task that way, and its detail
/// then stood alone in its stack without a way back. Pure; `ContentView` follows every change of the selection.
struct DetailBack: Equatable {
    /// The selection before the task opened: nil is the start page. Nil as a whole while no task is open.
    private(set) var origin: ViewSelection??

    /// Whether the open task has a way back.
    var isOffered: Bool { origin != nil }

    /// Where "Back" leads; the start page when nothing was remembered.
    var destination: ViewSelection? { origin ?? nil }

    /// From one selection to the next. Task to task (a widget opening another task) keeps the first origin,
    /// so "Back" never leads to a task that was replaced.
    mutating func follow(from old: ViewSelection?, to new: ViewSelection?) {
        guard case .task = new else {
            origin = nil
            return
        }
        if case .task = old {
            if origin == nil { origin = .some(nil) }
            return
        }
        origin = .some(old)
    }
}
