import Foundation
import SwiftData

/// A context is a tag with a deletable default set ("Garden" is a context, not a location).
@Model
final class TaskContext {
    var id: UUID = UUID()
    var name: String = ""
    var isSystemDefault: Bool = false
    var sortOrder: Int = 0
    @Relationship(inverse: \TaskItem.contexts) var tasks: [TaskItem]?

    init(name: String, isSystemDefault: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.isSystemDefault = isSystemDefault
        self.sortOrder = sortOrder
    }

    /// Localized default set, seeded once on first launch.
    static let defaultNameKeys: [String.LocalizationValue] = [
        "Computer", "Phone", "Home", "Garden", "Errands", "Out and about",
    ]
}
