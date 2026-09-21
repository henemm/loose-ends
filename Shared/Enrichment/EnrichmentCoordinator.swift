import Foundation
import OSLog
import SwiftData

/// Runs enrichment for every task that has none yet (ADR-4): right after capture and as the
/// catch-up pass at app start. A failure — model call or save — stays with that one task, leaves
/// it unprocessed for the next pass and does not stop the pass; nothing is swallowed silently.
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

        // An unavailable model ends the model step, not the pass: the rule runs anyway (#95, AC-7).
        let modelUnavailable = enricher.unavailableReason
        if let modelUnavailable {
            logger.notice("Model unavailable, rules only: \(modelUnavailable, privacy: .public)")
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
            let examples = modelUnavailable == nil ? try Self.examples(in: context) : []

            for task in pending {
                applyRules(to: task)
                if modelUnavailable == nil {
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
                        logger.info("Enriched \(task.id, privacy: .public): \(written) fields")
                    } catch {
                        logger.error("Enrichment failed for \(task.id, privacy: .public): \(error, privacy: .public)")
                    }
                }
                // Saving per task, caught per task: a failed save skips this one task, the pass
                // continues with the next (#95). The rule hit is persisted even when the model
                // was unavailable or its call failed.
                do {
                    try context.save()
                } catch {
                    logger.error("Saving failed for \(task.id, privacy: .public): \(error, privacy: .public)")
                }
            }
        } catch {
            logger.error("Enrichment pass failed: \(error, privacy: .public)")
        }
    }

    /// The rule step, before and independent of the model (#95): it writes the due date the way
    /// `EnrichmentWriter` writes a model value — same field source, same revision — but leaves
    /// `processedAt` alone, because that marker means "the model has seen this task" (ADR-4).
    /// Only while `dueDate` is still empty, so the catch-up pass adds no second revision (AC-8).
    private func applyRules(to task: TaskItem) {
        guard task.dueDate == nil,
              let match = DueDateRule.match(in: task.rawText, reference: task.capturedAt) else { return }
        let revision = Revision(
            task: task,
            field: .dueDate,
            oldValue: nil,
            newValue: match.guess.value.ISO8601Format(),
            author: .ai,
            reason: match.guess.reason
        )
        task.revisions = (task.revisions ?? []) + [revision]
        task.dueDate = match.guess.value
        task.dueHasTime = match.hasTime
        task.dueSourceRaw = FieldSource.ai.rawValue
        task.dueConfidence = match.guess.confidence
        logger.info("Rule set due date for \(task.id, privacy: .public)")
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
