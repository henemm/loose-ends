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

    /// The energy dot under the finger (−3 … 3); written on tap (#112, #482).
    @State private var energyPosition: Int?
    /// "Other date …" and "Other time …" open their pickers in place (#482).
    @State private var showsOtherDate = false
    @State private var showsOtherTime = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private var automaticRevision: Revision? {
        guard RevisionService.automaticFields(on: task).contains(field) else { return nil }
        return RevisionService.firstAutomaticRevision(of: field, on: task)
    }

    var body: some View {
        paperPage
            .onAppear { energyPosition = task.energy?.rawValue }
    }

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
        case .dueDate:
            return task.dueDate.map { FieldFormatting.dueWords($0, hasTime: task.dueHasTime) }
        case .energy:
            return shownEnergy.map { FieldFormatting.energy($0) }
        case .repeatRule:
            return task.repeatRule.map(Self.sentence)
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
        case .dueDate: dueNote
        case .energy: String(localized: "Three steps to each side, the middle is neutral.")
        default: nil
        }
    }

    /// The weekday of the date; past its day the question that brought the editor up (#518).
    private var dueNote: String? {
        switch ViewRules.dueState(of: task) {
        case .carried(let days) where days == 1: String(localized: "Open since yesterday. When now?")
        case .carried(let days): String(localized: "Open for \(days) days. When now?")
        case .missed: String(localized: "The time has passed. When now?")
        case .today, .later: task.dueDate?.formatted(.dateTime.weekday(.wide).day().month(.wide))
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
        case .dueDate:
            dueControl
        case .energy:
            energyControl
        case .repeatRule:
            repeatControl
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

    // MARK: - Due (#440, #482)

    /// Quick days, two weeks as a calendar, times as words, and any other date or time in place.
    @ViewBuilder
    private var dueControl: some View {
        let calendar = Calendar.current
        let chosen = QuickDue.matching(task.dueDate)
        VStack(alignment: .leading, spacing: 20) {
            FlowLayout(spacing: 8) {
                ForEach(QuickDue.Day.allCases, id: \.self) { day in
                    quickChip(Self.dayLabel(day), on: chosen == day, id: "quickDay_\(day)") {
                        setDue(QuickDue.move(task.dueDate, hasTime: task.dueHasTime, to: QuickDue.day(day)),
                               hasTime: task.dueHasTime)
                    }
                }
            }
            fortnight(calendar: calendar)
            if showsOtherDate {
                DatePicker("Date", selection: Binding(
                    get: { task.dueDate ?? Self.tomorrow },
                    set: { setDue(QuickDue.move(task.dueDate, hasTime: task.dueHasTime, to: calendar.startOfDay(for: $0)),
                                  hasTime: task.dueHasTime) }
                ), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .accessibilityIdentifier("dueOtherDatePicker")
            } else {
                Button("Other date …", systemImage: "calendar") { showsOtherDate = true }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("dueOtherDate")
            }
            if let due = task.dueDate {
                times(due: due, calendar: calendar)
                Button("No date") { setDue(nil, hasTime: false); dismiss() }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("dueNone")
            }
        }
    }

    /// This week and the next in New York: past days faint, today ringed, the due day filled. The
    /// weekday heads sit in a grid of their own: in one lazy grid they shared the dates of the first
    /// week as identity, and SwiftUI dropped that whole row of days, today included (#557).
    private func fortnight(calendar: Calendar) -> some View {
        let days = QuickDue.fortnight(calendar: calendar)
        let today = calendar.startOfDay(for: Date())
        let due = task.dueDate.map { calendar.startOfDay(for: $0) }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(days.prefix(7)), id: \.self) { day in
                    Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: columns, spacing: 4) {
                fortnightDays(days, today: today, due: due)
            }
        }
    }

    private func fortnightDays(_ days: [Date], today: Date, due: Date?) -> some View {
        ForEach(days, id: \.self) { day in
            let past = day < today
            let on = day == due
            Button {
                setDue(QuickDue.move(task.dueDate, hasTime: task.dueHasTime, to: day), hasTime: task.dueHasTime)
            } label: {
                Text(day.formatted(.dateTime.day()))
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(on ? AnyShapeStyle(.background) : past ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.primary))
                    .frame(width: 38, height: 38)
                    .background {
                        if on {
                            Circle().fill(.tint)
                        } else if day == today {
                            Circle().strokeBorder(.secondary, lineWidth: 1.2)
                        }
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(past)
            .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
            .accessibilityAddTraits(on ? .isSelected : [])
            .accessibilityIdentifier("dueDay_\(day.formatted(.iso8601.year().month().day()))")
        }
    }

    /// Times as words; one of them sets and closes, "Other time …" opens a wheel and stays (#482). A time
    /// set outside the full hours stands as its own word by the clock; "Other time …" stays the last word
    /// either way, so the way to another time never disappears (#556).
    @ViewBuilder
    private func times(due: Date, calendar: Calendar) -> some View {
        let day = calendar.startOfDay(for: due)
        let choices = QuickDue.timeChoices(on: day, due: due, hasTime: task.dueHasTime, calendar: calendar)
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 16) {
                timeWord(String(localized: "No time"), on: !task.dueHasTime, id: "quickTime_none") {
                    setDue(due, hasTime: false)
                    dismiss()
                }
                ForEach(choices, id: \.self) { at in
                    let hour = calendar.component(.hour, from: at)
                    let full = QuickDue.hours.contains(hour) && at == QuickDue.at(hour: hour, on: day, calendar: calendar)
                    timeWord(at.formatted(date: .omitted, time: .shortened), on: task.dueHasTime && due == at,
                             id: full ? "quickTime_\(hour)" : "quickTime_custom") {
                        setDue(at, hasTime: true)
                        dismiss()
                    }
                }
                timeWord(String(localized: "Other time …"), on: false, id: "quickTime_other") {
                    showsOtherTime.toggle()
                }
            }
            if showsOtherTime {
                DatePicker("Time", selection: Binding(
                    get: { task.dueHasTime ? due : QuickDue.at(hour: 9, on: day) },
                    set: { setDue($0, hasTime: true) }
                ), displayedComponents: .hourAndMinute)
                #if os(iOS)
                .datePickerStyle(.wheel)
                #endif
                .labelsHidden()
                .accessibilityIdentifier("dueOtherTimePicker")
            }
        }
    }

    private func timeWord(_ title: String, on: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(on ? .primary : .secondary)
                .underline(on, color: .accentColor)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
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
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(on ? AnyShapeStyle(.background) : AnyShapeStyle(.primary))
                .background {
                    if on {
                        Capsule().fill(.tint)
                    } else {
                        Capsule().strokeBorder(.quaternary)
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

    // MARK: - Energy (#112, #482)

    private var shownEnergy: Energy? {
        energyPosition.flatMap(Energy.init(rawValue:)) ?? task.energy
    }

    /// Seven dots on a dotted line instead of the system slider; the chosen one large in accent.
    @ViewBuilder
    private var energyControl: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                Line()
                    .stroke(.secondary, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0, 4]))
                    .frame(height: 1.2)
                    .padding(.horizontal, 10)
                    .accessibilityHidden(true)
                HStack(spacing: 0) {
                    ForEach(-3...3, id: \.self) { value in
                        let on = shownEnergy?.rawValue == value
                        let words = Energy(rawValue: value).map { FieldFormatting.energy($0) } ?? ""
                        Button {
                            energyPosition = value
                            apply(Energy(rawValue: value)?.stored)
                        } label: {
                            Circle()
                                .fill(on ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Paper.ground))
                                .overlay { Circle().strokeBorder(on ? Color.clear : Color.secondary, lineWidth: 1.3) }
                                .frame(width: on ? 22 : 13, height: on ? 22 : 13)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(words)
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier("energyDot_\(value)")
                    }
                }
            }
            HStack {
                Label("takes", systemImage: "battery.0percent")
                Spacer()
                Label("gives", systemImage: "battery.100percent")
                    .labelStyle(TrailingIconLabel())
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
            if task.energy != nil {
                Button("Remove value") { energyPosition = nil; apply(nil) }
                    .buttonStyle(.borderless)
                    .padding(.top, 12)
                    .accessibilityIdentifier("energyRemoveButton")
            }
        }
    }

    // MARK: - Repeat (ADR-7, #482)

    /// "Every two weeks on Monday and Thursday": the rule as the header's sentence.
    static func sentence(_ rule: RepeatRule) -> String {
        let base = FieldFormatting.intervalDescription(rule)
        guard rule.frequency == .weekly, let days = rule.weekdays, !days.isEmpty else { return base }
        let calendar = Calendar.current
        let names = days.map { calendar.weekdaySymbols[$0 - 1] }.formatted(.list(type: .and))
        return String(localized: "\(base), on \(names)")
    }

    /// The frequency as words, then how often, the weekdays for a weekly rule and where counting starts.
    @ViewBuilder
    private var repeatControl: some View {
        let rule = task.repeatRule
        VStack(alignment: .leading, spacing: 22) {
            FlowLayout(spacing: 18) {
                ForEach(RepeatRule.Frequency.allCases, id: \.self) { frequency in
                    let on = rule?.frequency == frequency
                    Button {
                        applyRepeat(RepeatRule.selecting(frequency, existing: rule, rawText: task.rawText))
                    } label: {
                        Text(Self.frequencyTitle(frequency))
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(on ? .primary : .secondary)
                            .underline(on, color: .accentColor)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("repeatOption_\(frequency.rawValue)")
                }
            }
            if let rule {
                HStack(spacing: 14) {
                    Text("Every").foregroundStyle(.secondary)
                    stepButton("minus", enabled: rule.interval > 1) {
                        var next = rule; next.interval = max(1, rule.interval - 1); applyRepeat(next)
                    }
                    Text(verbatim: "\(rule.interval)")
                        .font(.system(.title2, design: .serif))
                        .monospacedDigit()
                        .frame(minWidth: 28)
                    stepButton("plus", enabled: rule.interval < 52) {
                        var next = rule; next.interval = min(52, rule.interval + 1); applyRepeat(next)
                    }
                    Text(Self.unit(rule)).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("repeatIntervalStepper")
                if rule.frequency == .weekly {
                    weekdayRow(rule)
                }
                HStack(spacing: 18) {
                    basisWord("From due date", basis: .fromDueDate, rule: rule)
                    basisWord("From completion", basis: .fromCompletion, rule: rule)
                }
                .font(.subheadline)
                Button("Don't repeat") { applyRepeat(nil) }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("repeatNone")
            }
        }
    }

    private static func frequencyTitle(_ frequency: RepeatRule.Frequency) -> LocalizedStringKey {
        switch frequency {
        case .daily: "Daily"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .yearly: "Yearly"
        }
    }

    private static func unit(_ rule: RepeatRule) -> String {
        let one = rule.interval == 1
        switch rule.frequency {
        case .daily: return one ? String(localized: "day") : String(localized: "days")
        case .weekly: return one ? String(localized: "week") : String(localized: "weeks")
        case .monthly: return one ? String(localized: "month") : String(localized: "months")
        case .yearly: return one ? String(localized: "year") : String(localized: "years")
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.callout.weight(.medium))
                .frame(width: 34, height: 34)
                .overlay { Circle().strokeBorder(.quaternary) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
        .disabled(!enabled)
        .accessibilityLabel(symbol == "plus" ? Text("More") : Text("Fewer"))
    }

    private func basisWord(_ title: LocalizedStringKey, basis: RepeatRule.Basis, rule: RepeatRule) -> some View {
        let on = rule.basis == basis
        return Button {
            var next = rule; next.basis = basis; applyRepeat(next)
        } label: {
            Text(title)
                .foregroundStyle(on ? .primary : .secondary)
                .underline(on, color: .accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Seven circles in the calendar's week order; an empty selection means every week.
    private func weekdayRow(_ rule: RepeatRule) -> some View {
        let calendar = Calendar.current
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        let selected = Set(rule.weekdays ?? [])
        return HStack(spacing: 6) {
            ForEach(order, id: \.self) { day in
                let on = selected.contains(day)
                Button {
                    var next = rule
                    var days = selected
                    if on { days.remove(day) } else { days.insert(day) }
                    next.weekdays = days.isEmpty ? nil : days.sorted()
                    applyRepeat(next)
                } label: {
                    Text(calendar.shortWeekdaySymbols[day - 1].prefix(2))
                        .font(.footnote.weight(.medium))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(on ? AnyShapeStyle(.background) : AnyShapeStyle(.secondary))
                        .background {
                            if on { Circle().fill(.tint) } else { Circle().strokeBorder(.quaternary) }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(calendar.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    /// A brand new rule without a due date gets an implicit first one, so the task reaches
    /// `DueReminders.plan` at all (#127). An existing due date is never overwritten. The series stands
    /// on that first day (#552): its anchor, which a date moved for one round does not shift.
    private func applyRepeat(_ rule: RepeatRule?) {
        guard task.repeatRule == nil, var fresh = rule else {
            apply(rule.flatMap(FieldCodec.encode))
            return
        }
        let first = task.dueDate ?? fresh.firstDueDate()
        fresh.anchor = first
        apply(FieldCodec.encode(fresh))
        if task.dueDate == nil {
            setDue(first, hasTime: fresh.hour != nil)
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
}

/// A horizontal line through the middle of its frame, for the energy dots.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Title first, icon after: "gives" with the full battery on the right.
private struct TrailingIconLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}
