import Foundation
import os
import SwiftData

/// An order from Claude (#613, Weg B), version 1 of `docs/reference/claude-abschrift-vertrag.md`. It carries the
/// expected state of the fields it changes, because a task has no `modifiedAt`: Claude works on a transcript
/// that may be old, and an order that no longer fits is refused instead of overwriting.
struct Order: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case capture, complete, setDue, setNext, park, addSubtask, update }

    var version: Int = 1
    var id: UUID
    var kind: Kind
    /// `capture`: the words, saved like any capture. `addSubtask`: the line to add.
    var text: String?
    /// `complete` and `setDue`: the task and the state the transcript showed.
    var taskID: UUID?
    var expectedStatus: TaskStatus?
    /// `setDue`: the new date (nil removes it) and whether it carries a time.
    var date: Date?
    var hasTime: Bool?
    /// Both kinds always compare it, nil = no date expected: the transcript carries the due date but not
    /// whether a task repeats, so a repeating task that already rolled forward is never completed twice.
    var expectedDueDate: Date?
    /// `setNext` (#622): into "Next up" (true) or out of it (false), and the rank the transcript showed (nil = none).
    var on: Bool?
    var expectedNextRank: Double?
    /// `capture` and `update` (#932): the values Claude sets, each as a user revision with the reason "Claude".
    var fields: OrderFields?
    /// `update`: the transcript's title, tags and project of every field it changes (nil = none).
    var expectedTitle: String?
    var expectedContexts: [String]?
    var expectedProject: String?
}

/// What Claude sets on a task (#932); a missing key leaves the field as it is. Importance, urgency and duration arrive as
/// text and are checked by the executor, so a wrong value is `invalid` for the task, not an unreadable order.
struct OrderFields: Codable, Equatable, Sendable {
    var title: String?
    /// `capture` only.
    var notes: String?
    /// Both or neither; a date without a time is stored as the start of its day.
    var dueDate: Date?
    var dueHasTime: Bool?
    var importance: String?
    var urgency: String?
    var duration: String?
    /// −3 … 3, like `Energy`.
    var energy: Int?
    /// Names of existing tags; an empty list clears them.
    var contexts: [String]?
    var project: String?

    var isEmpty: Bool { self == OrderFields() }
}

struct OrderResult: Codable, Equatable, Sendable {
    enum Outcome: String, Codable, Sendable { case done, rejected }
    enum Reason: String, Codable, Sendable { case invalid, stale, missing }

    var orderID: UUID
    var outcome: Outcome
    var reason: Reason?
    var taskID: UUID?
}

/// Runs an order as a user change with the reason "Claude", like `SiriCapture` (#225). Every check runs before
/// the first write, so a refused order leaves the store as it was.
enum OrderExecutor {
    static let reason = "Claude"
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Orders")

    static func execute(_ order: Order, in context: ModelContext, now: Date, calendar: Calendar) throws -> OrderResult {
        guard order.version == TranscriptCodec.version else { return refuse(order, .invalid) }
        switch order.kind {
        case .capture: return try capture(order, in: context, now: now, calendar: calendar)
        case .complete: return try complete(order, in: context, now: now, calendar: calendar)
        case .setDue: return try setDue(order, in: context, now: now, calendar: calendar)
        case .setNext: return try setNext(order, in: context, now: now)
        case .park: return try park(order, in: context, now: now)
        case .addSubtask: return try addSubtask(order, in: context, now: now)
        case .update: return try update(order, in: context, now: now, calendar: calendar)
        }
    }

    /// Saves the words like any capture; `fields` (#932) are checked first and written onto the new task afterwards.
    /// The raw text stays as it came (ADR-3); Claude's title replaces the rule title as a user revision.
    private static func capture(_ order: Order, in context: ModelContext, now: Date, calendar: Calendar) throws -> OrderResult {
        guard let text = order.text, order.fields.map(isWellFormed) ?? true else { return refuse(order, .invalid) }
        guard let names = try resolve(order.fields, in: context) else { return refuse(order, .invalid) }
        let task: TaskItem
        do {
            task = try CaptureService.save(text, via: .claude, in: context)
        } catch CaptureError.emptyText {
            return refuse(order, .invalid)
        }
        if let fields = order.fields, !fields.isEmpty {
            write(fields, names: names, on: task, now: now, calendar: calendar, markTitle: true)
            try commit(context)
        }
        return OrderResult(orderID: order.id, outcome: .done, taskID: task.id)
    }

