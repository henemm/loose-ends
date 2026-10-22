import Foundation
import SwiftData

/// A context is a tag with a deletable default set ("Garden" is a context, not a location).
@Model
final class TaskContext {
    var id: UUID = UUID()
    var name: String = ""
    var isSystemDefault: Bool = false
    var sortOrder: Int = 0
    /// Words the user struck from this tag's learned list (#233 Schnitt 2b), normalized like
    /// `RawTextWords.normalized`, one per line: never learned for this tag again, on every device. One
    /// string, not an array, so CloudKit carries it as a single additive field (#175).
    var forgottenWordsRaw: String = ""
    @Relationship(inverse: \TaskItem.contexts) var tasks: [TaskItem]?

    var forgottenWords: Set<String> {
        get { Set(forgottenWordsRaw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }) }
        set { forgottenWordsRaw = newValue.sorted().joined(separator: "\n") }
    }

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
