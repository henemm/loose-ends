import Foundation
import SwiftData

/// Every change to a derived field, by AI or user. Never deleted.
/// A user undo is a revision with `author == .user` and is a learning example (ADR-6).
@Model
final class Revision {
    var id: UUID = UUID()
    var task: TaskItem?
    var fieldRaw: String = RevisedField.title.rawValue
    var oldValue: String?       // JSON-encoded
    var newValue: String?       // JSON-encoded
    var authorRaw: String = FieldSource.ai.rawValue
    var reason: String?
    var createdAt: Date = Date()
    var seenAt: Date?

    init(task: TaskItem?, field: RevisedField, oldValue: String?, newValue: String?, author: FieldSource, reason: String? = nil) {
        self.task = task
        self.fieldRaw = field.rawValue
        self.oldValue = oldValue
        self.newValue = newValue
        self.authorRaw = author.rawValue
        self.reason = reason
    }

    var field: RevisedField {
        get { RevisedField(rawValue: fieldRaw) ?? .title }
        set { fieldRaw = newValue.rawValue }
    }
    var author: FieldSource {
        get { FieldSource(rawValue: authorRaw) ?? .ai }
        set { authorRaw = newValue.rawValue }
    }
}
