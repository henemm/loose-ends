import Foundation
import UniformTypeIdentifiers

/// A photo or file from the share sheet before it is saved (#399). It points at a temporary copy and
/// never holds the bytes: the extension has little memory, so each file is read only when it is inserted.
struct SharedAttachment: Equatable, Sendable {
    enum Status: Equatable, Sendable { case ready, tooLarge, overLimit }
    static let maximumCount = 10

    var fileURL: URL
    var fileName: String
    var typeIdentifier: String
    var byteCount: Int
    var status: Status

    /// "Befund_Dr-Meier.pdf" → "Befund Dr Meier": no extension, `_` and `-` as spaces, single spaces, trimmed.
    static func title(fromFileName fileName: String) -> String {
        // By hand, not `deletingPathExtension`: that keeps ".pdf" whole as a hidden file's name.
        var base = Substring(fileName)
        if let dot = fileName.lastIndex(of: "."), !fileName[dot...].dropFirst().contains(where: \.isWhitespace) {
            base = fileName[..<dot]
        }
        let spaced = base.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        return spaced.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Named like a photo added in the detail: "Photo <date, time>.<extension>".
    static func photoFileName(typeIdentifier: String, at date: Date, prefix: String = "Photo") -> String {
        let ext = UTType(typeIdentifier)?.preferredFilenameExtension ?? "jpg"
        return "\(prefix) \(date.formatted(date: .numeric, time: .shortened)).\(ext)"
    }

    /// Same order out as in: over 50 MB is too large, after ten ready ones the rest is over the limit.
    static func classify(_ attachments: [SharedAttachment]) -> [SharedAttachment] {
        var readyCount = 0
        return attachments.map { attachment in
            var result = attachment
            if !AttachmentKind.fits(byteCount: attachment.byteCount) {
                result.status = .tooLarge
            } else if readyCount >= maximumCount {
                result.status = .overLimit
            } else {
                result.status = .ready
                readyCount += 1
            }
            return result
        }
    }
}