    /// Sets Claude's fields on an open or parked task (#932): form, task, names, expected state, then one write.
    /// Importance, urgency, duration and energy are not in the transcript: for them only the status is the expected state.
    private static func update(_ order: Order, in context: ModelContext, now: Date, calendar: Calendar) throws -> OrderResult {
        guard let id = order.taskID else { return refuse(order, .invalid) }
        guard let fields = order.fields, !fields.isEmpty, fields.notes == nil, isWellFormed(fields),
              let expected = order.expectedStatus, completable.contains(expected) else {
            return refuse(order, .invalid, task: id)
        }
        guard let task = try find(id, in: context) else { return refuse(order, .missing) }
        guard let names = try resolve(fields, in: context) else { return refuse(order, .invalid, task: id) }
        guard task.status == expected, matchesTranscript(order, fields, task) else { return refuse(order, .stale, task: id) }
        // The same instant with another `dueHasTime` could only change `dueHasTime`, which is no revision field (#777).
        if let stored = storedDue(fields, calendar: calendar), let hasTime = fields.dueHasTime,
           same(stored, task.dueDate), task.dueHasTime != hasTime {
            return refuse(order, .invalid, task: id)
        }
        write(fields, names: names, on: task, now: now, calendar: calendar, markTitle: false)
        try commit(context)
        return OrderResult(orderID: order.id, outcome: .done, taskID: id)
    }

    /// The pure form of `fields`: a title with words, known values, energy −3 … 3, a date only with its time flag.
    private static func isWellFormed(_ fields: OrderFields) -> Bool {
        if let title = fields.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if let value = fields.importance, Importance(rawValue: value) == nil { return false }
        if let value = fields.urgency, Urgency(rawValue: value) == nil { return false }
        if let value = fields.duration, DurationBucket(rawValue: value) == nil { return false }
        if let value = fields.energy, Energy(rawValue: value) == nil { return false }
        return (fields.dueDate == nil) == (fields.dueHasTime == nil)
    }

    /// Tags and project from the app's catalogs, in the catalog's spelling.
    private struct Names {
        var contexts: [TaskContext]?
        var project: Project?
    }

    /// Matched by `CatalogService.nameKey` (#157), the survivor among duplicates. Nil when a name is unknown:
    /// nothing is ever created.
    private static func resolve(_ fields: OrderFields?, in context: ModelContext) throws -> Names? {
        var names = Names()
        if let wanted = fields?.contexts {
            let all = try context.fetch(FetchDescriptor<TaskContext>())
            var found: [TaskContext] = []
            for name in wanted {
                let key = CatalogService.nameKey(name)
                guard !key.isEmpty,
                      let hit = all.filter({ CatalogService.nameKey($0.name) == key }).min(by: CatalogService.survivesBefore)
                else { return nil }
                if !found.contains(where: { $0.persistentModelID == hit.persistentModelID }) { found.append(hit) }
            }
            names.contexts = found
        }
        if let name = fields?.project {
            guard let project = try CatalogService.project(named: name, in: context) else { return nil }
            names.project = project
        }
        return names
    }

    /// Every changed field the transcript carries still shows its value there; a missing value means "had none".
    private static func matchesTranscript(_ order: Order, _ fields: OrderFields, _ task: TaskItem) -> Bool {
        let keys = { (names: [String]) in Set(names.map(CatalogService.nameKey)) }
        if fields.title != nil, order.expectedTitle != task.title { return false }
        if fields.dueDate != nil, !same(order.expectedDueDate, task.dueDate) { return false }
        if fields.contexts != nil, keys(order.expectedContexts ?? []) != keys((task.contexts ?? []).map(\.name)) {
            return false
        }
        if fields.project != nil, keys(order.expectedProject.map { [$0] } ?? []) != keys(task.project.map { [$0.name] } ?? []) {
            return false
        }
        return true
    }

    private static func storedDue(_ fields: OrderFields, calendar: Calendar) -> Date? {
        guard let date = fields.dueDate, let hasTime = fields.dueHasTime else { return nil }
        return hasTime ? date : calendar.startOfDay(for: date)
    }

