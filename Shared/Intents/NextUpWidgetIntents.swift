import AppIntents
import Foundation
import OSLog
import SwiftData

/// The check mark in the "Next up" widget (#307): completes the task without opening the app.
/// Runs in the widget extension and writes into the shared app-group store; WidgetKit reloads the
/// timeline afterwards, so the next task moves up.
struct CompleteTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Complete task"
    /// Only the widget calls it; it makes no sense as a shortcut of its own.
    static let isDiscoverable = false

    @Parameter(title: "Task")
    var taskID: String

    init() {}

    init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else { return .result() }
        // The context does not retain its container (CLAUDE.md): keep it alive for the whole call.
        let container = try ModelContainerFactory.make()
        try NextUpWidgetActions.complete(id, in: ModelContext(container))
        return .result()
    }
}

/// A tap on a title in the widget opens that task in the app (#307).
struct OpenTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Open task"
    static let isDiscoverable = false
    static let openAppWhenRun = true

    @Parameter(title: "Task")
    var taskID: String

    init() {}

    init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        OpenTaskRequest.shared.taskID = UUID(uuidString: taskID)
        return .result()
    }
}

/// Bridge from `OpenTaskIntent` to the app scene, like `CaptureRequest`.
@MainActor
@Observable
final class OpenTaskRequest {
    static let shared = OpenTaskRequest()
    var taskID: UUID?
}

enum NextUpWidgetActions {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Widget")

    /// Completes the task as the app does (`TaskActions.complete`: a repeating task rolls forward
    /// with a `CompletionRecord`) and saves. A task that is gone, already done or parked is left
    /// alone: the widget may show a stale line until its next reload, and a second tap there must
    /// not complete anything twice. Returns whether it completed.
    @discardableResult
    static func complete(_ id: UUID, in context: ModelContext, now: Date = Date(), calendar: Calendar = .current) throws -> Bool {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        guard let task = try context.fetch(descriptor).first else {
            logger.info("Widget completion: task no longer exists")
            return false
        }
        guard task.isOpen else {
            logger.info("Widget completion: task is not open any more")
            return false
        }
        TaskActions.complete(task, now: now, calendar: calendar)
        try context.save()
        return true
    }

    /// What the widget shows: the first tasks of "Next up", the same rule as in the app.
    static func nextUp(in context: ModelContext, limit: Int) throws -> [(id: UUID, title: String)] {
        let all = try context.fetch(FetchDescriptor<TaskItem>())
        return ViewRules.tasks(for: .next, in: all).prefix(limit).map { ($0.id, $0.displayTitle) }
    }
}
