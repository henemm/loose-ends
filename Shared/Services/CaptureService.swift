import Foundation
import os
import SwiftData

enum CaptureError: Error, Equatable {
    case emptyText
}

/// The one write path for new tasks. Every channel (app, Siri, Watch, Control Center, Share) goes
/// through here so the rules live in one place: the text is trimmed once and never touched again (ADR-3).
enum CaptureService {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Capture")

    /// The signature every channel had before #399; a pinned reference in `SiriCaptureTests` (AC-8 of #225) needs it.
    @discardableResult
    static func save(_ rawText: String, via channel: CaptureChannel, sourceURL: URL? = nil, in context: ModelContext) throws -> TaskItem {
        try save(rawText, via: channel, sourceURL: sourceURL, attachments: [], in: context)
    }

    @discardableResult
    static func save(
        _ rawText: String,
        via channel: CaptureChannel,
        sourceURL: URL? = nil,
        attachments: [SharedAttachment],
        in context: ModelContext
    ) throws -> TaskItem {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CaptureError.emptyText }
        let item = TaskItem(rawText: text, capturedVia: channel, sourceURL: sourceURL)
        // A title from the moment of capture, by rule: no AI marker, no revision (#202). Without the
        // words the rule step reads into due date, importance and urgency (#217).
        item.title = TitleRule.title(from: text, reference: item.capturedAt)
        context.insert(item)
        // Strictly rising times keep the shared order in the detail; to-many has no order (#399).
        for (index, attachment) in attachments.enumerated() where attachment.status == .ready {
            insert(attachment, for: item, at: item.capturedAt.addingTimeInterval(Double(index) / 1000), in: context)
        }
        try context.save()
        return item
    }

    /// Reads one ready attachment from disk, size checked first; a failure skips it and logs type and size only.
    private static func insert(_ attachment: SharedAttachment, for item: TaskItem, at date: Date, in context: ModelContext) {
        do {
            let size = try attachment.fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard AttachmentKind.fits(byteCount: size) else {
                logger.error("Shared attachment too large: \(attachment.typeIdentifier, privacy: .public), \(size) bytes")
                return
            }
            let data = try Data(contentsOf: attachment.fileURL)
            let stored = TaskAttachment(
                task: item, data: data, fileName: attachment.fileName,
                typeIdentifier: attachment.typeIdentifier, createdAt: date
            )
            context.insert(stored)
        } catch {
            logger.error("Reading a shared attachment failed: \(attachment.typeIdentifier, privacy: .public), \(attachment.byteCount) bytes")
        }
    }
}
