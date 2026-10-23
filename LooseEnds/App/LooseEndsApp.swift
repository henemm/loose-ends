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
    /// Which fields a task offers (#538); one choice on every device.
    let fieldSettings: FieldSettingsStore

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
        Self.seedLeftoversIfAsked(in: container)
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
        #if os(iOS)
        // The plan holds without an app start (#553): registered before launch ends, as the system requires.
        BackgroundRefresh.register(notifications)
        #endif
        calendar = CalendarBridge(container: container)
        fieldSettings = FieldSettingsStore.forApp()
        fieldSettings.activate()
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

    /// Henning's case of 2026-10-23 for `StartNumberTests` (#637), only under `--ui-testing-leftovers` and
    /// only in the in-memory store: four deadlines passed (one lined up) and one more task lined up, so the
    /// app icon and "Now" both say 5.
    private static func seedLeftoversIfAsked(in container: ModelContainer) {
        guard ModelContainerFactory.isUITesting,
              ProcessInfo.processInfo.arguments.contains("--ui-testing-leftovers") else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let seeds: [(title: String, daysAgo: Int?, rank: Double?)] = [
            ("Altpapier und Altglas zur Mülldeponie bringen", 2, 1),
            ("Friederich zum Thema Apfel Champagner schreiben", nil, 2),
            ("Steuerunterlagen sortieren", 3, nil),
            ("Geburtstagskarte für Oma schreiben", 1, nil),
            ("Fahrradkette ölen", 4, nil),
        ]
        for seed in seeds {
            let task = TaskItem(rawText: seed.title)
            task.title = seed.title
            task.status = .active
            task.nextRank = seed.rank
            task.dueDate = seed.daysAgo.flatMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            container.mainContext.insert(task)
        }
        do {
            try container.mainContext.save()
        } catch {
            Logger(subsystem: "com.henning.looseends", category: "App")
                .error("Seeding the leftover test tasks failed: \(error, privacy: .public)")
        }
    }

    /// The design gallery (#182) asks for dark mode by launch argument: the device-wide switch
    /// from XCUITest did not reach the app on the CI simulator. Nil follows the system.
    private static var uiTestColorScheme: ColorScheme? {
        ProcessInfo.processInfo.arguments.contains("--ui-testing-dark") ? .dark : nil
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(enrichment: enrichment, notifications: notifications, calendar: calendar)
                .environment(calendar)
                .environment(fieldSettings)
                .preferredColorScheme(Self.uiTestColorScheme)
                #if os(macOS)
                // The smallest main window (#480): sidebar 220 + a 540 pt page, the detail's 480 fit in it.
                .frame(minWidth: 760, minHeight: 520)
                #endif
        }
        .modelContainer(container)
        #if os(macOS)
        // Said outright, not left to the default: the window takes the content's minimum (#480).
        .windowResizability(.contentMinSize)
        // The start page with its right column needs about 1120 pt (sidebar 220 + page 900, #473); without
        // a size the window opened at 900 x 450 and the column and the sidebar's names were cut (#514).
        .defaultSize(width: 1200, height: 780)
        #endif
        #if os(macOS)
        Settings {
            SettingsView(notifications: notifications)
                .environment(calendar)
                .environment(fieldSettings)
                // 640 pt wide like the board (#478); a list has no height of its own, and 512 cut off the last
                // rows. The board's 720 held its six blocks; with the evening and morning rows (#518) and
                // "Fields" (#538) the list set after the board (#573) runs to about 860: 880 where the screen
                // allows, else what the screen leaves (`SettingsView.macWindowHeight`).
                .frame(width: 640, height: SettingsView.macWindowHeight)
                .preferredColorScheme(Self.uiTestColorScheme)
        }
        // Quick capture from the menu bar (#356); the logo's thread, the one exception of the
        // SF Symbols rule (#350, #366).
        MenuBarExtra {
            MenuBarCaptureView(enrichment: enrichment)
                .modelContainer(container)
                .preferredColorScheme(Self.uiTestColorScheme)
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
