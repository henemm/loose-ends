import OSLog
import SwiftData
import SwiftUI

/// The start screen (design briefing, screen 2): system views with counts, then projects,
/// then contexts, Done last. Projects and contexts are created, renamed and deleted right here
/// (screen 7). Tile styling waits for the design freeze; the structure is final.
struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Binding var selection: ViewSelection?
    let tasks: [TaskItem]

    @State private var edit: NameEdit?
    @State private var isEditing = false
    @State private var editName = ""
    @State private var pendingDelete: NameEdit.Target?
    @State private var confirmingDelete = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Sidebar")

    private static let systemKinds: [ViewKind] = [.next, .new, .due, .quick, .old, .waiting, .repeating, .parked]

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(Self.systemKinds, id: \.self) { kind in
                    countRow(String(localized: kind.titleKey), count: ViewRules.tasks(for: kind, in: tasks).count, id: "viewRow_\(kind.rawValue)")
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
            }

            Section {
                countRow(String(localized: ViewKind.done.titleKey), count: ViewRules.tasks(for: .done, in: tasks).count, id: "viewRow_done")
                    .tag(ViewSelection.system(.done))
            }
        }
        .alert(Text(edit?.title ?? ""), isPresented: $isEditing, presenting: edit) { edit in
            TextField("Name", text: $editName)
                .accessibilityIdentifier("nameField")
            Button(edit.isNew ? "Add" : "Save") { commit(edit) }
                .accessibilityIdentifier("nameSaveButton")
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(Text(pendingDelete?.deleteTitle ?? ""), isPresented: $confirmingDelete, titleVisibility: .visible, presenting: pendingDelete) { target in
            Button("Delete", role: .destructive) { delete(target) }
                .accessibilityIdentifier("confirmDeleteButton")
        } message: { target in
            Text(target.deleteMessage)
        }
    }

    private func countRow(_ title: String, count: Int, id: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
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

    /// A blank name is a cancel, not an error worth showing.
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
                try CatalogService.rename(context, to: editName)
            }
            try modelContext.save()
        } catch CatalogError.emptyName {
            return
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
