import OSLog
import SwiftData
import SwiftUI

/// The usual gestures on a task (design briefing, screen 3), one set for every list and for the
/// start screen's "Next up" preview (#303): swipe right Done (Restore in Done, Activate in Parked,
/// "Looks right" in New), swipe left Next up (Park in Old; All open: Activate for a parked task), long press the full menu. The view owns the state behind the
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
    /// The task whose Complete asks about its open subtasks (#565).
    @Binding var askingSubtasks: TaskItem?
    /// The task that wants to be the Knäuel while another holds it (#643): the app asks first.
    @Binding var askingKnaeuel: TaskItem?
    /// Runs after a delete is saved, so the view can let go of a selection on that task.
    var didDelete: (UUID) -> Void = { _ in }
    /// Which fields are offered (#538): "The Knäuel" and "Counts" stand in the menu only while on, or
    /// while the task carries them (off is not offered, never hidden).
    var fields: DetailFieldSettings = .standard
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "List")

    func isPending(_ task: TaskItem) -> Bool {
        pendingCompletions?.isPending(task.id) == true
    }

    /// Done, waiting out its three seconds (#32): struck through, no link, no swipes. A second tap
    /// anywhere on the row takes it back; "Undo" says so. The long-press menu stays for Delete.
    func pendingRow(_ task: TaskItem, _ row: some View) -> some View {
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
            Button("Activate", systemImage: "sun.max") { activate(task) }
                .tint(.accentColor)
        case .new?:
            // New is the inbox: there the check reads "looked over", and a Done swipe made tasks
            // vanish unseen (Henning, 2026-10-11, #318). The swipe confirms what the AI sorted
            // (#188); Done stays in the long-press menu. A title nobody vouched for ("Needs a
            // look") gets no swipe, it has to be opened.
            // The word, as in the detail's bar, not a sign: a bare eye said nothing (Henning,
            // 2026-10-16, build 76), and a checkmark belongs to Complete alone (#349).
            if !ViewRules.needsLook(task) {
                Button("Looks right") { confirm(task) }
                    .tint(.accentColor)
                    .accessibilityIdentifier("swipeConfirm_\(task.id.uuidString)")
            }
        default:
            Button("Complete", systemImage: "checkmark.circle") { complete(task) }
                .tint(Color("Completed"))
                .accessibilityIdentifier("swipeDone_\(task.id.uuidString)")
        }
    }

    @ViewBuilder
    func trailingActions(_ task: TaskItem) -> some View {
        switch kind {
        case .done?, .parked?:
            EmptyView()
        case .old?:
            Button("Park", systemImage: "moon.zzz") { park(task) }
                .tint(Color("Quiet"))
        case .open? where task.status == .parked:
            // A parked task never shows in Next up, so the swipe wakes it instead (#319).
            Button("Activate", systemImage: "sun.max") { activate(task) }
                .tint(.accentColor)
                .accessibilityIdentifier("swipeActivate_\(task.id.uuidString)")
        default:
            nextUpAction(task)
        }
    }

    @ViewBuilder
    private func nextUpAction(_ task: TaskItem) -> some View {
        if task.nextRank == nil {
            Button("Next up", systemImage: "star") { toggleNext(task) }
                .tint(.accentColor)
        } else {
            Button("Remove from Next up", systemImage: "star.slash") { toggleNext(task) }
        }
    }

    // MARK: - Long-press menu

    @ViewBuilder
    func menu(_ task: TaskItem) -> some View {
        if task.status == .done {
            Button("Restore", systemImage: "arrow.uturn.backward") { restore(task) }
        } else if task.status == .parked {
            Button("Activate", systemImage: "sun.max") { activate(task) }
        } else {
            if task.nextRank == nil {
                Button("Next up", systemImage: "star") { toggleNext(task) }
            } else {
                Button("Remove from Next up", systemImage: "star.slash") { toggleNext(task) }
            }
            driveEntries(task)
            if isPending(task) {
                Button("Undo", systemImage: "arrow.uturn.backward") { undoComplete(task) }
            } else {
                Button("Complete", systemImage: "checkmark.circle") { complete(task) }
                    .accessibilityIdentifier("menuDone")
            }
            Menu("Move", systemImage: "calendar") {
                Button("Tomorrow") { move(task, to: .tomorrow) }
                Button("Weekend") { move(task, to: .weekend) }
                Button("Next week") { move(task, to: .nextWeek) }
                Button("Date…") { datingTask = task }
                    .accessibilityIdentifier("menuMoveDate")
            }
            Button("Park", systemImage: "moon.zzz") { park(task) }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) {
            pendingDelete = task
            confirmingDelete = true
        }
        .accessibilityIdentifier("menuDelete")
    }

    /// "The Knäuel" and "Counts" (#643, #645), after Next up: each only while its field is on or the
    /// task carries it. Over the budget "Counts (5 of 5)" stands grey. A subtask gets neither.
    @ViewBuilder
    func driveEntries(_ task: TaskItem) -> some View {
        if task.parent == nil {
            if task.isKnaeuel {
                Button { releaseKnaeuel(task) } label: {
                    Label { Text("No longer the Knäuel") } icon: { ThreadShape.menuImage(form: .knaeuel) }
                }
                .accessibilityIdentifier("menuKnaeuelRelease")
            } else if fields.isOn(.knaeuel) {
                Button { setKnaeuel(task) } label: {
                    Label { Text("The Knäuel") } icon: { ThreadShape.menuImage(form: .knaeuel) }
                }
                .accessibilityIdentifier("menuKnaeuel")
            }
            if task.countsAt != nil {
                Button("No longer counts", systemImage: "circle.slash") { toggleCounts(task) }
                    .accessibilityIdentifier("menuCountsRelease")
            } else if fields.isOn(.counts) {
                if TaskActions.canCount(task, among: tasks) {
                    Button("Counts", systemImage: "circle") { toggleCounts(task) }
                        .accessibilityIdentifier("menuCounts")
                } else {
                    Button("Counts (\(TaskActions.countsBudget) of \(TaskActions.countsBudget))", systemImage: "circle") {}
                        .disabled(true)
                        .accessibilityIdentifier("menuCountsFull")
                }
            }
        }
    }

    // MARK: - Actions

    /// Makes the task the Knäuel (#643); while another task holds the mark the app asks first.
    func setKnaeuel(_ task: TaskItem) {
        if let holder = ViewRules.knaeuel(in: tasks), holder.id != task.id {
            askingKnaeuel = task
            return
        }
        moveKnaeuel(to: task)
    }

    /// The answer, or the first Knäuel: the mark goes onto the task, off any other.
    func moveKnaeuel(to task: TaskItem) {
        askingKnaeuel = nil
        TaskActions.setKnaeuel(task, among: tasks, contexts: contexts, projects: projects)
        save("knaeuel")
    }

    func releaseKnaeuel(_ task: TaskItem) {
        TaskActions.releaseKnaeuel(task, contexts: contexts, projects: projects)
        save("knaeuel")
    }

    func toggleCounts(_ task: TaskItem) {
        TaskActions.toggleCounts(task, among: tasks, contexts: contexts, projects: projects)
        save("counts")
    }

    /// Starts the three-second window (#32); `ContentView` completes once it ran out. Without the
    /// window (previews) Done lands at once. With open subtasks it asks first (#565).
    func complete(_ task: TaskItem) {
        if !Subtasks.open(of: task).isEmpty {
            askingSubtasks = task
            return
        }
        complete(task, withSubtasks: false)
    }

    /// The answer to the question (#565): "Complete all" takes the open subtasks along.
    func complete(_ task: TaskItem, withSubtasks: Bool) {
        if let pendingCompletions {
            pendingCompletions.schedule(task.id, withSubtasks: withSubtasks)
            return
        }
        if withSubtasks {
            for subtask in Subtasks.open(of: task) { TaskActions.complete(subtask) }
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

    /// Its subtasks stay as tasks of their own (#605); the log says how many were let go.
    func delete(_ task: TaskItem) {
        let id = task.id
        pendingCompletions?.cancel(id)
        pendingDelete = nil
        do {
            let lifted = try TaskActions.delete(task, in: modelContext)
            Self.logger.info("Deleted a task, \(lifted.count, privacy: .public) subtasks lifted")
        } catch {
            Self.logger.error("Deleting a task failed: \(error, privacy: .public)")
        }
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
        .completesWithSubtasks(asking: actions.$askingSubtasks) { task, withSubtasks in
            actions.complete(task, withSubtasks: withSubtasks)
        }
        .movesKnaeuel(asking: actions.$askingKnaeuel, from: ViewRules.knaeuel(in: actions.tasks)) { task in
            actions.moveKnaeuel(to: task)
        }
        .sheet(item: actions.$datingTask) { task in
            MoveDateSheet(start: TaskActions.suggestedMoveDate(for: task)) { day in
                actions.move(task, to: .date(day))
            }
        }
    }
}

extension View {
    /// The question before the Knäuel moves (#643, Henning 2026-10-23): only one task can be it, so a
    /// second one asks, naming the one that holds the mark so far.
    func movesKnaeuel(asking: Binding<TaskItem?>, from holder: TaskItem?, move: @escaping (TaskItem) -> Void) -> some View {
        confirmationDialog(
            Text("Make “\(asking.wrappedValue?.displayTitle ?? "")” the Knäuel?"),
            isPresented: Binding(get: { asking.wrappedValue != nil }, set: { if !$0 { asking.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: asking.wrappedValue
        ) { task in
            Button("Move the Knäuel") { move(task) }
                .accessibilityIdentifier("confirmKnaeuelMove")
        } message: { _ in
            Text("“\(holder?.displayTitle ?? "")” is the Knäuel so far. Only one task can be.")
        }
    }
}
