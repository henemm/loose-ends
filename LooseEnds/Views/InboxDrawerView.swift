import OSLog
import SwiftData
import SwiftUI

/// The "New" button with the writing line under it, and the drawer the first Return opens (#601,
/// form 2, Henning 2026-10-21). One row of the start list, so the whole thing moves as one piece:
/// the button's tint spreads into a body that holds this sitting's rows, the line stays its last row,
/// and the end of the entry folds it back into the button. Every sentence is a task the moment
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
    /// The head's short glow when a row arrives.
    @State private var glowing = false
    @FocusState private var writing: Bool
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "StartPage")
    /// Opening, folding and a new row take one soft curve, no spring: paper, not rubber.
    private static let softMotion: Animation = .smooth(duration: 0.4)

    private var count: Int { ViewRules.tasks(for: .new, in: tasks).count }
    private var rows: [TaskItem] { drawer.rows(in: tasks) }
    private var isOpen: Bool { drawer.isOpen }

    var body: some View {
        let metrics = StartMetrics(typeSize)
        VStack(spacing: 0) {
            if count > 0 || isOpen {
                head(metrics)
                    .transition(.opacity)
            }
            ForEach(rows) { task in
                row(task, metrics)
                    .transition(rowTransition)
            }
            line(metrics)
        }
        // The body's tint: the button's own, spread thin, there only while the drawer is open.
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(isOpen ? 0.06 : 0))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.accentColor.opacity(glowing ? 0.35 : 0), lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    /// The button as it was (#368): one accent surface while closed. Open, its tint hands over to the
    /// body and the chevron turns down: the button has become the head of what it holds.
    private func head(_ metrics: StartMetrics) -> some View {
        Button {
            open(.system(.new))
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "tray")
                Text("\(count) to look over")
                    .contentTransition(.numericText(value: Double(count)))
                    .animation(motion, value: count)
                Spacer()
                Image(systemName: "chevron.right")
                    .imageScale(.small)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))
            }
            .font(metrics.inbox)
            .foregroundStyle(.tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(isOpen ? 0 : 0.12), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("inboxBar")
    }

    /// A row of the drawer: the lists' row, a hairline above, a tap opens the task.
    private func row(_ task: TaskItem, _ metrics: StartMetrics) -> some View {
        Button {
            open(.task(task.id))
        } label: {
            TaskRow(task: task, identifierPrefix: "drawerRow_")
                .environment(\.startMetrics, metrics)
                .padding(.vertical, 11)
                .padding(.horizontal, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Rectangle().fill(.separator).frame(height: 0.5).padding(.horizontal, 12)
        }
    }

    /// The line on the paper: no box, the text where the rows' titles stand, a hairline under it a
    /// shade firmer than the rows'. Return saves and keeps the cursor; an empty Return does nothing.
    private func line(_ metrics: StartMetrics) -> some View {
        TextField("What should I remember?", text: $text)
            .textFieldStyle(.plain)
            .font(metrics.rowTitle)
            .focused($writing)
            .submitLabel(.return)
            .onSubmit(save)
            .padding(.leading, 12 + metrics.marginWidth + 12)
            .padding(.trailing, 12)
            .padding(.top, 13)
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.primary.opacity(0.28))
                    .frame(height: 1)
                    .padding(.leading, 12 + metrics.marginWidth + 12)
                    .padding(.trailing, 12)
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
            glow()
            AccessibilityNotification.Announcement(String(localized: "Filed in New: \(item.displayTitle)")).post()
        } catch {
            Self.logger.error("Capture from the writing line failed: \(error, privacy: .public)")
            saveFailed = true
        }
        writing = true
    }

    /// The head lights up for a moment as the number changes, then settles.
    private func glow() {
        glowing = true
        withAnimation(.easeOut(duration: 0.8).delay(0.1)) { glowing = false }
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
