import Foundation
import OSLog
import SwiftData

/// Runs enrichment for every task that has none yet (ADR-4): right after capture and as the
/// catch-up pass at app start. A failure — model call or save — stays with that one task, leaves
/// it unprocessed for the next pass and does not stop the pass; nothing is swallowed silently.
@MainActor
final class EnrichmentCoordinator {
    static let exampleLimit = 5

    /// What "Analyze again" (#34) reports back to the detail.
    enum ReanalysisResult: Equatable, Sendable {
        /// Another pass is running; nothing was done.
        case busy
        /// `changed` fields got a new value; `modelRan` is false when only the rules ran.
        case finished(changed: Int, modelRan: Bool)
        /// Reading or saving the store failed (logged).
        case failed
    }

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
            let recognition = try Self.recognitionInputs(in: context)   // once before the loop (#136)

            for task in pending {
                applyRules(to: task, mode: .firstRun, recognitionPool: recognition.pool, tasksByID: recognition.tasksByID)
                // Outside the model block and outside its `do`/`catch` on purpose: the rule step ran,
                // whether or not the model was there and whether or not its call threw (#144).
                task.rulesAppliedAt = Date()
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

    /// The second analysis, only on the user's explicit request (ADR-4, #34): the same rule step and
    /// model call as the first run, in `EnrichmentWriter.Mode.reanalysis`. Every field the user never
    /// touched may change — AI-set or still empty —, each change is a new AI revision; a field the
    /// user set stays as it is, and a value found again unchanged adds nothing. A missing value in
    /// the new result never clears an existing one.
    func reanalyze(_ task: TaskItem) async -> ReanalysisResult {
        guard !isRunning else { return .busy }
        isRunning = true
        defer { isRunning = false }

        let context = container.mainContext
        let before = task.revisions?.count ?? 0
        let modelUnavailable = enricher.unavailableReason
        if let modelUnavailable {
            logger.notice("Model unavailable, re-analysis with rules only: \(modelUnavailable, privacy: .public)")
        }
        var modelRan = false
        do {
            let contexts = try context.fetch(FetchDescriptor<TaskContext>(sortBy: [SortDescriptor(\.sortOrder)]))
            let projects = try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)]))
            let recognition = try Self.recognitionInputs(in: context)
            // The task's own rule step ran before, so it sits in the pool: it must not recognise itself.
            let pool = recognition.pool.filter { $0.id != task.id }
            let ruleFields = applyRules(to: task, mode: .reanalysis, recognitionPool: pool, tasksByID: recognition.tasksByID)
            task.rulesAppliedAt = Date()

            if modelUnavailable == nil {
                let examples = try Self.examples(in: context)
                let input = EnrichmentInput(
                    rawText: task.rawText,
                    capturedAt: task.capturedAt,
                    contextVocabulary: contexts.map(\.name),
                    projectNames: projects.map(\.name),
                    examples: examples
                )
                do {
                    let draft = try await enricher.enrich(input)
                    EnrichmentWriter.apply(
                        draft, to: task, contexts: contexts, projects: projects, mode: .reanalysis, ruleFields: ruleFields
                    )
                    modelRan = true
                } catch {
                    logger.error("Re-analysis model call failed for \(task.id, privacy: .public): \(error, privacy: .public)")
                }
            }
            try context.save()
        } catch {
            logger.error("Re-analysis failed for \(task.id, privacy: .public): \(error, privacy: .public)")
            return .failed
        }
        let changed = (task.revisions?.count ?? 0) - before
        logger.info("Re-analysed \(task.id, privacy: .public): \(changed) fields")
        return .finished(changed: changed, modelRan: modelRan)
    }

    /// The rule step, before and independent of the model (#95, #117, #136): it writes due date,
    /// importance, urgency and — from a raw text captured before — duration and contexts the way
    /// `EnrichmentWriter` writes a model value — same field source, same revision — but leaves
    /// `processedAt` alone, because that marker means "the model has seen this task" (ADR-4). Each
    /// field only while it is still empty, so the catch-up pass adds no second revision (#95 AC-8,
    /// #117 AC-6, #136 AC-8). The four steps are independent of each other. In a re-analysis (#34)
    /// `EnrichmentWriter.mayWrite` decides instead: any field the user never touched, to a new value.
    /// Returns the fields a rule matched, written or not: the model leaves them alone (#34).
    @discardableResult
    private func applyRules(
        to task: TaskItem,
        mode: EnrichmentWriter.Mode,
        recognitionPool: [RecognitionRule.Candidate],
        tasksByID: [UUID: TaskItem]
    ) -> Set<RevisedField> {
        var matched = Set<RevisedField>()
        if applyDueDateRule(to: task, mode: mode) { matched.insert(.dueDate) }
        if applyImportanceRule(to: task, mode: mode) { matched.insert(.importance) }
        if applyUrgencyRule(to: task, mode: mode) { matched.insert(.urgency) }
        matched.formUnion(applyRecognitionRule(to: task, mode: mode, pool: recognitionPool, tasksByID: tasksByID))
        return matched
    }

    /// Each rule returns whether it matched, whether or not it wrote.
    private func applyDueDateRule(to task: TaskItem, mode: EnrichmentWriter.Mode) -> Bool {
        guard let match = DueDateRule.match(in: task.rawText, reference: task.capturedAt) else { return false }
        guard EnrichmentWriter.mayWrite(
            .dueDate, on: task, mode: mode, firstRun: task.dueDate == nil,
            changes: match.guess.value != task.dueDate || match.hasTime != task.dueHasTime
        ) else { return true }
        let revision = Revision(
            task: task,
            field: .dueDate,
            oldValue: task.dueDate?.ISO8601Format(),
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
        return true
    }

    private func applyImportanceRule(to task: TaskItem, mode: EnrichmentWriter.Mode) -> Bool {
        guard let guess = ImportanceUrgencyRule.matchImportance(in: task.rawText) else { return false }
        guard EnrichmentWriter.mayWrite(
            .importance, on: task, mode: mode, firstRun: task.importance == nil, changes: guess.value != task.importance
        ) else { return true }
        let revision = Revision(
            task: task,
            field: .importance,
            oldValue: task.importanceRaw,
            newValue: guess.value.rawValue,
            author: .ai,
            reason: guess.reason
        )
        task.revisions = (task.revisions ?? []) + [revision]
        task.importance = guess.value
        task.importanceSourceRaw = FieldSource.ai.rawValue
        task.importanceConfidence = guess.confidence
        logger.info("Rule set importance for \(task.id, privacy: .public)")
        return true
    }

    private func applyUrgencyRule(to task: TaskItem, mode: EnrichmentWriter.Mode) -> Bool {
        guard let guess = ImportanceUrgencyRule.matchUrgency(in: task.rawText) else { return false }
        guard EnrichmentWriter.mayWrite(
            .urgency, on: task, mode: mode, firstRun: task.urgency == nil, changes: guess.value != task.urgency
        ) else { return true }
        let revision = Revision(
            task: task,
            field: .urgency,
            oldValue: task.urgencyRaw,
            newValue: guess.value.rawValue,
            author: .ai,
            reason: guess.reason
        )
        task.revisions = (task.revisions ?? []) + [revision]
        task.urgency = guess.value
        task.urgencySourceRaw = FieldSource.ai.rawValue
        task.urgencyConfidence = guess.confidence
        logger.info("Rule set urgency for \(task.id, privacy: .public)")
        return true
    }

    /// The comparison set for the recognition, fetched once per pass and from tasks whose rule or
    /// model step already ran (#136, #144): a task of this very catch-up pass can structurally never
    /// feed another one, so an AI mistake cannot multiply — no runtime filter needed, it follows from
    /// the fetch time. No `done` filter either: a re-capture should take the values of a still open
    /// task too, unlike `examples`. The map resolves a hit back to its `TaskContext` objects.
    ///
    /// Two fetches instead of one `#Predicate` with `||`: no such predicate exists anywhere in this
    /// project, and whether SwiftData translates an OR predicate correctly against the CloudKit store
    /// is unproven. `uniquingKeysWith` deduplicates a task that carries both markers, and a task
    /// enriched before #144 (`processedAt != nil`, `rulesAppliedAt == nil`) stays reachable.
    static func recognitionInputs(
        in context: ModelContext
    ) throws -> (pool: [RecognitionRule.Candidate], tasksByID: [UUID: TaskItem]) {
        let byModel = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.processedAt != nil }))
        let byRules = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.rulesAppliedAt != nil }))
        let merged = Dictionary((byModel + byRules).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return (recognitionCandidates(in: Array(merged.values)), merged)
    }

    private static func recognitionCandidates(in tasks: [TaskItem]) -> [RecognitionRule.Candidate] {
        tasks.map { task in
            RecognitionRule.Candidate(
                id: task.id,
                rawText: task.rawText,
                duration: task.duration,
                durationSourceRaw: task.durationSourceRaw,
                contextNames: (task.contexts ?? []).map(\.name),
                contextsSourceRaw: task.contextsSourceRaw
            )
        }
    }

    /// Takes duration and contexts of a task whose raw text carries the same word set (#136, ADR-5).
    /// Contexts come over as the neighbour's `TaskContext` objects — same store, so no name can drift,
    /// unlike the name match in `EnrichmentWriter`. Energy stays untouched: the rule does not know it.
    private func applyRecognitionRule(
        to task: TaskItem, mode: EnrichmentWriter.Mode, pool: [RecognitionRule.Candidate], tasksByID: [UUID: TaskItem]
    ) -> Set<RevisedField> {
        guard let match = RecognitionRule.match(rawText: task.rawText, in: pool) else { return [] }
        var matched = Set<RevisedField>()
        if match.duration != nil { matched.insert(.duration) }
        if match.contexts != nil { matched.insert(.contexts) }

        // Empty is not the same as emptied by the user: `FieldCodec` clears `durationSourceRaw` along
        // with the value (`FieldCodec.swift:56`), so the origin marker cannot tell a field the user
        // reset (`RevisionService`) from one that was never set — only the user `Revision` can, and
        // revisions are never deleted (ADR-5: "corrections by the user stay first-class examples").
        if let hit = match.duration,
           EnrichmentWriter.mayWrite(
            .duration, on: task, mode: mode,
            firstRun: task.duration == nil && !EnrichmentWriter.userHasTouched(.duration, on: task),
            changes: hit.guess.value != task.duration
           ) {
            let revision = Revision(
                task: task, field: .duration, oldValue: task.durationRaw,
                newValue: hit.guess.value.rawValue, author: .ai, reason: hit.guess.reason
            )
            task.revisions = (task.revisions ?? []) + [revision]
            task.duration = hit.guess.value
            task.durationSourceRaw = FieldSource.ai.rawValue
            task.durationConfidence = hit.guess.confidence
            logger.info("Recognition set duration for \(task.id, privacy: .public)")
        }

        // An empty relationship counts as unset: SwiftData hands a to-many relationship back as an
        // empty array as readily as `nil`, and both mean "no context yet". Same second condition as
        // above, for the same reason: `FieldCodec` clears `contextsSourceRaw` when the list becomes
        // empty (`FieldCodec.swift:65`), so only a user `Revision` marks a list the user cleared.
        let current = Set((task.contexts ?? []).map(\.id))
        if let hit = match.contexts, let source = tasksByID[hit.sourceID],
           EnrichmentWriter.mayWrite(
            .contexts, on: task, mode: mode,
            firstRun: current.isEmpty && !EnrichmentWriter.userHasTouched(.contexts, on: task),
            changes: Set((source.contexts ?? []).map(\.id)) != current
           ) {
            let revision = Revision(
                task: task, field: .contexts,
                oldValue: current.isEmpty ? nil : EnrichmentWriter.encode((task.contexts ?? []).map(\.name)),
                newValue: EnrichmentWriter.encode(hit.guess.value), author: .ai, reason: hit.guess.reason
            )
            task.revisions = (task.revisions ?? []) + [revision]
            task.contexts = source.contexts
            task.contextsSourceRaw = FieldSource.ai.rawValue
            task.contextsConfidence = hit.guess.confidence
            logger.info("Recognition set contexts for \(task.id, privacy: .public)")
        }
        return matched
    }

    /// The most recent completed tasks with their final attributes, by recency. The similarity-picked
    /// examples ADR-5 once promised are gone (B1 decided 2026-09-27): measured word overlap only
    /// carries where the text recurs almost verbatim, and that case is `RecognitionRule` (#136).
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
                contexts: (task.contexts ?? []).map(\.name)
            )
        }
    }
}
