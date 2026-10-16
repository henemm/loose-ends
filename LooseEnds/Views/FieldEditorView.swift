import OSLog
import SwiftData
import SwiftUI

/// One field, one screen (design briefing, screen 4, "Ändern"): the control for the value and,
/// when a rule or the AI set this field, what it changed plus "Reset" — "From your words" with the
/// trigger marked in the raw text, or "Estimated by Apple Intelligence" (#101). Every change is a
/// user revision and therefore a learning example (ADR-5, ADR-6).
struct FieldEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskItem
    let field: RevisedField
    let contexts: [TaskContext]
    let projects: [Project]

    /// The energy slider's position (−3 … 3) and whether a finger is on it: written once on release (#112).
    @State private var energyPosition = 0.0
    @State private var energyDragging = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var automaticRevision: Revision? {
        guard RevisionService.automaticFields(on: task).contains(field) else { return nil }
        return RevisionService.firstAutomaticRevision(of: field, on: task)
    }

    var body: some View {
        if Self.onPaper.contains(field) {
            paperPage
        } else {
            formPage
        }
    }

    /// The fields already drawn as notebook pages (#482, Schnitt 1); the rest follow in Schnitt 2.
    private static let onPaper: Set<RevisedField> = [.importance, .urgency, .duration, .contexts, .project]

    // MARK: - Notebook page (#482)

    private var paperPage: some View {
        EditorPage(caption: FieldFormatting.label(field), value: paperValue,
                   pressing: field == .urgency && task.urgency == .high, note: paperNote) {
            VStack(alignment: .leading, spacing: 0) {
                paperControl
                if let revision = automaticRevision {
                    origin(revision)
                        .padding(.top, 34)
                }
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var paperValue: String? {
        switch field {
        case .contexts:
            let names = (task.contexts ?? []).sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
            return names.isEmpty ? nil : names.formatted(.list(type: .and))
        default:
            return FieldFormatting.value(FieldCodec.encode(field, of: task), for: field)
        }
    }

    private var paperNote: String? {
        switch field {
        case .urgency where task.urgency == .high: String(localized: "Shown in red in the margin.")
        case .contexts: String(localized: "Tap a word to add or remove it.")
        case .project: String(localized: "When its name is in your words, the app sets it by itself.")
        default: nil
        }
    }

    /// Single choices set and close: one tap from the detail and back (Henning, 2026-10-16).
    @ViewBuilder
    private var paperControl: some View {
        switch field {
        case .importance:
            LevelLadder(current: task.importanceRaw, highIsPressing: false) { choose($0) }
        case .urgency:
            LevelLadder(current: task.urgencyRaw, highIsPressing: true) { choose($0) }
        case .duration:
            DurationTape(current: task.duration) { choose($0?.rawValue) }
        case .contexts:
            TagSentence(contexts: contexts, chosen: Set((task.contexts ?? []).map(\.id))) { toggle($0) }
        case .project:
            ProjectIndex(projects: projects, current: task.project) { choose($0?.name) }
        default:
            EmptyView()
        }
    }

    private func choose(_ encoded: String?) {
        apply(encoded)
        dismiss()
    }

    /// Where a rule or the model set the value: the said sentence as a quote with the trigger marked,
    /// before and after, and "Reset" (#101), on paper like the rest of the page.
    private func origin(_ revision: Revision) -> some View {
        let fromRule = RevisionService.origin(of: field, on: task) == .rule
        return VStack(alignment: .leading, spacing: 14) {
            Label(fromRule ? LocalizedStringKey("From your words") : LocalizedStringKey("Estimated by Apple Intelligence"),
                  systemImage: fromRule ? "quote.opening" : "sparkle")
                .captionHead()
                .accessibilityIdentifier(fromRule ? "originRuleHeader" : "originAIHeader")
            if fromRule {
                Text(Self.marked(task.rawText, trigger: RuleTrigger.range(
                    of: field, in: task.rawText, contexts: (task.contexts ?? []).map(\.name))))
                    .font(.system(.title3, design: .serif))
                    .italic()
                    .padding(.leading, 14)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.quaternary).frame(width: 1.5)
                    }
                    .accessibilityIdentifier("originRawText")
            }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("Before").captionHead()
                    Text(FieldFormatting.value(revision.oldValue, for: field) ?? String(localized: "Empty"))
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(.secondary)
                }
                GridRow {
                    Text("After").captionHead()
                    Text(FieldFormatting.value(revision.newValue, for: field) ?? String(localized: "Empty"))
                        .font(.system(.body, design: .serif))
                }
            }
            if let reason = revision.reason, !reason.isEmpty {
                Text(reason).font(.footnote).foregroundStyle(.secondary)
            } else if !fromRule {
                Text("Estimated, not read – worth a look.").font(.footnote).foregroundStyle(.secondary)
            }
            Button("Reset", systemImage: "arrow.uturn.backward") { reset(revision) }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("resetRevisionButton")
        }
    }

    // MARK: - Form page (until Schnitt 2)

    private var formPage: some View {
        Form {
            Section {
                control
            }
            if let revision = automaticRevision {
                if RevisionService.origin(of: field, on: task) == .rule {
                    fromYourWords(revision)
                } else {
                    estimated(revision)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(FieldFormatting.label(field))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            energyPosition = Double(task.energy?.rawValue ?? 0)
        }
    }

    // MARK: - Origin (#101)

    /// Read, not guessed: the raw text with the trigger marked, before and after, the rule's sentence.
    private func fromYourWords(_ revision: Revision) -> some View {
        Section {
            Text(Self.marked(task.rawText, trigger: RuleTrigger.range(
                of: field, in: task.rawText, contexts: (task.contexts ?? []).map(\.name))))
                .italic()
                .fontDesign(.serif)
                .accessibilityIdentifier("originRawText")
            beforeAfter(revision)
            Button("Reset") { reset(revision) }
                .accessibilityIdentifier("resetRevisionButton")
        } header: {
            Label("From your words", systemImage: "quote.opening")
                .foregroundStyle(.tint)
                .accessibilityIdentifier("originRuleHeader")
        } footer: {
            if let reason = revision.reason, !reason.isEmpty { Text(reason) }
        }
    }

    private func estimated(_ revision: Revision) -> some View {
        Section {
            beforeAfter(revision)
            if let reason = revision.reason, !reason.isEmpty {
                Text(reason).foregroundStyle(.secondary)
            }
            Button("Reset") { reset(revision) }
                .accessibilityIdentifier("resetRevisionButton")
        } header: {
            Label("Estimated by Apple Intelligence", systemImage: "sparkle")
                .foregroundStyle(.tint)
                .accessibilityIdentifier("originAIHeader")
        } footer: {
            Text("Estimated, not read – worth a look.")
        }
    }

    @ViewBuilder
    private func beforeAfter(_ revision: Revision) -> some View {
        LabeledContent("Before", value: FieldFormatting.value(revision.oldValue, for: field) ?? String(localized: "Empty"))
        LabeledContent("After", value: FieldFormatting.value(revision.newValue, for: field) ?? String(localized: "Empty"))
    }

    /// The trigger in the primary colour on a light accent wash, the rest as the raw text stands.
    private static func marked(_ text: String, trigger: Range<String.Index>?) -> AttributedString {
        var attributed = AttributedString(text)
        guard let trigger,
              let lower = AttributedString.Index(trigger.lowerBound, within: attributed),
              let upper = AttributedString.Index(trigger.upperBound, within: attributed) else { return attributed }
        attributed[lower..<upper].backgroundColor = Color.accentColor.opacity(0.16)
        attributed[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        return attributed
    }

    // MARK: - Controls

    @ViewBuilder
    private var control: some View {
        switch field {
        case .dueDate: dueControl
        case .importance: levelPicker(current: task.importanceRaw)
        case .urgency: levelPicker(current: task.urgencyRaw)
        case .energy: energyControl
        case .duration: durationPicker
        case .contexts: contextsControl
        case .project: projectPicker
        case .repeatRule: repeatControl
        case .title, .blockedBy, .place, .people, .notes: EmptyView()
        }
    }

    @ViewBuilder
    private var dueControl: some View {
        quickDue
        Toggle("Due", isOn: Binding(
            get: { task.dueDate != nil },
            set: { on in setDue(on ? Self.tomorrow : nil, hasTime: false) }
        ))
        .accessibilityIdentifier("dueToggle")
        if let due = task.dueDate {
            DatePicker(
                "Date",
                selection: Binding(get: { due }, set: { setDue($0, hasTime: task.dueHasTime) }),
                displayedComponents: task.dueHasTime ? [.date, .hourAndMinute] : [.date]
            )
            Toggle("Time", isOn: Binding(
                get: { task.dueHasTime },
                set: { setDue(due, hasTime: $0) }
            ))
        }
    }

    /// Quick choices first (#440): a day, then a time, and the editor closes. "Tomorrow at 3 pm" is
    /// three taps from the detail. The toggles and the wheel below stay for any other date.
    @ViewBuilder
    private var quickDue: some View {
        let chosen = QuickDue.matching(task.dueDate)
        FlowLayout(spacing: 8) {
            ForEach(QuickDue.Day.allCases, id: \.self) { day in
                quickChip(Self.dayLabel(day), on: chosen == day, id: "quickDay_\(day)") {
                    setDue(QuickDue.move(task.dueDate, hasTime: task.dueHasTime, to: QuickDue.day(day)),
                           hasTime: task.dueHasTime)
                }
            }
        }
        .padding(.vertical, 4)
        if let due = task.dueDate {
            FlowLayout(spacing: 8) {
                quickChip(String(localized: "No time"), on: !task.dueHasTime, id: "quickTime_none") {
                    setDue(due, hasTime: false)
                    dismiss()
                }
                ForEach(QuickDue.hours, id: \.self) { hour in
                    let at = QuickDue.at(hour: hour, on: Calendar.current.startOfDay(for: due))
                    quickChip(at.formatted(date: .omitted, time: .shortened), on: task.dueHasTime && due == at,
                              id: "quickTime_\(hour)") {
                        setDue(at, hasTime: true)
                        dismiss()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private static func dayLabel(_ day: QuickDue.Day) -> String {
        switch day {
        case .today: String(localized: "Today")
        case .tomorrow: String(localized: "Tomorrow")
        case .weekend: String(localized: "Weekend")
        case .nextWeek: String(localized: "Next week")
        }
    }

    /// A capsule: filled in accent when chosen, outlined otherwise (accent = tappable, ADR-14).
    private func quickChip(_ title: String, on: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(on ? AnyShapeStyle(.background) : AnyShapeStyle(.tint))
                .background {
                    if on {
                        Capsule().fill(.tint)
                    } else {
                        Capsule().strokeBorder(.tint.opacity(0.5))
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }

    private static var tomorrow: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
    }

    private func levelPicker(current: String?) -> some View {
        Picker(FieldFormatting.label(field), selection: Binding(
            get: { current ?? "" },
            set: { apply($0.isEmpty ? nil : $0) }
        )) {
            Text("None").tag("")
            Text("Low").tag(Importance.low.rawValue)
            Text("Medium").tag(Importance.medium.rawValue)
            Text("High").tag(Importance.high.rawValue)
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }

    /// Variant D (#112): a slider between an empty and a full battery that snaps at seven stops,
    /// only words above it, "Remove value" below. Set by hand only, so there is no AI section.
    @ViewBuilder
    private var energyControl: some View {
        let shown = energyDragging ? Energy(rawValue: Int(energyPosition.rounded())) : task.energy
        let words = shown.map { FieldFormatting.energy($0) } ?? String(localized: "Not set")
        VStack(spacing: 18) {
            Text(words)
                .font(.title3)
                .fontDesign(.serif)
                .foregroundStyle(shown == nil ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
                .accessibilityIdentifier("energyWords")
            Slider(value: $energyPosition, in: -3...3, step: 1) {
                Text(FieldFormatting.label(field))
            } minimumValueLabel: {
                Image(systemName: "battery.0percent")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            } maximumValueLabel: {
                Image(systemName: "battery.100percent")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            } onEditingChanged: { editing in
                energyDragging = editing
                if !editing { commitEnergy() }
            }
            .accessibilityValue(words)
            .accessibilityIdentifier("energySlider")
            // VoiceOver adjusts without a drag, so no editing callback fires there.
            .onChange(of: energyPosition) { _, position in
                guard !energyDragging, Int(position.rounded()) != task.energy?.rawValue else { return }
                commitEnergy()
            }
        }
        .padding(.vertical, 8)
        if task.energy != nil {
            Button("Remove value") { apply(nil) }
                .accessibilityIdentifier("energyRemoveButton")
        }
    }

    private func commitEnergy() {
        apply(Energy(rawValue: Int(energyPosition.rounded()))?.stored)
    }

    private var durationPicker: some View {
        Picker(FieldFormatting.label(field), selection: Binding(
            get: { task.durationRaw ?? "" },
            set: { apply($0.isEmpty ? nil : $0) }
        )) {
            Text("None").tag("")
            ForEach(DurationBucket.allCases, id: \.rawValue) { bucket in
                Text(FieldFormatting.duration(bucket)).tag(bucket.rawValue)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }

    private var contextsControl: some View {
        ForEach(contexts) { context in
            let selected = (task.contexts ?? []).contains { $0.id == context.id }
            Button {
                toggle(context)
            } label: {
                HStack {
                    Text(context.name)
                        .foregroundStyle(.primary)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
            }
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("contextOption_\(context.id.uuidString)")
        }
    }

    private var projectPicker: some View {
        Picker(FieldFormatting.label(field), selection: Binding(
            get: { task.project?.name ?? "" },
            set: { apply($0.isEmpty ? nil : $0) }
        )) {
            Text("None").tag("")
            ForEach(projects) { project in
                Text(project.name).tag(project.name)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }

    /// Frequency first; interval, weekdays and the counting basis appear once there is a rule (ADR-7).
    @ViewBuilder
    private var repeatControl: some View {
        let rule = task.repeatRule
        Picker(FieldFormatting.label(field), selection: Binding(
            get: { rule?.frequency.rawValue ?? "" },
            set: { raw in
                guard let frequency = RepeatRule.Frequency(rawValue: raw) else { applyRepeat(nil); return }
                applyRepeat(RepeatRule.selecting(frequency, existing: rule, rawText: task.rawText))
            }
        )) {
            Text("None").tag("")
            Text("Daily").tag(RepeatRule.Frequency.daily.rawValue)
            Text("Weekly").tag(RepeatRule.Frequency.weekly.rawValue)
            Text("Monthly").tag(RepeatRule.Frequency.monthly.rawValue)
            Text("Yearly").tag(RepeatRule.Frequency.yearly.rawValue)
        }
        .pickerStyle(.inline)
        .labelsHidden()

        if let rule {
            Stepper(value: Binding(
                get: { rule.interval },
                set: { var next = rule; next.interval = max(1, $0); applyRepeat(next) }
            ), in: 1...52) {
                Text(FieldFormatting.intervalDescription(rule))
            }
            .accessibilityIdentifier("repeatIntervalStepper")

            if rule.frequency == .weekly {
                weekdayRow(rule)
            }

            Picker("Counting from", selection: Binding(
                get: { rule.basis.rawValue },
                set: { var next = rule; next.basis = RepeatRule.Basis(rawValue: $0) ?? .fromDueDate; applyRepeat(next) }
            )) {
                Text("From due date").tag(RepeatRule.Basis.fromDueDate.rawValue)
                Text("From completion").tag(RepeatRule.Basis.fromCompletion.rawValue)
            }
        }
    }

    /// Seven small toggles in the calendar's week order; an empty selection means every week.
    private func weekdayRow(_ rule: RepeatRule) -> some View {
        let calendar = Calendar.current
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        let selected = Set(rule.weekdays ?? [])
        return HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let on = selected.contains(day)
                Button(calendar.veryShortWeekdaySymbols[day - 1]) {
                    var next = rule
                    var days = selected
                    if on { days.remove(day) } else { days.insert(day) }
                    next.weekdays = days.isEmpty ? nil : days.sorted()
                    applyRepeat(next)
                }
                .buttonStyle(.bordered)
                .tint(on ? .accentColor : .secondary)
                .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    /// A brand new rule without a due date gets an implicit first one, so the task reaches
    /// `DueReminders.plan` at all (#127). An existing due date is never overwritten.
    private func applyRepeat(_ rule: RepeatRule?) {
        let isNewRule = task.repeatRule == nil && rule != nil
        apply(rule.flatMap(FieldCodec.encode))
        if isNewRule, let rule, task.dueDate == nil {
            setDue(rule.firstDueDate(), hasTime: rule.hour != nil)
        }
    }

    // MARK: - Writes

    /// Dates without a time are stored at the start of the day, so "same day" compares cleanly.
    private func setDue(_ date: Date?, hasTime: Bool) {
        let stored = date.map { hasTime ? $0 : Calendar.current.startOfDay(for: $0) }
        RevisionService.set(.dueDate, to: stored?.ISO8601Format(), on: task, contexts: contexts, projects: projects)
        task.dueHasTime = stored != nil && hasTime
        save()
    }

    private func toggle(_ context: TaskContext) {
        var names = (task.contexts ?? []).map(\.name)
        if names.contains(context.name) {
            names.removeAll { $0 == context.name }
        } else {
            names.append(context.name)
        }
        apply(FieldCodec.encode(names))
    }

    private func apply(_ encoded: String?) {
        guard RevisionService.set(field, to: encoded, on: task, contexts: contexts, projects: projects) != nil else { return }
        save()
    }

    private func reset(_ revision: Revision) {
        RevisionService.revert(revision, on: task, contexts: contexts, projects: projects)
        save()
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving \(field.rawValue, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}
