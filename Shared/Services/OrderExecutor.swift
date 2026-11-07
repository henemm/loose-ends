import Foundation
import os
import SwiftData

/// An order from Claude (#613, Weg B), version 1 of `docs/reference/claude-abschrift-vertrag.md`. It carries the
/// expected state of the fields it changes, because a task has no `modifiedAt`: Claude works on a transcript
/// that may be old, and an order that no longer fits is refused instead of overwriting.
struct Order: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case capture, complete, setDue, setNext, park, addSubtask }

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
        case .capture: return try capture(order, in: context)
        case .complete: return try complete(order, in: context, now: now, calendar: calendar)
        case .setDue: return try setDue(order, in: context, now: now, calendar: calendar)
        case .setNext: return try setNext(order, in: context)
        case .park: return try park(order, in: context, now: now)
        case .addSubtask: return try addSubtask(order, in: context, now: now)
        }
    }

    private static func capture(_ order: Order, in context: ModelContext) throws -> OrderResult {
        guard let text = order.text else { return refuse(order, .invalid) }
        do {
            let task = try CaptureService.save(text, via: .claude, in: context)
            return OrderResult(orderID: order.id, outcome: .done, taskID: task.id)
        } catch CaptureError.emptyText {
            return refuse(order, .invalid)
        }
    }

    private static func complete(_ order: Order, in context: ModelContext, now: Date, calendar: Calendar) throws -> OrderResult {
        guard let id = order.taskID, let expected = order.expectedStatus, completable.contains(expected) else {
            return refuse(order, .invalid)
        }
        guard let task = try find(id, in: context) else { return refuse(order, .missing) }
        guard task.status == expected, same(order.expectedDueDate, task.dueDate) else {
            return refuse(order, .stale, task: id)
        }
        TaskActions.complete(task, now: now, calendar: calendar)
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
    /// Status and rank are no revised fields, so there is no revision, as with `complete`.
    private static func setNext(_ order: Order, in context: ModelContext) throws -> OrderResult {
        guard let id = order.taskID, let expected = order.expectedStatus, let on = order.on, Self.listable.contains(expected) else {
            return refuse(order, .invalid)
        }
        guard let task = try find(id, in: context) else { return refuse(order, .missing) }
        guard task.status == expected, task.nextRank == order.expectedNextRank else { return refuse(order, .stale, task: id) }
        guard (task.nextRank != nil) != on else { return refuse(order, .invalid, task: id) }
        let all = try context.fetch(FetchDescriptor<TaskItem>())
        TaskActions.toggleNext(task, among: all)
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
        TaskActions.park(task, now: now)
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
            try Subtasks.add(text, to: task, in: context, now: now)
        } catch {
            return refuse(order, .invalid, task: id)
        }
        try commit(context)
        return OrderResult(orderID: order.id, outcome: .done, taskID: id)
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
