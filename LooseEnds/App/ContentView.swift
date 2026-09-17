import OSLog
import SwiftData
import SwiftUI

/// Start screen on the left, one list on the right. One code path for iPhone, iPad and Mac (ADR-1).
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.capturedAt, order: .reverse) private var tasks: [TaskItem]
    @State private var selection: ViewSelection?
    @State private var isCapturing = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "App")

    /// Nil only in previews; the app always passes its coordinator.
    var enrichment: EnrichmentCoordinator?
    private var captureRequest: CaptureRequest { .shared }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, tasks: tasks)
                .navigationTitle("Views")
                .toolbar { captureToolbarItem }
        } detail: {
            if let selection {
                NavigationStack {
                    TaskListView(selection: selection, tasks: tasks)
                        .toolbar { captureToolbarItem }
                }
            } else {
                Text("Pick a view")
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $isCapturing) {
            CaptureView()
        }
        .task { await startUp() }
        .onChange(of: tasks.count) { _, _ in
            Task { await enrichment?.processPending() }
        }
        .onAppear(perform: consumeCaptureRequest)
        .onChange(of: captureRequest.pending) { _, _ in consumeCaptureRequest() }
    }

    /// The capture button sits in the same place on every screen (design briefing, screen 2).
    private var captureToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Capture", systemImage: "plus") { isCapturing = true }
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityIdentifier("captureButton")
        }
    }

    /// Seed the default contexts once, then run the catch-up enrichment pass (ADR-4).
    private func startUp() async {
        do {
            try ContextSeeder.seedIfNeeded(in: modelContext)
        } catch {
            Self.logger.error("Seeding contexts failed: \(error, privacy: .public)")
        }
        await enrichment?.processPending()
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
