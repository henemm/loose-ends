import OSLog
import SwiftData
import SwiftUI

/// One system view as a list (design briefing, screen 3). Swipe right: Done (Restore in Done,
/// Activate in Parked). Swipe left: Next up, or Park in Old. Long press: the full menu.
struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    let kind: ViewKind
    /// Every task; the view applies its own rule.
    let tasks: [TaskItem]

    @State private var pendingDelete: TaskItem?
    @State private var confirmingDelete = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "List")

    private var shown: [TaskItem] { ViewRules.tasks(for: kind, in: tasks) }

    var body: some View {
        List(shown) { task in
            NavigationLink {
                TaskDetailView(task: task)
            } label: {
                TaskRow(task: task, hidesContext: kind == .context)
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) { leadingActions(task) }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) { trailingActions(task) }
            .contextMenu { menu(task) }
        }
        .overlay {
            if shown.isEmpty {
                Text("Nothing here")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("emptyViewLabel")
            }
        }
        .confirmationDialog("Delete this task?", isPresented: $confirmingDelete, titleVisibility: .visible, presenting: pendingDelete) { task in
            Button("Delete", role: .destructive) { delete(task) }
                .accessibilityIdentifier("confirmDeleteButton")
        } message: { _ in
            Text("This cannot be undone.")
        }
    }

    // MARK: - Swipes

    @ViewBuilder
    private func leadingActions(_ task: TaskItem) -> some View {
        switch kind {
        case .done:
            Button("Restore", systemImage: "arrow.uturn.backward") { restore(task) }
                .tint(.accentColor)
        case .parked:
            Button("Activate", systemImage: "play") { activate(task) }
                .tint(.accentColor)
        default:
            Button("Done", systemImage: "checkmark") { complete(task) }
                .tint(.green)
                .accessibilityIdentifier("swipeDone_\(task.id.uuidString)")
        }
    }

    @ViewBuilder
    private func trailingActions(_ task: TaskItem) -> some View {
        switch kind {
        case .done, .parked:
            EmptyView()
        case .old:
            Button("Park", systemImage: "pause") { park(task) }
        default:
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
    private func menu(_ task: TaskItem) -> some View {
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
            Button("Done", systemImage: "checkmark") { complete(task) }
                .accessibilityIdentifier("menuDone")
            Menu("Move", systemImage: "calendar") {
                Button("Tomorrow") { move(task, to: .tomorrow) }
                Button("Weekend") { move(task, to: .weekend) }
                Button("Next week") { move(task, to: .nextWeek) }
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

    private func complete(_ task: TaskItem) {
        TaskActions.complete(task)
        save("done")
    }

    private func restore(_ task: TaskItem) {
        TaskActions.restore(task)
        save("restore")
    }

    private func toggleNext(_ task: TaskItem) {
        TaskActions.toggleNext(task, among: tasks)
        save("next")
    }

    private func park(_ task: TaskItem) {
        TaskActions.park(task)
        save("park")
    }

    private func activate(_ task: TaskItem) {
        TaskActions.activate(task)
        save("activate")
    }

    private func move(_ task: TaskItem, to target: TaskActions.MoveTarget) {
        TaskActions.move(task, to: target, contexts: contexts, projects: projects)
        save("move")
    }

    private func delete(_ task: TaskItem) {
        modelContext.delete(task)
        pendingDelete = nil
        save("delete")
    }

    private func save(_ what: String) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving \(what, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}
