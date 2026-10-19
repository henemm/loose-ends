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
    @State private var datingTask: TaskItem?
    /// A task left from an earlier day whose new date is being chosen (#518).
    @State private var redating: TaskItem?
    /// Parents whose subtasks are folded out in the project view (#28); folded by default.
    @State private var unfolded: Set<UUID> = []
    /// The disclosure arrow's width, so titles line up with and without one.
    @ScaledMetric(relativeTo: .body) private var disclosureWidth: CGFloat = 22
    @Environment(\.dynamicTypeSize) private var typeSize
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    /// The Mac always, iOS whenever the window is not compact (#477, as #471/#476).
    private var isWide: Bool {
        #if os(iOS)
        sizeClass != .compact
        #else
        true
        #endif
    }

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
        case .task, .catalog: []
        }
    }

    /// Swipes, long-press menu and their actions, shared with the start screen (#303).
    private var actions: TaskInteractions {
        TaskInteractions(
            kind: kind, tasks: tasks, contexts: contexts, projects: projects, modelContext: modelContext,
            pendingCompletions: pendingCompletions, completionPulse: completionPulse,
            pendingDelete: $pendingDelete, confirmingDelete: $confirmingDelete, datingTask: $datingTask
        )
    }

    private var title: String {
        switch selection {
        case .system(let kind): String(localized: kind.titleKey)
        case .context: context?.name ?? ""
        case .project: project?.name ?? ""
        case .task, .catalog: ""
        }
    }

    var body: some View {
        hull(List {
            if kind == .done {
                doneSections
            } else if project != nil {
                projectRows
            } else if kind == .new {
                reviewSections
            } else if kind == .due || kind == .open {
                newDateSections
            } else {
                openRows
            }
        })
        .overlay {
            if shown.isEmpty {
                emptyState
            }
        }
        .navigationTitle(title)
        .modifier(ListSubtitle(wide: isWide, text: subtitle))
        .taskInteractionDialogs(actions)
        .sheet(item: $redating) { task in
            NewDateSheet(task: task) { redating = nil }
        }
    }

    /// Compact: the paper list as before. Wide (#477): plain on paper in the start page's 720 pt
    /// column, the paper running edge to edge below it.
    @ViewBuilder
    private func hull(_ list: some View) -> some View {
        if isWide {
            list
                .listStyle(.plain)
                .paperGround()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .background(Paper.ground.ignoresSafeArea())
        } else {
            list.paperList()
        }
    }

    /// "2 open · 20 min"; never in Done, where "open" would be wrong.
    private var subtitle: String? {
        kind == .done ? nil : ListSummary.of(shown).text()
    }

    /// A section head: as before on compact, the start screen's grey capitals on wide.
    @ViewBuilder
    private func head(_ text: Text) -> some View {
        if isWide {
            text.captionHead().startRow(StartMetrics(typeSize))
        } else {
            text
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
        case .due: "Nothing due today."
        case .quick: "No quick ones right now."
        case .old: "Nothing has been lying around."
        case .waiting: "Not waiting on anyone."
        case .repeating: "Nothing comes back."
        case .parked: "Nothing parked."
        case .open: "Nothing left open."
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
                head(Text(group.day, format: .dateTime.weekday(.wide).day().month()))
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
                head(Text("Needs a look"))
            }
        }
    }

    /// "Due" and "Loose ends" (#518, #548): whose deadline passed stands on top until it has a new date,
    /// subtasks among them with their parent named; the margin's button and the swipe open the date
    /// choice. The rest follows in the view's order. In "Loose ends" the parked tasks close the list as
    /// their own block under a grey head (#545): visible, but apart, and no colour of its own (grey is
    /// hierarchy).
    @ViewBuilder
    private var newDateSections: some View {
        let needsDate = ViewRules.leftovers(in: tasks)
        let left = Set(needsDate.map(\.id))
        let parked = kind == .open ? shown.filter { $0.status == .parked } : []
        let rest = shown.filter { !left.contains($0.id) && $0.status != .parked }
        if needsDate.isEmpty, parked.isEmpty {
            openRows
        } else {
            if !needsDate.isEmpty {
                Section {
                    ForEach(needsDate) { row($0) }
                } header: {
                    head(Text("Needs a new date"))
                        .accessibilityIdentifier("newDateHead")
                }
            }
            Section {
                ForEach(rest) { row($0) }
            }
            if !parked.isEmpty {
                Section {
                    ForEach(parked) { row($0) }
                } header: {
                    head(Text("Parked"))
                        .accessibilityIdentifier("parkedHead")
                }
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
                    if actions.isPending(task) {
                        pendingRow(task).wideListRow()
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
                TaskRow(task: task, note: note(for: task), nextRank: nextRank(of: task), onNewDate: { redating = task })
            }
            .navigationLinkIndicatorVisibility(.hidden)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) { actions.leadingActions(task) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { actions.trailingActions(task) }
        .contextMenu { actions.menu(task) }
        .paperRow()
        .wideListRow()
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
            actions.save("toggle subtask")
        } label: {
            HStack(spacing: 10) {
                // No circle (#424): open is just the words, done a fine grey check.
                Image(systemName: "checkmark")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .opacity(done ? 1 : 0)
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
        .wideListRow()
    }

    @ViewBuilder
    private func row(_ task: TaskItem) -> some View {
        if actions.isPending(task) {
            pendingRow(task).wideListRow()
        } else {
            openRow(task)
        }
    }

    private func pendingRow(_ task: TaskItem) -> some View {
        actions.pendingRow(task, TaskRow(task: task, hidesContext: context != nil, note: note(for: task), marksParked: kind == .open, nextRank: nextRank(of: task)))
    }

    private func openRow(_ task: TaskItem) -> some View {
        NavigationLink {
            TaskDetailView(task: task, reviewing: kind == .new)
        } label: {
            TaskRow(task: task, hidesContext: context != nil, note: note(for: task), marksParked: kind == .open,
                    nextRank: nextRank(of: task), onNewDate: { redating = task })
        }
        // The whole row opens the task; the system's arrow at its end made room for the star (#509).
        .navigationLinkIndicatorVisibility(.hidden)
        .swipeActions(edge: .leading, allowsFullSwipe: true) { actions.leadingActions(task) }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) { trailingActions(task) }
        .contextMenu { actions.menu(task) }
        .paperRow()
        .wideListRow()
    }

    /// Whose deadline passed (#518, #548): the swipe gives it a new date; everything else as everywhere.
    @ViewBuilder
    private func trailingActions(_ task: TaskItem) -> some View {
        if kind == .due || kind == .open, NewDateRule.needsNewDate(task) {
            Button("New date", systemImage: "calendar") { redating = task }
                .tint(.accentColor)
                .accessibilityIdentifier("swipeNewDate_\(task.id.uuidString)")
        } else {
            actions.trailingActions(task)
        }
    }

    /// The star's number (#509): not in "Next up" itself, where every row would carry one.
    private func nextRank(of task: TaskItem) -> Int? {
        guard kind != .next else { return nil }
        return ViewRules.nextRanks(in: tasks)[task.id]
    }

    /// Old shows the age and how often the task was pushed (design briefing, screen 11). A subtask
    /// under "Needs a new date" (#548) names its parent.
    private func note(for task: TaskItem) -> String? {
        if let parent = task.parent {
            return String(localized: "Subtask of \(parent.displayTitle)")
        }
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
        actions.save("reorder")
    }
}

/// The list's subtitle under its title, wide only (#477); compact stays exactly as it was. On wide
/// it stays attached while empty, so the list keeps its identity when the last task is done.
private struct ListSubtitle: ViewModifier {
    let wide: Bool
    let text: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if wide {
            content.navigationSubtitle(text ?? "")
        } else {
            content
        }
    }
}
