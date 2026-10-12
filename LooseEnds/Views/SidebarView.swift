import OSLog
import SwiftData
import SwiftUI

/// The start screen (design briefing, screen 2): system views with counts, then projects,
/// then contexts, Done last. Projects and contexts are created, renamed and deleted right here
/// (screen 7). On iPhone it opens in three zones (#368): an inbox bar while anything waits in "New",
/// the "Now" block (due today first, then "Next up", each task once, with the same swipes and
/// long-press menu as in the list, #303), and situation chips; the other views follow quietly.
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
    @ScaledMetric(relativeTo: .caption) private var knotHeight: CGFloat = 16
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var edit: NameEdit?
    @State private var isEditing = false
    @State private var editName = ""
    @State private var pendingDelete: NameEdit.Target?
    @State private var confirmingDelete = false
    @State private var duplicateRejected = false
    @State private var pendingTaskDelete: TaskItem?
    @State private var confirmingTaskDelete = false
    @State private var datingTask: TaskItem?
    /// Projects and contexts start folded (Henning, 2026-10-05): most days need neither, and their
    /// rows and "New …" buttons pushed the views off the screen. Per device, a view setting only.
    @AppStorage("startShowsProjects") private var showsProjects = false
    @AppStorage("startShowsContexts") private var showsContexts = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Sidebar")

    /// iPhone: the sentence and the preview replace the big "Views" title. iPad and Mac keep the
    /// plain sidebar, where the list sits right next to it anyway.
    private var isCompact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    /// The preview's rows stand in "Next up", so they act as they do there (#303).
    private var taskActions: TaskInteractions { interactions(.next) }

    /// The "Due today" rows (#299) act as they do in "Due".
    private var dueActions: TaskInteractions { interactions(.due) }

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
                    inboxBar
                    nowBlock
                    situationChips
                }
            }
            if isCompact {
                Section {
                    caption("All views")
                    viewGrid
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

            Section {
                if showsProjects {
                    ForEach(projects) { project in
                        countRow(project.name, count: ViewRules.tasks(inProject: project, in: tasks).count, id: "projectRow_\(project.id.uuidString)")
                            .tag(ViewSelection.project(project.id))
                            .contextMenu { catalogMenu(.project(project)) }
                            .swipeActions { deleteButton(.project(project)) }
                    }
                    Button("New project", systemImage: "plus") { begin(NameEdit(target: .newProject)) }
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
                            .contextMenu { catalogMenu(.context(context)) }
                            .swipeActions { deleteButton(.context(context)) }
                    }
                    Button("New context", systemImage: "plus") { begin(NameEdit(target: .newContext)) }
                        .accessibilityIdentifier("newContextButton")
                        .paperRow()
                }
            } header: {
                foldHeader("Contexts", count: contexts.count, isOpen: $showsContexts, id: "contextsToggle")
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
        .navigationTitle(isCompact ? Text(verbatim: "") : Text("Views"))
        #if os(iOS)
        .listSectionSpacing(.compact)
        .navigationBarTitleDisplayMode(isCompact ? .inline : .automatic)
        #endif
        .alert(Text(edit?.title ?? ""), isPresented: $isEditing, presenting: edit) { edit in
            TextField("Name", text: $editName)
                .accessibilityIdentifier("nameField")
            Button(edit.isNew ? "Add" : "Save") { commit(edit) }
                .accessibilityIdentifier("nameSaveButton")
            Button("Cancel", role: .cancel) {}
        }
        .alert("A context with this name already exists.", isPresented: $duplicateRejected) {
            Button("OK", role: .cancel) {}
                .accessibilityIdentifier("duplicateNameOKButton")
        }
        .confirmationDialog(Text(pendingDelete?.deleteTitle ?? ""), isPresented: $confirmingDelete, titleVisibility: .visible, presenting: pendingDelete) { target in
            Button("Delete", role: .destructive) { delete(target) }
                .accessibilityIdentifier("confirmDeleteButton")
        } message: { target in
            Text(target.deleteMessage)
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

    /// The quiet views in two columns (#368): the system views that hold something, then All open
    /// and Done. Grey glyphs, no accent: these are places to browse, not a call to act (ADR-14).
    /// From a large Dynamic Type size on, one column, so no name is cut.
    @ViewBuilder
    private var viewGrid: some View {
        let columns = dynamicTypeSize >= .xxLarge
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 20), GridItem(.flexible())]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
            ForEach(ViewRules.compactGridViews(in: tasks), id: \.self) { kind in
                gridCell(kind)
            }
        }
        .listRowSeparator(.hidden)
        .paperRow()
    }

    private func gridCell(_ kind: ViewKind) -> some View {
        let count = ViewRules.tasks(for: kind, in: tasks).count
        return Button {
            selection = .system(kind)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind.symbol)
                    .resizable()
                    .scaledToFit()
                    .frame(width: glyphSize * 0.8, height: glyphSize * 0.8)
                    .foregroundStyle(.secondary)
                Text(String(localized: kind.titleKey))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if count > 0 {
                    Text(verbatim: "\(count)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("viewRow_\(kind.rawValue)")
    }

    /// The date under the knot. Plain: the sentence it used to carry is gone (#368).
    private var header: some View {
        HStack(spacing: 8) {
            // The knot, first of its three places (#180, rule 1). Grey like the date: it is
            // the mark, not something to tap (ADR-14).
            ThreadGlyph(form: .knot, lineWidth: 1.5)
                .frame(width: knotHeight * 1.6, height: knotHeight)
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1)
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("startHeader")
        .paperRow()
    }

    /// "New" is an inbox, not a list among lists (#368): a bar that exists only while something
    /// waits there. The one accent surface of the start screen, since it is the one thing to tap.
    /// It keeps the id of the row it replaces.
    @ViewBuilder
    private var inboxBar: some View {
        let review = ViewRules.tasks(for: .new, in: tasks).count
        if review > 0 {
            HStack(spacing: 10) {
                Image(systemName: "tray")
                Text("\(review) to look over")
                Spacer()
                Image(systemName: "chevron.right")
                    .imageScale(.small)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("viewRow_new")
            .tag(ViewSelection.system(.new))
            .listRowSeparator(.hidden)
            .paperRow()
        }
    }

    /// What stands for now (#368): due today or overdue, then "Next up", the first five, each
    /// task once. A task lined up keeps the "Next up" menu (it can leave the line there), one
    /// that is only due acts as in "Due". Nothing at all: one line, "All tied up".
    @ViewBuilder
    private var nowBlock: some View {
        let now = ViewRules.now(in: tasks)
        if now.isEmpty {
            if ViewRules.tasks(for: .new, in: tasks).isEmpty {
                Text("All tied up.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .paperRow()
            }
        } else {
            caption("Now")
            ForEach(now.prefix(5)) { task in
                if task.nextRank != nil {
                    previewRow(task)
                } else {
                    previewRow(task, actions: dueActions, prefix: "dueTodayPreview_")
                }
            }
        }
    }

    /// Quick and the contexts that hold a task, one tap each (#368). Accent outline: tappable.
    @ViewBuilder
    private var situationChips: some View {
        let quick = ViewRules.tasks(for: .quick, in: tasks).count
        let places = contexts.map { ($0, ViewRules.tasks(inContext: $0, in: tasks).count) }.filter { $0.1 > 0 }
        if quick > 0 || !places.isEmpty {
            caption("Fits right now")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if quick > 0 {
                        chip(String(localized: ViewKind.quick.titleKey), count: quick, target: .system(.quick), id: "situationChip_quick")
                    }
                    ForEach(places, id: \.0.id) { context, count in
                        chip(context.name, count: count, target: .context(context.id), id: "situationChip_\(context.id.uuidString)")
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowSeparator(.hidden)
            .paperRow()
        }
    }

    private func chip(_ title: String, count: Int, target: ViewSelection, id: String) -> some View {
        Button {
            selection = target
        } label: {
            HStack(spacing: 4) {
                Text(title)
                Text(verbatim: "\(count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
            .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func caption(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden)
            .paperRow()
    }

    /// A tap opens the task; while its Done window runs (#32) a tap takes it back instead.
    @ViewBuilder
    private func previewRow(_ task: TaskItem, actions: TaskInteractions? = nil, prefix: String = "nextUpPreview_") -> some View {
        let actions = actions ?? taskActions
        let row = TaskRow(task: task, identifierPrefix: prefix)
        if actions.isPending(task) {
            actions.pendingRow(task, row)
        } else {
            row
                .tag(ViewSelection.task(task.id))
                .swipeActions(edge: .leading, allowsFullSwipe: true) { actions.leadingActions(task) }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) { actions.trailingActions(task) }
                .contextMenu { actions.menu(task) }
                .paperRow()
        }
    }

    @ViewBuilder
    private func catalogMenu(_ target: NameEdit.Target) -> some View {
        Button("Rename", systemImage: "pencil") { begin(NameEdit(target: target)) }
        deleteButton(target)
    }

    private func deleteButton(_ target: NameEdit.Target) -> some View {
        Button("Delete", systemImage: "trash", role: .destructive) {
            pendingDelete = target
            confirmingDelete = true
        }
    }

    // MARK: - Edits

    private func begin(_ edit: NameEdit) {
        editName = edit.currentName
        self.edit = edit
        isEditing = true
    }

    /// A blank name is a cancel, not an error worth showing. A taken context name is (#157).
    private func commit(_ edit: NameEdit) {
        do {
            switch edit.target {
            case .newProject:
                try CatalogService.addProject(named: editName, in: modelContext, existing: projects)
            case .newContext:
                try CatalogService.addContext(named: editName, in: modelContext, existing: contexts)
            case .project(let project):
                try CatalogService.rename(project, to: editName)
            case .context(let context):
                try CatalogService.rename(context, to: editName, among: contexts)
            }
            try modelContext.save()
        } catch CatalogError.emptyName {
            return
        } catch CatalogError.duplicateName {
            duplicateRejected = true
        } catch {
            Self.logger.error("Saving the name failed: \(error, privacy: .public)")
        }
    }

    private func delete(_ target: NameEdit.Target) {
        switch target {
        case .project(let project):
            if selection == .project(project.id) { selection = nil }
            CatalogService.delete(project, in: modelContext)
        case .context(let context):
            if selection == .context(context.id) { selection = nil }
            CatalogService.delete(context, in: modelContext, among: contexts)
        case .newProject, .newContext:
            return
        }
        pendingDelete = nil
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Deleting failed: \(error, privacy: .public)")
        }
    }
}

/// What the name alert is editing.
struct NameEdit {
    enum Target {
        case newProject, newContext
        case project(Project)
        case context(TaskContext)

        var deleteTitle: String {
            switch self {
            case .project: String(localized: "Delete this project?")
            case .context: String(localized: "Delete this context?")
            case .newProject, .newContext: ""
            }
        }

        var deleteMessage: String {
            switch self {
            case .project: String(localized: "Its tasks stay and lose the project.")
            case .context: String(localized: "Its tasks stay and lose the context.")
            case .newProject, .newContext: ""
            }
        }
    }

    let target: Target

    var isNew: Bool {
        switch target {
        case .newProject, .newContext: true
        case .project, .context: false
        }
    }

    var title: String {
        switch target {
        case .newProject: String(localized: "New project")
        case .newContext: String(localized: "New context")
        case .project, .context: String(localized: "Rename")
        }
    }

    var currentName: String {
        switch target {
        case .project(let project): project.name
        case .context(let context): context.name
        case .newProject, .newContext: ""
        }
    }
}
