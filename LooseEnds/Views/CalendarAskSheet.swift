import SwiftUI

/// "Add to calendar" (#203, Teil B): asks only for what the event lacks, so the task never lands in
/// the calendar on a guess. "Add" stays off until every open question is answered.
struct CalendarAskSheet: View {
    @Environment(\.dismiss) private var dismiss
    let gaps: CalendarAsk.Gaps
    /// The task's own day and time, when it has them: the range reads against them.
    let existingStart: Date?
    let onAdd: (CalendarAsk.Answer) -> Void

    @State private var answer = CalendarAsk.Answer(
        date: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())),
        time: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
    )

    var body: some View {
        NavigationStack {
            Form {
                if gaps.date {
                    DatePicker("Date", selection: dateBinding, displayedComponents: .date)
                        .accessibilityIdentifier("calendarAskDate")
                }
                if gaps.timing {
                    Section {
                        choice(Text("All day"), isOn: answer.timing == .allDay, id: "calendarAskAllDay") { answer.timing = .allDay }
                        choice(Text("At a time"), isOn: answer.timing == .timed, id: "calendarAskTimed") { answer.timing = .timed }
                    }
                }
                if gaps.timing && answer.timing == .timed {
                    DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("calendarAskTime")
                }
                if gaps.duration || answer.timing == .timed {
                    Section {
                        ForEach(DurationBucket.allCases, id: \.self) { bucket in
                            choice(Text(FieldFormatting.duration(bucket)),
                                   isOn: answer.duration == bucket, id: "calendarAskDuration_\(bucket.rawValue)") {
                                answer.duration = bucket
                            }
                        }
                    } header: {
                        Text("Duration")
                    } footer: {
                        if let range { Text(range).accessibilityIdentifier("calendarAskRange") }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Add to calendar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("calendarAskCancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add event") {
                        onAdd(answer)
                        dismiss()
                    }
                    .disabled(!CalendarAsk.isComplete(answer, for: gaps))
                    .accessibilityIdentifier("calendarAskConfirm")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 420)
        #endif
    }

    private var dateBinding: Binding<Date> {
        Binding(get: { answer.date ?? Date() }, set: { answer.date = $0 })
    }

    private var timeBinding: Binding<Date> {
        Binding(get: { answer.time ?? Date() }, set: { answer.time = $0 })
    }

    /// "14:00–15:00" once the start and the duration are known.
    private var range: String? {
        guard let duration = answer.duration else { return nil }
        let start: Date?
        if gaps.timing {
            start = answer.timing == .timed ? answer.time : nil
        } else {
            start = existingStart
        }
        guard let start else { return nil }
        let end = start.addingTimeInterval(Double(CalendarSync.length(of: duration)) * 60)
        return CalendarSync.timeRange(start: start, end: end)
    }

    private func choice(_ title: Text, isOn: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                title.foregroundStyle(.primary)
                Spacer()
                if isOn { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
            }
        }
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
