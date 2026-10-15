import OSLog
import SwiftData
import SwiftUI

/// Adding, renaming and deleting tags and projects (design briefing, screen 7). One editor for the
/// iPad and Mac sidebar and the iPhone pages (#428), so both ask and refuse alike.
@MainActor @Observable
final class CatalogEditor {
    var edit: NameEdit?
    var isEditing = false
    var editName = ""
    var pendingDelete: NameEdit.Target?
    var confirmingDelete = false
    var duplicateRejected = false

    func begin(_ edit: NameEdit) {
        editName = edit.currentName
        self.edit = edit
        isEditing = true
    }

    func askToDelete(_ target: NameEdit.Target) {
        pendingDelete = target
        confirmingDelete = true
    }
}

extension View {
    /// The name alert, the duplicate notice and the delete confirmation of `editor`. `willDelete`
    /// hears the selection that is about to go, so the caller can let go of it first.
    func catalogDialogs(
        _ editor: CatalogEditor,
        contexts: [TaskContext],
        projects: [Project],
        willDelete: @escaping (ViewSelection) -> Void = { _ in }
    ) -> some View {
        modifier(CatalogDialogs(editor: editor, contexts: contexts, projects: projects, willDelete: willDelete))
    }

    /// Rename and Delete, for a row's long-press menu.
    func catalogMenu(_ target: NameEdit.Target, in editor: CatalogEditor) -> some View {
        contextMenu {
            Button("Rename", systemImage: "pencil") { editor.begin(NameEdit(target: target)) }
            CatalogDeleteButton(target: target, editor: editor)
        }
    }
}

/// Asks before deleting; the dialog does the deleting.
struct CatalogDeleteButton: View {
    let target: NameEdit.Target
    let editor: CatalogEditor

    var body: some View {
        Button("Delete", systemImage: "trash", role: .destructive) { editor.askToDelete(target) }
    }
}

private struct CatalogDialogs: ViewModifier {
    @Bindable var editor: CatalogEditor
    let contexts: [TaskContext]
    let projects: [Project]
    let willDelete: (ViewSelection) -> Void
    @Environment(\.modelContext) private var modelContext
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Catalog")

    func body(content: Content) -> some View {
        content
            .alert(Text(editor.edit?.title ?? ""), isPresented: $editor.isEditing, presenting: editor.edit) { edit in
                TextField("Name", text: $editor.editName)
                    .accessibilityIdentifier("nameField")
                Button(edit.isNew ? "Add" : "Save") { commit(edit) }
                    .accessibilityIdentifier("nameSaveButton")
                Button("Cancel", role: .cancel) {}
            }
            .alert("A tag with this name already exists.", isPresented: $editor.duplicateRejected) {
                Button("OK", role: .cancel) {}
                    .accessibilityIdentifier("duplicateNameOKButton")
            }
            .confirmationDialog(Text(editor.pendingDelete?.deleteTitle ?? ""), isPresented: $editor.confirmingDelete,
                                titleVisibility: .visible, presenting: editor.pendingDelete) { target in
                Button("Delete", role: .destructive) { delete(target) }
                    .accessibilityIdentifier("confirmDeleteButton")
            } message: { target in
                Text(target.deleteMessage)
            }
    }

    /// A blank name is a cancel, not an error worth showing. A taken context name is (#157).
    private func commit(_ edit: NameEdit) {
        do {
            switch edit.target {
            case .newProject:
                try CatalogService.addProject(named: editor.editName, in: modelContext, existing: projects)
            case .newContext:
                try CatalogService.addContext(named: editor.editName, in: modelContext, existing: contexts)
            case .project(let project):
                try CatalogService.rename(project, to: editor.editName)
            case .context(let context):
                try CatalogService.rename(context, to: editor.editName, among: contexts)
            }
            try modelContext.save()
        } catch CatalogError.emptyName {
            return
        } catch CatalogError.duplicateName {
            editor.duplicateRejected = true
        } catch {
            Self.logger.error("Saving the name failed: \(error, privacy: .public)")
        }
    }

    private func delete(_ target: NameEdit.Target) {
        switch target {
        case .project(let project):
            willDelete(.project(project.id))
            CatalogService.delete(project, in: modelContext)
        case .context(let context):
            willDelete(.context(context.id))
            CatalogService.delete(context, in: modelContext, among: contexts)
        case .newProject, .newContext:
            return
        }
        editor.pendingDelete = nil
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
            case .context: String(localized: "Delete this tag?")
            case .newProject, .newContext: ""
            }
        }

        var deleteMessage: String {
            switch self {
            case .project: String(localized: "Its tasks stay and lose the project.")
            case .context: String(localized: "Its tasks stay and lose the tag.")
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
        case .newContext: String(localized: "New tag")
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
