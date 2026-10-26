import SwiftData
import SwiftUI

@main
struct LooseEndsWatchApp: App {
    let container: ModelContainer

    init() {
        do { container = try ModelContainerFactory.make() } catch { fatalError("Store: \(error)") }
    }

    var body: some Scene {
        WindowGroup { WatchNowView() }
            .modelContainer(container)
    }
}
