import Foundation

/// What the start screen has selected: a system view, one context, or one project.
/// Contexts and projects are referenced by id so the selection survives renames.
enum ViewSelection: Hashable, Sendable {
    case system(ViewKind)
    case context(UUID)
    case project(UUID)
}
