import SwiftData
import SwiftUI

/// The start screen (design briefing, screen 2): system views with counts, then projects,
/// then contexts, Done last. Projects and contexts are created, renamed and deleted right here
/// (screen 7). On iPhone it opens in zones (#368): the inbox bar while anything waits in "New", then
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
    /// One size for every view glyph, growing with Dynamic Type: SF Symbols differ in width
    /// (the hare is wide), and a bare frame lets a wide one spill past the margin.
    @ScaledMetric(relativeTo: .body) private var glyphSize: CGFloat = 20
    /// The start screen's sizes from the draft, growing at half the system's rate (#463).
    @Environment(\.dynamicTypeSize) private var typeSize
    private var metrics: StartMetrics { StartMetrics(typeSize) }

    @State private var catalog = CatalogEditor()
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
    /// iPad and Mac: projects and tags start folded (Henning, 2026-10-05): most days need neither,
    /// and their rows and "New …" buttons pushed the views off the screen. Per device, a view setting
    /// only. The iPhone ignores both: its index opens a page instead (#428).
    @AppStorage("startShowsProjects") private var showsProjects = false
    @AppStorage("startShowsContexts") private var showsContexts = false
    /// Tags and Projects stand on the start page only while their field is on (#538, rule 7).
    @Environment(FieldSettingsStore.self) private var fieldSettings: FieldSettingsStore?
    private var offersTags: Bool { (fieldSettings?.settings ?? .standard).isOn(.contexts) }
    private var offersProjects: Bool { (fieldSettings?.settings ?? .standard).isOn(.project) }

    /// iPhone: the sentence and the preview replace the big "Views" title. iPad and Mac keep the
    /// plain sidebar, where the list sits right next to it anyway.
    private var isCompact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    /// The Mac sidebar is the iPhone's index too (#476, Henning 2026-10-16: the sidebar must match the iOS look):
    /// names in New York, dotted leader, small count; "Tags" and "Projects" open their page. The date, the
    /// sentence and "Now" are the start page's on the Mac. iPad keeps its folding groups.
    private var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    private var showsFoldGroups: Bool { !isCompact && !isMac }

    /// The iPhone index (#421): the views, then Tags and Projects with their words, then All open
    /// and Done. The Tags and Projects lines open their own page (#428). The Mac puts "Start" first
    /// (#583): its start page shows only while nothing is chosen, and a Mac list never lets go of
    /// its selection by a click; ⌘1 does the same.
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
        let views = (isMac ? [start] : []) + ViewRules.indexViews(in: tasks).map(view)
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
            fields: fieldSettings?.settings ?? .standard
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
                        .paperRow()
                    NowBlock(tasks: ViewRules.now(in: tasks).all, count: nowCount) { previewRow($0) }
                    WeekStringRows(beads: ViewRules.weekBeads(in: tasks), all: tasks)
                    // Same section: a second one put the list's section gap above "Contents" (#463).
                    // iPad: the sidebar marks the open list (#334); iPhone: after Back selection is nil.
                    ContentsIndex(groups: indexGroups, selected: selection) { selection = $0 }
                }
            } else if isMac {
                Section {
                    ContentsIndex(groups: indexGroups, selected: selection) { selection = $0 }
                }
            } else {
                Section {
                    // iPad: the start page shows while nothing is chosen; this row and ⌘1 lead back (#583).
                    Button { selection = nil } label: {
                        countRow(String(localized: "Start page"), symbol: "house", count: nowCount, id: "viewRow_start")
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("1", modifiers: .command)
                    .accessibilityAddTraits(selection == nil ? .isSelected : [])
                    // The daily three always, the others only with a task in them.
                    ForEach(ViewRules.startViews(in: tasks), id: \.self) { kind in
                        countRow(String(localized: kind.titleKey), symbol: kind.symbol, count: ViewRules.tasks(for: kind, in: tasks).count, id: "viewRow_\(kind.rawValue)")
                            .tag(ViewSelection.system(kind))
                    }
                }
            }

            // On iPhone and Mac the index lines open these groups as pages (#428).
            if showsFoldGroups, offersProjects {
                Section {
                    if showsProjects {
                        ForEach(projects) { project in
                            countRow(project.name, count: ViewRules.tasks(inProject: project, in: tasks).count, id: "projectRow_\(project.id.uuidString)")
                                .tag(ViewSelection.project(project.id))
                                .catalogMenu(.project(project), in: catalog)
                                .swipeActions { CatalogDeleteButton(target: .project(project), editor: catalog) }
                        }
                        Button("New project", systemImage: "plus") { catalog.begin(NameEdit(target: .newProject)) }
                            .accessibilityIdentifier("newProjectButton")
                            .paperRow()
                    }
                } header: {
                    foldHeader("Projects", count: projects.count, isOpen: $showsProjects, id: "projectsToggle")
                }
            }

            if showsFoldGroups, offersTags {
                Section {
                    if showsContexts {
                        ForEach(contexts) { context in
                            countRow(context.name, count: ViewRules.tasks(inContext: context, in: tasks).count, id: "contextRow_\(context.id.uuidString)")
                                .tag(ViewSelection.context(context.id))
                                .catalogMenu(.context(context), in: catalog)
                                .swipeActions { CatalogDeleteButton(target: .context(context), editor: catalog) }
                        }
                        Button("New tag", systemImage: "plus") { catalog.begin(NameEdit(target: .newContext)) }
                            .accessibilityIdentifier("newContextButton")
                            .paperRow()
                    }
                } header: {
                    foldHeader("Tags", count: contexts.count, isOpen: $showsContexts, id: "contextsToggle")
                }
            }

            if showsFoldGroups {
                Section {
                    // Always there, right above Done (#319); `.badge` leaves a zero out.
                    countRow(String(localized: ViewKind.open.titleKey), symbol: ViewKind.open.symbol, count: ViewRules.tasks(for: .open, in: tasks).count, id: "viewRow_open")
                        .tag(ViewSelection.system(.open))
                    countRow(String(localized: ViewKind.done.titleKey), symbol: ViewKind.done.symbol, count: ViewRules.tasks(for: .done, in: tasks).count, id: "viewRow_done")
                        .tag(ViewSelection.system(.done))
                }
            }
        }
        .paperList()
        // Rows as tall as their content: the 44 pt minimum put a gap under every caption (#433).
        .environment(\.defaultMinListRowHeight, isCompact ? 0 : 44)
        .navigationTitle(isCompact ? Text(verbatim: "") : Text("Views"))
        #if os(iOS)
        // Putting the keyboard away by scrolling ends the entry in the writing line (#601).
        .scrollDismissesKeyboard(.immediately)
        .listSectionSpacing(.compact)
        .navigationBarTitleDisplayMode(isCompact ? .inline : .automatic)
        #endif
        .catalogDialogs(catalog, contexts: contexts, projects: projects) { gone in
            if selection == gone { selection = nil }
        }
        .taskInteractionDialogs(taskActions)
        .sheet(item: $redating) { task in
            NewDateSheet(task: task) { redating = nil }
        }
    }

    /// The header of a foldable group: its name, how many it holds while folded, and the arrow.
    /// The whole line is the button.
    private func foldHeader(_ title: LocalizedStringKey, count: Int, isOpen: Binding<Bool>, id: String) -> some View {
        Button {
            withAnimation(.snappy) { isOpen.wrappedValue.toggle() }
        } label: {
            HStack {
                Text(title)
                Spacer()
                if !isOpen.wrappedValue, count > 0 {
                    Text(verbatim: "\(count)")
                        .monospacedDigit()
                }
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .rotationEffect(.degrees(isOpen.wrappedValue ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOpen.wrappedValue ? Text("Shown") : Text("Hidden"))
        .accessibilityIdentifier(id)
    }

    /// A view, project or context with its count. `.badge` leaves a zero out (#180).
    @ViewBuilder
    private func countRow(_ title: String, symbol: String? = nil, count: Int, id: String) -> some View {
        Group {
            if let symbol {
                Label {
                    Text(title)
                } icon: {
                    // Grey, not the list's accent: accent means tappable (ADR-14). A fixed column,
                    // so a wide glyph (the hare) does not push past the margin.
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: glyphSize, height: glyphSize)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(title)
            }
        }
        .badge(count)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
        .paperRow()
    }

    // MARK: - Start (iPhone)

    /// The date at the knot or the Knäuel, the Knäuel's row, the sentence of the day (#426, #643), as
    /// the first rows of the start list. A tap beside the writing line, on the date or the sentence,
    /// ends the entry (#601).
    @ViewBuilder
    private var headerRows: some View {
        StartHeaderRows(tasks: tasks, onTap: { endRequest += 1 }, openDone: { selection = .system(.done) }) { task, head in knaeuelRow(task, head) }
    }

    /// The Knäuel's head (#643, #644), date and row as one: a tap opens the task, swipe right completes
    /// it with the Undo window, the long press holds the menu, as in "Now".
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
                .paperRow()
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
                .paperRow()
        }
    }
}
