import OSLog
import SwiftData
import SwiftUI

/// Quick Capture (design briefing, screen 1): the microphone listens the moment the scene opens,
/// the waveform shows it, the recognized text appears live in one text field that stays typable,
/// and one button finishes. Nothing to decide. Shared by iPhone, iPad and Mac.
struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
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

    /// UI-Test der Diagnosezeile (#274): zeigt die Zeile mit festem Zustand, ohne Mikrofon und Erkennung.
    private var diagnosisFixture: Bool {
        ModelContainerFactory.isUITesting
            && ProcessInfo.processInfo.arguments.contains("--ui-testing-speech-diagnosis")
    }

    /// UI-Test der Hört-zu-Anzeige (#279, #297): gilt als „hört zu“ mit festen Pegeln, ohne Mikrofon und Erkennung.
    private var listeningFixture: Bool {
        ModelContainerFactory.isUITesting
            && ProcessInfo.processInfo.arguments.contains("--ui-testing-speech-listening")
    }

    /// Fixed levels for the fixture; the last one is 0.5 (normal speech, −40 dBFS).
    private static let fixtureLevels: [Float] = (0..<Waveform.capacity).map { [0.15, 0.35, 0.6, 0.8, 0.5][$0 % 5] }

    private var isListening: Bool {
        listeningFixture || speech.isListening
    }

    private var levels: [Float] {
        listeningFixture ? Self.fixtureLevels : speech.waveform.levels
    }

    private var hintState: ListeningHint {
        ListeningHint.state(isListening: isListening, text: text)
    }

    private var diagnosis: SpeechDiagnosis? {
        guard diagnosisFixture else { return speech.diagnosis }
        return SpeechDiagnosis(modelStatus: "installed", microphone: true, speech: true, buffers: 62, results: 0)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                // The hint replaces the placeholder visually; the field keeps its name for VoiceOver.
                TextField("What should I remember?", text: $text, prompt: hintState == .hint ? Text(verbatim: "") : nil, axis: .vertical)
                    .font(.title3)
                    .lineLimit(3...10)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .onChange(of: text) { _, newValue in submitOnReturn(newValue) }
                    .accessibilityIdentifier("captureTextField")
                    .overlay(alignment: .topLeading) {
                        if hintState == .hint { ListeningHintView() }
                    }
                if speechWanted || diagnosisFixture || listeningFixture {
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
            switch state {
            case .unavailable, .accessDenied: isFocused = true
            default: break
            }
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
        case .accessDenied(let access):
            // Nach einem „Nicht erlauben“ fragt das System nie wieder; nur die Einstellungen helfen (#280).
            HStack(spacing: 12) {
                Text(access.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("speechUnavailableLabel")
                Spacer()
                if let url = access.settingsURL {
                    Button("Open Settings") { openURL(url) }
                        .font(.footnote)
                        .accessibilityIdentifier("speechOpenSettingsButton")
                }
            }
        case .needsModel:
            // Erst fragen, dann laden (Henning, 2026-10-07, #64): das Modell ist groß.
            HStack(spacing: 12) {
                Text("Speech model for \(speech.languageName) is missing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Load") { speech.loadModel() }
                    .font(.footnote)
                    .accessibilityIdentifier("speechLoadModelButton")
            }
        case .loadingModel(let fraction):
            VStack(alignment: .leading, spacing: 6) {
                Text("Loading speech model … \(fraction.formatted(.percent.precision(.fractionLength(0))))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                ProgressView(value: fraction)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("speechLoadingLabel")
        case .idle, .listening:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    WaveformView(levels: levels, isListening: isListening)
                    MicButton(isListening: isListening, level: levels.last ?? 0, action: toggleListening)
                }
                if let diagnosis {
                    // Ton ohne Text (#274): grau, reiner Text, darf umbrechen.
                    Text(diagnosis.text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(diagnosis.text)
                        .accessibilityIdentifier("speechDiagnosisLabel")
                }
            }
        }
    }

    private func begin() {
        LaunchTimings.mark(.captureAppeared)
        if speechWanted {
            speech.noteOpened()
            Task {
                LaunchTimings.mark(.speechStartCalled)
                await speech.start()
            }
        } else if !listeningFixture {
            isFocused = true
        }
    }

    private func toggleListening() {
        // Festzustand der Diagnosezeile (#274, AC-10): kein Mikrofon, auch nicht auf Tipp.
        guard !diagnosisFixture, !listeningFixture else { return }
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

/// Bars for the last levels over a grey baseline: accent while listening, grey otherwise (#279).
private struct WaveformView: View {
    let levels: [Float]
    let isListening: Bool

    var body: some View {
        Canvas { context, size in
            let baseline = CGRect(x: 0, y: size.height / 2 - 0.75, width: size.width, height: 1.5)
            context.fill(Path(baseline), with: .color(.secondary.opacity(0.5)))
            let bar: Color = isListening ? .accentColor : .secondary
            let slot = size.width / CGFloat(Waveform.capacity)
            let width = slot * 0.5
            for (index, level) in levels.enumerated() {
                let height = max(2, CGFloat(level) * size.height)
                let rect = CGRect(x: CGFloat(index) * slot + slot * 0.25, y: (size.height - height) / 2, width: width, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(bar))
            }
        }
        .frame(height: 32)
        .accessibilityHidden(true)
    }
}

/// "Listening …" where the text will appear (#297): grey, three dots lighting up in turn, still under
/// Reduce Motion. Hidden only while VoiceOver runs, so the field keeps its placeholder name there
/// while UI tests still find it by its label.
private struct ListeningHintView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private static let label = String(localized: "Listening …")
    private static let word = label.replacingOccurrences(of: "…", with: "").trimmingCharacters(in: .whitespaces)
    private static let tick: TimeInterval = 0.4

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.tick)) { timeline in
            let lit = reduceMotion ? nil : Int(timeline.date.timeIntervalSinceReferenceDate / Self.tick) % 3
            HStack(spacing: 0) {
                Text(verbatim: Self.word + " ")
                ForEach(0..<3, id: \.self) { index in
                    Text(verbatim: ".").opacity(lit.map { $0 == index ? 1 : 0.25 } ?? 0.7)
                }
            }
            .animation(.smooth, value: lit)
        }
        .font(.title3)
        .foregroundStyle(.secondary)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label)
        .accessibilityIdentifier("listeningHint")
        .accessibilityHidden(voiceOverEnabled)
    }
}

