import OSLog
import SwiftData
import SwiftUI

/// One field, one screen (design briefing, screen 4, "Ändern"): the control for the value and,
/// when the AI set this field, what it changed plus "Reset". Every change is a user revision and
/// therefore a learning example (ADR-5, ADR-6).
struct FieldEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: TaskItem
    let field: RevisedField
    let contexts: [TaskContext]
    let projects: [Project]

    @State private var peopleText = ""
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var aiRevision: Revision? {
        guard RevisionService.aiSetFields(on: task).contains(field) else { return nil }
        return RevisionService.firstAIRevision(of: field, on: task)
    }

    var body: some View {
        Form {
            Section {
                control
            }
            if let revision = aiRevision {
                Section("Set by AI") {
                    LabeledContent("Before", value: FieldFormatting.value(revision.oldValue, for: field) ?? String(localized: "Empty"))
                    LabeledContent("After", value: FieldFormatting.value(revision.newValue, for: field) ?? String(localized: "Empty"))
                    if let reason = revision.reason, !reason.isEmpty {
                        Text(reason).foregroundStyle(.secondary)
                    }
                    Button("Reset") { reset(revision) }
                        .accessibilityIdentifier("resetRevisionButton")
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(FieldFormatting.label(field))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { peopleText = task.people.joined(separator: ", ") }
        .onDisappear { if field == .people { commitPeople() } }
    }

    // MARK: - Controls

    @ViewBuilder
    private var control: some View {
        switch field {
        case .dueDate: dueControl
        case .importance: levelPicker(current: task.importanceRaw)
        case .urgency: levelPicker(current: task.urgencyRaw)
        case .energy: levelPicker(current: task.energyRaw)
        case .duration: durationPicker
        case .contexts: contextsControl
        case .people: peopleControl
        case .project: projectPicker
        case .repeatRule: repeatControl
        case .title, .blockedBy: EmptyView()
        }
    }

    @ViewBuilder
    private var dueControl: some View {
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

    private var peopleControl: some View {
        TextField("Names, comma separated", text: $peopleText)
            .onSubmit(commitPeople)
            .accessibilityIdentifier("peopleField")
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

    private func applyRepeat(_ rule: RepeatRule?) {
        apply(rule.flatMap(FieldCodec.encode))
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

    private func commitPeople() {
        let names = peopleText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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
