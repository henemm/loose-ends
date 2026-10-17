import OSLog
import SwiftData
import SwiftUI

/// The date under the knot and the one sentence of the day (#426). The iPhone start list and the
/// wide start page (#408) show the same two lines.
struct StartHeader: View {
    let tasks: [TaskItem]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        // Once a minute, so the line turns to the look back at 16:00 without a save (#426).
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    // The knot, first of its three places (#180, rule 1). Grey like the date: it is
                    // the mark, not something to tap (ADR-14).
                    ThreadGlyph(form: .knot, lineWidth: 1.5)
                        .frame(width: metrics(30), height: metrics(16))
                    Text(timeline.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(metrics.caption)
                        .textCase(.uppercase)
                        .tracking(metrics.captionTracking)
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("startHeader")
                // The one fact that stands out today, from 16:00 a look back (#426). Content, so New York.
                Text(StartHeadlineText.sentence(StartHeadline.of(tasks, now: timeline.date)))
                    .font(metrics.headline)
                    .tracking(-0.3)
                    .lineSpacing(0)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("startHeadline")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// What the wide window shows while no view is chosen (#408, draft "Papier und Faden", cut 1): the
/// sentence of the day, a field to say something, and "Now". iPad in a wide window and the Mac;
/// the iPhone opens its start list instead.
struct StartPage: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(CompletionPulse.self) private var completionPulse: CompletionPulse?
    @Environment(PendingCompletions.self) private var pendingCompletions: PendingCompletions?
    @Query(sort: \TaskContext.sortOrder) private var contexts: [TaskContext]
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Binding var selection: ViewSelection?
    let tasks: [TaskItem]
    /// ⌘N on the start page: each change puts the cursor in the field (#472).
    var focusRequest = 0
    @State private var text = ""
    @State private var saveFailed = false
    @State private var pendingTaskDelete: TaskItem?
    @State private var confirmingTaskDelete = false
    @State private var datingTask: TaskItem?
    @FocusState private var fieldFocused: Bool
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "StartPage")

    var body: some View {
        // The right column needs room: from about 900 pt of width it stands next to the list (#473).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                listColumn
                SideColumnView(tasks: tasks, selection: $selection)
            }
            .frame(minWidth: 900)
            listColumn
        }
        .accessibilityIdentifier("startPage")
        .taskInteractionDialogs(actions)
        .onChange(of: focusRequest) { _, _ in fieldFocused = true }
    }

    private var listColumn: some View {
        let metrics = StartMetrics(typeSize)
        return List {
            StartHeader(tasks: tasks)
                .padding(.top, 14)
                .padding(.bottom, 16)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
            captureField
                .padding(.bottom, 8)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
            LeftoversCard(tasks: tasks)
            NowBlock(tasks: ViewRules.now(in: tasks).all) { nowRow($0, metrics) }
        }
        .listStyle(.plain)
        .paperGround()
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        // The paper runs edge to edge: outside the 720 pt column the window showed white bars (build 71).
        .background(Paper.ground.ignoresSafeArea())
    }

    /// The "Now" rows act as on the iPhone (#472): Done with the Undo window, swipes, the menu on
    /// right click. One set of actions, the one "Next up" uses (#303).
    private var actions: TaskInteractions {
        TaskInteractions(
            kind: .next, tasks: tasks, contexts: contexts, projects: projects, modelContext: modelContext,
            pendingCompletions: pendingCompletions, completionPulse: completionPulse,
            pendingDelete: $pendingTaskDelete, confirmingDelete: $confirmingTaskDelete, datingTask: $datingTask,
            didDelete: { id in if selection == .task(id) { selection = nil } }
        )
    }

    @ViewBuilder
    private func nowRow(_ task: TaskItem, _ metrics: StartMetrics) -> some View {
        let actions = self.actions
        let row = TaskRow(task: task, identifierPrefix: "startNowRow_")
        if actions.isPending(task) {
            actions.pendingRow(task, row)
        } else {
            Button { selection = .task(task.id) } label: {
                row
                    .padding(.vertical, 11)
                    .environment(\.startMetrics, metrics)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .startRow(metrics)
            .swipeActions(edge: .leading, allowsFullSwipe: true) { actions.leadingActions(task) }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) { actions.trailingActions(task) }
            .contextMenu { actions.menu(task) }
            .paperRow()
        }
    }

    /// Saving is the same write path as the capture sheet; the text is kept as typed (ADR-3).
    private var captureField: some View {
        TextField("What should I remember?", text: $text)
            .textFieldStyle(.plain)
            .font(StartMetrics(typeSize).rowTitle)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator))
            .focused($fieldFocused)
            .onSubmit(save)
            .submitLabel(.done)
            .accessibilityIdentifier("startCaptureField")
            .alert("Could not save", isPresented: $saveFailed) {
                Button("OK") {}
            }
    }

    private func save() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try CaptureService.save(text, via: .app, in: modelContext)
            text = ""
        } catch {
            Self.logger.error("Capture from the start page failed: \(error, privacy: .public)")
            saveFailed = true
        }
    }
}
