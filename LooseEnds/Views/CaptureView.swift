import OSLog
import SwiftData
import SwiftUI

/// Quick Capture (design briefing, screen 1): the microphone listens the moment the scene opens,
/// the waveform shows it, the recognized text appears live in one text field that stays typable,
/// and one button finishes. Nothing to decide. Shared by iPhone, iPad and Mac.
struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text: String
    @State private var saveFailed = false
    @State private var speech = SpeechCapture()

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

    /// UI tests run without a microphone; they get the keyboard straight away.
    private var speechWanted: Bool {
        !ModelContainerFactory.isUITesting
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("What should I remember?", text: $text, axis: .vertical)
                    .font(.title3)
                    .lineLimit(3...10)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .onChange(of: text) { _, newValue in submitOnReturn(newValue) }
                    .accessibilityIdentifier("captureTextField")
                if speechWanted {
                    listeningRow
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Capture")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { cancel() }
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
        .onAppear(perform: begin)
        .onDisappear { speech.stop() }
        .onChange(of: speech.transcript) { _, transcript in
            if speech.isListening { text = transcript }
        }
        .onChange(of: speech.state) { _, state in
            if case .unavailable = state { isFocused = true }
        }
        .onChange(of: isFocused) { _, focused in
            if focused { speech.stop() }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 240)
        #endif
    }

    /// Waveform plus the microphone toggle; when speech is unavailable, one line says why.
    @ViewBuilder
    private var listeningRow: some View {
        switch speech.state {
        case .unavailable(let reason):
            Text(reason)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("speechUnavailableLabel")
        case .idle, .listening:
            HStack(spacing: 12) {
                WaveformView(levels: speech.waveform.levels)
                Button {
                    toggleListening()
                } label: {
                    Image(systemName: speech.isListening ? "mic.fill" : "mic")
                        .font(.title2)
                }
                .accessibilityLabel(speech.isListening ? "Stop listening" : "Listen")
                .accessibilityIdentifier("micButton")
            }
        }
    }

    private func begin() {
        if speechWanted {
            Task { await speech.start() }
        } else {
            isFocused = true
        }
    }

    private func toggleListening() {
        if speech.isListening {
            speech.stop()
        } else {
            isFocused = false
            Task { await speech.start() }
        }
    }

    /// Return sends. A vertical text field inserts a newline instead of submitting, so a trailing
    /// newline is the signal; newlines elsewhere (pasted text) are flattened to spaces.
    private func submitOnReturn(_ newValue: String) {
        guard newValue.contains("\n") else { return }
        let endedWithReturn = newValue.hasSuffix("\n")
        text = newValue.replacingOccurrences(of: "\n", with: " ")
        if endedWithReturn { save() }
    }

    private func cancel() {
        speech.stop()
        dismiss()
    }

    private func save() {
        guard canSave else { return }
        speech.stop()
        do {
            try CaptureService.save(text, via: channel, sourceURL: sourceURL, in: modelContext)
            dismiss()
        } catch {
            Self.logger.error("Capture failed: \(error, privacy: .public)")
            saveFailed = true
        }
    }
}

/// Bars for the last levels, accent-colored: the one animated thing on the screen.
private struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        Canvas { context, size in
            let slot = size.width / CGFloat(Waveform.capacity)
            let width = slot * 0.5
            for (index, level) in levels.enumerated() {
                let height = max(2, CGFloat(level) * size.height)
                let rect = CGRect(x: CGFloat(index) * slot + slot * 0.25, y: (size.height - height) / 2, width: width, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(.accentColor))
            }
        }
        .frame(height: 32)
        .accessibilityHidden(true)
    }
}

#Preview {
    CaptureView()
        .modelContainer(try! ModelContainerFactory.make(inMemory: true))
}
