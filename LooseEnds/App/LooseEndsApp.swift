import SwiftData
import SwiftUI

@main
struct LooseEndsApp: App {
    let container: ModelContainer
    let enrichment: EnrichmentCoordinator
    let notifications: DueNotificationCenter
    let calendar: CalendarBridge

    init() {
        do {
            container = try ModelContainerFactory.make()
        } catch {
            fatalError("Could not open the Loose Ends store: \(error)")
        }
        enrichment = EnrichmentCoordinator(enricher: FoundationModelsEnricher(), container: container)
        notifications = DueNotificationCenter(container: container)
        notifications.activate()
        calendar = CalendarBridge(container: container)
    }

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
