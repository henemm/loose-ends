import OSLog
import SwiftData
import SwiftUI

/// The "Subtasks" area of the detail (design briefing, screen 4): one level, each line checkable,
/// a text field adds the next one. Only a top-level task has it (ADR-8).
struct SubtasksSection: View {
    @Environment(\.modelContext) private var modelContext
    let task: TaskItem
    /// Opened from the word line (#538): the field takes the focus at once.
    var startsEditing = false

    @State private var draft = ""
    @FocusState private var draftFocused: Bool
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var lines: [TaskItem] { Subtasks.ordered(of: task) }
    private var progress: Subtasks.Progress { Subtasks.progress(of: task) }
    private var draftIsEmpty: Bool { draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Section {
            ForEach(lines) { line in
                Button {
                    toggle(line)
                } label: {
                    row(line)
                }
                .buttonStyle(.plain)
                .accessibilityValue(line.status == .done ? Text("Completed") : Text("Open"))
                .accessibilityIdentifier("subtaskRow_\(line.id.uuidString)")
            }
            .onDelete(perform: delete)

            HStack {
                TextField("Add a subtask", text: $draft)
                    .focused($draftFocused)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityIdentifier("subtaskTextField")
                Button("Add", action: add)
                    .disabled(draftIsEmpty)
                    .accessibilityIdentifier("subtaskAddButton")
            }
        } header: {
            Text("Subtasks").captionHead()
        } footer: {
            if progress.total > 0 {
                Text("\(progress.done) of \(progress.total) done")
                    .accessibilityIdentifier("subtaskProgress")
            }
        }
        .onAppear {
            if startsEditing, lines.isEmpty { draftFocused = true }
        }
    }

    private func row(_ line: TaskItem) -> some View {
        let done = line.status == .done
        return HStack(spacing: 10) {
            // No circle (#424): an open subtask is just its words, a done one gets a fine grey check.
            Image(systemName: "checkmark")
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .opacity(done ? 1 : 0)
                .accessibilityHidden(true)
            Text(line.displayTitle)
                .fontDesign(.serif)
                .strikethrough(done)
                .foregroundStyle(done ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func add() {
        guard !draftIsEmpty else { return }
        do {
            try Subtasks.add(draft, to: task, in: modelContext)
            draft = ""
            draftFocused = true
            save("add subtask")
        } catch {
            Self.logger.error("Adding a subtask failed: \(error, privacy: .public)")
        }
    }

    private func toggle(_ line: TaskItem) {
        Subtasks.toggle(line)
        save("toggle subtask")
    }

    private func delete(at offsets: IndexSet) {
        let current = lines
        for index in offsets where current.indices.contains(index) {
            modelContext.delete(current[index])
        }
        save("delete subtask")
    }

    private func save(_ what: String) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving \(what, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}
