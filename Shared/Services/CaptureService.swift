import Foundation
import SwiftData

enum CaptureError: Error, Equatable {
    case emptyText
}

/// The one write path for new tasks. Every channel (app, Siri, Watch, Control Center, Share) goes
/// through here so the rules live in one place: the text is trimmed once and never touched again (ADR-3).
enum CaptureService {
    @discardableResult
    static func save(
        _ rawText: String,
        via channel: CaptureChannel,
        sourceURL: URL? = nil,
        in context: ModelContext
    ) throws -> TaskItem {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw CaptureError.emptyText }
        let item = TaskItem(rawText: text, capturedVia: channel, sourceURL: sourceURL)
        context.insert(item)
        try context.save()
        return item
    }
}
