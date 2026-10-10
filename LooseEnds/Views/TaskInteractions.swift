import OSLog
import SwiftData
import SwiftUI

/// The usual gestures on a task (design briefing, screen 3), one set for every list and for the
/// start screen's "Next up" preview (#303): swipe right Done (Restore in Done, Activate in Parked),
/// swipe left Next up (Park in Old), long press the full menu. The view owns the state behind the
/// delete confirmation and the date sheet and attaches both with `taskInteractionDialogs`.
@MainActor
struct TaskInteractions {
    /// The view the rows stand in; nil for a context or project.
    let kind: ViewKind?
    /// Every task: Next up ranks against all of them.
    let tasks: [TaskItem]
    let contexts: [TaskContext]
    let projects: [Project]
    let modelContext: ModelContext
    let pendingCompletions: PendingCompletions?
    let completionPulse: CompletionPulse?
    @Binding var pendingDelete: TaskItem?
    @Binding var confirmingDelete: Bool
    /// The task whose "Move → Date…" sheet is open (#33).
    @Binding var datingTask: TaskItem?
    /// Runs after a delete is saved, so the view can let go of a selection on that task.
    var didDelete: (UUID) -> Void = { _ in }
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "List")

    func isPending(_ task: TaskItem) -> Bool {
        pendingCompletions?.isPending(task.id) == true
    }

    /// Done, waiting out its three seconds (#32): struck through, no link, no swipes. A second tap
    /// anywhere on the row takes it back; "Undo" says so. The long-press menu stays for Delete.
    func pendingRow(_ task: TaskItem, _ row: TaskRow) -> some View {
        HStack {
            row
                .strikethrough()
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Undo") { undoComplete(task) }
                .buttonStyle(.borderless)
                .font(.callout)
                .accessibilityIdentifier("undoComplete_\(task.id.uuidString)")
        }
        .contentShape(Rectangle())
        .onTapGesture { undoComplete(task) }
        .contextMenu { menu(task) }
        .paperRow()
    }

    // MARK: - Swipes

    @ViewBuilder
    func leadingActions(_ task: TaskItem) -> some View {
        switch kind {
        case .done?:
            Button("Restore", systemImage: "arrow.uturn.backward") { restore(task) }
                .tint(.accentColor)
        case .parked?:
            Button("Activate", systemImage: "play") { activate(task) }
                .tint(.accentColor)
        default:
            Button("Complete", systemImage: "checkmark") { complete(task) }
                .tint(.green)
                .accessibilityIdentifier("swipeDone_\(task.id.uuidString)")
        }
    }

    @ViewBuilder
    func trailingActions(_ task: TaskItem) -> some View {
        switch kind {
        case .done?, .parked?:
            EmptyView()
        case .old?:
            Button("Park", systemImage: "pause") { park(task) }
        default:
            // In "New" the full swipe confirms what the AI sorted (#188); Next up moves second.
            if kind == .new, !ViewRules.needsLook(task) {
                Button("Looks right", systemImage: "checkmark.circle") { confirm(task) }
                    .tint(.accentColor)
                    .accessibilityIdentifier("swipeConfirm_\(task.id.uuidString)")
            }
            if task.nextRank == nil {
                Button("Next up", systemImage: "star") { toggleNext(task) }
                    .tint(.accentColor)
            } else {
                Button("Remove from Next up", systemImage: "star.slash") { toggleNext(task) }
            }
        }
    }

    // MARK: - Long-press menu

    @ViewBuilder
    func menu(_ task: TaskItem) -> some View {
        if task.status == .done {
            Button("Restore", systemImage: "arrow.uturn.backward") { restore(task) }
        } else if task.status == .parked {
            Button("Activate", systemImage: "play") { activate(task) }
        } else {
            if task.nextRank == nil {
                Button("Next up", systemImage: "star") { toggleNext(task) }
            } else {
                Button("Remove from Next up", systemImage: "star.slash") { toggleNext(task) }
            }
            if isPending(task) {
                Button("Undo", systemImage: "arrow.uturn.backward") { undoComplete(task) }
            } else {
                Button("Complete", systemImage: "checkmark") { complete(task) }
                    .accessibilityIdentifier("menuDone")
            }
            Menu("Move", systemImage: "calendar") {
                Button("Tomorrow") { move(task, to: .tomorrow) }
                Button("Weekend") { move(task, to: .weekend) }
                Button("Next week") { move(task, to: .nextWeek) }
                Button("Date…") { datingTask = task }
                    .accessibilityIdentifier("menuMoveDate")
            }
            Button("Park", systemImage: "pause") { park(task) }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            pendingDelete = task
            confirmingDelete = true
        }
        .accessibilityIdentifier("menuDelete")
    }

    // MARK: - Actions

    /// Starts the three-second window (#32); `ContentView` completes once it ran out. Without the
    /// window (previews) Done lands at once.
    func complete(_ task: TaskItem) {
        if let pendingCompletions {
            pendingCompletions.schedule(task.id)
            return
        }
        TaskActions.complete(task)
        save("done")
        completionPulse?.fire()
    }

    func undoComplete(_ task: TaskItem) {
        pendingCompletions?.cancel(task.id)
    }

    func restore(_ task: TaskItem) {
        TaskActions.restore(task)
        save("restore")
    }

    /// Marks the AI's changes as seen; the task leaves "New", its revisions stay.
    func confirm(_ task: TaskItem) {
        _ = RevisionService.markSeen(task)
        save("confirm")
    }

    func toggleNext(_ task: TaskItem) {
        TaskActions.toggleNext(task, among: tasks)
        save("next")
    }

    func park(_ task: TaskItem) {
        TaskActions.park(task)
        save("park")
    }

    func activate(_ task: TaskItem) {
        TaskActions.activate(task)
        save("activate")
    }

    func move(_ task: TaskItem, to target: TaskActions.MoveTarget) {
        TaskActions.move(task, to: target, contexts: contexts, projects: projects)
        save("move")
    }

    func delete(_ task: TaskItem) {
        let id = task.id
        pendingCompletions?.cancel(id)
        modelContext.delete(task)
        pendingDelete = nil
        save("delete")
        didDelete(id)
    }

    func save(_ what: String) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving \(what, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}

extension View {
    /// The delete confirmation and the "Move → Date…" sheet behind `TaskInteractions`.
    func taskInteractionDialogs(_ actions: TaskInteractions) -> some View {
        confirmationDialog("Delete this task?", isPresented: actions.$confirmingDelete, titleVisibility: .visible, presenting: actions.pendingDelete) { task in
            Button("Delete", role: .destructive) { actions.delete(task) }
                .accessibilityIdentifier("confirmDeleteButton")
        } message: { _ in
            Text("This cannot be undone.")
        }
        .sheet(item: actions.$datingTask) { task in
            MoveDateSheet(start: TaskActions.suggestedMoveDate(for: task)) { day in
                actions.move(task, to: .date(day))
            }
        }
    }
}
