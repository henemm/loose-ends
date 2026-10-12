import Intents
import OSLog
import SwiftData

/// Siri's own task intent, handled outside the app (#353). Apple's rule for app name synonyms
/// (`INAlternativeAppNames`): Siri recognizes them only for apps with an Intents extension that
/// supports at least one intent. German Siri hears "Loose End"; without this extension the synonym
/// for exactly that was ignored ("Ich finde keine passende App", Build 44).
///
/// Every title becomes one raw text through `CaptureService`, the one write path. The extension has
/// no iCloud entitlement (the CI key cannot add it to a new identifier, #307), so it opens the
/// app-group store without sync; the app's mirroring exports the change on its next run (#320).
final class IntentHandler: INExtension, INAddTasksIntentHandling {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "SiriIntent")

    override func handler(for intent: INIntent) -> Any { self }

    func resolveTaskTitles(for intent: INAddTasksIntent) async -> [INSpeakableStringResolutionResult] {
        let titles = (intent.taskTitles ?? []).filter { !$0.spokenPhrase.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !titles.isEmpty else { return [.needsValue()] }
        return titles.map { .success(with: $0) }
    }

    func handle(intent: INAddTasksIntent) async -> INAddTasksIntentResponse {
        let titles = (intent.taskTitles ?? []).map(\.spokenPhrase)
        do {
            let saved = try await Self.save(titles)
            let response = INAddTasksIntentResponse(code: .success, userActivity: nil)
            response.addedTasks = saved.map {
                INTask(title: INSpeakableString(spokenPhrase: $0), status: .notCompleted, taskType: .completable,
                       spatialEventTrigger: nil, temporalEventTrigger: nil, createdDateComponents: nil,
                       modifiedDateComponents: nil, identifier: nil)
            }
            return response
        } catch {
            Self.logger.error("Siri capture failed: \(error, privacy: .public)")
            return INAddTasksIntentResponse(code: .failure, userActivity: nil)
        }
    }

    /// The container stays alive for the whole save; a context does not retain it.
    @MainActor
    private static func save(_ titles: [String]) throws -> [String] {
        let container = try ModelContainerFactory.make(syncs: false)
        let context = ModelContext(container)
        var saved: [String] = []
        for title in titles {
            do {
                saved.append(try CaptureService.save(title, via: .siri, in: context).rawText)
            } catch CaptureError.emptyText {
                logger.info("Skipped an empty title from Siri")
            }
        }
        guard !saved.isEmpty else { throw CaptureError.emptyText }
        return saved
    }
}