/// The microphone as a round button (#279 C): listening = filled accent circle with a ring that grows
/// with the last level; off = grey outlined circle with `mic.slash`. At least 44 pt to tap.
private struct MicButton: View {
    let isListening: Bool
    let level: Float
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let circle: CGFloat = 44
    /// The ring rests 4 pt outside the circle, as in the design (#279).
    private static let ringRest: CGFloat = circle + 8

    /// Resting ring × (1 + 0.35 × level); fixed at × 1.15 with Reduce Motion (#279).
    private var ringDiameter: CGFloat {
        Self.ringRest * (reduceMotion ? 1.15 : Waveform.ringScale(for: level))
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isListening {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 3)
                        .frame(width: ringDiameter, height: ringDiameter)
                        .animation(reduceMotion ? nil : .smooth, value: ringDiameter)
                    Circle().fill(Color.accentColor).frame(width: Self.circle, height: Self.circle)
                    Image(systemName: "mic.fill").foregroundStyle(.white)
                } else {
                    Circle().stroke(Color.secondary, lineWidth: 1.5).frame(width: Self.circle, height: Self.circle)
                    Image(systemName: "mic.slash").foregroundStyle(.secondary)
                }
            }
            .font(.title3)
            // Room for the largest ring (52 × 1.35 ≈ 70.2 pt) plus its 3 pt stroke.
            .frame(width: 74, height: 74)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isListening ? "Stop listening" : "Listen")
        .accessibilityIdentifier("micButton")
    }
}

#Preview {
    CaptureView()
        .modelContainer(try! ModelContainerFactory.make(inMemory: true))
}
