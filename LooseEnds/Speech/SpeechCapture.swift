import AVFoundation
import Foundation
import OSLog
import Speech

/// Live speech for the capture scene (design briefing, screen 1): listens the moment the scene
/// opens, shows the recognized text as it forms, and feeds the waveform. On-device recognition
/// where the system offers it. The transcript is raw text like anything typed and goes through
/// the same enrichment afterwards (ADR-4).
@MainActor
@Observable
final class SpeechCapture {
    enum State: Equatable {
        case idle
        case listening
        case unavailable(String)
    }

    private(set) var state: State = .idle
    private(set) var transcript = ""
    private(set) var waveform = Waveform()

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Speech")

    var isListening: Bool { state == .listening }

    func start() async {
        guard !isListening else { return }
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable else {
            state = .unavailable(String(localized: "Speech recognition is not available."))
            return
        }
        let microphone = await AVAudioApplication.requestRecordPermission()
        let speech = await Self.requestSpeechAuthorization()
        guard microphone, speech else {
            state = .unavailable(String(localized: "Microphone or speech access was not allowed."))
            return
        }
        do {
            try startEngine(with: recognizer)
            transcript = ""
            state = .listening
        } catch {
            Self.logger.error("Starting speech failed: \(error, privacy: .public)")
            state = .unavailable(String(localized: "Speech recognition is not available."))
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        request?.endAudio()
        task?.cancel()
        engine = nil
        request = nil
        task = nil
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Self.logger.error("Releasing the audio session failed: \(error, privacy: .public)")
        }
        #endif
        if isListening { state = .idle }
    }

    private func startEngine(with recognizer: SFSpeechRecognizer) throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        let box = RequestBox(request)
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            box.request.append(buffer)
            let level = Waveform.level(of: buffer)
            Task { @MainActor in self.waveform.append(level) }
        }
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let message = error?.localizedDescription
            Task { @MainActor in
                if let text { self.transcript = text }
                if let message, text == nil {
                    Self.logger.notice("Recognition ended: \(message, privacy: .public)")
                }
            }
        }
        self.engine = engine
        self.request = request
    }

    private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

/// The recognition request is appended to from the audio thread; it is only ever used from there
/// and torn down on the main actor after the tap is removed.
private final class RequestBox: @unchecked Sendable {
    let request: SFSpeechAudioBufferRecognitionRequest
    init(_ request: SFSpeechAudioBufferRecognitionRequest) { self.request = request }
}
