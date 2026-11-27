import Foundation
import OSLog
import SwiftData

/// Runs the rule step for every task that has had none yet (ADR-4): right after capture and as the
/// catch-up pass at app start. The on-device model is out of the product path (ADR-22, #982): this type
/// cannot receive or call one, every field comes from the rules. `processedAt` keeps its meaning "the
/// model ran" and is no longer set; `rulesAppliedAt` marks the one rule run (#144). A failed save stays
/// with that one task and does not stop the pass; nothing is swallowed silently.
@MainActor
final class EnrichmentCoordinator {
    /// What "Analyze again" (#34) reports back to the detail.
    enum ReanalysisResult: Equatable, Sendable {
        /// Another pass is running; nothing was done.
        case busy
        /// `changed` fields got a new value from the rules.
        case finished(changed: Int)
        /// Reading or saving the store failed (logged).
        case failed
    }

    private let container: ModelContainer
    /// Home and work as the user saved them (#680), read at each rule step; the app passes its store.
    private let savedPlaces: @MainActor () -> SavedPlaces
    private let logger = Logger(subsystem: "com.henning.looseends", category: "Enrichment")
    private var isRunning = false

    init(
        container: ModelContainer,
        savedPlaces: @escaping @MainActor () -> SavedPlaces = { .empty }
    ) {
        self.container = container
        self.savedPlaces = savedPlaces
    }

