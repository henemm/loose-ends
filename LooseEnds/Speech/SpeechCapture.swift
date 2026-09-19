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
        /// Die Erkennung auf dem Gerät kam nicht hoch. Ob stattdessen Apples Server gefragt
        /// werden dürfen, entscheidet der Nutzer einmal — die Aufnahme verlässt dann das Gerät.
        case needsServerConsent
    }

    /// Antwort auf die Einmal-Frage. `nil` = noch nie gefragt.
    static let serverConsentKey = "speechServerRecognitionAllowed"

    private(set) var state: State = .idle
    private(set) var transcript = ""
    private(set) var waveform = Waveform()

    private var engine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Verhindert eine Endlosschleife: pro Sitzung wird höchstens einmal auf Server umgestellt.
    private var triedServerRecognition = false
    /// `nonisolated`, weil auch die Rückrufe von fremden Strängen hierüber melden — und nicht
    /// `private`, weil die Tonzählung im `RequestBox` denselben Kanal benutzt.
    nonisolated static let logger = Logger(subsystem: "com.henning.looseends", category: "Speech")

    var isListening: Bool { state == .listening }

    func start() async {
        guard !isListening else { return }
        await Self.reportSpeechSupport()
        // `isAvailable` ist direkt nach dem Start unzuverlässig: Henning bekam am 2026-09-19 beim
        // ersten Versuch sofort „nicht verfügbar", beim nächsten lief dieselbe App. Ein einzelner
        // Blick darauf darf also kein endgültiges Urteil sein — einmal kurz warten und erneut
        // fragen, bevor die Spracherfassung aufgegeben wird.
        guard let recognizer = await Self.availableRecognizer() else {
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
        // Auf dem Gerät ist die Vorgabe (ADR: nichts verlässt das Gerät). Hat der Nutzer dem
        // Ausweichen auf Apples Server einmal zugestimmt und ist die Erkennung auf dem Gerät
        // vorher gescheitert, läuft dieser Versuch ohne die Einschränkung.
        let onDevice = recognizer.supportsOnDeviceRecognition && !(triedServerRecognition && Self.serverConsent == true)
        request.requiresOnDeviceRecognition = onDevice
        Self.installTap(on: engine.inputNode, feeding: request) { [weak self] level in
            Task { @MainActor in self?.waveform.append(level) }
        }
        engine.prepare()
        try engine.start()

        Self.logger.notice("Erkennung startet: auf dem Gerät \(onDevice, privacy: .public), Sprache \(recognizer.locale.identifier, privacy: .public)")
        task = Self.startRecognition(with: recognizer, request: request) { [weak self] text, message in
            Task { @MainActor in
                if let text {
                    self?.transcript = text
                    Self.logger.notice("Erkannt: \(text, privacy: .public)")
                }
                if let message, text == nil {
                    Self.logger.notice("Erkennung abgebrochen: \(message, privacy: .public)")
                    self?.recognitionFailed(wasOnDevice: onDevice)
                }
            }
        }
        self.engine = engine
        self.request = request
    }

    /// Die Erkennung meldet einen Fehlschlag. Bisher wurde er nur protokolliert — die App blieb
    /// äußerlich im Zuhör-Zustand, der Ton lief weiter, und für den Nutzer sah es aus, als würde
    /// zugehört, während nichts ankam (2026-09-19). Jetzt endet das Zuhören sichtbar.
    private func recognitionFailed(wasOnDevice: Bool) {
        guard isListening, transcript.isEmpty else { return }
        stop()

        guard wasOnDevice else {
            state = .unavailable(String(localized: "Speech recognition is not available. You can type instead."))
            return
        }
        switch Self.serverConsent {
        case .some(true):
            // Zustimmung liegt vor: einmal ohne die Einschränkung erneut versuchen.
            guard !triedServerRecognition else {
                state = .unavailable(String(localized: "Speech recognition is not available. You can type instead."))
                return
            }
            triedServerRecognition = true
            Task { await start() }
        case .some(false):
            state = .unavailable(String(localized: "Speech recognition on this device is not available. You can type instead."))
        case .none:
            triedServerRecognition = true
            state = .needsServerConsent
        }
    }

    /// Stufe 0 aus `docs/context/spracherfassung-teststufen.md`, ausgeführt im echten App-Prozess:
    /// Was bietet Apples Erkennung hier überhaupt an, und liegt das Modell auf dem Gerät? Die alte
    /// Schnittstelle konnte das nicht beantworten — sie meldete „unterstützt" und scheiterte dann
    /// am fehlenden Modell.
    /// Wartet kurz, falls der Erkenner sich beim ersten Blick noch nicht als verfügbar meldet.
    /// Drei Versuche über gut eine Sekunde — genug für den Systemdienst, kurz genug, dass niemand
    /// vor einem eingefrorenen Bildschirm sitzt.
    private static func availableRecognizer() async -> SFSpeechRecognizer? {
        for versuch in 0..<3 {
            if let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable {
                if versuch > 0 { logger.notice("Erkenner war erst im Versuch \(versuch + 1, privacy: .public) verfügbar") }
                return recognizer
            }
            try? await Task.sleep(for: .milliseconds(400))
        }
        return nil
    }

    static func reportSpeechSupport() async {
        let unterstützt = await SpeechTranscriber.supportedLocales.map { $0.identifier(.bcp47) }
        let installiert = await SpeechTranscriber.installedLocales.map { $0.identifier(.bcp47) }
        let alt = SFSpeechRecognizer(locale: .current)
        logger.notice("""
            Stufe 0 — Sprache \(Locale.current.identifier, privacy: .public): \
            neu unterstützt \(unterstützt.count, privacy: .public), \
            neu installiert \(installiert.joined(separator: ","), privacy: .public), \
            alt verfügbar \(alt?.isAvailable ?? false, privacy: .public), \
            alt auf dem Gerät möglich \(alt?.supportsOnDeviceRecognition ?? false, privacy: .public)
            """)
    }

    /// Antwort auf die Einmal-Frage; wird dauerhaft gemerkt.
    static var serverConsent: Bool? {
        get { UserDefaults.standard.object(forKey: serverConsentKey) as? Bool }
        set { UserDefaults.standard.set(newValue, forKey: serverConsentKey) }
    }

    /// Der Nutzer hat die Frage beantwortet.
    func answerServerConsent(_ allowed: Bool) async {
        Self.serverConsent = allowed
        state = .idle
        if allowed {
            await start()
        } else {
            state = .unavailable(String(localized: "Speech recognition on this device is not available. You can type instead."))
        }
    }

    /// Beide Rückrufe hier sind `nonisolated`, weil sie von fremden Strängen kommen: der Audio-Tap
    /// vom Echtzeit-Strang des Audiosystems, die Erkennung von der Warteschlange des Speech-Dienstes.
    /// Läge der Abschluss in der `@MainActor`-Klasse, erbte er deren Hauptstrang-Bindung, Swift
    /// prüfte sie beim Aufruf und bräche den Prozess ab (`dispatch_assert_queue` → `brk #0x1`).
    /// Als `@Sendable`-Parameter einer `nonisolated`-Funktion erben sie keine Bindung; der Sprung
    /// zurück auf den Hauptstrang passiert ausdrücklich im `Task { @MainActor in … }` des Aufrufers.
    private nonisolated static func installTap(
        on input: AVAudioInputNode,
        feeding request: SFSpeechAudioBufferRecognitionRequest,
        onLevel: @escaping @Sendable (Float) -> Void
    ) {
        let box = RequestBox(request)
        let format = input.outputFormat(forBus: 0)
        logger.notice("Audio-Eingang: \(format.sampleRate, privacy: .public) Hz, \(format.channelCount, privacy: .public) Kanäle")
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            box.request.append(buffer)
            box.noteBuffer(frames: buffer.frameLength)
            onLevel(Waveform.level(of: buffer))
        }
    }

    private nonisolated static func startRecognition(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        onUpdate: @escaping @Sendable (String?, String?) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            onUpdate(result?.bestTranscription.formattedString, error?.localizedDescription)
        }
    }

    /// `nonisolated`, weil der TCC-Dienst seine Antwort auf einem Hintergrund-Strang zustellt
    /// (`com.apple.root.default-qos`). In einer `@MainActor`-Klasse erbt der Abschluss sonst die
    /// Hauptstrang-Bindung, Swift prüft sie beim Aufruf und bricht den Prozess ab
    /// (`dispatch_assert_queue` → `brk #0x1`). Die App starb dadurch, sobald die Rechteabfrage
    /// beantwortet war: der Erfassungs-Screen war danach tot, Abbrechen und Mikrofon eingeschlossen.
    private nonisolated static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
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
    private let lock = NSLock()
    private var buffers = 0

    init(_ request: SFSpeechAudioBufferRecognitionRequest) { self.request = request }

    /// Belegt, dass überhaupt Ton ankommt: die erste Meldung sofort, danach alle 100 Puffer.
    /// Ohne das lässt sich „Mikrofon hört zu" nicht von „es kommt nichts an" unterscheiden —
    /// beides sieht auf dem Bildschirm gleich aus.
    func noteBuffer(frames: AVAudioFrameCount) {
        lock.lock()
        buffers += 1
        let count = buffers
        lock.unlock()
        if count == 1 || count % 100 == 0 {
            SpeechCapture.logger.notice("Ton kommt an: \(count, privacy: .public) Puffer, zuletzt \(frames, privacy: .public) Bilder")
        }
    }
}
