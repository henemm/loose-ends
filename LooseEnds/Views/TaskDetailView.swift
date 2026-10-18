import OSLog
import SwiftData
import SwiftUI

/// Task detail (design briefing, screen 4): editable title, the raw text underneath while it says
/// more than the title, then the fields that are set; empty ones follow as a line of words (#440, before: "Add detail", #187).
/// Tapping a row opens its editor; a field a rule read from the raw text carries the quote mark, one the AI
/// estimated the spark (#101), both accent-tinted, and its editor also shows before, after, the
/// reason and Reset. Opening the detail marks the AI changes as seen, except from "New" (#349):
/// there a line under the title says why the task waits, and "Looks right" takes the place of
/// Complete, which moves into the menu. Opened elsewhere, the bar carries Complete, "Looks right"
/// while the task still needs a look (#318), and the briefing's menu (Next up, Park, Analyze again).
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
    /// Opened from "New" (#349): opening confirms nothing, "Looks right" does.
    var reviewing = false
    /// Nil in previews and tests; the app passes its bridge for the access note.
    @Environment(CalendarBridge.self) private var calendar: CalendarBridge?
    /// Nil in previews; then "Analyze again" is not offered.
    @Environment(\.enrichment) private var enrichment: EnrichmentCoordinator?

    /// The title as on the start screen (#438): New York medium, a little smaller than the headline.
    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = DetailLayout.titleSize(wide: false)
    /// The same, larger in a wide window and on the Mac (#477).
    @ScaledMetric(relativeTo: .title2) private var wideTitleSize: CGFloat = DetailLayout.titleSize(wide: true)
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    /// The field names' column (#438), so every value starts at the same edge.
    @ScaledMetric(relativeTo: .footnote) private var labelWidth: CGFloat = 92
    /// The field whose editor is open; a button row instead of a link, so no chevron (#438).
    @State private var editingField: RevisedField?
    @State private var titleDraft = ""
    @FocusState private var titleFocused: Bool
    @State private var showsRevisions = false
    /// Owned here, not by `PlaceSection`: a sheet on a section inside the list did not present (#241).
    @State private var searchesPlace = false
    /// "Add to calendar" (#203): what the sheet still asks, nil while closed.
    @State private var calendarGaps: CalendarAsk.Gaps?
    /// The calendar picker (#203 Teil C) is open.
    @State private var choosesCalendar = false
    /// "Analyze again" (#34): running, or what it found, until the detail closes.
    @State private var reanalysis: Reanalysis?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var aiFields: [RevisedField] { RevisionService.automaticFields(on: task) }
    private var inReview: Bool { reviewing && ViewRules.isInNew(task) }
    /// A wide window or the Mac (#477): the detail as a centered column with the larger title.
    /// Split View and Slide Over are compact and keep the iPhone's detail.
    private var isWide: Bool {
        #if os(iOS)
        sizeClass != .compact
        #else
        true
        #endif
    }

    /// The detail's sections, the same in the form and in the list (#477).
    private var sections: some View {
        Group {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    // Serif is the content, SF is the app (#180, rule 2). Wraps instead of cutting the
                    // title off with "…" (#216); Return still ends the edit, as in the capture field.
                    TextField("Title", text: $titleDraft, axis: .vertical)
                        .font(.system(size: isWide ? wideTitleSize : titleSize, weight: .medium, design: .serif))
                        .tracking(-0.2)
                        .lineLimit(1...4)
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit(commitTitle)
                        .onChange(of: titleDraft) { _, newValue in endEditOnReturn(newValue) }
                        .accessibilityIdentifier("detailTitleField")
                        #if os(macOS)
                        // No "Title" column before the title on the Mac (#477); the label stays for VoiceOver.
                        .labelsHidden()
                        #endif
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
                    // The raw text as a quote: what was said, in the words it was said (#180). One
                    // running sentence behind a small head, so a second line starts at the edge (#438).
                    (Text(String(localized: "Said").uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1)
                     + Text(verbatim: "  ")
                     + Text(task.rawText)
                        .font(.system(.subheadline, design: .serif))
                        .italic())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(task.rawText)
                        .accessibilityIdentifier("detailRawText")
                }
            }
            .detailRow()

            if inReview {
                Section {
                    ReviewNote(task: task, automaticFields: aiFields.count)
                }
                .listRowBackground(Color.accentColor.opacity(0.08))
            }

            if let reanalysis {
                Section {
                    reanalysisNote(reanalysis)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("reanalysisNote")
                }
                .detailRow()
            }

            let layout = DetailLayout.split(fieldEntries)
            if !layout.set.isEmpty {
                Section {
                    ForEach(layout.set, id: \.field) { fieldRow($0.field, value: $0.value) }
                }
                .detailRow()
            }
            if !layout.empty.isEmpty {
                Section {
                    // The empty fields as a line of words (#440): one tap opens the editor, no list
                    // to unfold first. Accent, since each word is a button (ADR-14).
                    FlowLayout(spacing: 14) {
                        ForEach(layout.empty, id: \.field) { entry in
                            Button { editingField = entry.field } label: {
                                Label(FieldFormatting.label(entry.field), systemImage: "plus")
                                    .labelStyle(AddWordLabelStyle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                            .accessibilityIdentifier("field_\(entry.field.rawValue)")
                            .editorPopover(entry.field, editing: $editingField) { editor(for: entry.field) }
                        }
                    }
                    .padding(.vertical, 4)
                    // Each word stays its own element with its own `field_…` identifier: an identifier on
                    // the line would overwrite theirs.
                    .accessibilityElement(children: .contain)
                }
                .detailRow()
            }

            // Numbers, addresses, links beside the title (#439).
            NoteSection(task: task)
                .detailRow()

            // Photos and files on the task (#442).
            AttachmentsSection(task: task)
                .detailRow()

            Section {
                // Stays visible without a due date: it can be switched on first (see the note).
                // Switching on asks for what the event still lacks (#203): the switch stays off until the
                // sheet is answered, and Cancel leaves it off.
                Toggle("Show in calendar", isOn: Binding(
                    get: { task.showInCalendar },
                    set: { on in
                        if on, let gaps = CalendarAsk.gaps(for: task) {
                            calendarGaps = gaps
                        } else if on {
                            CalendarSync.switchOn(task, deviceDefault: calendar?.defaultForNewEvents)
                            save("calendar")
                        } else {
                            task.showInCalendar = false
                            save("calendar")
                        }
                    }
                ))
                .accessibilityIdentifier("showInCalendarToggle")
                if task.showInCalendar, let plan = CalendarSync.plan(for: task) {
                    HStack {
                        Text("Appointment")
                        Spacer()
                        Text(CalendarSync.appointment(plan))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("calendarAppointmentRow")
                }
                if task.showInCalendar, task.dueDate != nil, let calendar, calendar.appCalendarID != nil {
                    // Tapping picks the task's own calendar (#203 Teil C). A choice this device does not
                    // have shows by name, without a color.
                    let target = calendar.target(for: task)
                    Button { choosesCalendar = true } label: {
                        HStack {
                            Text("Calendar").foregroundStyle(.primary)
                            Spacer()
                            if let target {
                                Image(systemName: "circle.fill")
                                    .imageScale(.small)
                                    .foregroundStyle(Color(cgColor: target.color))
                                    .accessibilityHidden(true)
                            }
                            Text(target?.title ?? task.calendarName ?? "")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.forward")
                                .imageScale(.small)
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("calendarTargetRow")
                }
            } footer: {
                calendarNote
            }
            .detailRow()

            PlaceSection(task: task, searching: $searchesPlace)
                .detailRow()

            if task.parent == nil {
                SubtasksSection(task: task)
                    .detailRow()
                WaitingOnSection(task: task)
                    .detailRow()
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
                .detailRow()
            }

            if let url = task.sourceURL {
                Section {
                    Link("Open the source", destination: url)
                } header: {
                    Text("Source").captionHead()
                }
                .detailRow()
            }

            // A sentence about the task, read by the rules (#441).
            SupplementSection(task: task)
                .detailRow()
        }
    }

    /// Compact: the grouped form as on the iPhone, unchanged. Wide and Mac (#477): a plain list, so the
    /// sections are lines on paper with hairlines like the lists of Schnitt 1, not cards.
    @ViewBuilder
    private var container: some View {
        if isWide {
            List { sections }
                .listStyle(.plain)
                #if os(macOS)
                // Outside a form the Mac draws a bezel around text fields and a checkbox for a toggle.
                .textFieldStyle(.plain)
                .toggleStyle(.switch)
                #endif
                .paperGround()
                .detailColumn(wide: true)
        } else {
            Form { sections }
                .formStyle(.grouped)
                .paperGround()
                .detailColumn(wide: false)
        }
    }

    var body: some View {
        container
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        // No 35 pt of air between the said sentence and the fields (#438).
        .listSectionSpacing(.compact)
        #endif
        #if os(iOS)
        .navigationDestination(item: $editingField) { field in
            FieldEditorView(task: task, field: field, contexts: contexts, projects: projects)
        }
        #endif
        .toolbar { actions }
        .onAppear {
            titleDraft = task.title ?? ""
            if !reviewing { markSeen() }
        }
        .onChange(of: titleFocused) { _, focused in
            if !focused { commitTitle() }
        }
        .sheet(isPresented: $showsRevisions) {
            RevisionsSheet(task: task, contexts: contexts, projects: projects)
        }
        .sheet(isPresented: $searchesPlace) {
            PlaceSearchSheet { hit in
                guard let place = hit.place(task.place?.event ?? .arrive) else { return }
                PlaceEditing.set(place, on: task)
                save("place")
            }
        }
        .sheet(item: $calendarGaps) { gaps in
            CalendarAskSheet(gaps: gaps, existingStart: task.dueHasTime ? task.dueDate : nil) { answer in
                CalendarAsk.apply(answer, gaps: gaps, to: task, contexts: contexts, projects: projects,
                                  deviceDefault: calendar?.defaultForNewEvents)
                save("calendar")
            }
        }
        .sheet(isPresented: $choosesCalendar) {
            if let calendar {
                CalendarPickerSheet(calendars: calendar.calendars, defaultID: calendar.appCalendarID,
                                    selectedID: calendar.target(for: task)?.id) { picked in
                    CalendarSync.choose(picked, for: task)
                    save("calendar")
                }
            }
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
            .init(field: .project, value: task.project?.name),
            .init(field: .repeatRule, value: FieldFormatting.value(FieldCodec.encode(.repeatRule, of: task), for: .repeatRule)),
        ]
    }

    /// The briefing's "…" menu (screen 4) with Complete first; completing leaves the detail. No
    /// checkmark in the bar: it reads as "close" (#349 for New, #435 everywhere). From "New" the
    /// bar holds "Looks right".
    @ToolbarContentBuilder
    private var actions: some ToolbarContent {
        // Deleting stays in the list's long-press menu: deleting from inside the open detail would
        // leave the view on a destroyed model until it is gone.
        if task.isOpen {
            if inReview {
                if ViewRules.canConfirm(task) {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Looks right", action: confirmReview)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("detailConfirmButton")
                    }
                }
            } else {
                // Still in New after opening ("Needs a look": title not checked, not sorted yet): one
                // tap vouches for it, without editing the title first (#318). The word, not a sign:
                // a bare eye in the bar said nothing (Henning, 2026-10-16, build 76).
                if ViewRules.needsLook(task), task.title != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Looks right") {
                            TaskActions.confirmReview(task)
                            save("confirm")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("detailConfirmButton")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    // No checkmark in the bar (Henning, 2026-10-15): anyone taps it to close the
                    // detail and completes the task by accident. Complete lives here, first, by name.
                    Button("Complete", systemImage: "checkmark.circle", action: complete)
                        .accessibilityIdentifier("menuCompleteButton")
                    if task.nextRank == nil {
                        Button("Next up", systemImage: "star", action: toggleNext)
                    } else {
                        Button("Remove from Next up", systemImage: "star.slash", action: toggleNext)
                    }
                    Button("Park", systemImage: "moon.zzz") {
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

    /// The nod (#349): the task leaves "New", and the detail returns to it for the next one.
    private func confirmReview() {
        TaskActions.confirmReview(task)
        save("confirm")
        dismiss()
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

    /// Under the switch: why nothing shows (ADR-13, #203). Silent while the switch is off or the
    /// last sync went through.
    @ViewBuilder
    private var calendarNote: some View {
        switch CalendarSync.note(for: task, problem: calendar?.problem, missing: calendar?.isMissing(task) ?? false) {
        case .needsDueDate: Text("Shows up once the task has a due date.")
        case .accessOff: Text("Calendar access is off in Settings.")
        case .noWritableSource: Text("Couldn't create the Loose Ends calendar in any of your accounts.")
        case .syncFailed: Text("The calendar couldn't be updated.")
        case .calendarMissing(let name): Text("The calendar “\(name)” isn't on this device.")
        case nil: EmptyView()
        }
    }

    /// A register line (#438): the name small and grey in a fixed column, the value in New York after
    /// it (the value is content, #180 rule 2), no chevron; the whole line opens the editor. Empty
    /// fields stay empty (no placeholder nudging for input). Red only for time pressure (ADR-14).
    @ViewBuilder
    private func fieldRow(_ field: RevisedField, value: String?) -> some View {
        let origin = aiFields.contains(field) ? RevisionService.origin(of: field, on: task) : nil
        let pressing = field == .dueDate && ViewRules.marginMark(of: task).pressing
        let shown = field == .dueDate ? task.dueDate.map { FieldFormatting.dueWords($0, hasTime: task.dueHasTime) } ?? value : value
        let row = HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(FieldFormatting.label(field))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            if let shown {
                Text(shown)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(pressing ? AnyShapeStyle(.red) : origin != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .multilineTextAlignment(.leading)
            }
            switch origin {
            case .rule:
                Image(systemName: "quote.opening")
                    .imageScale(.small)
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
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())

        Button { editingField = field } label: { row }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("field_\(field.rawValue)")
            .editorPopover(field, editing: $editingField) { editor(for: field) }
    }

    private func editor(for field: RevisedField) -> FieldEditorView {
        FieldEditorView(task: task, field: field, contexts: contexts, projects: projects)
    }

    /// Return in the wrapping title field ends the edit, which commits (#216).
    private func endEditOnReturn(_ newValue: String) {
        guard let result = DetailLayout.titleAfterReturn(newValue) else { return }
        titleDraft = result.text
        if result.ended { titleFocused = false }
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
                    Text("\(FieldFormatting.value(revision.oldValue, for: revision.field) ?? String(localized: "Empty")) \(Image(systemName: "arrow.right")) \(FieldFormatting.value(revision.newValue, for: revision.field) ?? String(localized: "Empty"))")
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

/// "+ Due": a small plus before the field's name in New York, for the line of empty fields (#440).
private struct AddWordLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            configuration.icon
                .imageScale(.small)
            configuration.title
                .font(.system(.body, design: .serif))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

extension View {
    /// Mac (#482, Henning 2026-10-16): the editor opens as a popover at its row and the detail stays
    /// where it is; Escape closes it, a single choice closes it by itself. iPhone and iPad push it.
    @ViewBuilder
    func editorPopover<Editor: View>(_ field: RevisedField, editing: Binding<RevisedField?>,
                                     @ViewBuilder editor: @escaping () -> Editor) -> some View {
        #if os(macOS)
        popover(isPresented: Binding(
            get: { editing.wrappedValue == field },
            set: { shown in if !shown, editing.wrappedValue == field { editing.wrappedValue = nil } }
        ), arrowEdge: .trailing) {
            editor()
                .frame(width: 340)
                .frame(minHeight: 260, idealHeight: 460, maxHeight: 620)
        }
        #else
        self
        #endif
    }
}
