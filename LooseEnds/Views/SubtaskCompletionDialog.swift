import SwiftUI

extension View {
    /// "Complete" on a task with open subtasks (#565, Schnitt 3, Henning 2026-10-20): asks whether
    /// they go along instead of closing them silently. Cancel leaves everything as it was. The
    /// detail and every list's gestures share it; widget and notification cannot ask and keep them open.
    func completesWithSubtasks(asking task: Binding<TaskItem?>, perform: @escaping (TaskItem, Bool) -> Void) -> some View {
        confirmationDialog(
            "Some subtasks are still open",
            isPresented: Binding(get: { task.wrappedValue != nil }, set: { if !$0 { task.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: task.wrappedValue
        ) { asked in
            Button("Complete all") { perform(asked, true) }
                .accessibilityIdentifier("completeAllSubtasks")
            Button("Keep open ones") { perform(asked, false) }
                .accessibilityIdentifier("completeKeepOpenSubtasks")
            Button("Cancel", role: .cancel) {}
        } message: { asked in
            Text("Open subtasks: \(Subtasks.open(of: asked).count)")
        }
    }
}
