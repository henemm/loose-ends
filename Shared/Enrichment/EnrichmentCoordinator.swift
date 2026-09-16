import Foundation
import OSLog
import SwiftData

/// Runs enrichment for every task that has none yet (ADR-4): right after capture and as the
/// catch-up pass at app start. A failure leaves the task unprocessed for the next pass; nothing
/// is swallowed silently.
@MainActor
final class EnrichmentCoordinator {
    static let exampleLimit = 5

    private let enricher: any TaskEnricher
    private let container: ModelContainer
    private let logger = Logger(subsystem: "com.henning.looseends", category: "Enrichment")
    private var isRunning = false

    init(enricher: any TaskEnricher, container: ModelContainer) {
        self.enricher = enricher
        self.container = container
    }

    /// Processes all pending tasks once, oldest first. A call while a pass is running returns at once.
    func processPending() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        if let reason = enricher.unavailableReason {
            logger.notice("Enrichment skipped, model unavailable: \(reason, privacy: .public)")
            return
        }

        let context = container.mainContext
        do {
            let unprocessed = TaskStatus.unprocessed.rawValue
            let pending = try context.fetch(FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.processedAt == nil && $0.statusRaw == unprocessed },
                sortBy: [SortDescriptor(\.capturedAt)]
            ))
            guard !pending.isEmpty else { return }

            let contexts = try context.fetch(FetchDescriptor<TaskContext>(sortBy: [SortDescriptor(\.sortOrder)]))
            let projects = try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)]))
            let examples = try Self.examples(in: context)

            for task in pending {
                let input = EnrichmentInput(
                    rawText: task.rawText,
                    capturedAt: task.capturedAt,
                    contextVocabulary: contexts.map(\.name),
                    projectNames: projects.map(\.name),
                    examples: examples
                )
                do {
                    let draft = try await enricher.enrich(input)
                    let written = EnrichmentWriter.apply(draft, to: task, contexts: contexts, projects: projects)
                    try context.save()
                    logger.info("Enriched \(task.id, privacy: .public): \(written) fields")
                } catch {
                    logger.error("Enrichment failed for \(task.id, privacy: .public): \(error, privacy: .public)")
                }
            }
        } catch {
            logger.error("Enrichment pass failed: \(error, privacy: .public)")
        }
    }

    /// The most recent completed tasks with their final attributes. Similarity-based retrieval
    /// (ADR-5, on-device embeddings) replaces recency in a later slice.
    static func examples(in context: ModelContext, limit: Int = exampleLimit) throws -> [EnrichmentExample] {
        let done = TaskStatus.done.rawValue
        var descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.statusRaw == done },
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map { task in
            EnrichmentExample(
                rawText: task.rawText,
                title: task.title,
                importance: task.importance,
                urgency: task.urgency,
                duration: task.duration,
                energy: task.energy,
                contexts: (task.contexts ?? []).map(\.name)
            )
        }
    }
}
