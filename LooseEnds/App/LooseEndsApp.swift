import SwiftData
import SwiftUI

@main
struct LooseEndsApp: App {
    let container: ModelContainer
    let enrichment: EnrichmentCoordinator

    init() {
        do {
            container = try ModelContainerFactory.make()
        } catch {
            fatalError("Could not open the Loose Ends store: \(error)")
        }
        enrichment = EnrichmentCoordinator(enricher: FoundationModelsEnricher(), container: container)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(enrichment: enrichment)
        }
        .modelContainer(container)
    }
}