    /// Runs the rule step once for all pending tasks, oldest first. A call while a pass is running returns at once.
    func processPending() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let context = container.mainContext
        // Lines under a task first (#565): their two rules, so an added line shows its date and tag
        // at once; the pass below is for top-level tasks only.
        applySubtaskRules(in: context)
        do {
            let pending = try pendingTasks(in: context)
            guard !pending.isEmpty else { return }

            let contexts = try context.fetch(FetchDescriptor<TaskContext>(sortBy: [SortDescriptor(\.sortOrder)]))
            let projects = try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)]))
            let recognition = try Self.recognitionInputs(in: context)   // once before the loop (#136)
            let learned = Self.learnedWords(from: recognition.tasksByID.values, catalog: contexts)   // once as well (#233)

            for task in pending {
                applyRules(to: task, mode: .firstRun, catalog: contexts, projects: projects,
                           recognitionPool: recognition.pool, tasksByID: recognition.tasksByID, learned: learned)
                task.rulesAppliedAt = Date()
                // Saving per task, caught per task: a failed save skips this one task, the pass
                // continues with the next (#95).
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

    /// The tasks still owed their one rule run (ADR-4): unprocessed ones, and open top-level tasks the
    /// user vouched for with "Looks right" before the pass (#318) or activated again from parked. Without
    /// the model `processedAt` stays empty, so `rulesAppliedAt` limits the pass to one run per task
    /// (#982); `processedAt == nil` keeps out tasks the model saw before #144, which never got the rule
    /// marker, so they get no late rule duration. Two fetches instead of `||`, as in `recognitionInputs`.
    private func pendingTasks(in context: ModelContext) throws -> [TaskItem] {
        let unprocessed = TaskStatus.unprocessed.rawValue
        let active = TaskStatus.active.rawValue
        let waiting = try context.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.processedAt == nil && $0.rulesAppliedAt == nil && $0.statusRaw == unprocessed }
        ))
        let confirmed = try context.fetch(FetchDescriptor<TaskItem>(
            predicate: #Predicate { $0.processedAt == nil && $0.rulesAppliedAt == nil && $0.statusRaw == active }
        )).filter { $0.parent == nil }
        return (waiting + confirmed).sorted { $0.capturedAt < $1.capturedAt }
    }

    /// The second analysis, only on the user's explicit request (ADR-4, #34): the same rule step as the
    /// first run, in `EnrichmentWriter.Mode.reanalysis`, no model (ADR-22, #982). Every field the user
    /// never touched may change to a new rule value, each change a new rule revision, and every older
    /// revision (an old AI one too) stays; a field the user set stays as it is, and a value found again
    /// unchanged adds nothing. A field no rule finds keeps its value.
    func reanalyze(_ task: TaskItem) async -> ReanalysisResult {
        guard !isRunning else { return .busy }
        isRunning = true
        defer { isRunning = false }

        let context = container.mainContext
        let before = task.revisions?.count ?? 0
        do {
            let contexts = try context.fetch(FetchDescriptor<TaskContext>(sortBy: [SortDescriptor(\.sortOrder)]))
            let recognition = try Self.recognitionInputs(in: context)
            let learned = Self.learnedWords(from: recognition.tasksByID.values, catalog: contexts)
            if task.parent != nil {
                // A line under a task is read again by its two rules only (#565).
                applySubtaskRules(to: task, mode: .reanalysis, catalog: contexts, learned: learned)
            } else {
                let projects = try context.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)]))
                // The task's own rule step ran before, so it sits in the pool: it must not recognise itself.
                let pool = recognition.pool.filter { $0.id != task.id }
                applyRules(to: task, mode: .reanalysis, catalog: contexts, projects: projects,
                           recognitionPool: pool, tasksByID: recognition.tasksByID, learned: learned)
            }
            task.rulesAppliedAt = Date()
            try context.save()
        } catch {
            logger.error("Re-analysis failed for \(task.id, privacy: .public): \(error, privacy: .public)")
            return .failed
        }
        let changed = (task.revisions?.count ?? 0) - before
        logger.info("Re-analysed \(task.id, privacy: .public): \(changed) fields")
        return .finished(changed: changed)
    }

    /// The rule step (#95, #117, #136): it writes due date, importance, urgency, a duration the user
    /// named (#673) and — from a raw text captured before — duration and contexts, one revision per
    /// field with the origin `rule`, read from the user's words rather than guessed (#101), and leaves
    /// `processedAt` alone, because that marker means "the model has seen this task" (ADR-4). Each
    /// field only while it is still empty, so the catch-up pass adds no second revision (#95 AC-8,
    /// #117 AC-6, #136 AC-8). The four steps are independent of each other. In a re-analysis (#34)
    /// `EnrichmentWriter.mayWrite` decides instead: any field the user never touched, to a new value.
    /// Returns the fields a rule matched, written or not.
    @discardableResult
    private func applyRules(
        to task: TaskItem,
        mode: EnrichmentWriter.Mode,
        catalog: [TaskContext],
        projects: [Project],
        recognitionPool: [RecognitionRule.Candidate],
        tasksByID: [UUID: TaskItem],
        learned: [String: Set<String>]
    ) -> Set<RevisedField> {
        var matched = Set<RevisedField>()
        if applyDueDateRule(to: task, mode: mode) { matched.insert(.dueDate) }
        if applyImportanceRule(to: task, mode: mode) { matched.insert(.importance) }
        if applyUrgencyRule(to: task, mode: mode) { matched.insert(.urgency) }
        matched.formUnion(applyRecognitionRule(to: task, mode: mode, pool: recognitionPool, tasksByID: tasksByID))
        // A named length only where recognition found nothing: recognition beats the word rule (#673).
        if !matched.contains(.duration), applyDurationRule(to: task, mode: mode) { matched.insert(.duration) }
        // The word list only where recognition found nothing: a text captured before carries what
        // the user decided then, which beats a word list (#232).
        if !matched.contains(.contexts), applyContextWordRule(to: task, mode: mode, catalog: catalog, learned: learned) {
            matched.insert(.contexts)
        }
        if applyPhoneRule(to: task, mode: mode) { matched.insert(.notes) }
        if applyProjectNameRule(to: task, mode: mode, projects: projects) { matched.insert(.project) }
        if applyPlaceRule(to: task, mode: mode) { matched.insert(.place) }
        return matched
    }

    /// The rule step for the lines under a task (#565, Henning 2026-10-20): a line reads its own due
    /// date and tag word from its words, like a task at capture, but the on-device model never sees
    /// it, and the other rules stay with top-level tasks (importance, urgency, recognition, phone
    /// number, project: a line belongs to its task's project already). Every open line without the
    /// rule marker, oldest first; the marker is set whether or not a rule hit, so each line gets the
    /// step once (#144). Saved per line, caught per line, like the pass for tasks. `rulesAppliedAt`
    /// alone marks a line: `processedAt` stays empty, because the model has not seen it (ADR-4).
    private func applySubtaskRules(in context: ModelContext) {
        do {
            let active = TaskStatus.active.rawValue
            let lines = try context.fetch(FetchDescriptor<TaskItem>(
                predicate: #Predicate { $0.rulesAppliedAt == nil && $0.statusRaw == active }
            )).filter { $0.parent != nil }.sorted { $0.capturedAt < $1.capturedAt }
            guard !lines.isEmpty else { return }
            let contexts = try context.fetch(FetchDescriptor<TaskContext>(sortBy: [SortDescriptor(\.sortOrder)]))
            let learned = try Self.learnedWords(from: Self.recognitionInputs(in: context).tasksByID.values, catalog: contexts)
            for line in lines {
                applySubtaskRules(to: line, mode: .firstRun, catalog: contexts, learned: learned)
                line.rulesAppliedAt = Date()
                do {
                    try context.save()
                } catch {
                    logger.error("Saving failed for subtask \(line.id, privacy: .public): \(error, privacy: .public)")
                }
            }
        } catch {
            logger.error("Subtask rule step failed: \(error, privacy: .public)")
        }
    }

    /// Due date and tag word only (#565). Returns the fields a rule matched, written or not.
    @discardableResult
    private func applySubtaskRules(
        to line: TaskItem, mode: EnrichmentWriter.Mode, catalog: [TaskContext], learned: [String: Set<String>]
    ) -> Set<RevisedField> {
        var matched = Set<RevisedField>()
        if applyDueDateRule(to: line, mode: mode) { matched.insert(.dueDate) }
        if applyContextWordRule(to: line, mode: mode, catalog: catalog, learned: learned) { matched.insert(.contexts) }
        return matched
    }

    /// The words the user's own tags taught (#233 Schnitt 2), learned once per pass from every task
    /// whose contexts the user set: never a model guess, and no rule value either, since a rule may
    /// have copied a guess (#244). The pool is the recognition's (#136): every task the rule step or
    /// the model has seen, done ones included, a removed one never. A word the user struck from a
    /// tag's list (`TaskContext.forgottenWords`, Schnitt 2b) stays out of that tag's list.
    static func learnedWords(from tasks: some Collection<TaskItem>, catalog: [TaskContext]) -> [String: Set<String>] {
        ContextWordLearning.learn(from: assignments(from: tasks), minimumCount: ContextWordLearning.minimumCount,
                                  forgotten: forgottenWords(in: catalog))
    }

    /// The tasks the learning counts: those whose contexts the user set, a removed one never (#605).
    static func assignments(from tasks: some Collection<TaskItem>) -> [ContextWordLearning.Assignment] {
        tasks.compactMap { task in
            guard task.status != .removed, task.contextsSourceRaw == FieldSource.user.rawValue,
                  let contexts = task.contexts, !contexts.isEmpty else { return nil }
            return ContextWordLearning.Assignment(rawText: task.rawText, contexts: contexts.map(\.name))
        }
    }

    /// Two tags of one name cannot exist for long (#157), but CloudKit may deliver them: their words unite.
    static func forgottenWords(in catalog: [TaskContext]) -> [String: Set<String>] {
        Dictionary(catalog.map { ($0.name, $0.forgottenWords) }, uniquingKeysWith: { $0.union($1) })
    }

    /// The learned words under each tag, spelled as the user wrote them (Schnitt 2b): what the
    /// "Recognizes: …" line of the tags page shows, the same list the rule step reads.
    static func recognizedWords(in tasks: [TaskItem], catalog: [TaskContext]) -> [String: [String]] {
        let assignments = assignments(from: tasks)
        let learned = ContextWordLearning.learn(from: assignments, minimumCount: ContextWordLearning.minimumCount,
                                                forgotten: forgottenWords(in: catalog))
        return ContextWordLearning.spelled(learned, in: assignments)
    }

    /// Contexts from words of the note: the fixed lists (#232) and the learned ones (#233) together,
    /// as measured ("fest + gelernt"). Same guards as the recognition: only while the user has not
    /// set or cleared the contexts, and in a re-analysis only to a new value. The reason names the
    /// fixed list's word where it hit, otherwise the learned one and where it came from (#101).
    private func applyContextWordRule(
        to task: TaskItem, mode: EnrichmentWriter.Mode, catalog: [TaskContext], learned: [String: Set<String>]
    ) -> Bool {
        let fixed = ContextWordRule.match(in: task.rawText, available: catalog.map(\.name))
        let fromLearning = ContextWordLearning.match(in: task.rawText, learned: learned)
            .filter { name in catalog.contains { $0.name == name } }
        let names = Set((fixed?.value ?? []) + fromLearning)
        guard !names.isEmpty else { return false }
        let reason = fixed?.reason ?? ContextWordLearning.reason(
            word: ContextWordLearning.firstWord(in: task.rawText, learned: learned, names: fromLearning) ?? ""
        )
        let hits = catalog.filter { names.contains($0.name) }
        let current = Set((task.contexts ?? []).map(\.id))
        guard EnrichmentWriter.mayWrite(
            .contexts, on: task, mode: mode,
            firstRun: current.isEmpty && !EnrichmentWriter.userHasTouched(.contexts, on: task),
            changes: Set(hits.map(\.id)) != current
        ) else { return true }
        let revision = Revision(
            task: task, field: .contexts,
            oldValue: current.isEmpty ? nil : EnrichmentWriter.encode((task.contexts ?? []).map(\.name)),
            newValue: EnrichmentWriter.encode(hits.map(\.name)), author: .rule, reason: reason
        )
        task.revisions = (task.revisions ?? []) + [revision]
        task.contexts = hits
        task.contextsSourceRaw = FieldSource.rule.rawValue
        task.contextsConfidence = ContextWordLearning.confidence
        logger.info("Rule set contexts for \(task.id, privacy: .public)")
        return true
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
            author: .rule,
            reason: match.guess.reason
        )
        task.revisions = (task.revisions ?? []) + [revision]
        task.dueDate = match.guess.value
        task.dueHasTime = match.hasTime
        task.dueSourceRaw = FieldSource.rule.rawValue
        task.dueConfidence = match.guess.confidence
        logger.info("Rule set due date for \(task.id, privacy: .public)")
        return true
    }

    /// The project whose name stands in the note (#469), only while the task has none and the user (or
    /// Siri) never set or cleared one; in a re-analysis only to a new project the user has not touched.
    private func applyProjectNameRule(to task: TaskItem, mode: EnrichmentWriter.Mode, projects: [Project]) -> Bool {
        guard let guess = ProjectNameRule.match(in: task.rawText, projects: projects.map(\.name)),
              let project = projects.first(where: { $0.name == guess.value }) else { return false }
        guard EnrichmentWriter.mayWrite(
            .project, on: task, mode: mode,
            firstRun: task.project == nil && !EnrichmentWriter.userHasTouched(.project, on: task),
            changes: project.id != task.project?.id
        ) else { return true }
        let revision = Revision(task: task, field: .project, oldValue: task.project?.name, newValue: project.name,
                                author: .rule, reason: guess.reason)
        task.revisions = (task.revisions ?? []) + [revision]
        task.project = project
        logger.info("Rule set the project of \(task.id, privacy: .public)")
        return true
    }

    /// "zu Hause" or "im Büro" sets the saved place (#680), only while the task has none and the user
    /// never set or cleared one; in a re-analysis only to a new place the user has not touched.
    private func applyPlaceRule(to task: TaskItem, mode: EnrichmentWriter.Mode) -> Bool {
        guard let guess = PlaceWordRule.match(in: task.rawText, places: savedPlaces()) else { return false }
        guard EnrichmentWriter.mayWrite(
            .place, on: task, mode: mode,
            firstRun: task.place == nil && !EnrichmentWriter.userHasTouched(.place, on: task),
            changes: guess.value != task.place
        ) else { return true }
        let revision = Revision(task: task, field: .place, oldValue: task.place.flatMap(FieldCodec.encode),
                                newValue: FieldCodec.encode(guess.value), author: .rule, reason: guess.reason)
        task.revisions = (task.revisions ?? []) + [revision]
        task.place = guess.value
        task.placeSourceRaw = FieldSource.rule.rawValue
        logger.info("Rule set the place of \(task.id, privacy: .public)")
        return true
    }

    /// A dictated phone number goes to the note (#439), only while the note is empty and the user never
    /// wrote one; in a re-analysis only to a new value the user has not touched.
    private func applyPhoneRule(to task: TaskItem, mode: EnrichmentWriter.Mode) -> Bool {
        guard let note = PhoneRule.note(from: task.rawText) else { return false }
        guard EnrichmentWriter.mayWrite(
            .notes, on: task, mode: mode,
            firstRun: (task.notes ?? "").isEmpty && !EnrichmentWriter.userHasTouched(.notes, on: task),
            changes: note != task.notes
        ) else { return true }
        let revision = Revision(task: task, field: .notes, oldValue: task.notes, newValue: note,
                                author: .rule, reason: PhoneRule.reason)
        task.revisions = (task.revisions ?? []) + [revision]
        task.notes = note
        task.notesSourceRaw = FieldSource.rule.rawValue
        logger.info("Rule moved a phone number into the note of \(task.id, privacy: .public)")
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
            author: .rule,
            reason: guess.reason
        )
        task.revisions = (task.revisions ?? []) + [revision]
        task.importance = guess.value
        task.importanceSourceRaw = FieldSource.rule.rawValue
        task.importanceConfidence = guess.confidence
        logger.info("Rule set importance for \(task.id, privacy: .public)")
        return true
    }

    /// A length the user named ("20 Minuten"), rounded up to its bucket (#441, #673). Same second
    /// condition as the recognition: only a user `Revision` marks a duration the user cleared.
    /// No catch-up over existing tasks: once the rule step ran (`rulesAppliedAt`), only a re-analysis
    /// brings the duration.
    private func applyDurationRule(to task: TaskItem, mode: EnrichmentWriter.Mode) -> Bool {
        if mode == .firstRun, task.rulesAppliedAt != nil { return false }
        guard let guess = DurationRule.match(in: task.rawText)?.guess else { return false }
        guard EnrichmentWriter.mayWrite(
            .duration, on: task, mode: mode,
            firstRun: task.duration == nil && !EnrichmentWriter.userHasTouched(.duration, on: task),
            changes: guess.value != task.duration
        ) else { return true }
        let revision = Revision(
            task: task, field: .duration, oldValue: task.durationRaw,
            newValue: guess.value.rawValue, author: .rule, reason: guess.reason
        )
        task.revisions = (task.revisions ?? []) + [revision]
        task.duration = guess.value
        task.durationSourceRaw = FieldSource.rule.rawValue
        task.durationConfidence = guess.confidence
        logger.info("Rule set duration for \(task.id, privacy: .public)")
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
            author: .rule,
            reason: guess.reason
        )
        task.revisions = (task.revisions ?? []) + [revision]
        task.urgency = guess.value
        task.urgencySourceRaw = FieldSource.rule.rawValue
        task.urgencyConfidence = guess.confidence
        logger.info("Rule set urgency for \(task.id, privacy: .public)")
        return true
    }

    /// The comparison set for the recognition, fetched once per pass and from tasks whose rule or
    /// model step already ran (#136, #144): a task of this very catch-up pass can structurally never
    /// feed another one, so an AI mistake cannot multiply — no runtime filter needed, it follows from
    /// the fetch time. No `done` filter either: a re-capture should take the values of a still open
    /// task too. The map resolves a hit back to its `TaskContext` objects.
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
        // A task removed with its subtasks (#605) is gone for the user: nothing is recognized from it.
        let merged = Dictionary((byModel + byRules).filter { $0.status != .removed }.map { ($0.id, $0) },
                                uniquingKeysWith: { first, _ in first })
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
        // Names the earlier task (#101): "Like “Rasen mähen” from 12 Sep." Falls back to the rule's
        // own sentence if the task is gone from the map.
        func reason(recognising id: UUID) -> String {
            guard let source = tasksByID[id] else { return String(localized: "From a raw text captured before, word for word.") }
            return RecognitionRule.reason(rawText: source.rawText, capturedAt: source.capturedAt)
        }
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
                newValue: hit.guess.value.rawValue, author: .rule, reason: reason(recognising: hit.sourceID)
            )
            task.revisions = (task.revisions ?? []) + [revision]
            task.duration = hit.guess.value
            task.durationSourceRaw = FieldSource.rule.rawValue
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
                newValue: EnrichmentWriter.encode(hit.guess.value), author: .rule, reason: reason(recognising: hit.sourceID)
            )
            task.revisions = (task.revisions ?? []) + [revision]
            task.contexts = source.contexts
            task.contextsSourceRaw = FieldSource.rule.rawValue
            task.contextsConfidence = hit.guess.confidence
            logger.info("Recognition set contexts for \(task.id, privacy: .public)")
        }
        return matched
    }
}
