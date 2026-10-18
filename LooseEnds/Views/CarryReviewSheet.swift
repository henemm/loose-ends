import SwiftData
import SwiftUI

/// Bridge from the evening notification's "Look over" to the app scene (#414 Schnitt 3), like
/// `OpenTaskRequest`.
@MainActor
@Observable
final class CarryReviewRequest {
    static let shared = CarryReviewRequest()
    var taskIDs: [UUID] = []
}

/// Bridge from the morning notification's "Show" to the app scene (#518): opens a view, "Loose ends".
@MainActor
@Observable
final class OpenViewRequest {
    static let shared = OpenViewRequest()
    var view: ViewKind?
}

/// "Look over" in the evening (#414 Schnitt 3, #518, #550): the tasks of the notification, each with the
/// "New date" button of the lists (#548) over the trace of what had been planned. The button opens the
/// date choice; nothing is hidden in a swipe or a menu (Henning, 2026-10-18: "Was soll ich hier
/// machen?"). A task decided leaves the list; what is left comes back in the next evenings.
struct CarryReviewSheet: View {
    let taskIDs: [UUID]
    let tasks: [TaskItem]
    /// The silent time of a task without one (#550): a day-only date is behind after it.
    let reminderTime: DueReminders.Time
    let onClose: () -> Void
    @State private var choosing: TaskItem?

    /// In the order of the notification; done, parked or given a date still ahead drop out.
    private var open: [TaskItem] {
        taskIDs.compactMap { id in tasks.first { $0.id == id } }
            .filter { NewDateRule.passed($0, reminderTime: reminderTime, now: Date()) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(open) { task in
                    TaskRow(task: task, note: task.parent.map { String(localized: "Subtask of \($0.displayTitle)") },
                            onNewDate: { choosing = task }, asksNewDate: true)
                        .paperRow()
                        .wideListRow()
                }
            }
            .paperList()
            .overlay {
                if open.isEmpty {
                    Text("Every one has a new date.")
                        .font(.title3)
                        .fontDesign(.serif)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("carryReviewEmpty")
                }
            }
            .navigationTitle("Needs a new date")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                        .accessibilityIdentifier("carryReviewDoneButton")
                }
            }
            .sheet(item: $choosing) { task in
                NewDateSheet(task: task) { choosing = nil }
            }
        }
    }
}
