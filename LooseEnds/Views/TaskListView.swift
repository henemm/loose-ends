import OSLog
import SwiftData
import SwiftUI

/// One view as a list (design briefing, screen 3): a system view, a context or a project.
/// Swipe right: Done (Restore in Done, Activate in Parked). Swipe left: Next up, or Park in Old.
/// Long press: the full menu.
struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    let selection: ViewSelection
    /// Every task; the view applies its own rule.
    let tasks: [TaskItem]

    @State private var pendingDelete: TaskItem?
    @State private var confirmingDelete = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "List")

    /// The system kind, nil for a context or project view.
    private var kind: ViewKind? {
        if case .system(let kind) = selection { return kind }
        return nil
    }

    private var context: TaskContext? {
        if case .context(let id) = selection { return contexts.first { $0.id == id } }
        return nil
    }

    private var project: Project? {
        if case .project(let id) = selection { return projects.first { $0.id == id } }
        return nil
    }

    private var shown: [TaskItem] {
        switch selection {
        case .system(let kind): ViewRules.tasks(for: kind, in: tasks)
        case .context: context.map { ViewRules.tasks(inContext: $0, in: tasks) } ?? []
        case .project: project.map { ViewRules.tasks(inProject: $0, in: tasks) } ?? []
        }
    }

    private var title: String {
        switch selection {
        case .system(let kind): String(localized: kind.titleKey)
        case .context: context?.name ?? ""
        case .project: project?.name ?? ""
        }
    }

    var body: some View {
        List {
            if kind == .done {
                ForEach(ViewRules.groupedByCompletionDay(shown), id: \.day) { group in
                    Section {
                        ForEach(group.tasks) { task in row(task) }
                    } header: {
                        Text(group.day, format: .dateTime.weekday(.wide).day().month())
                    }
                }
            } else {
                ForEach(shown) { task in row(task) }
                    .onMove(perform: kind == .next ? moveNext : nil)
            }
        }
        .overlay {
            if shown.isEmpty {
                Text("Nothing here")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("emptyViewLabel")
            }
        }
        .navigationTitle(title)
        .confirmationDialog("Delete this task?", isPresented: $confirmingDelete, titleVisibility: .visible, presenting: pendingDelete) { task in
            Button("Delete", role: .destructive) { delete(task) }
                .accessibilityIdentifier("confirmDeleteButton")
        } message: { _ in
            Text("This cannot be undone.")
        }
    }

    private func row(_ task: TaskItem) -> some View {
        NavigationLink {
            TaskDetailView(task: task)
        } label: {
            TaskRow(task: task, hidesContext: context != nil, note: note(for: task))
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) { leadingActions(task) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { trailingActions(task) }
        .contextMenu { menu(task) }
    }

    /// Old shows the age and how often the task was pushed (design briefing, screen 11).
    private func note(for task: TaskItem) -> String? {
        guard kind == .old else { return nil }
        var parts = [task.capturedAt.formatted(.relative(presentation: .named))]
        let postponed = ViewRules.postponeCount(task)
        if postponed > 0 {
            parts.append(String(localized: "postponed \(postponed) times"))
        }
        return parts.joined(separator: " · ")
    }

    private func moveNext(from source: IndexSet, to destination: Int) {
        TaskActions.moveNext(shown, from: source, to: destination)
        save("reorder")
    }

    // MARK: - Swipes

    @ViewBuilder
    private func leadingActions(_ task: TaskItem) -> some View {
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
    private func trailingActions(_ task: TaskItem) -> some View {
        switch kind {
        case .done?, .parked?:
            EmptyView()
        case .old?:
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
            Button("Complete", systemImage: "checkmark") { complete(task) }
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