    /// The one write path of `capture` and `update`: each present field as a user revision with the reason "Claude";
    /// a value that already stands writes none. `markTitle` (capture) makes Claude's title the user's even where the
    /// rule title reads the same, so the model leaves it.
    private static func write(_ fields: OrderFields, names: Names, on task: TaskItem, now: Date, calendar: Calendar,
                              markTitle: Bool) {
        func set(_ field: RevisedField, _ value: String?, contexts: [TaskContext] = [], projects: [Project] = [],
                 force: Bool = false) {
            RevisionService.set(field, to: value, on: task, contexts: contexts, projects: projects, now: now, force: force)?
                .reason = reason
        }
        if let title = fields.title?.trimmingCharacters(in: .whitespacesAndNewlines) {
            set(.title, title, force: markTitle && task.titleSourceRaw != FieldSource.user.rawValue)
        }
        if let notes = fields.notes { set(.notes, notes) }
        if let stored = storedDue(fields, calendar: calendar), let hasTime = fields.dueHasTime {
            set(.dueDate, stored.ISO8601Format())
            task.dueHasTime = hasTime
        }
        if let value = fields.importance { set(.importance, value) }
        if let value = fields.urgency { set(.urgency, value) }
        if let value = fields.duration { set(.duration, value) }
        if let value = fields.energy { set(.energy, String(value)) }
        if let contexts = names.contexts,
           Set(contexts.map(\.persistentModelID)) != Set((task.contexts ?? []).map(\.persistentModelID)) {
            set(.contexts, FieldCodec.encode(contexts.map(\.name)), contexts: contexts)
        }
        if let project = names.project { set(.project, project.name, projects: [project]) }
    }

    private static func complete(_ order: Order, in context: ModelContext, now: Date, calendar: Calendar) throws -> OrderResult {
        guard let id = order.taskID, let expected = order.expectedStatus, completable.contains(expected) else {
            return refuse(order, .invalid)
        }
        guard let task = try find(id, in: context) else { return refuse(order, .missing) }
        guard task.status == expected, same(order.expectedDueDate, task.dueDate) else {
            return refuse(order, .stale, task: id)
        }
        // A round of a repeating task reads "→ done" too; its date moves without a revision (no postponement, #622).
        recording(.status, on: task, now: now) {
            TaskActions.complete(task, now: now, calendar: calendar)
            return TaskStatus.done.rawValue
        }
        try commit(context)
        return OrderResult(orderID: order.id, outcome: .done, taskID: id)
    }

    private static func setDue(_ order: Order, in context: ModelContext, now: Date, calendar: Calendar) throws -> OrderResult {
        guard let id = order.taskID, let hasTime = order.hasTime else { return refuse(order, .invalid) }
        guard let task = try find(id, in: context) else { return refuse(order, .missing) }
        guard completable.contains(task.status) else { return refuse(order, .stale, task: id) }
        guard same(order.expectedDueDate, task.dueDate) else { return refuse(order, .stale, task: id) }
        // As `TaskActions.setDue` does it, but the revision is kept to carry the reason.
        let stored = order.date.map { hasTime ? $0 : calendar.startOfDay(for: $0) }
        // The same instant with another `hasTime` could only change `dueHasTime`, which is no revision field.
        if let stored, same(stored, task.dueDate), task.dueHasTime != hasTime { return refuse(order, .invalid, task: id) }
        let revision = RevisionService.set(
            .dueDate, to: stored?.ISO8601Format(), on: task, contexts: [], projects: [], now: now
        )
        revision?.reason = reason
        task.dueHasTime = stored != nil && hasTime
        try commit(context)
        return OrderResult(orderID: order.id, outcome: .done, taskID: id)
    }

    /// Into "Next up" at the end or out of it (#622), like the swipe. Status and rank are the expected state; a task that
    /// is not open (parked included, "Next up" lists open tasks only) or already in the asked state is `invalid`.
    /// It leaves one `nextRank` revision with the reason "Claude" (#622 Schnitt 1).
    private static func setNext(_ order: Order, in context: ModelContext, now: Date) throws -> OrderResult {
        guard let id = order.taskID, let expected = order.expectedStatus, let on = order.on, Self.listable.contains(expected) else {
            return refuse(order, .invalid)
        }
        guard let task = try find(id, in: context) else { return refuse(order, .missing) }
        guard task.status == expected, task.nextRank == order.expectedNextRank else { return refuse(order, .stale, task: id) }
        guard (task.nextRank != nil) != on else { return refuse(order, .invalid, task: id) }
        let all = try context.fetch(FetchDescriptor<TaskItem>())
        recording(.nextRank, on: task, now: now) {
            TaskActions.toggleNext(task, among: all)
            return FieldCodec.encode(.nextRank, of: task)
        }
        try commit(context)
        return OrderResult(orderID: order.id, outcome: .done, taskID: id)
    }

