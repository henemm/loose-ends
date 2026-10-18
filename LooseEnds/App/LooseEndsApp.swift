import OSLog
import SwiftData
import SwiftUI

@main
struct LooseEndsApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var macDelegate
    #endif
    let container: ModelContainer
    let enrichment: EnrichmentCoordinator
    let notifications: DueNotificationCenter
    let calendar: CalendarBridge

    init() {
        LaunchTimings.mark(.initStart)
        // Startargument der Kaltstart-Messung (#22): öffnet die Erfassung wie das Control.
        if LaunchTimings.kind(arguments: ProcessInfo.processInfo.arguments) == .automated {
            CaptureRequest.shared.pending = true
        }
        #if DEBUG
        Self.initializeCloudKitSchemaIfAsked()
        #endif
        LaunchTimings.mark(.containerStart)
        do {
            container = try ModelContainerFactory.make()
        } catch {
            fatalError("Could not open the Loose Ends store: \(error)")
        }
        LaunchTimings.mark(.containerEnd)
        let enricher: any TaskEnricher = ModelContainerFactory.isUITesting ? ModelOffEnricher() : FoundationModelsEnricher()
        enrichment = EnrichmentCoordinator(enricher: enricher, container: container)
        #if os(iOS)
        Self.seedPlaceTaskIfAsked(in: container)
        let places: (any PlaceReconciling)? = PlaceNotificationCenter(container: container)
        #else
        let places: (any PlaceReconciling)? = nil
        #endif
        notifications = DueNotificationCenter(container: container, places: places)
        notifications.activate()
        calendar = CalendarBridge(container: container)
        if ModelContainerFactory.isUITesting { MainThreadWatchdog.start() }
        LaunchTimings.mark(.initEnd)
    }

    #if DEBUG
    /// With `-LEInitializeCloudKitSchema` the process only writes the CloudKit schema and exits
    /// (0 success, 1 failure, #175) — before the factory, so the app-group store is never opened.
    private static func initializeCloudKitSchemaIfAsked() {
        let isTestRun = ModelContainerFactory.isRunningTests || ModelContainerFactory.isUITesting
        guard CloudKitSchemaInitializer.shouldRun(
            arguments: ProcessInfo.processInfo.arguments, isDebugBuild: true, isTestRun: isTestRun
        ) else { return }
        do {
            try CloudKitSchemaInitializer.run()
            exit(0)
        } catch {
            Logger(subsystem: "com.henning.looseends", category: "Persistence")
                .error("Schema-Initialisierung fehlgeschlagen: \(error, privacy: .public)")
            exit(1)
        }
    }
    #endif

    #if os(iOS)
    /// The task the pushed place notification names in `PlaceNotificationTapTests` (#240), only under
    /// `--ui-testing-places` and only in the in-memory store. Lined up, so it stands on the start screen.
    private static func seedPlaceTaskIfAsked(in container: ModelContainer) {
        guard ModelContainerFactory.isUITesting,
              ProcessInfo.processInfo.arguments.contains(PlaceNotifications.testArgument),
              let id = UUID(uuidString: "00000000-0000-0000-0000-000000000240") else { return }
        let task = TaskItem(rawText: "UI test place")
        task.id = id
        task.title = "UI test place"
        task.status = .active
        task.nextRank = 1
        task.place = TaskPlace(name: "Post office", latitude: 51.99563, longitude: 7.71357, event: .arrive)
        container.mainContext.insert(task)
        do {
            try container.mainContext.save()
        } catch {
            Logger(subsystem: "com.henning.looseends", category: "Notifications")
                .error("Seeding the place test task failed: \(error, privacy: .public)")
        }
    }
    #endif

    /// The design gallery (#182) asks for dark mode by launch argument: the device-wide switch
    /// from XCUITest did not reach the app on the CI simulator. Nil follows the system.
    private static var uiTestColorScheme: ColorScheme? {
        ProcessInfo.processInfo.arguments.contains("--ui-testing-dark") ? .dark : nil
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(enrichment: enrichment, notifications: notifications, calendar: calendar)
                .environment(calendar)
                .preferredColorScheme(Self.uiTestColorScheme)
        }
        .modelContainer(container)
        #if os(macOS)
        // The start page with its right column needs about 1120 pt (sidebar 220 + page 900, #473); without
        // a size the window opened at 900 x 450 and the column and the sidebar's names were cut (#514).
        .defaultSize(width: 1200, height: 780)
        Settings {
            SettingsView(notifications: notifications)
                .environment(calendar)
        }
        // Quick capture from the menu bar (#356); the logo's thread, the one exception of the
        // SF Symbols rule (#350, #366).
        MenuBarExtra {
            MenuBarCaptureView(enrichment: enrichment)
                .modelContainer(container)
        } label: {
            Image(nsImage: MenuBarThreadImage.image)
                .accessibilityLabel("Loose Ends")
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}

/// The model as UI tests see it: absent (#228). The iOS 27 simulator carries an on-device model;
/// its runs race the tests (#208) and load the CI runner until XCTest gets no accessibility
/// snapshot ("Timed out while evaluating UI query"). The UI tests were written for a simulator
/// without Apple Intelligence, which is also what a device without it shows: the rules run, the
/// model step reports itself unavailable. The app itself never uses this.
private struct ModelOffEnricher: TaskEnricher {
    var unavailableReason: String? { "Apple Intelligence is off under UI testing." }

    func enrich(_ input: EnrichmentInput) async throws -> EnrichmentDraft {
        throw ModelOff()
    }

    private struct ModelOff: Error {}
}
