import OSLog
import SwiftData
import SwiftUI

/// The "Subtasks" area of the detail (design briefing, screen 4): one level, each line checkable,
/// a text field adds the next one. Only a top-level task has it (ADR-8). A line becomes a task when
/// needed (#565, concept D): "Details" at its end opens its own detail, and what it carries of its
/// own stands grey under its words. Its words are read by the due date and tag word rules alone.
struct SubtasksSection: View {
    @Environment(\.modelContext) private var modelContext
    /// Runs the line's two rules right after it is added (#565); nil in previews.
    @Environment(\.enrichment) private var enrichment: EnrichmentCoordinator?
    let task: TaskItem
    /// Opened from the word line (#538): the field takes the focus at once.
    var startsEditing = false
    /// Opens a line's own detail in the same navigation (#565).
    let open: (TaskItem) -> Void

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
                    // A tap on the words still checks off: quick outlining stays as it was.
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
                // Only with text (#565): a grey button before any input read as dead on the Mac.
                // Return adds as well and keeps the focus for the next line.
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
                let traits = Subtasks.traits(of: line)
                if !traits.isEmpty {
                    traitLine(traits)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Grey, the due date as in the lists' margin: red only for time pressure (ADR-14).
    private func traitLine(_ traits: [Subtasks.Trait]) -> Text {
        traits.enumerated().reduce(Text(verbatim: "")) { line, item in
            let separator = item.offset == 0 ? Text(verbatim: "") : Text(verbatim: " · ").foregroundStyle(.secondary)
            return line + separator + traitText(item.element)
        }
    }

    private func traitText(_ trait: Subtasks.Trait) -> Text {
        switch trait {
        case .due(let mark): Text(mark.text).foregroundStyle(mark.pressing ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        case .tag(let name), .place(let name): Text(name).foregroundStyle(.secondary)
        case .duration(let bucket): Text(bucket.shortText).foregroundStyle(.secondary)
        case .note: Text("Note").foregroundStyle(.secondary)
        }
    }

    private func add() {
        guard !draftIsEmpty else { return }
        do {
            try Subtasks.add(draft, to: task, in: modelContext)
            draft = ""
            draftFocused = true
            save("add subtask")
            // Due date and tag word by rule, never the model (#565): the line shows them at once.
            if let enrichment { Task { await enrichment.processPending() } }
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
