import OSLog
import SwiftData
import SwiftUI

/// The start screen (design briefing, screen 2): system views with counts, then projects,
/// then contexts, Done last. Projects and contexts are created, renamed and deleted right here
/// (screen 7). On iPhone it opens with the two reasons to open the app at all (#180): a sentence
/// on what is left to look over and what is lined up, then the first three of "Next up".
struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
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
    @ScaledMetric(relativeTo: .caption) private var knotHeight: CGFloat = 13

    @State private var edit: NameEdit?
    @State private var isEditing = false
    @State private var editName = ""
    @State private var pendingDelete: NameEdit.Target?
    @State private var confirmingDelete = false
    @State private var duplicateRejected = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Sidebar")

    private static let systemKinds: [ViewKind] = [.next, .new, .due, .quick, .old, .waiting, .repeating, .parked]

    /// iPhone: the sentence and the preview replace the big "Views" title. iPad and Mac keep the
    /// plain sidebar, where the list sits right next to it anyway.
    private var isCompact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        List(selection: $selection) {
            if isCompact {
                // One section: a plain list puts a tall gap above every section header.
                Section {
                    header
                    nextUpPreview
                }
            }
            Section {
                ForEach(Self.systemKinds, id: \.self) { kind in
                    countRow(String(localized: kind.titleKey), symbol: kind.symbol, count: ViewRules.tasks(for: kind, in: tasks).count, id: "viewRow_\(kind.rawValue)")
                        .tag(ViewSelection.system(kind))
                }
            }

            Section("Projects") {
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

            Section("Contexts") {
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

            Section {
                countRow(String(localized: ViewKind.done.titleKey), symbol: ViewKind.done.symbol, count: ViewRules.tasks(for: .done, in: tasks).count, id: "viewRow_done")
                    .tag(ViewSelection.system(.done))
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

    /// The date, then one sentence in serif. Tapping it opens "New" while anything waits there.
    @ViewBuilder
    private var header: some View {
        let review = ViewRules.tasks(for: .new, in: tasks).count
        let content = VStack(alignment: .leading, spacing: 6) {
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
            lead(review: review, next: ViewRules.tasks(for: .next, in: tasks).count)
                .font(.title2.weight(.medium))
                .fontDesign(.serif)
        }
        .padding(.vertical, 6)
        .listRowSeparator(.hidden)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("startHeader")
        .paperRow()
        if review > 0 {
            content.tag(ViewSelection.system(.new))
        } else {
            content
        }
    }

    /// The count to look over is accent-tinted: it is the tappable part (ADR-14).
    private func lead(review: Int, next: Int) -> Text {
        let reviewCount = Text(verbatim: "\(review)").foregroundStyle(.tint)
        switch (review, next) {
        case (0, 0): return Text("All tied up.")
        case (0, _): return Text("Nothing to look over, \(next) lined up.")
        case (_, 0): return Text("\(reviewCount) to look over, nothing lined up.")
        default: return Text("\(reviewCount) to look over, \(next) lined up.")
        }
    }

    /// The first three of "Next up" under a small caption; a tap opens the task. Empty: one line
    /// on how to fill it.
    @ViewBuilder
    private var nextUpPreview: some View {
        let next = ViewRules.tasks(for: .next, in: tasks)
        Text("Next up")
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden)
            .paperRow()
        Group {
            if next.isEmpty {
                Text("Swipe left on any task to line it up here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .paperRow()
            } else {
                ForEach(next.prefix(3)) { task in
                    TaskRow(task: task, identifierPrefix: "nextUpPreview_")
                        .tag(ViewSelection.task(task.id))
                        .paperRow()
                }
            }
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
            CatalogService.delete(context, in: modelContext)
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
