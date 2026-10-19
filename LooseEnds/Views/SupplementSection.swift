import OSLog
import SwiftData
import SwiftUI

/// "Add" at the end of the detail (#441): a sentence about the task, typed or dictated, read by the
/// rules while it is written. Below it what was read; "Apply" writes it as user revisions. Words no
/// rule read stay in the field, so nothing is lost and nothing guessed. The raw text stays as said.
struct SupplementSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    let task: TaskItem
    /// A switch takes a field out of the reading too (#538, rule 5); due is fixed.
    @Environment(FieldSettingsStore.self) private var fieldSettings: FieldSettingsStore?

    @State private var text = ""
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var read: Supplement {
        Supplement.read(text, available: contexts.map(\.name), current: (task.contexts ?? []).map(\.name))
            .offered(by: fieldSettings?.settings ?? .standard)
    }

    var body: some View {
        let read = read
        Section {
            TextField("Friday, one hour, call first", text: $text, axis: .vertical)
                .font(.system(.body, design: .serif))
                .lineLimit(1...4)
                .accessibilityIdentifier("supplementField")
            if !read.isEmpty {
                ForEach(lines(of: read), id: \.label) { line in
                    LabeledContent {
                        Text(line.value).font(.system(.body, design: .serif))
                    } label: {
                        Text(line.label).font(.footnote).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("supplementRead_\(line.field.rawValue)")
                }
                if !read.rest.isEmpty {
                    Text("Not read: \(read.rest)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("supplementRest")
                }
                Button("Apply") { apply(read) }
                    .accessibilityIdentifier("supplementApply")
            }
        } header: {
            Text("Add more").captionHead()
        }
    }

    private struct Line {
        var field: RevisedField
        var label: String
        var value: String
    }

    /// One line per field the sentence sets, in the order of the detail's fields.
    private func lines(of read: Supplement) -> [Line] {
        var lines: [Line] = []
        if let due = read.due {
            lines.append(Line(field: .dueDate, label: FieldFormatting.label(.dueDate),
                              value: FieldFormatting.dueWords(due.guess.value, hasTime: due.hasTime)))
        }
        if let duration = read.duration {
            lines.append(Line(field: .duration, label: FieldFormatting.label(.duration),
                              value: FieldFormatting.duration(duration)))
        }
        if let importance = read.importance, let value = FieldFormatting.level(importance.rawValue) {
            lines.append(Line(field: .importance, label: FieldFormatting.label(.importance), value: value))
        }
        if let urgency = read.urgency, let value = FieldFormatting.level(urgency.rawValue) {
            lines.append(Line(field: .urgency, label: FieldFormatting.label(.urgency), value: value))
        }
        if !read.contexts.isEmpty {
            lines.append(Line(field: .contexts, label: FieldFormatting.label(.contexts),
                              value: read.contexts.formatted(.list(type: .and))))
        }
        return lines
    }

    /// Writes what was read; the unread words stay in the field for the user to keep or delete.
    private func apply(_ read: Supplement) {
        read.apply(to: task, contexts: contexts, projects: projects)
        text = read.rest
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving the supplement failed: \(error, privacy: .public)")
        }
    }
}
