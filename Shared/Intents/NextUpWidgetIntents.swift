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
        let container = try ModelContainerFactory.make(syncs: false)
        let context = ModelContext(container)
        // Where the line stood, so the knot ties itself in its place before the list moves up (#521).
        let before = try NextUpWidgetActions.nextUp(in: context, limit: NextUpWidgetActions.maxLines).lines
        if try NextUpWidgetActions.complete(id, in: context), let index = before.firstIndex(where: { $0.id == id }) {
            let mark = NextUpWidgetActions.CompletionMark(line: before[index], index: index, at: .now)
            NextUpWidgetActions.store(mark, in: UserDefaults(suiteName: ModelContainerFactory.appGroup))
        }
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

    /// The most lines a family shows (the large one).
    static let maxLines = 6

    /// "Neue Aufgabe" in the large widget (#521): a link, not an intent, so it always opens in the app
    /// process; an intent compiled into the widget too may run there (#326).
    static let captureURL = URL(string: "looseends://capture")!

    static func isCaptureLink(_ url: URL) -> Bool {
        url.scheme == captureURL.scheme && url.host() == captureURL.host()
    }

    /// One line of the widget: the margin as in the list rows (#424), red only for time pressure.
    struct Line: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        let title: String
        let margin: String
        let pressing: Bool
        /// The Knäuel (#643): its sign stands in the margin, as in the app's head.
        var isKnaeuel = false
        /// Just completed from the widget: the knot stands in place of the check (#521).
        var done = false
    }

    /// What the widget shows: the same as the start screen's "Now" (#368): the Knäuel first (#643), then
    /// "Due today" and "Next up" as one list, and how many that makes in all (the number in the head).
    static func nextUp(in context: ModelContext, limit: Int, now: Date = Date(), calendar: Calendar = .current) throws -> (lines: [Line], total: Int) {
        let all = try context.fetch(FetchDescriptor<TaskItem>())
        let knaeuel = ViewRules.knaeuel(in: all)
        let shown = (knaeuel.map { [$0] } ?? []) + ViewRules.now(in: all, now: now, calendar: calendar).all
        let lines = shown.prefix(limit).map { task in
            let mark = ViewRules.marginMark(of: task, now: now, calendar: calendar)
            return Line(id: task.id, title: task.displayTitle, margin: mark.text, pressing: mark.pressing,
                        isKnaeuel: task.id == knaeuel?.id)
        }
        return (Array(lines), shown.count)
    }

    /// The line a tap on the check just completed, kept in the app group for the widget's next reload.
    struct CompletionMark: Codable, Equatable, Sendable {
        let line: Line
        let index: Int
        let at: Date
    }

    private static let markKey = "nextUp.justCompleted"

    static func store(_ mark: CompletionMark, in defaults: UserDefaults?) {
        guard let defaults else {
            logger.error("Widget completion: app group defaults unavailable")
            return
        }
        do {
            defaults.set(try JSONEncoder().encode(mark), forKey: markKey)
        } catch {
            logger.error("Widget completion: storing the mark failed: \(error, privacy: .public)")
        }
    }

    static func loadMark(from defaults: UserDefaults?) -> CompletionMark? {
        guard let data = defaults?.data(forKey: markKey) else { return nil }
        do {
            return try JSONDecoder().decode(CompletionMark.self, from: data)
        } catch {
            logger.error("Widget completion: reading the mark failed: \(error, privacy: .public)")
            return nil
        }
    }

    /// How long the knot stands before the list moves up: drawn in 0.55 s, then held, as the app's
    /// completion knot (#521).
    static let knotDuration: TimeInterval = 1.65
    /// A mark older than this belongs to a reload long past; it shows nothing.
    static let markFreshness: TimeInterval = 5

    /// The entries after a reload: with a fresh mark first the completed line with its knot in its old
    /// place, then, once the knot stood, the list without it. A repeating task that rolled forward and
    /// stays in "Next up" is replaced by its done line in the first entry, not shown twice.
    static func plan(lines: [Line], total: Int, mark: CompletionMark?, limit: Int, now: Date) -> [(date: Date, lines: [Line], total: Int)] {
        let settled = (date: now, lines: Array(lines.prefix(limit)), total: total)
        guard let mark, now.timeIntervalSince(mark.at) >= 0, now.timeIntervalSince(mark.at) < markFreshness else {
            return [settled]
        }
        var done = mark.line
        done.done = true
        var showing = lines.filter { $0.id != mark.line.id }
        showing.insert(done, at: min(mark.index, showing.count))
        let tying = (date: now, lines: Array(showing.prefix(limit)), total: total)
        let after = mark.at.addingTimeInterval(knotDuration)
        return [tying, (date: max(after, now), lines: settled.lines, total: total)]
    }
}
