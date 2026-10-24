import Foundation

/// Which SF Symbol stands with which field (#344): one source for the list row and the detail's register line.
/// Plain names, no SwiftUI, so `Shared/` stays watchOS-safe.
enum FieldGlyph {
    /// Importance is a ladder of exclamation marks, one per level.
    static func importance(_ level: Importance) -> String {
        switch level {
        case .low: "exclamationmark"
        case .medium: "exclamationmark.2"
        case .high: "exclamationmark.3"
        }
    }

    /// The sign of a field, the same in every level (the word carries the level). Importance has none here:
    /// its ladder is `importance(_:)`. Fields without a sign give nil.
    static func symbol(for field: RevisedField) -> String? {
        switch field {
        case .urgency: "flame"
        case .dueDate: "calendar"
        case .duration: "clock"
        case .project: "folder"
        default: nil
        }
    }
}
