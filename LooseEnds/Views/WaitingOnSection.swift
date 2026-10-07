import OSLog
import SwiftData
import SwiftUI

/// "Waiting on" in the detail (#251, design decision on #27): a reference to another full task,
/// drawn so it can never pass for a subtask — an outlined card without a circle, the other task's
/// trait line, an arrow at the end, a lock at the header while anything is still open. Tapping the
/// card opens the other task; "Done" in words completes it; swiping "Loosen" drops only the link.
struct WaitingOnSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CompletionPulse.self) private var completionPulse: CompletionPulse?
    /// Every task, for the picker.
    @Query private var allTasks: [TaskItem]
    let task: TaskItem

    @State private var picking = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    var body: some View {
        Section {
            ForEach(WaitingOn.blockers(of: task)) { blocker in
                NavigationLink {
                    TaskDetailView(task: blocker)
                } label: {
                    WaitingOnCard(blocker: blocker) { complete(blocker) }
                }
                .swipeActions(edge: .trailing) {
                    Button("Loosen", systemImage: "link") { loosen(blocker) }
                        .tint(.gray)
                        .accessibilityIdentifier("loosenBlocker_\(blocker.id.uuidString)")
                }
                .accessibilityIdentifier("blockerCard_\(blocker.id.uuidString)")
            }
            Button("Choose a task", systemImage: "plus") { picking = true }
                .accessibilityIdentifier("chooseBlockerButton")
        } header: {
            HStack(spacing: 4) {
                if task.isBlocked {
                    Image(systemName: "lock")
                        .accessibilityLabel("Blocked")
                }
                Text("Waiting on")
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("waitingOnHeader")
        }
        .sheet(isPresented: $picking) {
            WaitingOnPicker(task: task, allTasks: allTasks) { blocker in
                WaitingOn.link(blocker, to: task)
                save("link blocker")
            }
        }
    }

    private func complete(_ blocker: TaskItem) {
        TaskActions.complete(blocker)
        save("complete blocker")
        completionPulse?.fire()
    }

    private func loosen(_ blocker: TaskItem) {
        WaitingOn.loosen(blocker, from: task)
        save("loosen blocker")
    }

    private func save(_ what: String) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving \(what, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}

/// The card for one task this one waits on. Open: title, trait line, "Done" in words. Done: grey
/// with a check mark — never a circle to tick, that is the subtask's sign.
private struct WaitingOnCard: View {
    let blocker: TaskItem
    let complete: () -> Void

    var body: some View {
        let open = blocker.isOpen
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(blocker.displayTitle)
                    .fontDesign(.serif)
                    .strikethrough(!open)
                    .foregroundStyle(open ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                    .lineLimit(2)
                Text(WaitingOnTraits.line(for: blocker))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if open {
                Button("Complete", action: complete)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("completeBlocker_\(blocker.id.uuidString)")
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Completed")
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator, lineWidth: 1)
        }
    }
}

/// "Choose a task": open tasks with a search, newest first; one tap links it and closes the sheet.
private struct WaitingOnPicker: View {
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    let allTasks: [TaskItem]
    let choose: (TaskItem) -> Void

    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(WaitingOn.candidates(for: task, among: allTasks, matching: query)) { candidate in
                Button {
                    choose(candidate)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(candidate.displayTitle)
                            .fontDesign(.serif)
                            .foregroundStyle(.primary)
                        Text(WaitingOnTraits.line(for: candidate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("blockerCandidate_\(candidate.id.uuidString)")
            }
            .overlay {
                if WaitingOn.candidates(for: task, among: allTasks, matching: query).isEmpty {
                    ContentUnavailableView("No open task to choose", systemImage: "tray")
                }
            }
            .searchable(text: $query)
            .navigationTitle("Choose a task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 360)
        #endif
    }
}

/// The other task's trait line on its card: "Own task · 9 Oct · Phone" (#27).
enum WaitingOnTraits {
    static func line(for task: TaskItem) -> String {
        var parts = [String(localized: "Own task")]
        if let due = task.dueDate {
            parts.append(due.formatted(.dateTime.day().month(.abbreviated)))
        }
        if let context = (task.contexts ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).first {
            parts.append(context.name)
        }
        return parts.joined(separator: " · ")
    }
}
