import Foundation
import SwiftData

/// A file on a task (#442): a photo, a scan or a document. The bytes live outside the store and travel
/// to CloudKit as an asset (`externalStorage`). Added 2026-10-15, additive for CloudKit; the views
/// that add and show attachments follow in their own slice.
@Model
final class Attachment {
    var id: UUID = UUID()
    var task: TaskItem?
    @Attribute(.externalStorage) var data: Data?
    /// What the user sees, e.g. "Befund.pdf".
    var fileName: String = ""
    /// The uniform type identifier, e.g. "public.jpeg" or "com.adobe.pdf".
    var typeIdentifier: String = ""
    var createdAt: Date = Date()

    init(task: TaskItem?, data: Data, fileName: String, typeIdentifier: String, createdAt: Date = Date()) {
        self.task = task
        self.data = data
        self.fileName = fileName
        self.typeIdentifier = typeIdentifier
        self.createdAt = createdAt
    }
}
