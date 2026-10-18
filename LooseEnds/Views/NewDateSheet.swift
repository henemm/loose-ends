import OSLog
import SwiftData
import SwiftUI

/// The date choice behind "New date" (#548, Henning 2026-10-18): a deadline that passed is no deadline,
/// so the task needs a decision, one tap each. Four suggestions (later today while the day runs,
/// tomorrow, the weekend, next week), then a calendar with the times as words, below them Park and
/// Complete. In the app's own language: paper, capsules, serif for the content, SF Symbols for the
/// signs. Every choice is a user revision; the old time stays in the revisions.
struct NewDateSheet: View {
    let task: TaskItem
    let onClose: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Environment(CompletionPulse.self) private var completionPulse: CompletionPulse?
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @State private var showsCalendar = false
    @State private var day: Date
    @State private var hour: Int?
    @State private var showsOtherTime = false
    @State private var otherTime: Date
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "App")

    init(task: TaskItem, onClose: @escaping () -> Void) {
        self.task = task
        self.onClose = onClose
        let tomorrow = QuickDue.day(.tomorrow)
        _day = State(initialValue: tomorrow)
        _otherTime = State(initialValue: QuickDue.at(hour: 9, on: tomorrow))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    head
                    suggestions
                    calendar
                    Divider()
                    decisions
                }
                .padding(20)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Paper.ground.ignoresSafeArea())
            .navigationTitle("New date")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onClose)
                        .accessibilityIdentifier("newDateCancel")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }

    /// The task in serif (content), its parent for a subtask, and the trace of what had been planned.
    private var head: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.displayTitle)
                .font(.system(.title3, design: .serif))
                .lineLimit(3)
            if let parent = task.parent {
                Text("Subtask of \(parent.displayTitle)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let trace = NewDateRule.trace(of: task) {
                Text(trace.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("newDateTrace")
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// One tap sets the day and closes. "Later today" only while a full hour of the day is left.
    private var suggestions: some View {
        FlowLayout(spacing: 8) {
            if let later = NewDateRule.laterToday() {
                chip(String(localized: "Later today"), id: "newDateLater") { set(later, hasTime: true) }
            }
            chip(String(localized: "Tomorrow"), id: "newDateTomorrow") { move(to: .tomorrow) }
            chip(String(localized: "Weekend"), id: "newDateWeekend") { move(to: .weekend) }
            chip(String(localized: "Next week"), id: "newDateNextWeek") { move(to: .nextWeek) }
        }
    }

    /// Any other day, with a time as a word or none; "Set date" takes it.
    @ViewBuilder
    private var calendar: some View {
        if showsCalendar {
            VStack(alignment: .leading, spacing: 12) {
                DatePicker("Date", selection: $day, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .accessibilityIdentifier("newDatePicker")
                times
                Button("Set date", systemImage: "calendar") {
                    let start = Calendar.current.startOfDay(for: day)
                    if let hour {
                        set(QuickDue.at(hour: hour, on: start), hasTime: true)
                    } else if showsOtherTime {
                        set(QuickDue.move(otherTime, hasTime: true, to: start), hasTime: true)
                    } else {
                        set(start, hasTime: false)
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("newDateSet")
            }
        } else {
            Button("Pick a date …", systemImage: "calendar") { showsCalendar = true }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("newDatePickDate")
        }
    }

    /// Times as words, as in the due editor (#482): none, four full hours, or any other on a wheel.
    private var times: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 16) {
                timeWord(String(localized: "No time"), on: hour == nil && !showsOtherTime, id: "newDateTime_none") {
                    hour = nil
                    showsOtherTime = false
                }
                ForEach(QuickDue.hours, id: \.self) { at in
                    timeWord(QuickDue.at(hour: at, on: day).formatted(date: .omitted, time: .shortened), on: hour == at,
                             id: "newDateTime_\(at)") {
                        hour = at
                        showsOtherTime = false
                    }
                }
                timeWord(showsOtherTime ? otherTime.formatted(date: .omitted, time: .shortened) : String(localized: "Other time …"),
                         on: showsOtherTime, id: "newDateTime_other") {
                    hour = nil
                    showsOtherTime = true
                }
            }
            if showsOtherTime {
                DatePicker("Time", selection: $otherTime, displayedComponents: .hourAndMinute)
                    #if os(iOS)
                    .datePickerStyle(.wheel)
                    #endif
                    .labelsHidden()
                    .accessibilityIdentifier("newDateOtherTimePicker")
            }
        }
    }

    /// Not a date at all: let it rest, or it is done after all.
    private var decisions: some View {
        HStack(spacing: 24) {
            Button("Park", systemImage: "moon.zzz") {
                act("park") { TaskActions.park(task) }
            }
            .accessibilityIdentifier("newDatePark")
            Button("Complete", systemImage: "checkmark.circle") {
                act("done") { TaskActions.complete(task) }
                completionPulse?.fire()
            }
            .tint(Color("Completed"))
            .accessibilityIdentifier("newDateComplete")
        }
        .buttonStyle(.borderless)
    }

    // MARK: - Pieces

    /// A capsule in the app's accent outline, as the due editor's quick days (#440).
    private func chip(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(.tint)
                .background { Capsule().strokeBorder(.tint) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
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

    // MARK: - Writes

    private func move(to target: TaskActions.MoveTarget) {
        act("new date") { TaskActions.move(task, to: target, contexts: contexts, projects: projects) }
    }

    /// Like the due editor's `setDue`: a day-only date at the start of its day, a user revision.
    private func set(_ date: Date, hasTime: Bool) {
        act("new date") {
            TaskActions.setDue(task, to: date, hasTime: hasTime, contexts: contexts, projects: projects)
        }
    }

    private func act(_ what: String, _ change: () -> Void) {
        change()
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving \(what, privacy: .public) failed: \(error, privacy: .public)")
        }
        onClose()
    }
}
