import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

/// The date under the knot and the one sentence of the day (#426). The iPhone start list and the
/// wide start page (#408) show the same two lines.
struct StartHeader: View {
    let tasks: [TaskItem]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        // Once a minute, so the line turns to the look back at 16:00 without a save (#426).
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    // The knot, first of its three places (#180, rule 1). Grey like the date: it is
                    // the mark, not something to tap (ADR-14).
                    ThreadGlyph(form: .knot, lineWidth: 1.5)
                        .frame(width: metrics(30), height: metrics(16))
                    Text(timeline.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(metrics.caption)
                        .textCase(.uppercase)
                        .tracking(metrics.captionTracking)
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("startHeader")
                // The one fact that stands out today, from 16:00 a look back (#426). Content, so New York.
                Text(StartHeadlineText.sentence(StartHeadline.of(tasks, now: timeline.date)))
                    .font(metrics.headline)
                    .tracking(-0.3)
                    .lineSpacing(0)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("startHeadline")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// What the wide window shows while no view is chosen (#408, draft "Papier und Faden", cut 1): the
/// sentence of the day, a field to say something, and "Now". iPad in a wide window and the Mac;
/// the iPhone opens its start list instead.
struct StartPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(CompletionPulse.self) private var completionPulse: CompletionPulse?
    @Environment(PendingCompletions.self) private var pendingCompletions: PendingCompletions?
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Binding var selection: ViewSelection?
    let tasks: [TaskItem]
    /// ⌘N on the start page: each change puts the cursor in the writing line (#472).
    var focusRequest = 0
    @State private var pendingTaskDelete: TaskItem?
    @State private var confirmingTaskDelete = false
    @State private var datingTask: TaskItem?
    /// Complete with open subtasks asks first (#565).
    @State private var askingSubtasks: TaskItem?
    #if os(macOS)
    /// "N more" unfolded; here, so the Mac's keys choose among the rows "Now" shows (#480).
    @State private var nowExpanded = false
    /// Never set on appear (#480): the writing line and ⌘N (#472) come first on the start page.
    @FocusState private var listFocused: Bool
    /// The writing line holds the focus: the row keys stay in the field.
    @State private var writingFocused = false

    /// The chosen "Now" row (#480); in `ChosenRows`, since the page is built anew on the way back from a task.
    private var selectedID: UUID? {
        get { ChosenRows.shared.start }
        nonmutating set { ChosenRows.shared.start = newValue }
    }
    #endif

    var body: some View {
        // The right column needs room: from about 900 pt of width it stands next to the list (#473).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                listColumn
                SideColumnView(tasks: tasks, selection: $selection)
            }
            .frame(minWidth: 900)
            listColumn
        }
        .accessibilityIdentifier("startPage")
        .taskInteractionDialogs(actions)
    }

    private var listColumn: some View {
        let metrics = StartMetrics(typeSize)
        return keyed(List {
            StartHeader(tasks: tasks)
                .padding(.top, 14)
                .padding(.bottom, 16)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
            // "New" with the writing line under it (#601): Return makes a task, the button opens
            // into a drawer that shows it, leaving the line folds it.
            InboxDrawerView(tasks: tasks, open: { selection = $0 }, selection: selection, focusRequest: focusRequest,
                            onWritingFocus: writingFocusChanged)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
            NowBlock(tasks: ViewRules.now(in: tasks).all, expanded: nowExpandedBinding) { nowRow($0, metrics) }
        })
        .listStyle(.plain)
        .paperGround()
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        // The paper runs edge to edge: outside the 720 pt column the window showed white bars (build 71).
        .background(Paper.ground.ignoresSafeArea())
    }

    /// The "Now" rows act as on the iPhone (#472): Done with the Undo window, swipes, the menu on
    /// right click. One set of actions, the one "Next up" uses (#303).
    private var actions: TaskInteractions {
        TaskInteractions(
            kind: .next, tasks: tasks, contexts: contexts, projects: projects, modelContext: modelContext,
            pendingCompletions: pendingCompletions, completionPulse: completionPulse,
            pendingDelete: $pendingTaskDelete, confirmingDelete: $confirmingTaskDelete, datingTask: $datingTask,
            askingSubtasks: $askingSubtasks,
            didDelete: { id in if selection == .task(id) { selection = nil } }
        )
    }

    /// The fold state of "Now": the page's on the Mac (#480), `NowBlock`'s own elsewhere, as before.
    private var nowExpandedBinding: Binding<Bool>? {
        #if os(macOS)
        $nowExpanded
        #else
        nil
        #endif
    }

    @ViewBuilder
    private func nowRow(_ task: TaskItem, _ metrics: StartMetrics) -> some View {
        #if os(macOS)
        macNowRow(task)
        #else
        let actions = self.actions
        let row = TaskRow(task: task, identifierPrefix: "startNowRow_")
        if actions.isPending(task) {
            actions.pendingRow(task, row)
        } else {
            Button { selection = .task(task.id) } label: {
                row
                    .padding(.vertical, 11)
                    .environment(\.startMetrics, metrics)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .startRow(metrics)
            .swipeActions(edge: .leading, allowsFullSwipe: true) { actions.leadingActions(task) }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) { actions.trailingActions(task) }
            .contextMenu { actions.menu(task) }
            .paperRow()
        }
        #endif
    }

    #if os(macOS)
    /// The Mac's "Now" row (#480): the chosen row is tinted and carries the selected trait.
    @ViewBuilder
    private func macNowRow(_ task: TaskItem) -> some View {
        let actions = self.actions
        let row = TaskRow(task: task, identifierPrefix: "startNowRow_")
        if actions.isPending(task) {
            actions.pendingRow(task, row).wideListRow(selected: isChosen(task))
        } else {
            Button { open(task) } label: {
                row
                    .contentShape(Rectangle())
                    .accessibilityAddTraits(isChosen(task) ? .isSelected : [])
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .leading, allowsFullSwipe: true) { actions.leadingActions(task) }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) { actions.trailingActions(task) }
            .contextMenu { actions.menu(task) }
            .paperRow()
            .wideListRow(selected: isChosen(task))
            // The 11 pt above and below sit outside the button now: they open the task as before.
            .contentShape(Rectangle())
            .onTapGesture { open(task) }
        }
    }

    private func open(_ task: TaskItem) {
        // A click marks the row too (#480), so the arrows go on from there after the task.
        selectedID = task.id
        selection = .task(task.id)
    }

    /// Whether the row is the one chosen on the Mac (#480).
    private func isChosen(_ task: TaskItem) -> Bool {
        selectedID == task.id
    }
    #endif

    private func writingFocusChanged(_ focused: Bool) {
        #if os(macOS)
        writingFocused = focused
        #endif
    }

    /// The Mac's keys on the "Now" rows (#480), as in `TaskListView`: arrows choose, Space finishes,
    /// Delete asks first. The list only gets the focus from a click, never on appear.
    @ViewBuilder
    private func keyed(_ list: some View) -> some View {
        #if os(macOS)
        ScrollViewReader { proxy in
            list
                .focused($listFocused)
                // Only the bare keys: ⌘⌫, ⇧Space or ⌥↓ mean something else.
                .onKeyPress(keys: [.upArrow, .downArrow, .space, .delete]) { press in
                    guard press.modifiers.isDisjoint(with: [.command, .shift, .option, .control]) else { return .ignored }
                    switch press.key {
                    case .upArrow: return handle(.up)
                    case .downArrow: return handle(.down)
                    case .space: return handle(.space)
                    default: return handle(.delete)
                    }
                }
                // Fallbacks should the list take the keys before `onKeyPress` (Apple forums 667366, 772806).
                .onMoveCommand { direction in
                    guard Self.bareKey else { return }
                    switch direction {
                    case .up: _ = handle(.up)
                    case .down: _ = handle(.down)
                    default: break
                    }
                }
                .onDeleteCommand { if Self.bareKey { _ = handle(.delete) } }
                .onChange(of: selectedID) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
                // A row that left "Now" (done, moved, deleted) takes the choice with it; nothing jumps on.
                .onChange(of: rowIDs) { _, ids in
                    if let chosen = selectedID, !ids.contains(chosen) { selectedID = nil }
                }
        }
        #else
        list
        #endif
    }

    #if os(macOS)
    /// Carries out what `RowKeyAction` decided, with the "Now" rows' existing actions only.
    private func handle(_ key: RowKey) -> KeyPress.Result {
        // The writing line sits in the same list: while it holds the focus, its keys stay in the field.
        let action = RowKeyAction.resolve(key, textFocused: writingFocused, selection: selectedID, ids: rowIDs) { id in
            tasks.first { $0.id == id }.map { RowKeyAction.spaceCompletes(in: .next, status: $0.status) } ?? false
        }
        let actions = self.actions
        switch action {
        case .select(let id):
            selectedID = id
        case .complete(let id):
            // A row in its Done window (#32) is not scheduled twice.
            if let task = tasks.first(where: { $0.id == id }), !actions.isPending(task) {
                actions.complete(task)
            }
        case .delete(let id):
            guard let task = tasks.first(where: { $0.id == id }) else { return .ignored }
            pendingTaskDelete = task
            confirmingTaskDelete = true
        case .ignore:
            return .ignored
        }
        return .handled
    }

    /// The move and delete commands carry no key press; the modifiers come from the current event.
    private static var bareKey: Bool {
        NSEvent.modifierFlags.isDisjoint(with: [.command, .shift, .option, .control])
    }

    /// The "Now" rows as shown, top to bottom: the first five while folded. Not "New" nor the right column.
    private var rowIDs: [UUID] {
        let now = ViewRules.now(in: tasks).all
        return (nowExpanded ? now : Array(now.prefix(NowBlock<EmptyView>.limit))).map(\.id)
    }
    #endif
}
