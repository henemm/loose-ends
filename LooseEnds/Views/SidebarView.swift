import SwiftData
import SwiftUI

/// The start screen (design briefing, screen 2): system views with counts, Tags and Projects (their
/// pages create, rename and delete, #428), Done last. On Mac and the wide iPad the index alone (#828). On iPhone it opens in zones (#368): the inbox bar while anything waits in "New", then
/// the "Now" block (overdue, due today, lined up, each task once, with the same swipes and
/// long-press menu as in the list, #303); the views follow below.
struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CompletionPulse.self) private var completionPulse: CompletionPulse?
    @Environment(PendingCompletions.self) private var pendingCompletions: PendingCompletions?
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Binding var selection: ViewSelection?
    let tasks: [TaskItem]
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    /// The start screen's sizes from the draft, growing at half the system's rate (#463).
    @Environment(\.dynamicTypeSize) private var typeSize
    private var metrics: StartMetrics { StartMetrics(typeSize) }

    @State private var pendingTaskDelete: TaskItem?
    @State private var confirmingTaskDelete = false
    @State private var datingTask: TaskItem?
    /// "New date" on a row in "Now" whose deadline passed (#637): the date choice "Due" uses.
    @State private var redating: TaskItem?
    /// Complete with open subtasks asks first (#565).
    @State private var askingSubtasks: TaskItem?
    /// A second Knäuel asks first (#643).
    @State private var askingKnaeuel: TaskItem?
    /// Each change ends the entry in the writing line (#601).
    @State private var endRequest = 0
    /// Tags and Projects stand on the start page only while their field is on (#538, rule 7).
    @Environment(FieldSettingsStore.self) private var fieldSettings: FieldSettingsStore?
    /// "Analyze again" in the long-press menu (#667); nil in previews, then it is not offered.
    @Environment(\.enrichment) private var enrichment: EnrichmentCoordinator?
    private var offersTags: Bool { (fieldSettings?.settings ?? .standard).isOn(.contexts) }
    private var offersProjects: Bool { (fieldSettings?.settings ?? .standard).isOn(.project) }

    /// iPhone (and an iPad in Split View or Slide Over): the sidebar is the start page. Read from the
    /// window, which `ContentView` hands in: the split view's sidebar column itself always reports compact
    /// on the iPad, and it showed the iPhone's start page beside the start page (#828).
    private var isCompact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    /// The iPhone index (#421): the views, then Tags and Projects with their words, then All open
    /// and Done. The Tags and Projects lines open their own page (#428). The Mac sidebar is the same index
    /// (#476, Henning 2026-10-16), the wide iPad's too (#828, Henning 2026-11-04: "orientiere dich am macOS").
    /// Both put "Start" first (#583): their start page shows only while nothing is chosen; ⌘1 does the same.
    private var indexGroups: [[IndexLine]] {
        func view(_ kind: ViewKind) -> IndexLine {
            IndexLine(id: "viewRow_\(kind.rawValue)", title: String(localized: kind.titleKey),
                      count: ViewRules.tasks(for: kind, in: tasks).count, target: .system(kind)) { selection = .system(kind) }
        }
        let tagWords = contexts.compactMap { context -> IndexWord? in
            let count = ViewRules.tasks(inContext: context, in: tasks).count
            return count > 0 ? IndexWord(id: "chip_\(context.id.uuidString)", name: context.name, count: count,
                                         target: .context(context.id)) : nil
        }
        let projectWords = projects.compactMap { project -> IndexWord? in
            let count = ViewRules.tasks(inProject: project, in: tasks).count
            return count > 0 ? IndexWord(id: "projectWord_\(project.id.uuidString)", name: project.name, count: count,
                                         target: .project(project.id)) : nil
        }
        let tagsLine = IndexLine(id: "contextsToggle", title: String(localized: "Tags"), count: contexts.count,
                                 words: tagWords, target: .catalog(.tags)) { selection = .catalog(.tags) }
        let projectsLine = IndexLine(id: "projectsToggle", title: String(localized: "Projects"), count: projects.count,
                                     words: projectWords, target: .catalog(.projects)) { selection = .catalog(.projects) }
        let groups = [offersTags ? tagsLine : nil, offersProjects ? projectsLine : nil].compactMap { $0 }
        // The app icon's number, the same as over "Now" on the start page (#637).
        let start = IndexLine(id: "viewRow_start", title: String(localized: "Start page"), count: nowCount, opensStart: true,
                              shortcut: KeyboardShortcut("1", modifiers: .command)) { selection = nil }
        let views = (isCompact ? [] : [start]) + ViewRules.indexViews(in: tasks).map(view)
        return [views, groups, [view(.open), view(.done)]].filter { !$0.isEmpty }
    }

    /// The number on the app icon and over "Now" (#637), one rule: `ViewRules.now`.
    private var nowCount: Int { ViewRules.nowCount(in: tasks) }

    /// The "Now" rows act as in "Next up" (#303): one set of actions carries them all (#368).
    private var taskActions: TaskInteractions { interactions(.next) }

    private func interactions(_ kind: ViewKind) -> TaskInteractions {
        TaskInteractions(
            kind: kind, tasks: tasks, contexts: contexts, projects: projects, modelContext: modelContext,
            pendingCompletions: pendingCompletions, completionPulse: completionPulse,
            pendingDelete: $pendingTaskDelete, confirmingDelete: $confirmingTaskDelete, datingTask: $datingTask,
            askingSubtasks: $askingSubtasks, askingKnaeuel: $askingKnaeuel,
            didDelete: { id in if selection == .task(id) { selection = nil } },
            fields: fieldSettings?.settings ?? .standard,
            analyze: TaskInteractions.listAnalysis(enrichment)
        )
    }

    var body: some View {
        List(selection: $selection) {
            if isCompact {
                // One section: a plain list puts a tall gap above every section header.
                Section {
                    headerRows
                    // "New" with the writing line under it (#601); a tap on the header ends the entry.
                    InboxDrawerView(tasks: tasks, open: { selection = $0 }, selection: selection, endRequest: endRequest)
                        .listRowSeparator(.hidden)
                        .startRow(metrics)
                        .sidebarRow()
                    NowBlock(tasks: tasks) { previewRow($0) } knaeuelRow: { task, head in knaeuelRow(task, head) }
                    // Same section: a second one put the list's section gap above "Contents" (#463).
                    // iPad: the sidebar marks the open list (#334); iPhone: after Back selection is nil.
                    ContentsIndex(groups: indexGroups, selected: selection, inMargin: true) { selection = $0 }
                    // The beads close the page, quiet and without a caption (#677).
                    let stringLength = fieldSettings?.stringLength ?? ViewRules.stringLength
                    WeekStringRows(string: ViewRules.currentString(in: tasks, length: stringLength), all: tasks, length: stringLength)
                }
            } else {
                // Mac and the wide iPad (#476, #828): the sidebar is the index alone, the start page stands
                // in the detail column beside it.
                Section {
                    ContentsIndex(groups: indexGroups, selected: selection) { selection = $0 }
                }
            }
        }
        .paperList()
        // Rows as tall as their content: the 44 pt minimum put a gap under every caption (#433).
        .environment(\.defaultMinListRowHeight, isCompact ? 0 : 44)
        #if os(macOS)
        .navigationTitle(Text("Views"))
        #else
        // No "Views" title over the index: the Mac shows none either (#828).
        .navigationTitle(Text(verbatim: ""))
        // Putting the keyboard away by scrolling ends the entry in the writing line (#601).
        .scrollDismissesKeyboard(.immediately)
        .listSectionSpacing(.compact)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .taskInteractionDialogs(taskActions)
        .sheet(item: $redating) { task in
            NewDateSheet(task: task) { redating = nil }
        }
    }

    // MARK: - Start (iPhone)

    /// The date at the knot and the sentence of the day (#426, #643), as the first row of the start
    /// list; the Knäuel's row stands first under "Now" (#703). A tap beside the writing line, on the
    /// date or the sentence, ends the entry (#601).
    @ViewBuilder
    private var headerRows: some View {
        StartHeaderRows(tasks: tasks, onTap: { endRequest += 1 }, openDone: { selection = .system(.done) })
    }

    /// The Knäuel's row, first under "Now" (#643, #644, #703): a tap opens the task, swipe right
    /// completes it with the Undo window, the long press holds the menu, as the other rows.
    @ViewBuilder
    private func knaeuelRow(_ task: TaskItem, _ head: KnaeuelHead) -> some View {
        let actions = taskActions
        if actions.isPending(task) {
            actions.pendingRow(task, head)
                .listRowSeparator(.hidden)
                .startRow(metrics)
        } else {
            head
                .startRow(metrics)
                .tag(ViewSelection.task(task.id))
                .listRowSeparator(.hidden)
                .swipeActions(edge: .leading, allowsFullSwipe: true) { actions.leadingActions(task) }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) { actions.trailingActions(task) }
                .contextMenu { actions.menu(task) }
                .sidebarRow()
        }
    }

    /// A tap opens the task; while its Done window runs (#32) a tap takes it back instead.
    @ViewBuilder
    private func previewRow(_ task: TaskItem) -> some View {
        let actions = taskActions
        let row = TaskRow(task: task, identifierPrefix: "nowRow_", onNewDate: { redating = task })
        if actions.isPending(task) {
            actions.pendingRow(task, row)
        } else {
            row
                // The draft's slim row: 11 pt above and below, its sizes, the list's edges (#463).
                .padding(.vertical, 11)
                .environment(\.startMetrics, metrics)
                .startRow(metrics)
                .tag(ViewSelection.task(task.id))
                .swipeActions(edge: .leading, allowsFullSwipe: true) { actions.leadingActions(task) }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) { actions.trailingActions(task) }
                .contextMenu { actions.menu(task) }
                .sidebarRow()
        }
    }
}
