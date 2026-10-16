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
    /// iPad and Mac: projects and tags start folded (Henning, 2026-10-05): most days need neither,
    /// and their rows and "New …" buttons pushed the views off the screen. Per device, a view setting
    /// only. The iPhone ignores both: its index opens a page instead (#428).
    @AppStorage("startShowsProjects") private var showsProjects = false
    @AppStorage("startShowsContexts") private var showsContexts = false

    /// iPhone: the sentence and the preview replace the big "Views" title. iPad and Mac keep the
    /// plain sidebar, where the list sits right next to it anyway.
    private var isCompact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    /// The iPhone index (#421): the views, then Tags and Projects with their words, then All open
    /// and Done. The Tags and Projects lines open their own page (#428).
    private var indexGroups: [[IndexLine]] {
        func view(_ kind: ViewKind) -> IndexLine {
            IndexLine(id: "viewRow_\(kind.rawValue)", title: String(localized: kind.titleKey),
                      count: ViewRules.tasks(for: kind, in: tasks).count) { selection = .system(kind) }
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
                                 words: tagWords) { selection = .catalog(.tags) }
        let projectsLine = IndexLine(id: "projectsToggle", title: String(localized: "Projects"), count: projects.count,
                                     words: projectWords) { selection = .catalog(.projects) }
        return [ViewRules.indexViews(in: tasks).map(view), [tagsLine, projectsLine], [view(.open), view(.done)]]
    }

    /// The "Now" rows act as in "Next up" (#303): one set of actions carries them all (#368).
    private var taskActions: TaskInteractions { interactions(.next) }

    private func interactions(_ kind: ViewKind) -> TaskInteractions {
        TaskInteractions(
            kind: kind, tasks: tasks, contexts: contexts, projects: projects, modelContext: modelContext,
            pendingCompletions: pendingCompletions, completionPulse: completionPulse,
            pendingDelete: $pendingTaskDelete, confirmingDelete: $confirmingTaskDelete, datingTask: $datingTask,
            didDelete: { id in if selection == .task(id) { selection = nil } }
        )
    }

    var body: some View {
        List(selection: $selection) {
            if isCompact {
                // One section: a plain list puts a tall gap above every section header.
                Section {
                    header
                    let review = ViewRules.tasks(for: .new, in: tasks).count
                    if review > 0 {
                        InboxBar(count: review).tag(ViewSelection.system(.new))
                    }
                    NowBlock(tasks: ViewRules.now(in: tasks).all) { previewRow($0) }
                    // Same section: a second one put the list's section gap above "Contents" (#463).
                    ContentsIndex(groups: indexGroups) { selection = $0 }
                }
            } else {
                Section {
                    // The daily three always, the others only with a task in them.
                    ForEach(ViewRules.startViews(in: tasks), id: \.self) { kind in
                        countRow(String(localized: kind.titleKey), symbol: kind.symbol, count: ViewRules.tasks(for: kind, in: tasks).count, id: "viewRow_\(kind.rawValue)")
                            .tag(ViewSelection.system(kind))
                    }
                }
            }

            // On iPhone the index lines open these groups as pages (#428).
            if !isCompact {
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

            if !isCompact {
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
        .listSectionSpacing(.compact)
        .navigationBarTitleDisplayMode(isCompact ? .inline : .automatic)
        #endif
        .catalogDialogs(catalog, contexts: contexts, projects: projects) { gone in
            if selection == gone { selection = nil }
        }
        .taskInteractionDialogs(taskActions)
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

    /// The date under the knot. Plain: the sentence it used to carry is the inbox bar now (#368).
    private var header: some View {
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
        // The draft: 14 above the date line, 16 under the headline (#463).
        .padding(.top, 14)
        .padding(.bottom, 16)
        .listRowSeparator(.hidden)
        .startRow(metrics)
        .paperRow()
    }

    private func previewRow(_ task: TaskItem) -> some View {
        let actions = taskActions
        let row = TaskRow(task: task, identifierPrefix: "nowRow_")
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
