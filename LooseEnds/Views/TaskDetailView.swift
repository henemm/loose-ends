import OSLog
import SwiftData
import SwiftUI

/// Task detail (design briefing, screen 4): editable title, the raw text underneath while it says
/// more than the title, then what the task carries, in five groups and one order (#538: What · When ·
/// Weight · Filing · Connection); a section shows only with content, and everything empty is offered
/// in one line of words below, grouped the same way, only the fields that are on in the settings.
/// Tapping a row opens its editor; a field a rule read from the raw text carries the quote mark, one the AI
/// estimated the spark (#101), both accent-tinted, and its editor also shows before, after, the
/// reason and Reset. Opening the detail marks the AI changes as seen, except from "New" (#349):
/// there a line under the title says why the task waits, and "Looks right" takes the place of
/// Complete, which moves into the menu. Opened elsewhere, the bar carries Complete, "Looks right"
/// while the task still needs a look (#318), and the "…" menu: the list's long-press menu, entry for
/// entry (`TaskInteractions.menu`, #667), Delete included, which leaves the detail.
struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(CompletionPulse.self) private var completionPulse: CompletionPulse?
    @Environment(PendingCompletions.self) private var pendingCompletions: PendingCompletions?
    @Environment(\.dismiss) private var dismiss
    /// Every task, for the "Next up" rank.
    @Query private var storedTasks: [TaskItem]
    /// Filtered here, not in `@Query`: a predicate there is rebuilt on every init and kept the
    /// detail from settling after a field tap (#605).
    private var allTasks: [TaskItem] { storedTasks.filter(\.isPresent) }
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Bindable var task: TaskItem
    /// Opened from "New" (#349): opening confirms nothing, "Looks right" does.
    var reviewing = false
    /// Opened by "Details" on its parent's line (#565): "Part of" goes back instead of stacking the
    /// parent once more.
    var fromParent = false
    /// Runs after Delete from the menu (#667): the host lets go of its selection on the task. A pushed
    /// detail needs nothing, `dismiss` pops it.
    var onDeleted: () -> Void = {}
    /// Nil in previews and tests; the app passes its bridge for the access note.
    @Environment(CalendarBridge.self) private var calendar: CalendarBridge?
    /// Nil in previews; then "Analyze again" is not offered.
    @Environment(\.enrichment) private var enrichment: EnrichmentCoordinator?
    /// Which fields the word line offers (#538); the standard in previews and tests.
    @Environment(FieldSettingsStore.self) private var fieldSettings: FieldSettingsStore?
    /// Sections opened from the word line while still empty (#538, rule 2): the note, the attachment
    /// buttons, the subtask field, the waiting-on picker, the calendar switch. Gone again with the detail.
    @State private var opened: Set<DetailField> = []

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
    /// Complete with open subtasks asks first (#565).
    @State private var askingSubtasks: TaskItem?
    /// A second Knäuel asks first (#643).
    @State private var askingKnaeuel: TaskItem?
    /// The menu's Delete (#667): the question, then the "Move → Date…" sheet's task, as in the lists.
    @State private var pendingDelete: TaskItem?
    @State private var confirmingDelete = false
    @State private var datingTask: TaskItem?
    /// Deleted from here: the view shows nothing more of the task (its model is gone from the store)
    /// while it leaves.
    @State private var deleted = false
    /// A subtask whose own detail is open (#565).
    @State private var openedSubtask: TaskItem?
    /// The parent, opened by "Part of" when this detail was not reached from it (#565).
    @State private var openedParent: TaskItem?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var aiFields: [RevisedField] { RevisionService.automaticFields(on: task) }
    private var settings: DetailFieldSettings { fieldSettings?.settings ?? .standard }
    private var carried: Set<DetailField> { DetailFields.carried(by: task) }
    /// A section shows with content, or once its word was tapped (rule 1 and 2).
    private func shows(_ field: DetailField) -> Bool { carried.contains(field) || opened.contains(field) }
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
                if let parent = task.parent {
                    partOf(parent)
                }
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
                // No hairline above the title in the wide list (#477); the form shows none anyway.
                .listRowSeparator(isWide ? .hidden : .automatic, edges: .top)
                if DetailLayout.showsRawText(task.rawText, title: task.title) {
                    // The raw text as a quote: what was said, in the words it was said (#180). One
                    // running sentence behind a small head, so a second line starts at the edge (#438).
                    // One Text by interpolation, not `+` (deprecated in iOS 26, #580).
                    let head = Text(String(localized: "Said").uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(1)
                    let said = Text(task.rawText)
                        .font(.system(.subheadline, design: .serif))
                        .italic()
                    Text("\(head)  \(said)")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(task.rawText)
                        .accessibilityIdentifier("detailRawText")
                }
            }
            .detailRow()

            driveSection

            if inReview {
                Section {
                    ReviewNote(task: task, automaticFields: aiFields.count)
                }
                // Wide: the tint no wider than the hairlines (#477).
                .listRowBackground(Color.accentColor.opacity(0.08).padding(.horizontal, isWide ? 20 : 0))
                .listRowInsets(isWide ? Paper.wideNoteInsets : nil)
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

            // What (#538): the note and the attachments, right by the title; each only with content.
            if shows(.notes) {
                NoteSection(task: task, startsEditing: opened.contains(.notes))
                    .detailRow()
            }
            if shows(.attachments) {
                AttachmentsSection(task: task)
                    .detailRow()
            }

            // When: the one time that counts, then what hangs on it.
            groupRows(.when)
            if shows(.calendar) {
                calendarSection
            }
            if shows(.place) {
                PlaceSection(task: task, searching: $searchesPlace)
                    .detailRow()
            }

            // Weight and Filing: set lines, one section per group so a gap separates them (rule 3).
            groupRows(.weight)
            groupRows(.filing)

            // Connection: top level only (rule 4).
            if task.parent == nil {
                if shows(.subtasks) {
                    SubtasksSection(task: task, startsEditing: opened.contains(.subtasks)) { openedSubtask = $0 }
                        .detailRow()
                }
                if shows(.waitingOn) {
                    WaitingOnSection(task: task, startsPicking: opened.contains(.waitingOn))
                        .detailRow()
                }
            }

            wordLine

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
        }
    }

    /// Compact: the grouped form as on the iPhone, unchanged. Wide and Mac (#477): a plain list, so the
    /// sections are lines on paper with hairlines like the lists of Schnitt 1, not cards.
    @ViewBuilder
    private var container: some View {
        if isWide {
            List {
                sections
                    .listRowInsets(Paper.wideRowInsets)
            }
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

    /// The list's gestures and menu on this one task (#667): Complete leaves the detail, Delete
    /// empties it and leaves; "Analyze again" shows its note here.
    private var actions: TaskInteractions {
        TaskInteractions(
            kind: nil, tasks: allTasks, contexts: contexts, projects: projects, modelContext: modelContext,
            pendingCompletions: pendingCompletions, completionPulse: completionPulse,
            pendingDelete: $pendingDelete, confirmingDelete: $confirmingDelete, datingTask: $datingTask,
            askingSubtasks: $askingSubtasks, askingKnaeuel: $askingKnaeuel,
            didDelete: { _ in
                deleted = true
                onDeleted()
                dismiss()
            },
            fields: settings,
            didComplete: { _ in dismiss() },
            analyze: analysis
        )
    }

    /// "Analyze again" for the menu: the detail's own run with its note; nil without the pipeline.
    private var analysis: (@MainActor (TaskItem) -> Void)? {
        guard enrichment != nil else { return nil }
        return { _ in analyzeAgain() }
    }

    var body: some View {
        Group {
            if deleted {
                Paper.ground.ignoresSafeArea()
            } else {
                container
            }
        }
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
        .navigationDestination(item: $openedSubtask) { subtask in
            TaskDetailView(task: subtask, fromParent: true)
        }
        .navigationDestination(item: $openedParent) { parent in
            TaskDetailView(task: parent)
        }
        .toolbar { toolbarActions }
        .taskInteractionDialogs(actions)
        .onAppear {
            titleDraft = storedTitle
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

    /// "Part of <task>" above a subtask's title (#565): accent, since a tap opens the task (ADR-14).
    private func partOf(_ parent: TaskItem) -> some View {
        Button {
            if fromParent { dismiss() } else { openedParent = parent }
        } label: {
            Label("Part of \(parent.displayTitle)", systemImage: "arrow.turn.left.up")
                .font(.footnote)
                .lineLimit(1)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.tint)
        .accessibilityIdentifier("partOfParentButton")
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

    /// The set lines of one group (#538, rule 3), in the group's order; nothing while the group is empty.
    @ViewBuilder
    private func groupRows(_ group: DetailField.Group) -> some View {
        // The Knäuel and "Counts" have no set line yet: the "…" menu says and takes them (the detail's
        // own line comes with #647).
        let rows = DetailField.allCases.filter { $0.group == group && $0.group != .drive && carried.contains($0) && $0.revisedField != nil }
        if !rows.isEmpty {
            Section {
                ForEach(rows, id: \.self) { field in
                    if let revised = field.revisedField {
                        fieldRow(revised, value: value(of: revised))
                    }
                }
            }
            .detailRow()
        }
    }

    /// The display value of a set field.
    private func value(of field: RevisedField) -> String? {
        switch field {
        case .dueDate: FieldFormatting.value(FieldCodec.encode(.dueDate, of: task), for: .dueDate, hasTime: task.dueHasTime)
        case .importance: FieldFormatting.value(task.importanceRaw, for: .importance)
        case .urgency: FieldFormatting.value(task.urgencyRaw, for: .urgency)
        case .duration: FieldFormatting.value(task.durationRaw, for: .duration)
        case .energy: FieldFormatting.value(task.energyRaw, for: .energy)
        case .contexts: FieldFormatting.value(FieldCodec.encode(.contexts, of: task), for: .contexts)
        case .project: task.project?.name
        case .repeatRule: FieldFormatting.value(FieldCodec.encode(.repeatRule, of: task), for: .repeatRule)
        case .title, .people, .blockedBy, .place, .notes, .knaeuel, .counts: nil
        }
    }

    /// Everything empty, offered at one place (#538, rule 2): one line of words per group, the groups
    /// in their order with a gap between them, only the fields that are on and whose conditions hold
    /// (rules 4 and 5). One tap opens the editor, the section, the picker or the search. Accent, since
    /// each word is a button (ADR-14).
    @ViewBuilder
    private var wordLine: some View {
        let groups = DetailFields.offered(settings: settings, carried: carried.union(opened),
                                          hasDueDate: task.dueDate != nil, topLevel: task.parent == nil)
        if !groups.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(groups, id: \.self) { words in
                        FlowLayout(spacing: 14) {
                            ForEach(words, id: \.self) { field in
                                word(field)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
                // Each word stays its own element with its own `field_…` identifier: an identifier on
                // the line would overwrite theirs.
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("wordLine")
            }
            .detailRow()
        }
    }

    @ViewBuilder
    private func word(_ field: DetailField) -> some View {
        let button = Button { offer(field) } label: {
            Label(FieldSettingsView.word(field), systemImage: "plus")
                .labelStyle(AddWordLabelStyle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityIdentifier("field_\(field.rawValue)")
        // The note and the place have no field editor: their word opens the section and the search;
        // the Knäuel and "Counts" are set with one tap (#643, #645).
        if let revised = field.revisedField, field != .notes, field != .place, field.group != .drive {
            button.editorPopover(revised, editing: $editingField) { editor(for: revised) }
        } else {
            button
        }
    }

    /// What a word does (#538, rule 2): a field with an editor opens it; the note, the attachments, the
    /// subtasks and waiting on open their section ready for input; the place its search; the calendar
    /// switches on, asking first for what the event still lacks (#203).
    private func offer(_ field: DetailField) {
        switch field {
        case .notes, .attachments, .subtasks, .waitingOn:
            opened.insert(field)
        case .place:
            searchesPlace = true
        case .calendar:
            opened.insert(.calendar)
            switchCalendar(on: true)
        case .dueDate, .repeatRule, .importance, .urgency, .duration, .energy, .contexts, .project:
            if let revised = field.revisedField { editingField = revised }
        case .knaeuel:
            actions.setKnaeuel(task)
        case .counts:
            actions.toggleCounts(task)
        }
    }

    /// "Show in calendar" (#203): switching on asks for what the event still lacks; the switch stays
    /// off until the sheet is answered, and Cancel leaves it off.
    private func switchCalendar(on: Bool) {
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

    /// The calendar as a section (#203): the switch, the appointment, the calendar it goes to. Shown
    /// while the task is in the calendar, or right after "+ Calendar" was tapped (#538).
    private var calendarSection: some View {
        Section {
            Toggle("Show in calendar", isOn: Binding(
                get: { task.showInCalendar },
                set: { switchCalendar(on: $0) }
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
    }

    /// The briefing's "…" menu (screen 4) with Complete first; completing leaves the detail. No
    /// checkmark in the bar: it reads as "close" (#349 for New, #435 everywhere). From "New" the
    /// bar holds "Looks right". The menu is the list's (#667), for a done or parked task too.
    @ToolbarContentBuilder
    private var toolbarActions: some ToolbarContent {
        if !deleted, task.isOpen {
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
        }
        if !deleted {
            ToolbarItem(placement: .primaryAction) {
                // No checkmark in the bar (Henning, 2026-10-15): anyone taps it to close the
                // detail and completes the task by accident. Complete lives in the menu, first, by name.
                Menu("More", systemImage: "ellipsis") {
                    actions.menu(task)
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
        guard let enrichment, reanalysis != .running else { return }
        reanalysis = .running
        Task {
            let result = await enrichment.reanalyze(task)
            titleDraft = storedTitle
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

    /// Under the raw text (#647): "The Knäuel · since Monday" with "No longer the Knäuel", only while the task is
    /// the Knäuel; "Counts" with it, or "Counts always, it is the Knäuel". Nothing while neither holds.
    @ViewBuilder
    private var driveSection: some View {
        if task.isKnaeuel || task.countsAt != nil {
            Section {
                if task.isKnaeuel, let at = task.knaeuelAt {
                    HStack(alignment: .firstTextBaseline) {
                        HStack(spacing: 8) {
                            ThreadGlyph(form: .knaeuel, lineWidth: 1.5)
                                .frame(width: 30, height: 15)
                            Text("The Tangle · \(KnaeuelSince.setWords(from: at))")
                        }
                        Spacer()
                        Button("No longer the Tangle") { actions.releaseKnaeuel(task) }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("detailReleaseKnaeuel")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("detailKnaeuelLine")
                }
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 8) {
                        PearlGlyph()
                            .frame(width: 30, height: 10)
                        if task.isKnaeuel {
                            Text("Collects a bead always, it is the Tangle")
                        } else {
                            Text("Collects a bead")
                        }
                    }
                    Spacer()
                    if task.countsAt != nil {
                        Button("Take the bead off") { actions.toggleCounts(task) }
                            .buttonStyle(.borderless)
                            .accessibilityIdentifier("detailReleaseCounts")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("detailCountsLine")
            }
            .font(.subheadline)
            .detailRow()
        }
    }

    /// The nod (#349): the task leaves "New", and the detail returns to it for the next one.
    private func confirmReview() {
        TaskActions.confirmReview(task)
        save("confirm")
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
        let mark = field == .dueDate ? ViewRules.marginMark(of: task) : ViewRules.MarginMark.none
        let pressing = mark.pressing
        let shown = field == .dueDate ? task.dueDate.map { FieldFormatting.dueWords($0, hasTime: task.dueHasTime) } ?? value : value
        let row = HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(FieldFormatting.label(field))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            if case .passed(let trace) = mark {
                // A deadline that passed is no deadline (#548): the line asks for a new one, the old
                // time stays as a grey trace.
                Text("New date")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(.tint)
                Text(trace.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let shown {
                Text(shown)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(pressing ? AnyShapeStyle(.red) : origin != nil ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .multilineTextAlignment(.leading)
            }
            if let glyph = glyph(for: field) {
                // The field's sign behind the value (#344): grey, it only repeats what label and value say.
                Image(systemName: glyph)
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("fieldGlyph_\(field.rawValue)")
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

    /// Importance by its level, the other fields by their one sign (#344).
    private func glyph(for field: RevisedField) -> String? {
        if field == .importance { return task.importance.map(FieldGlyph.importance) }
        return FieldGlyph.symbol(for: field)
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

    /// The title the field starts from. A subtask added before #565 has none; its line's words stand
    /// in, so its own detail is not an empty "Title".
    private var storedTitle: String {
        task.title ?? (task.parent != nil ? task.rawText : "")
    }

    private func commitTitle() {
        guard !deleted else { return }
        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != storedTitle else { return }
        RevisionService.set(.title, to: trimmed.isEmpty ? nil : trimmed, on: task, contexts: contexts, projects: projects)
        if task.status == .unverified, !trimmed.isEmpty { task.status = .active }
        save("title")
    }

    /// One tap back to the value before the AI touched the title (Bug #125). `titleDraft` only
    /// follows `task.title` in `.onAppear`, so it is pulled along here.
    private func resetTitle() {
        guard let revision = RevisionService.firstAutomaticRevision(of: .title, on: task) else { return }
        RevisionService.revert(revision, on: task, contexts: contexts, projects: projects)
        titleDraft = storedTitle
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
