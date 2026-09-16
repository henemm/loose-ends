import SwiftData
import SwiftUI

/// Voice in, nothing else (v1). Dictation is the system text input on watchOS.
struct WatchCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var text = ""
    @State private var saved = false

    var body: some View {
        VStack(spacing: 12) {
            if saved {
                Image(systemName: "checkmark.circle").font(.largeTitle).foregroundStyle(.tint)
                Text("Saved").font(.headline)
            } else {
                TextField("I'm listening", text: $text)
                Button("Done") {
                    guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    modelContext.insert(TaskItem(rawText: text, capturedVia: .watch))
                    try? modelContext.save()
                    saved = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
