import Foundation
import os
import SwiftData

/// An order from Claude (#613, Weg B), version 1 of `docs/reference/claude-abschrift-vertrag.md`. It carries the
/// expected state of the fields it changes, because a task has no `modifiedAt`: Claude works on a transcript
/// that may be old, and an order that no longer fits is refused instead of overwriting.
struct Order: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case capture, complete, setDue }

    var version: Int = 1
    var id: UUID
    var kind: Kind
    /// `capture`: the words, saved like any capture.
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
        let revision = RevisionService.set(
            .dueDate, to: stored?.ISO8601Format(), on: task, contexts: [], projects: [], now: now
        )
        revision?.reason = reason
        task.dueHasTime = stored != nil && hasTime
        try commit(context)
        return OrderResult(orderID: order.id, outcome: .done, taskID: id)
    }

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
