import SwiftData
import SwiftUI

@main
struct LooseEndsWatchApp: App {
    let container: ModelContainer

    init() {
        do { container = try ModelContainerFactory.make() } catch { fatalError("Store: \(error)") }
        if ModelContainerFactory.isUITesting, ProcessInfo.processInfo.arguments.contains("--ui-testing-store-sample") {
            Self.seedStoreSample(in: container.mainContext)
        }
    }

    /// Beispielaufgaben für die Store-Bilder (#742): nur unter `--ui-testing` und `--ui-testing-store-sample`.
    private static func seedStoreSample(in context: ModelContext) {
        for text in ["Steuerbescheid prüfen", "Anna wegen Geburtstag anrufen", "Blumen gießen"] {
            do {
                let task = try CaptureService.save(text, via: .watch, in: context)
                task.dueDate = Calendar.current.startOfDay(for: Date())
            } catch { fatalError("Store sample: \(error)") }
        }
        do { try context.save() } catch { fatalError("Store sample: \(error)") }
    }

    var body: some Scene {
        WindowGroup { WatchNowView() }
            .modelContainer(container)
    }
}
