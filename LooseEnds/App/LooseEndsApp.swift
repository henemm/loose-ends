import SwiftData
import SwiftUI

@main
struct LooseEndsApp: App {
    let container: ModelContainer
    let enrichment: EnrichmentCoordinator
    let notifications: DueNotificationCenter

    init() {
        do {
            container = try ModelContainerFactory.make()
        } catch {
            fatalError("Could not open the Loose Ends store: \(error)")
        }
        enrichment = EnrichmentCoordinator(enricher: FoundationModelsEnricher(), container: container)
        notifications = DueNotificationCenter(container: container)
        notifications.activate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(enrichment: enrichment, notifications: notifications)
        }
        .modelContainer(container)
    }
}
