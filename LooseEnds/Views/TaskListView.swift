import OSLog
import SwiftData
import SwiftUI

/// One view as a list (design briefing, screen 3): a system view, a context or a project.
/// Swipe right: Done (Restore in Done, Activate in Parked). Swipe left: Next up, or Park in Old.
/// Long press: the full menu.
struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CompletionPulse.self) private var completionPulse: CompletionPulse?
    @Environment(PendingCompletions.self) private var pendingCompletions: PendingCompletions?
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    let selection: ViewSelection
    /// Every task; the view applies its own rule.
    let tasks: [TaskItem]

    @State private var pendingDelete: TaskItem?
    @State private var confirmingDelete = false
    /// The task whose "Move → Date…" sheet is open (#33).
    @State private var datingTask: TaskItem?
    /// Parents whose subtasks are folded out in the project view (#28); folded by default.
    @State private var unfolded: Set<UUID> = []
    /// The disclosure arrow's width, so titles line up with and without one.
    @ScaledMetric(relativeTo: .body) private var disclosureWidth: CGFloat = 22
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
        case .task: []
        }
    }

    private var title: String {
        switch selection {
        case .system(let kind): String(localized: kind.titleKey)
        case .context: context?.name ?? ""
        case .project: project?.name ?? ""
        case .task: ""
        }
    }

    var body: some View {
        List {
            if kind == .done {
                doneSections
            } else if project != nil {
                projectRows
            } else if kind == .new {
                reviewSections
            } else {
                openRows
            }
        }
        .paperList()
        .overlay {
            if shown.isEmpty {
                emptyState
            }
        }
        .navigationTitle(title)
        .confirmationDialog("Delete this task?", isPresented: $confirmingDelete, titleVisibility: .visible, presenting: pendingDelete) { task in
            Button("Delete", role: .destructive) { delete(task) }
                .accessibilityIdentifier("confirmDeleteButton")
        } message: { _ in
            Text("This cannot be undone.")
        }
        .sheet(item: $datingTask) { task in
            MoveDateSheet(start: TaskActions.suggestedMoveDate(for: task)) { day in
                move(task, to: .date(day))
            }
        }
    }

    /// The loose thread, third place of the knot (#180, rule 1), over one sentence per view.
    private var emptyState: some View {
        VStack(spacing: 14) {
            ThreadGlyph(form: .loose, lineWidth: 2.5)
                .frame(width: 120, height: 24)
                .foregroundStyle(.tertiary)
            Text(emptySentence)
                .font(.title3)
                .fontDesign(.serif)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("emptyViewLabel")
        }
        .padding(32)
    }

    private var emptySentence: LocalizedStringKey {
        switch kind {
        case .new: "Nothing to look over."
        case .next: "Nothing lined up yet."
        case .due: "Nothing due this week."
        case .quick: "No quick ones right now."
        case .old: "Nothing has been lying around."
        case .waiting: "Not waiting on anyone."
        case .repeating: "Nothing comes back."
        case .parked: "Nothing parked."
        case .done: "Nothing finished yet."
        case .context, .project, nil: "Nothing here yet."
        }
    }

    /// Completed, one section per day, newest day first.
    private var doneSections: some View {
        let groups = ViewRules.groupedByCompletionDay(shown)
        return ForEach(groups, id: \.day) { group in
            Section {
                ForEach(group.tasks) { task in
                    row(task)
                }
            } header: {
                Text(group.day, format: .dateTime.weekday(.wide).day().month())
            }
        }
    }

    /// "New" as the review tray (#188): on top what only needs a nod ("Looks right" by swipe),
    /// below what needs opening: no title vouched for, or nothing sorted yet.
    @ViewBuilder
    private var reviewSections: some View {
        let confirm = shown.filter { !ViewRules.needsLook($0) }
        let look = shown.filter(ViewRules.needsLook)
        if !confirm.isEmpty {
            Section {
                ForEach(confirm) { row($0) }
            }
        }
        if !look.isEmpty {
            Section {
                ForEach(look) { row($0) }
            } header: {
                Text("Needs a look")
            }
        }
    }

    /// Every other view; only Next up lets the rows be dragged.
    private var openRows: some View {
        let move: ((IndexSet, Int) -> Void)? = kind == .next ? { moveNext(from: $0, to: $1) } : nil
        return ForEach(shown) { task in
            row(task)
        }
        .onMove(perform: move)
    }

    /// A project: its tasks, each with an arrow when it has subtasks; the arrow folds them out
    /// indented below (#28). Subtasks are plain lines here as in the detail: a tap checks one off.
    @ViewBuilder
    private var projectRows: some View {
        if let project {
            ForEach(ViewRules.lines(inProject: project, in: tasks, unfolded: unfolded)) { line in
                switch line {
                case .task(let task):
                    // The Done window (#32) holds here too: struck through with Undo for three seconds.
                    if pendingCompletions?.isPending(task.id) == true {
                        pendingRow(task)
                    } else {
                        projectTaskRow(task)
                    }
                case .subtask(let subtask, _): subtaskRow(subtask)
                }
            }
        }
    }

    private func projectTaskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 4) {
            disclosure(task)
            NavigationLink {
                TaskDetailView(task: task)
            } label: {
                TaskRow(task: task, note: note(for: task))
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) { leadingActions(task) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { trailingActions(task) }
        .contextMenu { menu(task) }
        .paperRow()
    }

    /// The arrow, or its empty width for a task without subtasks. A deleted task can be drawn once
    /// more while the list animates it out, and reading it then traps (#194, see `TaskRow`).
    @ViewBuilder
    private func disclosure(_ task: TaskItem) -> some View {
        if task.isDeleted || task.modelContext == nil || (task.subtasks ?? []).isEmpty {
            Color.clear.frame(width: disclosureWidth, height: 1)
        } else {
            let open = unfolded.contains(task.id)
            Button {
                withAnimation(.snappy) {
                    if open { unfolded.remove(task.id) } else { unfolded.insert(task.id) }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(open ? 90 : 0))
                    .imageScale(.small)
                    .frame(width: disclosureWidth, height: disclosureWidth)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(open ? Text("Hide subtasks") : Text("Show subtasks"))
            .accessibilityIdentifier("disclosure_\(task.id.uuidString)")
        }
    }

    @ViewBuilder
    private func subtaskRow(_ subtask: TaskItem) -> some View {
        // Same guard as `TaskRow`: a line deleted with its parent can still be drawn once (#194).
        if subtask.isDeleted || subtask.modelContext == nil {
            EmptyView()
        } else {
            subtaskLine(subtask)
        }
    }

    private func subtaskLine(_ subtask: TaskItem) -> some View {
        let done = subtask.status == .done
        return Button {
            Subtasks.toggle(subtask)
            save("toggle subtask")
        } label: {
            HStack(spacing: 10) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)
                Text(subtask.displayTitle)
                    .fontDesign(.serif)
                    .strikethrough(done)
                    .foregroundStyle(done ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.leading, disclosureWidth + 4)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(.plain)
        .accessibilityValue(done ? Text("Completed") : Text("Open"))
        .accessibilityIdentifier("projectSubtask_\(subtask.id.uuidString)")
        .paperRow()
    }

    @ViewBuilder
    private func row(_ task: TaskItem) -> some View {
        if pendingCompletions?.isPending(task.id) == true {
            pendingRow(task)
        } else {
            openRow(task)
        }
    }

    /// Done, waiting out its three seconds (#32): struck through, no link, no swipes. A second tap
    /// anywhere on the row takes it back; "Undo" says so. The long-press menu stays for Delete.
    private func pendingRow(_ task: TaskItem) -> some View {
        HStack {
            TaskRow(task: task, hidesContext: context != nil, note: note(for: task))
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

    private func openRow(_ task: TaskItem) -> some View {
        NavigationLink {
            TaskDetailView(task: task)
        } label: {
            TaskRow(task: task, hidesContext: context != nil, note: note(for: task))
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) { leadingActions(task) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { trailingActions(task) }
        .contextMenu { menu(task) }
        .paperRow()
    }

    /// Old shows the age and how often the task was pushed (design briefing, screen 11).
    private func note(for task: TaskItem) -> String? {
        if kind == .new {
            switch ViewRules.reviewReason(of: task) {
            case .titleChanged(let raw): return String(localized: "was: \(raw)")
            case .sortedByAI: return nil
            case .titleNotChecked: return String(localized: "Title not checked")
            case .notSortedYet: return String(localized: "Not sorted yet")
            }
        }
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
            if pendingCompletions?.isPending(task.id) == true {
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
    private func complete(_ task: TaskItem) {
        if let pendingCompletions {
            pendingCompletions.schedule(task.id)
            return
        }
        TaskActions.complete(task)
        save("done")
        completionPulse?.fire()
    }

    private func undoComplete(_ task: TaskItem) {
        pendingCompletions?.cancel(task.id)
    }

    private func restore(_ task: TaskItem) {
        TaskActions.restore(task)
        save("restore")
    }

    /// Marks the AI's changes as seen; the task leaves "New", its revisions stay.
    private func confirm(_ task: TaskItem) {
        _ = RevisionService.markSeen(task)
        save("confirm")
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
        pendingCompletions?.cancel(task.id)
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