    /// Parks an open task (#622) like the swipe: out of "Next up", the Knäuel mark falls. Parking a parked task is `invalid`.
    private static func park(_ order: Order, in context: ModelContext, now: Date) throws -> OrderResult {
        guard let id = order.taskID, let expected = order.expectedStatus, Self.listable.contains(expected) else {
            return refuse(order, .invalid)
        }
        guard let task = try find(id, in: context) else { return refuse(order, .missing) }
        guard task.status == expected else { return refuse(order, .stale, task: id) }
        recording(.status, on: task, now: now) {
            TaskActions.park(task, now: now)
            return FieldCodec.encode(.status, of: task)
        }
        try commit(context)
        return OrderResult(orderID: order.id, outcome: .done, taskID: id)
    }

    /// Adds a line under a top-level task (#622) as typed, like the detail does. An empty line, a subtask as parent or a
    /// parent that is parked are `invalid` (a parked task takes no new work, Claude restores it in the app first).
    private static func addSubtask(_ order: Order, in context: ModelContext, now: Date) throws -> OrderResult {
        guard let id = order.taskID, let expected = order.expectedStatus, let text = order.text, Self.listable.contains(expected) else {
            return refuse(order, .invalid)
        }
        guard let task = try find(id, in: context) else { return refuse(order, .missing) }
        guard task.status == expected else { return refuse(order, .stale, task: id) }
        do {
            try recording(.subtasks, on: task, now: now) {
                try Subtasks.add(text, to: task, in: context, now: now, via: .claude).rawText
            }
        } catch {
            return refuse(order, .invalid, task: id)
        }
        try commit(context)
        return OrderResult(orderID: order.id, outcome: .done, taskID: id)
    }

    /// Runs the action and leaves one user revision of `field` with the reason "Claude" (#622): old value before,
    /// `action`'s result as the new one. Side revisions the action wrote without a reason (the Knäuel mark falls)
    /// get the same reason; a reason that was there stays. A throwing action writes no revision.
    private static func recording(_ field: RevisedField, on task: TaskItem, now: Date,
                                  _ action: () throws -> String?) rethrows {
        let earlier = Set((task.revisions ?? []).map(\.persistentModelID))
        let old = FieldCodec.encode(field, of: task)
        let new = try action()
        for side in task.revisions ?? [] where side.reason == nil && !earlier.contains(side.persistentModelID) {
            side.reason = reason
        }
        let revision = Revision(task: task, field: field, oldValue: old, newValue: new, author: .user, reason: reason)
        revision.createdAt = now
        revision.seenAt = now
        task.revisions = (task.revisions ?? []) + [revision]
    }

    /// The statuses a task can be listed in as open: not parked, done or removed.
    private static let listable: Set<TaskStatus> = [.unprocessed, .unverified, .active]

    /// A task the transcript lists can be completed; a done or removed one cannot.
    private static let completable: Set<TaskStatus> = [.unprocessed, .unverified, .active, .parked]

    /// A failed save takes the order's changes back, so the context holds nothing half written.
    private static func commit(_ context: ModelContext) throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            logger.error("Order could not be saved, rolled back: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    private static func find(_ id: UUID, in context: ModelContext) throws -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Dates compared in whole seconds, the precision the transcript carries.
    private static func same(_ expected: Date?, _ stored: Date?) -> Bool {
        expected?.ISO8601Format() == stored?.ISO8601Format()
    }

    private static func refuse(_ order: Order, _ reason: OrderResult.Reason, task: UUID? = nil) -> OrderResult {
        logger.info("Order \(order.id.uuidString, privacy: .public) refused: \(reason.rawValue, privacy: .public)")
        return OrderResult(orderID: order.id, outcome: .rejected, reason: reason, taskID: task)
    }
}
