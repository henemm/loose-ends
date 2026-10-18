import Combine
import OSLog
import SwiftData
import SwiftUI
import WidgetKit

/// Start screen on the left, one list on the right. One code path for iPhone, iPad and Mac (ADR-1).
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TaskItem.capturedAt, order: .reverse) private var tasks: [TaskItem]
    @State private var selection: ViewSelection?
    @State private var isCapturing = false
    /// ⌘N while the wide start page is open puts the cursor in its field instead of opening the sheet (#472).
    @State private var startFocusRequest = 0
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showsSettings = false
    @State private var completionPulse = CompletionPulse()
    @State private var pendingCompletions = PendingCompletions(window: Self.doneWindow)
    @State private var showsOnboarding = OnboardingFlow.shouldShow()
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "App")

    /// The Undo UI test asks for a long window: on the CI runner a single element lookup has taken
    /// longer than the three seconds (#172). Every other run uses the real window.
    private static var doneWindow: TimeInterval {
        ProcessInfo.processInfo.arguments.contains("--ui-testing-long-done-window") ? 20 : PendingCompletions.defaultWindow
    }

    /// Nil only in previews; the app always passes its coordinator and notification center.
    var enrichment: EnrichmentCoordinator?
    var notifications: DueNotificationCenter?
    var calendar: CalendarBridge?
    private var captureRequest: CaptureRequest { .shared }
    private var openTaskRequest: OpenTaskRequest { .shared }
    private var carryReviewRequest: CarryReviewRequest { .shared }
    private var openViewRequest: OpenViewRequest { .shared }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, tasks: tasks)
                #if os(macOS)
                // 220 to 300 pt, 250 by default (#476): "Wiederkehrend" and "Neues Etikett" were cut off.
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
                #endif
                .toolbar {
                    #if os(macOS)
                    // The detail columns carry the capture button; a second one in the sidebar column
                    // ended up behind the toolbar's overflow arrow (build 71).
                    settingsToolbarItem
                    #else
                    captureToolbarItem
                    settingsToolbarItem
                    #endif
                }
        } detail: {
            if case .task(let id) = selection, let task = tasks.first(where: { $0.id == id }) {
                NavigationStack {
                    withMacCapture(TaskDetailView(task: task))
                }
            } else if case .catalog(let kind) = selection {
                NavigationStack {
                    CatalogPage(kind: kind, tasks: tasks)
                        .toolbar { captureToolbarItem }
                }
            } else if let selection {
                NavigationStack {
                    TaskListView(selection: selection, tasks: tasks)
                        .toolbar { captureToolbarItem }
                }
            } else {
                StartPage(selection: $selection, tasks: tasks, focusRequest: startFocusRequest)
                    .toolbar { captureToolbarItem }
            }
        }
        .environment(completionPulse)
        .environment(pendingCompletions)
        .environment(\.enrichment, enrichment)
        .overlay {
            CompletionKnot(trigger: completionPulse.count)
        }
        .sheet(isPresented: $isCapturing) {
            CaptureView()
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                SettingsView(notifications: notifications)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showsSettings = false }
                                .accessibilityIdentifier("settingsDoneButton")
                        }
                    }
            }
        }
        .sheet(isPresented: Binding(
            get: { !carryReviewRequest.taskIDs.isEmpty },
            set: { if !$0 { carryReviewRequest.taskIDs = [] } }
        )) {
            CarryReviewSheet(taskIDs: carryReviewRequest.taskIDs, tasks: tasks) { carryReviewRequest.taskIDs = [] }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showsOnboarding) { onboarding }
        #else
        .sheet(isPresented: $showsOnboarding) { onboarding }
        #endif
        .task { await startUp() }
        // Restarts whenever the earliest deadline changes: a new Done, an Undo, a commit.
        .task(id: pendingCompletions.nextDeadline) { await commitPendingCompletions() }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the foreground ends every window: a Done must not hang in memory.
            if phase != .active { commitCompletions(all: true) }
            // Back in front, maybe on a new day: "Due today" and the badge follow the date (#299).
            if phase == .active { notifications?.rescheduleSoon() }
            // A task Siri or a shortcut saved while the app sat in the background is still unsorted:
            // the catch-up ran only at launch. Cheap without pending tasks, and one pass at a time.
            if phase == .active { Task { await enrichment?.processPending() } }
        }
        .onChange(of: tasks.count) { _, _ in
            Task { await enrichment?.processPending() }
        }
        .onAppear(perform: consumeCaptureRequest)
        .onChange(of: captureRequest.pending) { _, _ in consumeCaptureRequest() }
        .onAppear(perform: consumeOpenTaskRequest)
        .onChange(of: openTaskRequest.taskID) { _, _ in consumeOpenTaskRequest() }
        .onAppear(perform: consumeOpenViewRequest)
        .onChange(of: openViewRequest.view) { _, _ in consumeOpenViewRequest() }
        // "Neue Aufgabe" in the large widget opens capture by link (#521).
        .onOpenURL { url in
            if NextUpWidgetActions.isCaptureLink(url) { captureRequest.pending = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            notifications?.rescheduleSoon()
            calendar?.syncSoon()
            // The "Next up" widget follows what the app changed, not only every 15 minutes (#307).
            WidgetCenter.shared.reloadTimelines(ofKind: "NextUp")
        }
    }

    /// The task detail has no capture button of its own; on the Mac it takes one, so ⌘N works there too.
    @ViewBuilder
    private func withMacCapture<Content: View>(_ content: Content) -> some View {
        #if os(macOS)
        content.toolbar { captureToolbarItem }
        #else
        content
        #endif
    }

    /// The capture button sits in the same place on every screen (design briefing, screen 2).
    private var captureToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Capture", systemImage: "plus") {
                if selection == nil, sizeClass != .compact {
                    startFocusRequest += 1
                } else {
                    isCapturing = true
                }
            }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier("captureButton")
        }
    }

    /// The gear at the start screen opens the settings (#311). On the Mac it opens the settings
    /// window, the same one as ⌘, and the app menu.
    private var settingsToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            #if os(macOS)
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
            }
            .accessibilityIdentifier("settingsButton")
            #else
            Button("Settings", systemImage: "gearshape") { showsSettings = true }
                .accessibilityIdentifier("settingsButton")
            #endif
        }
    }

    /// Screen 12 (#29), once per device. The model is asked directly: the coordinator only knows
    /// whether it is there when a pass runs.
    private var onboarding: some View {
        OnboardingView(
            modelUnavailableReason: FoundationModelsEnricher().unavailableReason,
            requestNotifications: { await notifications?.requestAuthorization() },
            onFinish: {
                OnboardingFlow.finish()
                showsOnboarding = false
            }
        )
        .interactiveDismissDisabled()
    }

    /// Seed the default contexts once, fold same-named contexts into one (#157) and
    /// English seeded defaults into German ones (#267), run the catch-up enrichment pass (ADR-4), then line up
    /// the due reminders.
    private func startUp() async {
        do {
            try ContextSeeder.seedIfNeeded(in: modelContext)
        } catch {
            Self.logger.error("Seeding contexts failed: \(error, privacy: .public)")
        }
        do {
            let merged = try CatalogService.mergeDuplicateContexts(in: modelContext)
            let english = try CatalogService.mergeEnglishDefaults(in: modelContext)
            try modelContext.save()
            if merged > 0 { Self.logger.info("Merged \(merged) duplicate contexts") }
            if english > 0 { Self.logger.info("Merged \(english) English default contexts into German") }
        } catch {
            Self.logger.error("Merging duplicate contexts failed: \(error, privacy: .public)")
        }
        do {
            // The model's project guesses go (#469); idempotent, so every start may run it.
            let released = try GuessedProjects.release(in: modelContext)
            // Also saves the repair of releases written unseen (build 70), which releases nothing.
            if modelContext.hasChanges { try modelContext.save() }
            if released > 0 { Self.logger.info("Released \(released) guessed projects") }
        } catch {
            Self.logger.error("Releasing guessed projects failed: \(error, privacy: .public)")
        }
        await enrichment?.processPending()
        // The onboarding asks first (#29); after it, a launch asks only if the system has not yet.
        if OnboardingFlow.isDone() {
            await notifications?.requestAuthorization()
        }
        await notifications?.reschedule()
        await calendar?.sync()
    }

    /// Sleeps until the earliest Done window runs out, then completes what is due (#32). A loop,
    /// not one sleep: should the clock wake a hair early, nothing is due yet and the deadline is
    /// unchanged, so no restart would come.
    private func commitPendingCompletions() async {
        while let deadline = pendingCompletions.nextDeadline {
            let wait = deadline.timeIntervalSinceNow
            if wait > 0 {
                do {
                    try await Task.sleep(for: .seconds(wait))
                } catch {
                    // Cancelled because the earliest deadline changed; the restarted task takes over.
                    return
                }
            }
            commitCompletions(all: false)
        }
    }

    private func commitCompletions(all: Bool) {
        let completed = pendingCompletions.commitDue(in: tasks, all: all)
        guard !completed.isEmpty else { return }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving completions failed: \(error, privacy: .public)")
        }
        completionPulse.fire()
    }

    /// The "Open capture" action (Shortcuts, Action Button) opens the app straight into capture (ADR-9, #326).
    private func consumeCaptureRequest() {
        guard captureRequest.pending else { return }
        captureRequest.pending = false
        isCapturing = true
    }

    /// A title tapped in the "Next up" widget opens that task (#307).
    private func consumeOpenTaskRequest() {
        guard let id = openTaskRequest.taskID else { return }
        openTaskRequest.taskID = nil
        selection = .task(id)
    }

    /// "Show" in the morning notification opens "Loose ends" (#518).
    private func consumeOpenViewRequest() {
        guard let view = openViewRequest.view else { return }
        openViewRequest.view = nil
        selection = .system(view)
    }
}

extension EnvironmentValues {
    /// The enrichment pipeline for "Analyze again" in the detail (#34); nil in previews.
    @Entry var enrichment: EnrichmentCoordinator? = nil
}

#Preview {
    ContentView()
        .modelContainer(try! ModelContainerFactory.make(inMemory: true))
}
