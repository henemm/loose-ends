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
                // System controls, as the Calendar app has them (#574): two ways side by side as a
                // segmented control, one of several values as a pop-up menu. Both start without a
                // choice, so nothing is guessed (#203, Teil B).
                if gaps.timing {
                    Picker("When", selection: $answer.timing) {
                        Text("All day").tag(CalendarAsk.Timing?.some(.allDay))
                        Text("At a time").tag(CalendarAsk.Timing?.some(.timed))
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("calendarAskTiming")
                }
                if gaps.timing && answer.timing == .timed {
                    DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("calendarAskTime")
                }
                if gaps.duration || answer.timing == .timed {
                    Section {
                        Picker("Duration", selection: $answer.duration) {
                            Text("Choose").tag(DurationBucket?.none)
                            ForEach(DurationBucket.allCases, id: \.self) { bucket in
                                Text(FieldFormatting.duration(bucket)).tag(DurationBucket?.some(bucket))
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("calendarAskDuration")
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
        .frame(width: 400)
        .frame(minHeight: 300)
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
}
