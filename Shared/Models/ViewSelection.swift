import Foundation

/// What the start screen has selected: a system view, one context, one project, or one task
/// from the "Next up" preview (#180). Everything is referenced by id so the selection survives renames.
enum ViewSelection: Hashable, Sendable {
    case system(ViewKind)
    case context(UUID)
    case project(UUID)
    case task(UUID)
}
