import OSLog
import SwiftData
import SwiftUI

@main
struct LooseEndsApp: App {
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
        notifications = DueNotificationCenter(container: container)
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

    /// The design gallery (#182) asks for dark mode by launch argument: the device-wide switch
    /// from XCUITest did not reach the app on the CI simulator. Nil follows the system.
    private static var uiTestColorScheme: ColorScheme? {
        ProcessInfo.processInfo.arguments.contains("--ui-testing-dark") ? .dark : nil
    }

    var body: some Scene {
        WindowGroup {
            ContentView(enrichment: enrichment, notifications: notifications, calendar: calendar)
                .environment(calendar)
                .preferredColorScheme(Self.uiTestColorScheme)
        }
        .modelContainer(container)
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
