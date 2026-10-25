import OSLog
import SwiftData
import SwiftUI

/// The writing line with "New" in its margin, and the drawer the first Return opens (#601, form 2,
/// Henning 2026-10-21; calm since #677, draft C3): no tinted surface, the margin word "New 3" in
/// accent opens "New", the rows of this sitting rise above the line, and the end of the entry folds
/// them away. One row of the start list, so the whole thing moves as one piece. Every sentence is a task the moment
/// Return is pressed (`CaptureService`, the rules read it at once), so the number counts it honestly
/// and the row shows it sorted. The rows are the lists' rows; a tap opens the task. Shared by the
/// iPhone start list and the wide start page. Only for typing: no microphone (the keyboard has one,
/// "+" opens the sheet with speech).
struct InboxDrawerView: View {
    let tasks: [TaskItem]
    /// Opens a list or a task; the host's navigation decides how.
    let open: (ViewSelection) -> Void
    /// What the host shows: a change (a task opened, a list chosen) ends the entry.
    var selection: ViewSelection?
    /// ⌘N on the Mac (#472): each change puts the cursor in the line.
    var focusRequest = 0
    /// A tap beside the line on the iPhone (the sentence of the day): each change ends the entry.
    var endRequest = 0
    /// Tells the host whether the line holds the focus, so the Mac's row keys leave it alone (#480).
    var onWritingFocus: (Bool) -> Void = { _ in }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawer = InboxDrawer()
    @State private var text = ""
    @State private var saveFailed = false
    @FocusState private var writing: Bool
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "StartPage")
    /// Opening, folding and a new row take one soft curve, no spring: paper, not rubber.
    private static let softMotion: Animation = .smooth(duration: 0.4)

    private var count: Int { ViewRules.tasks(for: .new, in: tasks).count }
    private var rows: [TaskItem] { drawer.rows(in: tasks) }

    var body: some View {
        let metrics = StartMetrics(typeSize)
        VStack(spacing: 0) {
            ForEach(rows) { task in
                row(task, metrics)
                    .transition(rowTransition)
            }
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                newWord(metrics)
                    .frame(width: metrics.marginWidth, alignment: .trailing)
                line(metrics)
            }
        }
        // No identifier on the stack: with the line as its only child it is transparent to
        // accessibility, and an outer identifier replaced the line's own (CI run 39556748082).
        .alert("Could not save", isPresented: $saveFailed) {
            Button("OK") {}
        }
        .onChange(of: writing) { _, focused in
            onWritingFocus(focused)
            if !focused { endEntryAfterFocusSettles() }
        }
        .onChange(of: selection) { _, _ in endEntry(animated: true) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { endEntry(animated: false) }
        }
        .onChange(of: focusRequest) { _, _ in writing = true }
        .onChange(of: endRequest) { _, _ in writing = false }
    }

    /// "New 3" in the line's margin (#677): accent, because a tap opens "New"; gone while nothing
    /// waits there. The label keeps the old words, so VoiceOver still says what waits.
    @ViewBuilder
    private func newWord(_ metrics: StartMetrics) -> some View {
        if count > 0 {
            Button {
                open(.system(.new))
            } label: {
                Text("New \(count)")
                    .font(metrics.margin.weight(.semibold))
                    .foregroundStyle(.tint)
                    .contentTransition(.numericText(value: Double(count)))
                    .animation(motion, value: count)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    // A thumb-sized target around the small word.
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(count) to look over"))
            .accessibilityIdentifier("inboxBar")
            .transition(.opacity)
        } else {
            Color.clear.frame(height: 1)
        }
    }

    /// A row of the drawer: the lists' row, a hairline above at the titles' edge, a tap opens the task.
    private func row(_ task: TaskItem, _ metrics: StartMetrics) -> some View {
        Button {
            open(.task(task.id))
        } label: {
            TaskRow(task: task, identifierPrefix: "drawerRow_")
                .environment(\.startMetrics, metrics)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(.separator).frame(height: 0.5).padding(.leading, metrics.marginWidth + 12)
        }
    }

    /// The line on the paper: no box, the text at the rows' titles' edge, a hairline under it. The
    /// question shows only while the cursor is in the line (#677): unfocused it is just the line.
    /// Return saves and keeps the cursor; an empty Return does nothing.
    private func line(_ metrics: StartMetrics) -> some View {
        TextField("", text: $text, prompt: writing ? Text("What should I remember?") : nil)
            .textFieldStyle(.plain)
            .font(metrics.rowTitle)
            .focused($writing)
            .submitLabel(.return)
            .onSubmit(save)
            .padding(.top, 13)
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.22))
                    .frame(height: 0.5)
            }
            .accessibilityLabel(Text("Write a task"))
            .accessibilityIdentifier("startCaptureField")
            .exitEndsEntry { writing = false }
    }

    /// A new row rises from the line into its place; on folding the rows slide up under the head.
    private var rowTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    private var motion: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : Self.softMotion
    }

    /// Return: the same write path as the capture sheet (ADR-3), then the drawer takes the task. The
    /// rules run through the host's catch-up pass right after the save. The cursor stays.
    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            writing = true
            return
        }
        do {
            let item = try CaptureService.save(text, via: .app, in: modelContext)
            text = ""
            withAnimation(motion) { drawer.didCapture(item.id) }
            AccessibilityNotification.Announcement(String(localized: "Filed in New: \(item.displayTitle)")).post()
        } catch {
            Self.logger.error("Capture from the writing line failed: \(error, privacy: .public)")
            saveFailed = true
        }
        writing = true
    }

    /// Return takes the focus away and gives it back within the same turn of the run loop; only a
    /// focus that stays gone (a tap beside, the keyboard put away, Escape) ends the entry.
    private func endEntryAfterFocusSettles() {
        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                return
            }
            if !writing { endEntry(animated: true) }
        }
    }

    private func endEntry(animated: Bool) {
        guard drawer.isOpen else { return }
        if animated {
            withAnimation(motion) { drawer.close() }
        } else {
            drawer.close()
        }
    }
}

private extension View {
    /// Escape on the Mac leaves the line; the iPhone has no such key.
    @ViewBuilder
    func exitEndsEntry(_ action: @escaping () -> Void) -> some View {
        #if os(macOS)
        onExitCommand(perform: action)
        #else
        self
        #endif
    }
}
