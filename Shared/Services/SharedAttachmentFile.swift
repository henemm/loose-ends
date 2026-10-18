import Foundation
import OSLog
import UniformTypeIdentifiers

/// The share extension's file handling (#442 Schnitt 2): which registered type is an attachment, and copying
/// the file a provider hands over (valid only inside its handler) into the extension's own temp folder.
/// Never holds the bytes; a file over 50 MB is not copied at all.
enum SharedAttachmentFile {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Share")

    /// The first image type, else the first data type that is no text, link or mail; nil = not an attachment.
    static func attachmentType(registered identifiers: [String]) -> String? {
        let types = identifiers.compactMap { id in UTType(id).map { (id, $0) } }
        if let image = types.first(where: { $0.1.conforms(to: .image) }) { return image.0 }
        let excluded: [UTType] = [.url, .text, .emailMessage]
        return types.first { id, type in
            type.conforms(to: .data) && !excluded.contains { type.conforms(to: $0) }
        }?.0
    }

    /// Copies `source` to `directory/<UUID>/<name>`. Reads the size first; over the limit nothing is copied
    /// and the result points at the source, so `classify` marks it too large and nobody reads it.
    static func adopt(_ source: URL, typeIdentifier: String, suggestedName: String?,
                      into directory: URL, at date: Date, photoPrefix: String) throws -> SharedAttachment {
        let byteCount = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let name = fileName(suggested: suggestedName, sourceName: source.lastPathComponent,
                            typeIdentifier: typeIdentifier, at: date, photoPrefix: photoPrefix)
        var fileURL = source
        if AttachmentKind.fits(byteCount: byteCount) {
            let folder = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            fileURL = folder.appendingPathComponent(name)
            try FileManager.default.copyItem(at: source, to: fileURL)
        }
        return SharedAttachment(fileURL: fileURL, fileName: name, typeIdentifier: typeIdentifier,
                                byteCount: byteCount, status: .ready)
    }

    /// The suggested name, else the source's; blank counts as missing. Then a photo name, or "File".
    static func fileName(suggested: String?, sourceName: String, typeIdentifier: String,
                         at date: Date, photoPrefix: String) -> String {
        for candidate in [suggested, sourceName] {
            if let candidate, !candidate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return candidate }
        }
        if UTType(typeIdentifier)?.conforms(to: .image) ?? false {
            return SharedAttachment.photoFileName(typeIdentifier: typeIdentifier, at: date, prefix: photoPrefix)
        }
        return "File"
    }

    /// A fresh, empty folder in the temp directory.
    static func makeDirectory() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("SharedAttachments-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Deletes the folder with its content. Already gone is fine; any other error is logged, never thrown.
    static func remove(_ directory: URL) {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            let error = error as NSError
            logger.error("Removing shared attachments failed: \(error.domain, privacy: .public) \(error.code, privacy: .public)")
        }
    }
}
