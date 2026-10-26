import OSLog
import SwiftData
import SwiftUI

/// "New" with its sentence, the writing line, and the drawer the first Return opens (#601, form 2,
/// Henning 2026-10-21; calm since #677, draft C3; variant B since #693): no tinted surface, "New" in
/// the margin and "3 to look over" beside it in accent open "New", the rows of this sitting rise
/// between that head and the line, and the end of the entry folds them away. One row of the start
/// list, so the whole thing moves as one piece. Every sentence is a task the moment
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
    /// The sentence lights up once as the folded rows reach it (#693).
    @State private var headGlow = false
    @FocusState private var writing: Bool
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "StartPage")
    /// Opening, folding and a new row take one soft curve, no spring: paper, not rubber.
    private static let softMotion: Animation = .smooth(duration: 0.4)

    private var count: Int { ViewRules.tasks(for: .new, in: tasks).count }
    private var rows: [TaskItem] { drawer.rows(in: tasks) }

    var body: some View {
        let metrics = StartMetrics(typeSize)
        VStack(spacing: 0) {
            head(metrics)
            ForEach(rows) { task in
                row(task, metrics)
                    .transition(rowTransition)
            }
            line(metrics)
                .padding(.leading, metrics.marginWidth + 12)
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

    /// "New" in the margin, "3 to look over" beside it at the rows' title size (#693, variant B,
    /// Henning 2026-10-26): the small margin word alone went under on the page. Accent, because a
    /// tap on either opens "New"; gone while nothing waits there.
    @ViewBuilder
    private func head(_ metrics: StartMetrics) -> some View {
        if count > 0 {
            Button {
                open(.system(.new))
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("New")
                        .font(metrics.margin.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: metrics.marginWidth, alignment: .trailing)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(count) to look over")
                            .font(metrics.rowTitle)
                            .contentTransition(.numericText(value: Double(count)))
                            .animation(motion, value: count)
                        Image(systemName: "chevron.right")
                            .font(metrics.margin.weight(.semibold))
                    }
                    // The glow reaches past the words, so the text keeps the titles' edge.
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(headGlow ? 0.14 : 0))
                    )
                    .padding(.horizontal, -6)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.tint)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("\(count) to look over"))
            .accessibilityIdentifier("inboxBar")
            .transition(.opacity)
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
    /// question always shows, in italics (#693): without it the empty line read as a divider.
    /// Return saves and keeps the cursor; an empty Return does nothing.
    private func line(_ metrics: StartMetrics) -> some View {
        TextField("", text: $text, prompt: Text("What should I remember?").italic())
            .textFieldStyle(.plain)
            .font(metrics.rowTitle)
            .focused($writing)
            .submitLabel(.return)
            .onSubmit(save)
            // Close under the sentence (#677): an empty line must not open a gap above "Now".
            .padding(.top, 4)
            .padding(.bottom, 8)
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
        let hadRows = !rows.isEmpty
        if animated {
            withAnimation(motion) { drawer.close() }
            if hadRows && !reduceMotion { glowHead() }
        } else {
            drawer.close()
        }
    }

    /// The folded rows slide up into the head; as they arrive the sentence lights up once and fades,
    /// so the eye follows them into "New" (#693, Henning 2026-10-26). Not under reduced motion.
    private func glowHead() {
        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(250))
                withAnimation(.easeOut(duration: 0.2)) { headGlow = true }
                try await Task.sleep(for: .milliseconds(200))
            } catch {
                headGlow = false
                return
            }
            withAnimation(.easeIn(duration: 0.4)) { headGlow = false }
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
