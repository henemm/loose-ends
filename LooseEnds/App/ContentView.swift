import Combine
import OSLog
import SwiftData
import SwiftUI

/// Start screen on the left, one list on the right. One code path for iPhone, iPad and Mac (ADR-1).
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.capturedAt, order: .reverse) private var tasks: [TaskItem]
    @State private var selection: ViewSelection?
    @State private var isCapturing = false
    @State private var completionPulse = CompletionPulse()
    @State private var showsOnboarding = OnboardingFlow.shouldShow()
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "App")

    /// Nil only in previews; the app always passes its coordinator and notification center.
    var enrichment: EnrichmentCoordinator?
    var notifications: DueNotificationCenter?
    var calendar: CalendarBridge?
    private var captureRequest: CaptureRequest { .shared }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, tasks: tasks)
                .toolbar { captureToolbarItem }
        } detail: {
            if case .task(let id) = selection, let task = tasks.first(where: { $0.id == id }) {
                NavigationStack {
                    TaskDetailView(task: task)
                }
            } else if let selection {
                NavigationStack {
                    TaskListView(selection: selection, tasks: tasks)
                        .toolbar { captureToolbarItem }
                }
            } else {
                Text("Pick a view")
                    .foregroundStyle(.secondary)
            }
        }
        .environment(completionPulse)
        .overlay {
            CompletionKnot(trigger: completionPulse.count)
        }
        .sheet(isPresented: $isCapturing) {
            CaptureView()
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showsOnboarding) { onboarding }
        #else
        .sheet(isPresented: $showsOnboarding) { onboarding }
        #endif
        .task { await startUp() }
        .onChange(of: tasks.count) { _, _ in
            Task { await enrichment?.processPending() }
        }
        .onAppear(perform: consumeCaptureRequest)
        .onChange(of: captureRequest.pending) { _, _ in consumeCaptureRequest() }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            notifications?.rescheduleSoon()
            calendar?.syncSoon()
        }
    }

    /// The capture button sits in the same place on every screen (design briefing, screen 2).
    private var captureToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Capture", systemImage: "plus") { isCapturing = true }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier("captureButton")
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

    /// Seed the default contexts once, fold same-named contexts into one (#157), run the catch-up enrichment pass (ADR-4), then line up
    /// the due reminders.
    private func startUp() async {
        do {
            try ContextSeeder.seedIfNeeded(in: modelContext)
        } catch {
            Self.logger.error("Seeding contexts failed: \(error, privacy: .public)")
        }
        do {
            let merged = try CatalogService.mergeDuplicateContexts(in: modelContext)
            try modelContext.save()
            if merged > 0 { Self.logger.info("Merged \(merged) duplicate contexts") }
        } catch {
            Self.logger.error("Merging duplicate contexts failed: \(error, privacy: .public)")
        }
        await enrichment?.processPending()
        // The onboarding asks first (#29); after it, a launch asks only if the system has not yet.
        if OnboardingFlow.isDone() {
            await notifications?.requestAuthorization()
        }
        await notifications?.reschedule()
        await calendar?.sync()
    }

    /// Control Center and the Action Button open the app straight into capture (ADR-9).
    private func consumeCaptureRequest() {
        guard captureRequest.pending else { return }
        captureRequest.pending = false
        isCapturing = true
    }
}

#Preview {
    ContentView()
        .modelContainer(try! ModelContainerFactory.make(inMemory: true))
}
