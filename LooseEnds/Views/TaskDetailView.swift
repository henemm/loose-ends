import OSLog
import SwiftData
import SwiftUI

/// Task detail (design briefing, screen 4): editable title, the raw text underneath while it says
/// more than the title, then the fields that are set; empty ones wait behind "Add detail" (#187).
/// Tapping a row opens its editor; a field a rule read from the raw text carries »«, one the AI
/// estimated the spark (#101), both accent-tinted, and its editor also shows before, after, the
/// reason and Reset. Opening the detail marks the AI changes
/// as seen. The bar carries Complete and the briefing's menu (Next up, Park, Analyze again).
struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CompletionPulse.self) private var completionPulse: CompletionPulse?
    @Environment(PendingCompletions.self) private var pendingCompletions: PendingCompletions?
    @Environment(\.dismiss) private var dismiss
    /// Every task, for the "Next up" rank.
    @Query private var allTasks: [TaskItem]
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Bindable var task: TaskItem
    /// Nil in previews and tests; the app passes its bridge for the access note.
    @Environment(CalendarBridge.self) private var calendar: CalendarBridge?
    /// Nil in previews; then "Analyze again" is not offered.
    @Environment(\.enrichment) private var enrichment: EnrichmentCoordinator?

    @State private var titleDraft = ""
    @FocusState private var titleFocused: Bool
    @State private var showsRevisions = false
    @State private var showsEmptyFields = false
    /// "Analyze again" (#34): running, or what it found, until the detail closes.
    @State private var reanalysis: Reanalysis?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var aiFields: [RevisedField] { RevisionService.automaticFields(on: task) }

    var body: some View {
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    // Serif is the content, SF is the app (#180, rule 2). Wraps instead of cutting the
                    // title off with "…" (#216); Return still ends the edit, as in the capture field.
                    TextField("Title", text: $titleDraft, axis: .vertical)
                        .font(.title3.weight(.semibold))
                        .fontDesign(.serif)
                        .lineLimit(1...4)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit(commitTitle)
                        .onChange(of: titleDraft) { _, newValue in endEditOnReturn(newValue) }
                        .accessibilityIdentifier("detailTitleField")
                    if aiFields.contains(.title) {
                        Button(action: resetTitle) {
                            Image(systemName: "arrow.uturn.backward")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Reset the title")
                        .accessibilityIdentifier("resetTitleButton")
                    }
                }
                // Invisible marker: the raw text identifies the open detail even when "You said:" is hidden (#202).
                .background {
                    Color.clear
                        .accessibilityElement()
                        .accessibilityLabel(task.rawText)
                        .accessibilityIdentifier("detailRawTextMarker")
                }
                if DetailLayout.showsRawText(task.rawText, title: task.title) {
                    // The raw text as a quote: what was said, in the words it was said (#180).
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("You said:")
                        Text(task.rawText)
                            .accessibilityIdentifier("detailRawText")
                    }
                    .font(.footnote)
                    .italic()
                    .fontDesign(.serif)
                    .foregroundStyle(.secondary)
                }
            }
            .paperRow()

            if let reanalysis {
                Section {
                    reanalysisNote(reanalysis)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("reanalysisNote")
                }
                .paperRow()
            }

            let layout = DetailLayout.split(fieldEntries)
            if !layout.set.isEmpty {
                Section {
                    ForEach(layout.set, id: \.field) { fieldRow($0.field, value: $0.value) }
                }
                .paperRow()
            }
            if !layout.empty.isEmpty {
                Section {
                    // Opens once and stays open while the detail is shown: a second tap never
                    // hides a row someone is about to reach.
                    if showsEmptyFields {
                        ForEach(layout.empty, id: \.field) { fieldRow($0.field, value: nil) }
                    } else {
                        Button("Add detail", systemImage: "plus") { showsEmptyFields = true }
                            .accessibilityIdentifier("addDetailRow")
                    }
                }
                .paperRow()
            }

            Section {
                // Stays visible without a due date: it can be switched on first (see the note).
                Toggle("Show in calendar", isOn: $task.showInCalendar)
                    .onChange(of: task.showInCalendar) { _, _ in save("calendar") }
                    .accessibilityIdentifier("showInCalendarToggle")
            } footer: {
                calendarNote
            }
            .paperRow()

            if task.parent == nil {
                SubtasksSection(task: task)
                    .paperRow()
            }

            if !aiFields.isEmpty {
                Section {
                    HStack {
                        Text(originSummary)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("originSummary")
                        Spacer()
                        Button("Show") { showsRevisions = true }
                            .accessibilityIdentifier("revisionsButton")
                    }
                }
                .paperRow()
            }

            if let url = task.sourceURL {
                Section("Source") {
                    Link("Open the source", destination: url)
                }
                .paperRow()
            }
        }
        .formStyle(.grouped)
        .paperGround()
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { actions }
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

    /// "2 from your words · 2 from AI" (#101); a part with nothing in it is left out.
    private var originSummary: String {
        let read = aiFields.filter { RevisionService.origin(of: $0, on: task) == .rule }.count
        let estimated = aiFields.count - read
        var parts: [String] = []
        if read > 0 { parts.append(String(localized: "\(read) from your words")) }
        if estimated > 0 { parts.append(String(localized: "\(estimated) from AI")) }
        return parts.joined(separator: " · ")
    }

    /// Every derived field in its fixed order, with its display value or nil.
    private var fieldEntries: [DetailLayout.Entry] {
        [
            .init(field: .dueDate, value: FieldFormatting.value(FieldCodec.encode(.dueDate, of: task), for: .dueDate, hasTime: task.dueHasTime)),
            .init(field: .importance, value: FieldFormatting.value(task.importanceRaw, for: .importance)),
            .init(field: .urgency, value: FieldFormatting.value(task.urgencyRaw, for: .urgency)),
            .init(field: .duration, value: FieldFormatting.value(task.durationRaw, for: .duration)),
            .init(field: .energy, value: FieldFormatting.value(task.energyRaw, for: .energy)),
            .init(field: .contexts, value: FieldFormatting.value(FieldCodec.encode(.contexts, of: task), for: .contexts)),
            .init(field: .people, value: FieldFormatting.value(FieldCodec.encode(.people, of: task), for: .people)),
            .init(field: .project, value: task.project?.name),
            .init(field: .repeatRule, value: FieldFormatting.value(FieldCodec.encode(.repeatRule, of: task), for: .repeatRule)),
        ]
    }

    /// Complete, and the briefing's "…" menu (screen 4). Completing leaves the detail.
    @ToolbarContentBuilder
    private var actions: some ToolbarContent {
        // Deleting stays in the list's long-press menu: deleting from inside the open detail would
        // leave the view on a destroyed model until it is gone.
        if task.isOpen {
            ToolbarItem(placement: .primaryAction) {
                Button("Complete", systemImage: "checkmark", action: complete)
                    .accessibilityIdentifier("detailCompleteButton")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    if task.nextRank == nil {
                        Button("Next up", systemImage: "star", action: toggleNext)
                    } else {
                        Button("Remove from Next up", systemImage: "star.slash", action: toggleNext)
                    }
                    Button("Park", systemImage: "pause") {
                        TaskActions.park(task)
                        save("park")
                    }
                    if enrichment != nil {
                        Button("Analyze again", systemImage: "sparkles", action: analyzeAgain)
                            .disabled(reanalysis == .running)
                            .accessibilityIdentifier("analyzeAgainButton")
                    }
                }
                .accessibilityIdentifier("detailMoreMenu")
            }
        }
    }

    private enum Reanalysis: Equatable {
        case running
        case done(EnrichmentCoordinator.ReanalysisResult)
    }

    /// The second analysis, only because the user asked (ADR-4, #34). Changed fields come back
    /// accent-tinted with the spark, like after the first run; the title field follows the task.
    private func analyzeAgain() {
        guard let enrichment else { return }
        reanalysis = .running
        Task {
            let result = await enrichment.reanalyze(task)
            titleDraft = task.title ?? ""
            reanalysis = .done(result)
        }
    }

    @ViewBuilder
    private func reanalysisNote(_ state: Reanalysis) -> some View {
        switch state {
        case .running:
            HStack(spacing: 8) {
                ProgressView()
                Text("Analyzing again…")
            }
        case .done(.busy):
            Text("Still sorting other tasks. Try again in a moment.")
        case .done(.failed):
            Text("Could not analyze again.")
        case .done(.finished(let changed, let modelRan)):
            VStack(alignment: .leading, spacing: 2) {
                switch changed {
                case 0: Text("Nothing new found.")
                case 1: Text("One field updated.")
                default: Text("\(changed) fields updated.")
                }
                if !modelRan {
                    Text("Apple Intelligence did not run, only the rules.")
                }
            }
        }
    }

    private func toggleNext() {
        TaskActions.toggleNext(task, among: allTasks)
        save("next")
    }

    /// Back to the list, where the row waits out its three seconds with Undo (#32). Without the
    /// window (previews) Done lands at once.
    private func complete() {
        if let pendingCompletions {
            pendingCompletions.schedule(task.id)
        } else {
            TaskActions.complete(task)
            save("done")
            completionPulse?.fire()
        }
        dismiss()
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
        let origin = aiFields.contains(field) ? RevisionService.origin(of: field, on: task) : nil
        let row = HStack {
            Text(FieldFormatting.label(field))
            Spacer()
            if let value {
                Text(value)
                    .foregroundStyle(origin != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            switch origin {
            case .rule:
                Text(verbatim: "»«")
                    .font(.footnote)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("From your words")
            case .ai:
                Image(systemName: "sparkle")
                    .imageScale(.small)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Estimated by AI")
            case .user, nil:
                EmptyView()
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

    /// A vertical text field turns Return into a line break instead of a submit. A title has no
    /// line breaks: they become spaces, and a trailing Return ends the edit, which commits (#216).
    private func endEditOnReturn(_ newValue: String) {
        guard newValue.contains("\n") else { return }
        let endedWithReturn = newValue.hasSuffix("\n")
        titleDraft = newValue.replacingOccurrences(of: "\n", with: " ")
        if endedWithReturn { titleFocused = false }
    }

    private func commitTitle() {
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (task.title ?? "") else { return }
        RevisionService.set(.title, to: trimmed.isEmpty ? nil : trimmed, on: task, contexts: contexts, projects: projects)
        if task.status == .unverified, !trimmed.isEmpty { task.status = .active }
        save("title")
    }

    /// One tap back to the value before the AI touched the title (Bug #125). `titleDraft` only
    /// follows `task.title` in `.onAppear`, so it is pulled along here.
    private func resetTitle() {
        guard let revision = RevisionService.firstAutomaticRevision(of: .title, on: task) else { return }
        RevisionService.revert(revision, on: task, contexts: contexts, projects: projects)
        titleDraft = task.title ?? ""
        save("title reset")
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
                            .foregroundStyle(revision.author.isAutomatic ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
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
                        if revision.author.isAutomatic {
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
                        .disabled(RevisionService.automaticFields(on: task).isEmpty)
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
