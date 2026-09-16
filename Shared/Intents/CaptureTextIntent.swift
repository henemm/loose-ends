import AppIntents
import Foundation
import SwiftData

/// Raw text in, nothing else. Enrichment happens afterwards (ADR-4).
struct CaptureTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture a task"
    static let description = IntentDescription("Say it, it's saved. Loose Ends sorts it out afterwards.")

    @Parameter(title: "Text", requestValueDialog: "What should I remember?")
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainerFactory.make()
        let context = ModelContext(container)
        let item = TaskItem(rawText: text, capturedVia: .siri)
        context.insert(item)
        try context.save()
        return .result(dialog: "Saved: \(text)")
    }
}

/// Opens the app straight into the capture scene (Control Center, ADR-9).
struct OpenCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Open capture"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        CaptureRequest.shared.pending = true
        return .result()
    }
}

/// Tiny bridge between intents and the app scene. Read it directly; no injection needed.
@MainActor
@Observable
final class CaptureRequest {
    static let shared = CaptureRequest()
    var pending = false
}

struct LooseEndsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureTextIntent(),
            phrases: [
                "Add to \(.applicationName)",
                "New task in \(.applicationName)",
                "Capture in \(.applicationName)",
            ],
            shortTitle: "Capture",
            systemImageName: "mic"
        )
    }
}
