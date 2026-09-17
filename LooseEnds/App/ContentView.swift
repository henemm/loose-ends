import OSLog
import SwiftData
import SwiftUI

/// Views on the left, one list on the right. Placeholder navigation until the tile start screen
/// from the design canvas is built. One code path for iPhone, iPad and Mac (ADR-1).
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.capturedAt, order: .reverse) private var tasks: [TaskItem]
    @State private var selection: ViewKind?
    @State private var isCapturing = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "App")

    /// Nil only in previews; the app always passes its coordinator.
    var enrichment: EnrichmentCoordinator?
    private var captureRequest: CaptureRequest { .shared }

    var body: some View {
        NavigationSplitView {
            List(ViewKind.allCases.filter(\.isSystem), id: \.self, selection: $selection) { kind in
                HStack {
                    Text(String(localized: kind.titleKey))
                    Spacer()
                    Text("\(ViewRules.tasks(for: kind, in: tasks).count)")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("viewRow_\(kind.rawValue)")
            }
            .navigationTitle("Views")
            .toolbar { captureToolbarItem }
        } detail: {
            if let selection {
                let shown = ViewRules.tasks(for: selection, in: tasks)
                NavigationStack {
                    List(shown) { task in
                        NavigationLink {
                            TaskDetailView(task: task)
                        } label: {
                            TaskRow(task: task)
                        }
                    }
                    .overlay {
                        if shown.isEmpty {
                            Text("Nothing here")
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("emptyViewLabel")
                        }
                    }
                    .navigationTitle(String(localized: selection.titleKey))
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

/// One row: the title, or the raw text while nothing better exists (raw text reads as raw text).
/// The spark marks unseen AI changes (marker variant C).
struct TaskRow: View {
    let task: TaskItem

    var body: some View {
        HStack(spacing: 6) {
            Text(task.displayTitle)
                .italic(task.title == nil || task.status == .unverified)
            if task.hasUnseenAIRevisions {
                Image(systemName: "sparkle")
                    .imageScale(.small)
                    .foregroundStyle(.tint)
                    .accessibilityLabel("Changed by AI")
                    .accessibilityIdentifier("aiMarker_\(task.id.uuidString)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("taskRow_\(task.id.uuidString)")
    }
}

#Preview {
    ContentView()
        .modelContainer(try! ModelContainerFactory.make(inMemory: true))
}
