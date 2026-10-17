import OSLog
import SwiftData
import SwiftUI

/// "Loose ends" on the start screen (#518, Henning 2026-10-17): what was due before today and is
/// still open, asked once each morning — Today, Tomorrow, Weekend or Park. Until a task is sorted
/// it stays out of "Now" and off the app icon, so a day no longer starts full. Rows of the start
/// list, like the other zones; nothing shows when nothing is left.
struct LeftoversCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    let tasks: [TaskItem]
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "StartPage")

    var body: some View {
        let leftovers = ViewRules.leftovers(in: tasks)
        if !leftovers.isEmpty {
            ZoneCaption("Loose ends: \(leftovers.count)")
            ForEach(leftovers) { task in
                row(task)
            }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        let metrics = StartMetrics(typeSize)
        // The same row as in "Now" (margin, serif title, trait line), the four choices under the title.
        return VStack(alignment: .leading, spacing: 8) {
            TaskRow(task: task, identifierPrefix: "leftoverRow_")
                .environment(\.startMetrics, metrics)
            // Wraps where four German words do not fit on one line (larger text, the Mac's narrow column).
            FlowLayout(spacing: 8) {
                choice("Today", .today, task)
                choice("Tomorrow", .tomorrow, task)
                choice("Weekend", .weekend, task)
                choice("Park", .park, task)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("leftover_\(task.id.uuidString)")
        .listRowSeparator(.hidden)
        .startRow(metrics)
        .paperRow()
    }

    private func choice(_ title: LocalizedStringKey, _ choice: TaskActions.LeftoverChoice, _ task: TaskItem) -> some View {
        Button(title) {
            withAnimation(.snappy) {
                TaskActions.sortLeftover(task, as: choice, contexts: contexts, projects: projects)
            }
            save()
        }
        .accessibilityIdentifier("leftover_\(choice)_\(task.id.uuidString)")
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Sorting a leftover failed: \(error, privacy: .public)")
        }
    }
}
