import AppIntents
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// Siri's "create reminder" over Apple's reminders schema (#25 Schnitt 2b-1). The macro requires every
/// schema parameter; values Loose Ends has no place for (images, section) are rejected by `SiriCapture`.
/// Errors go up unchanged: Siri reads its general failure sentence, and no task is left behind.
@AppIntent(schema: .reminders.createReminder)
struct CreateReminderIntent: AppIntent {
    /// Own title: without it the metadata carries none, and Shortcuts does not list the action (AC-9).
    static let title: LocalizedStringResource = "Create Reminder"

    var title: String
    var list: ListEntity?
    var note: AttributedString?
    var dueDate: DateComponents?
    var isFlagged: Bool?
    @Parameter(default: [], supportedContentTypes: [.image]) var images: [IntentFile]
    @Parameter(default: []) var tags: Set<String>
    @Parameter(default: []) var urls: [URL]
    var recurrence: Calendar.RecurrenceRule?
    var locationTrigger: LocationTriggerEntity?
    var section: SectionEntity?

    /// Glue only: the container stays held in a local for as long as the context is used.
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ReminderEntity> {
        let container = try ModelContainerFactory.make()
        // A context does not retain its container; keep it alive until perform returns (F001).
        defer { withExtendedLifetime(container) {} }
        let context = ModelContext(container)
        let input = ReminderTranslation.input(
            title: title, note: note, dueDate: dueDate, list: list, recurrence: recurrence,
            locationTrigger: locationTrigger, urls: urls, isFlagged: isFlagged, tags: tags, section: section,
            imageCount: images.count
        )
        let task = try await Self.create(input, in: context, geocode: Geocoding.live)
        return .result(value: ReminderEntity(task: task))
    }

    /// Checks everything, then writes: `prepare` throws before anything is stored, `commit` cleans up after itself.
    @MainActor
    static func create(
        _ input: SiriCapture.Input, in context: ModelContext, geocode: @escaping SiriCapture.Geocode
    ) async throws -> TaskItem {
        let prepared = try await SiriCapture.prepare(input, in: context, geocode: geocode)
        return try SiriCapture.commit(prepared, in: context)
    }
}
