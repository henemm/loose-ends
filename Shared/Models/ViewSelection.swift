import Foundation

/// What the start screen has selected: a system view, one context, one project, one task
/// from the "Next up" preview (#180), or on iPhone the page that keeps all tags or all projects (#428).
/// Everything is referenced by id so the selection survives renames.
enum ViewSelection: Hashable, Sendable {
    case system(ViewKind)
    case context(UUID)
    case project(UUID)
    case task(UUID)
    case catalog(CatalogKind)
}

/// The two catalogs the user keeps by hand: tags (`TaskContext`) and projects.
enum CatalogKind: Hashable, Sendable {
    case tags
    case projects
}
