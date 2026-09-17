import OSLog
import SwiftData
import SwiftUI

/// Voice in, nothing else (v1). Dictation is the system text input on watchOS.
struct WatchCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @State private var saved = false
    @State private var saveFailed = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Capture")

    var body: some View {
        VStack(spacing: 12) {
            if saved {
                Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(.tint)
                Text("Saved").font(.headline)
            } else {
                TextField("I'm listening", text: $text)
                Button("Done", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .alert("Could not save", isPresented: $saveFailed) {
            Button("OK") {}
        }
    }

    private func save() {
        do {
            try CaptureService.save(text, via: .watch, in: modelContext)
            saved = true
        } catch {
            Self.logger.error("Capture failed: \(error, privacy: .public)")
            saveFailed = true
        }
    }
}
