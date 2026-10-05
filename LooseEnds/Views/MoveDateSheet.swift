import SwiftUI

/// "Move → Date…" (#33): one calendar, one day. Moving keeps the task's day only, like the other
/// move targets; the time of a timed task is dropped (`TaskActions.move`).
struct MoveDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var day: Date
    let onMove: (Date) -> Void

    init(start: Date, onMove: @escaping (Date) -> Void) {
        _day = State(initialValue: start)
        self.onMove = onMove
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Due", selection: $day, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .accessibilityIdentifier("moveDatePicker")
            }
            .formStyle(.grouped)
            .navigationTitle("Move to")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        onMove(day)
                        dismiss()
                    }
                    .accessibilityIdentifier("moveDateConfirm")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 420)
        #endif
    }
}
