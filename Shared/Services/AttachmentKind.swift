import Foundation
import UniformTypeIdentifiers

/// How an attachment shows and what it may weigh (#442). Pure, over the type identifier and the bytes.
enum AttachmentKind {
    /// iCloud carries large assets, but a task is no file store: 50 MB is a scan of many pages.
    static let maximumBytes = 50 * 1024 * 1024

    static func fits(_ data: Data) -> Bool {
        data.count <= maximumBytes
    }

    /// The SF Symbol for the row: a photo, a PDF, or any other document.
    static func symbol(for typeIdentifier: String) -> String {
        guard let type = UTType(typeIdentifier) else { return "doc" }
        if type.conforms(to: .image) { return "photo" }
        if type.conforms(to: .pdf) { return "doc.richtext" }
        return "doc"
    }
}
