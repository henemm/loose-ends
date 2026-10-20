import OSLog
import SwiftData
import SwiftUI

/// The "Subtasks" area of the detail (design briefing, screen 4): one level, each line checkable,
/// a text field adds the next one. Only a top-level task has it (ADR-8). A line is a full task when
/// needed (#565, concept D): "Details" opens its own detail, and what it carries of its own stands
/// grey under its words.
struct SubtasksSection: View {
    @Environment(\.modelContext) private var modelContext
    let task: TaskItem
    /// Opened from the word line (#538): the field takes the focus at once.
    var startsEditing = false
    /// Opens a line's own detail (#565); the detail owns the navigation.
    var open: (TaskItem) -> Void = { _ in }

    @State private var draft = ""
    @FocusState private var draftFocused: Bool
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var lines: [TaskItem] { Subtasks.ordered(of: task) }
    private var progress: Subtasks.Progress { Subtasks.progress(of: task) }
    private var draftIsEmpty: Bool { draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Section {
            ForEach(lines) { line in
                HStack(spacing: 8) {
                    Button {
                        toggle(line)
                    } label: {
                        row(line)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(line.status == .done ? Text("Completed") : Text("Open"))
                    .accessibilityIdentifier("subtaskRow_\(line.id.uuidString)")
                    Button {
                        open(line)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Details")
                    .accessibilityIdentifier("subtaskDetails_\(line.id.uuidString)")
                }
            }
            .onDelete(perform: delete)

            HStack {
                TextField("Add a subtask", text: $draft)
                    .focused($draftFocused)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityIdentifier("subtaskTextField")
                // Only with text (#565): a grey "Add" before the first word read as dead on the Mac.
                if !draftIsEmpty {
                    Button("Add", action: add)
                        .accessibilityIdentifier("subtaskAddButton")
                }
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
            VStack(alignment: .leading, spacing: 2) {
                Text(line.displayTitle)
                    .fontDesign(.serif)
                    .strikethrough(done)
                    .foregroundStyle(done ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                if !done {
                    traits(of: line)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// What the line carries of its own (#565): the time that counts as in the lists, red only under
    /// time pressure, then its tags. Nothing while it carries nothing.
    @ViewBuilder
    private func traits(of line: TaskItem) -> some View {
        let mark = ViewRules.marginMark(of: line)
        let tags = (line.contexts ?? []).map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        if !mark.text.isEmpty || !tags.isEmpty {
            HStack(spacing: 6) {
                if !mark.text.isEmpty {
                    Text(mark.text)
                        .foregroundStyle(mark.pressing ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                }
                if !tags.isEmpty {
                    Text(tags.joined(separator: ", "))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .accessibilityIdentifier("subtaskTraits_\(line.id.uuidString)")
        }
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
