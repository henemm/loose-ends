import OSLog
import SwiftData
import SwiftUI

/// "Now" on the watch (#699): the app icon opens here, the complication opens capture. The rows are
/// `ViewRules.nowRows`, so the watch shows the same tasks as "Now" everywhere (#637). A tap completes
/// after the three-second window, a second tap takes it back (ADR-17).
struct WatchNowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var tasks: [TaskItem]
    @State private var pending = PendingCompletions()
    @State private var capturing = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Watch")

    var body: some View {
        NavigationStack {
            List {
                Button {
                    capturing = true
                } label: {
                    Label("Capture", systemImage: "mic")
                }
                .accessibilityIdentifier("watch.now.capture")
                let rows = ViewRules.nowRows(in: tasks)
                if rows.isEmpty {
                    Text("Nothing presses today.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("watch.now.empty")
                }
                ForEach(rows) { task in
                    row(task)
                }
            }
            .navigationTitle("Now")
            .navigationDestination(isPresented: $capturing) { WatchCaptureView() }
        }
        .onOpenURL { url in
            if NextUpWidgetActions.isCaptureLink(url) { capturing = true }
        }
        .task(id: pending.nextDeadline) { await commitPending() }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the foreground ends every window now, as on the iPhone.
            if phase == .background { commit(all: true) }
        }
    }

    private func row(_ task: TaskItem) -> some View {
        let done = pending.isPending(task.id)
        return Button {
            if !pending.cancel(task.id) { pending.schedule(task.id) }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? AnyShapeStyle(.green) : AnyShapeStyle(.tint))
                Text(task.displayTitle)
                    .strikethrough(done)
                    .lineLimit(3)
            }
        }
        .accessibilityIdentifier("watch.now.row")
        .accessibilityValue(done ? Text("Done") : Text(verbatim: ""))
    }

    /// Sleeps until the earliest window runs out, then completes what is due (as `ContentView`).
    private func commitPending() async {
        while let deadline = pending.nextDeadline {
            let wait = deadline.timeIntervalSinceNow
            if wait > 0 {
                do {
                    try await Task.sleep(for: .seconds(wait))
                } catch {
                    return
                }
            }
            commit(all: false)
        }
    }

    private func commit(all: Bool) {
        let completed = pending.commitDue(in: tasks, all: all)
        guard !completed.isEmpty else { return }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving completions failed: \(error, privacy: .public)")
        }
    }
}
