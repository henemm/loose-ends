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
                    .accessibilityIdentifier("watch.capture.saved")
            } else {
                TextField("I'm listening", text: $text)
                    .accessibilityIdentifier("watch.capture.field")
                Button("Done", action: save)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("watch.capture.done")
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Text(verbatim: AppVersion.text())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .task(id: saved) {
            // #409: show "Saved" about 1.5 s, then the empty field again. A cancelled sleep changes nothing.
            guard saved else { return }
            do {
                try await Task.sleep(for: .seconds(1.5))
            } catch {
                return
            }
            saved = false
        }
        .alert("Could not save", isPresented: $saveFailed) {
            Button("OK") {}
        }
    }

    private func save() {
        do {
            try CaptureService.save(text, via: .watch, in: modelContext)
            text = ""
            saved = true
        } catch {
            Self.logger.error("Capture failed: \(error, privacy: .public)")
            saveFailed = true
        }
    }
}
