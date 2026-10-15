import OSLog
import SwiftData
import SwiftUI

/// The note of the detail (#439): a long text in New York. At rest, phone numbers, links, mail and
/// street addresses are links (`NoteLinks`); the pencil, or an empty note, opens the field. Leaving
/// the field writes the note as a user revision.
struct NoteSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    let task: TaskItem

    @State private var draft = ""
    @State private var editing = false
    @FocusState private var focused: Bool
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    var body: some View {
        Section {
            if editing || (task.notes ?? "").isEmpty {
                TextField("Numbers, addresses, anything else", text: $draft, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .lineLimit(2...12)
                    .focused($focused)
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { commit() }
                    }
                    .accessibilityIdentifier("noteField")
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(NoteLinks.attributed(task.notes ?? ""))
                        .font(.system(.body, design: .serif))
                        .tint(.accentColor)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("noteText")
                    Button("Edit note", systemImage: "pencil") {
                        draft = task.notes ?? ""
                        editing = true
                        focused = true
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .accessibilityIdentifier("editNoteButton")
                }
            }
        } header: {
            Text("Note").captionHead()
        }
        .onAppear { draft = task.notes ?? "" }
    }

    /// Trimmed; empty clears the note. Unchanged writes nothing (`RevisionService.set`).
    private func commit() {
        editing = false
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let written = RevisionService.set(.notes, to: trimmed.isEmpty ? nil : trimmed, on: task,
                                          contexts: contexts, projects: projects)
        guard written != nil else { return }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving the note failed: \(error, privacy: .public)")
        }
    }
}
