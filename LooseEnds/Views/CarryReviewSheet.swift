import OSLog
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

/// "Look over" in the evening (#414 Schnitt 3, #518): what needs a new date, each decided in one move.
/// Swipe right completes, swipe left moves to tomorrow; the menu also offers the weekend, next week
/// and parking. A task decided leaves the list; what is left comes back in the next evenings.
struct CarryReviewSheet: View {
    let taskIDs: [UUID]
    let tasks: [TaskItem]
    let onClose: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "App")

    /// In the order of the notification; done, parked or moved to a later day drop out.
    private var open: [TaskItem] {
        taskIDs.compactMap { id in tasks.first { $0.id == id } }
            .filter { ViewRules.dueState(of: $0) != .later }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(open) { task in
                    HStack {
                        TaskRow(task: task)
                        Spacer(minLength: 8)
                        Menu {
                            Button("Tomorrow", systemImage: "sunrise") { move(task, to: .tomorrow) }
                            Button("Weekend", systemImage: "calendar") { move(task, to: .weekend) }
                            Button("Next week", systemImage: "calendar") { move(task, to: .nextWeek) }
                            Button("Park", systemImage: "moon.zzz") { act { TaskActions.park(task) } }
                            Button("Complete", systemImage: "checkmark.circle") { act { TaskActions.complete(task) } }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .accessibilityLabel("Decide")
                        }
                        .accessibilityIdentifier("carryReviewMenu_\(task.id.uuidString)")
                    }
                    .swipeActions(edge: .leading) {
                        Button("Complete", systemImage: "checkmark.circle") { act { TaskActions.complete(task) } }
                            .tint(Color("Completed"))
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Tomorrow", systemImage: "sunrise") { move(task, to: .tomorrow) }
                    }
                }
            }
            .overlay {
                if open.isEmpty {
                    Text("Every one has a new date.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Needs a new date")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                        .accessibilityIdentifier("carryReviewDoneButton")
                }
            }
        }
    }

    private func move(_ task: TaskItem, to target: TaskActions.MoveTarget) {
        act { TaskActions.move(task, to: target, contexts: contexts, projects: projects) }
    }

    private func act(_ change: () -> Void) {
        change()
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving the evening look failed: \(error, privacy: .public)")
        }
    }
}
