import OSLog
import SwiftData
import SwiftUI

/// Task detail (design briefing, screen 4): editable title, the raw text underneath, derived
/// fields as compact rows. Tapping a row opens its editor; a field the AI set is accent-tinted
/// with the spark and its editor also shows before, after, the reason and Reset. Opening the
/// detail marks the AI changes as seen.
struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Bindable var task: TaskItem
    /// Nil in previews and tests; the app passes its bridge for the access note.
    @Environment(CalendarBridge.self) private var calendar: CalendarBridge?

    @State private var titleDraft = ""
    @FocusState private var titleFocused: Bool
    @State private var showsRevisions = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var aiFields: [RevisedField] { RevisionService.aiSetFields(on: task) }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $titleDraft)
                    .font(.title3.weight(.semibold))
                    .focused($titleFocused)
                    .onSubmit(commitTitle)
                    .accessibilityIdentifier("detailTitleField")
                Text(task.rawText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("detailRawText")
            }

            Section {
                fieldRow(.dueDate, value: FieldFormatting.value(FieldCodec.encode(.dueDate, of: task), for: .dueDate, hasTime: task.dueHasTime))
                fieldRow(.importance, value: FieldFormatting.value(task.importanceRaw, for: .importance))
                fieldRow(.urgency, value: FieldFormatting.value(task.urgencyRaw, for: .urgency))
                fieldRow(.duration, value: FieldFormatting.value(task.durationRaw, for: .duration))
                fieldRow(.energy, value: FieldFormatting.value(task.energyRaw, for: .energy))
                fieldRow(.contexts, value: FieldFormatting.value(FieldCodec.encode(.contexts, of: task), for: .contexts))
                fieldRow(.people, value: FieldFormatting.value(FieldCodec.encode(.people, of: task), for: .people))
                fieldRow(.project, value: task.project?.name)
                fieldRow(.repeatRule, value: FieldFormatting.value(FieldCodec.encode(.repeatRule, of: task), for: .repeatRule))
                Toggle("Show in calendar", isOn: $task.showInCalendar)
                    .onChange(of: task.showInCalendar) { _, _ in save("calendar") }
                    .accessibilityIdentifier("showInCalendarToggle")
            } header: {
                Text("Details")
            } footer: {
                calendarNote
            }

            if task.parent == nil {
                SubtasksSection(task: task)
            }

            if !aiFields.isEmpty {
                Section {
                    HStack {
                        Text(aiFields.count == 1 ? String(localized: "One field set by AI") : String(localized: "\(aiFields.count) fields set by AI"))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Show") { showsRevisions = true }
                            .accessibilityIdentifier("revisionsButton")
                    }
                }
            }

            if let url = task.sourceURL {
                Section("Source") {
                    Link("Open the source", destination: url)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            titleDraft = task.title ?? ""
            markSeen()
        }
        .onChange(of: titleFocused) { _, focused in
            if !focused { commitTitle() }
        }
        .sheet(isPresented: $showsRevisions) {
            RevisionsSheet(task: task, contexts: contexts, projects: projects)
        }
    }

    /// Under the switch: why nothing shows yet (ADR-13). Silent while the switch is off.
    @ViewBuilder
    private var calendarNote: some View {
        if task.showInCalendar {
            if task.dueDate == nil {
                Text("Shows up once the task has a due date.")
            } else if calendar?.accessDenied == true {
                Text("Calendar access is off in Settings.")
            }
        }
    }

    /// Label left, value right. Empty fields stay empty (no placeholder nudging for input).
    @ViewBuilder
    private func fieldRow(_ field: RevisedField, value: String?) -> some View {
        let fromAI = aiFields.contains(field)
        let row = HStack {
            Text(FieldFormatting.label(field))
            Spacer()
            if let value {
                Text(value)
                    .foregroundStyle(fromAI ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            if fromAI {
                Image(systemName: "sparkle")
                    .imageScale(.small)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Set by AI")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("field_\(field.rawValue)")

        NavigationLink {
            FieldEditorView(task: task, field: field, contexts: contexts, projects: projects)
        } label: {
            row
        }
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (task.title ?? "") else { return }
        RevisionService.set(.title, to: trimmed.isEmpty ? nil : trimmed, on: task, contexts: contexts, projects: projects)
        if task.status == .unverified, !trimmed.isEmpty { task.status = .active }
        save("title")
    }

    private func markSeen() {
        guard RevisionService.markSeen(task) > 0 else { return }
        save("seen")
    }

    private func save(_ what: String) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving \(what, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}

/// Every change to this task, newest first (design briefing, screen 5).
struct RevisionsSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let task: TaskItem
    let contexts: [TaskContext]
    let projects: [Project]
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var revisions: [Revision] {
        (task.revisions ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            List(revisions) { revision in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(FieldFormatting.label(revision.field)).font(.headline)
                        Spacer()
                        Text(FieldFormatting.author(revision.author))
                            .font(.caption)
                            .foregroundStyle(revision.author == .ai ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }
                    Text("\(FieldFormatting.value(revision.oldValue, for: revision.field) ?? String(localized: "Empty")) → \(FieldFormatting.value(revision.newValue, for: revision.field) ?? String(localized: "Empty"))")
                    if let reason = revision.reason, !reason.isEmpty {
                        Text(reason).font(.footnote).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(revision.createdAt, format: .dateTime.day().month().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if revision.author == .ai {
                            Button("Reset") { revert(revision) }
                                .font(.caption)
                                .accessibilityIdentifier("resetRevision_\(revision.id.uuidString)")
                        }
                    }
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("revision_\(revision.id.uuidString)")
            }
            .navigationTitle("Changes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset all", action: revertAll)
                        .disabled(RevisionService.aiSetFields(on: task).isEmpty)
                        .accessibilityIdentifier("resetAllButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 360)
        #endif
    }

    private func revert(_ revision: Revision) {
        RevisionService.revert(revision, on: task, contexts: contexts, projects: projects)
        save()
    }

    private func revertAll() {
        RevisionService.revertAll(on: task, contexts: contexts, projects: projects)
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Reset failed: \(error, privacy: .public)")
        }
    }
}
