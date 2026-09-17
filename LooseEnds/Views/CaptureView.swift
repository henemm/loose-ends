import OSLog
import SwiftData
import SwiftUI

/// Quick Capture (design briefing, screen 1): one text field, one button, nothing to decide.
/// Shared by iPhone, iPad and Mac; presented as a sheet from anywhere in the app.
/// Dictation is the system keyboard's in this slice; live speech with waveform is a later spike.
struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text: String
    @State private var saveFailed = false

    private let channel: CaptureChannel
    private let sourceURL: URL?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Capture")

    /// `prefill` and `sourceURL` serve the share and mail paths (subject in, mail link attached).
    init(prefill: String = "", channel: CaptureChannel = .app, sourceURL: URL? = nil) {
        _text = State(initialValue: prefill)
        self.channel = channel
        self.sourceURL = sourceURL
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                TextField("What should I remember?", text: $text, axis: .vertical)
                    .font(.title3)
                    .lineLimit(3...10)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .onChange(of: text) { _, newValue in submitOnReturn(newValue) }
                    .accessibilityIdentifier("captureTextField")
                Spacer()
            }
            .padding()
            .navigationTitle("Capture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("captureCancelButton")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("captureDoneButton")
                }
            }
            .alert("Could not save", isPresented: $saveFailed) {
                Button("OK") {}
            }
        }
        .onAppear { isFocused = true }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 240)
        #endif
    }

    /// Return sends. A vertical text field inserts a newline instead of submitting, so a trailing
    /// newline is the signal; newlines elsewhere (pasted text) are flattened to spaces.
    private func submitOnReturn(_ newValue: String) {
        guard newValue.contains("\n") else { return }
        let endedWithReturn = newValue.hasSuffix("\n")
        text = newValue.replacingOccurrences(of: "\n", with: " ")
        if endedWithReturn { save() }
    }

    private func save() {
        guard canSave else { return }
        do {
            try CaptureService.save(text, via: channel, sourceURL: sourceURL, in: modelContext)
            dismiss()
        } catch {
            Self.logger.error("Capture failed: \(error, privacy: .public)")
            saveFailed = true
        }
    }
}

#Preview {
    CaptureView()
        .modelContainer(try! ModelContainerFactory.make(inMemory: true))
}
