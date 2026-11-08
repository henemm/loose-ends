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
    /// Die Texte kommen aus `--ui-testing-store-sample-texts <a|b|c>` (#842), sonst die deutsche Liste.
    private static func seedStoreSample(in context: ModelContext) {
        for text in storeSampleTexts(ProcessInfo.processInfo.arguments) {
            do {
                let task = try CaptureService.save(text, via: .watch, in: context)
                task.dueDate = Calendar.current.startOfDay(for: Date())
            } catch { fatalError("Store sample: \(error)") }
        }
        do { try context.save() } catch { fatalError("Store sample: \(error)") }
    }

    /// Genau drei nichtleere Einträge nach `--ui-testing-store-sample-texts`, sonst die deutsche Liste.
    private static func storeSampleTexts(_ arguments: [String]) -> [String] {
        let german = ["Steuerbescheid prüfen", "Anna wegen Geburtstag anrufen", "Blumen gießen"]
        guard let flag = arguments.firstIndex(of: "--ui-testing-store-sample-texts"), flag + 1 < arguments.count else { return german }
        let texts = arguments[flag + 1].split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        return texts.count == 3 && !texts.contains(where: \.isEmpty) ? texts : german
    }

    var body: some Scene {
        WindowGroup { WatchNowView() }
            .modelContainer(container)
    }
}
