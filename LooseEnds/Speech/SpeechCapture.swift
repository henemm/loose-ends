import AVFoundation
import Foundation
import OSLog
import Speech

/// Live speech for the capture scene (design briefing, screen 1): listens the moment the scene
/// opens, shows the recognized text as it forms, and feeds the waveform. On the device only, through
/// `SpeechAnalyzer` (#64): nothing leaves the device, and a missing model is said and loaded on a tap
/// instead of failing silently like the old `SFSpeechRecognizer` did (2026-09-19). The transcript is
/// raw text like anything typed and goes through the same enrichment afterwards (ADR-4).
@MainActor
@Observable
final class SpeechCapture {
    enum State: Equatable {
        case idle
        case listening
        case unavailable(String)
        /// A right is missing; the scene names it and offers Settings (#280).
        case accessDenied(SpeechAccess)
        /// The language is supported, the model is not on the device. Loaded only on a tap (Henning, 2026-10-07).
        case needsModel
        /// 0...1
        case loadingModel(Double)
    }

    private(set) var state: State = .idle
    private(set) var transcript = ""
    private(set) var waveform = Waveform()

    private var engine: AVAudioEngine?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzer: SpeechAnalyzer?
    private var results: Task<Void, Never>?
    private var loading: Task<Void, Never>?
    /// Kurzdiagnose „Ton ohne Text“ (#274): steht nur, solange `SpeechDiagnosis.hint` sie liefert.
    private(set) var diagnosis: SpeechDiagnosis?
    private var box: ConverterBox?
    private var check: Task<Void, Never>?
    private var resultCount = 0
    /// Kennung des laufenden Zuhörens: `collect` zählt nur, solange seine Kennung die aktuelle ist (#274).
    private var run = 0
    private var listeningSince: ContinuousClock.Instant?
    private var modelStatus = ""
    private var microphoneGranted = false
    private var speechGranted = false
    /// Zählt jedes `stop()`. `start()` wartet auf Modell, Rechte und Analyzer; kam in der Zeit ein
    /// `stop()` (Abbrechen, Fertig, Tippen ins Textfeld), darf es danach kein Mikrofon mehr öffnen (#184).
    private var stopCount = 0
    /// `nonisolated`, weil auch die Rückrufe von fremden Strängen hierüber melden — und nicht
    /// `private`, weil die Tonzählung im `ConverterBox` denselben Kanal benutzt.
    nonisolated static let logger = Logger(subsystem: "com.henning.looseends", category: "Speech")

    var isListening: Bool { state == .listening }

    /// The device language by name, for the "model missing" line.
    var languageName: String {
        let code = Locale.current.language.languageCode?.identifier ?? Locale.current.identifier
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    func start() async {
        guard !isListening else { return }
        let ticket = stopCount
        guard let transcriber = await Self.transcriber() else {
            state = .unavailable(String(localized: "Speech recognition is not available for this language. You can type instead."))
            return
        }
        let status = await AssetInventory.status(forModules: [transcriber])
        Self.logger.notice("Stufe 0 — Sprache \(Locale.current.identifier, privacy: .public): Modell \(String(describing: status), privacy: .public)")
        modelStatus = String(describing: status)
        switch SpeechReadiness.from(status) {
        case .unsupported:
            state = .unavailable(String(localized: "Speech recognition is not available for this language. You can type instead."))
            return
        case .needsModel, .loading:
            state = .needsModel
            return
        case .ready:
            LaunchTimings.mark(.modelReady)
        }
        let microphone = await AVAudioApplication.requestRecordPermission()
        let speech = await Self.requestSpeechAuthorization()
        // Ob SpeechAnalyzer das Spracherkennungsrecht braucht, ist nicht dokumentiert; Stufe 7 liest es hier ab.
        Self.logger.notice("Rechte: Mikrofon \(microphone, privacy: .public), Spracherkennung \(speech, privacy: .public)")
        microphoneGranted = microphone
        speechGranted = speech
        if let missing = SpeechAccess.missing(microphone: microphone, speech: speech) {
            state = .accessDenied(missing)
            return
        }
        guard ticket == stopCount else {
            Self.logger.notice("Erfassung wurde während der Vorbereitung beendet, Mikrofon bleibt zu")
            return
        }
        do {
            try await begin(with: transcriber, ticket: ticket)
        } catch {
            Self.logger.error("Starting speech failed: \(error, privacy: .public)")
            stop()
            state = .unavailable(String(localized: "Speech recognition is not available."))
        }
    }

    func stop() {
        stopCount += 1
        loading?.cancel()
        loading = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        input?.finish()
        results?.cancel()
        check?.cancel()
        check = nil
        box = nil
        resultCount = 0
        listeningSince = nil
        diagnosis = nil
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        engine = nil
        input = nil
        results = nil
        analyzer = nil
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Self.logger.error("Releasing the audio session failed: \(error, privacy: .public)")
        }
        #endif
        switch state {
        case .listening: state = .idle
        case .loadingModel: state = .needsModel
        default: break
        }
    }

    /// The user tapped "Load": fetch the model with visible progress, then listen without another tap.
    func loadModel() {
        if case .loadingModel = state { return }
        let ticket = stopCount
        state = .loadingModel(0)
        loading = Task { [weak self] in await self?.load(ticket: ticket) }
    }

    private func load(ticket: Int) async {
        guard let transcriber = await Self.transcriber() else {
            state = .unavailable(String(localized: "Speech recognition is not available for this language. You can type instead."))
            return
        }
        do {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                let poll = Task { [weak self] in
                    while !Task.isCancelled {
                        guard let self else { return }
                        if case .loadingModel = state {
                            state = .loadingModel(SpeechReadiness.fraction(request.progress))
                        }
                        do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                    }
                }
                defer { poll.cancel() }
                Self.logger.notice("Stufe 1 — Modell wird geladen")
                try await request.downloadAndInstall()
                Self.logger.notice("Stufe 1 — Modell installiert")
            }
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("Loading the speech model failed: \(error, privacy: .public)")
            guard ticket == stopCount else { return }
            state = .unavailable(String(localized: "The speech model could not be loaded. You can type instead."))
            return
        }
        guard ticket == stopCount else { return }
        loading = nil
        state = .idle
        await start()
    }

    private static func transcriber() async -> SpeechTranscriber? {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) else {
            logger.notice("Stufe 0 — Sprache \(Locale.current.identifier, privacy: .public) wird auf dem Gerät nicht unterstützt")
            return nil
        }
        return SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
    }

    private enum StartError: Error {
        case noAudioInput
    }

    private func begin(with transcriber: SpeechTranscriber, ticket: Int) async throws {
        let converter = try await AnalyzerInputConverter.converter(compatibleWith: [transcriber])
        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.start(inputSequence: stream)
        LaunchTimings.mark(.analyzerStarted)
        guard ticket == stopCount else {
            continuation.finish()
            await analyzer.cancelAndFinishNow()
            Self.logger.notice("Erfassung wurde während der Vorbereitung beendet, Mikrofon bleibt zu")
            return
        }
        self.analyzer = analyzer
        self.input = continuation

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        // Ohne Eingang baut `inputNode` die Audio-Ein-/Ausgabe trotzdem auf und fragt den
        // Audio-Dienst; dann lieber gleich auf Tippen ausweichen (#184).
        guard session.isInputAvailable else { throw StartError.noAudioInput }
        #endif

        let engine = AVAudioEngine()
        let box = ConverterBox(converter, feeding: continuation) { [weak self] message in
            Task { @MainActor in self?.recognitionFailed(message) }
        }
        try Self.installTap(on: engine.inputNode, feeding: box) { [weak self] level in
            Task { @MainActor in self?.waveform.append(level) }
        }
        self.engine = engine
        self.box = box
        engine.prepare()
        try engine.start()
        LaunchTimings.mark(.engineStarted)

        Self.logger.notice("Erkennung startet auf dem Gerät, Sprache \(Locale.current.identifier, privacy: .public)")
        transcript = ""
        state = .listening
        LaunchTimings.mark(.listening)
        resultCount = 0
        diagnosis = nil
        listeningSince = ContinuousClock.now
        run += 1
        let current = run
        results = Task { [weak self] in await self?.collect(from: transcriber, run: current) }
        check?.cancel()
        check = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, !Task.isCancelled else { return }
                self.updateDiagnosis()
            }
        }
    }

    /// Jede Sekunde: Zähler und Uhr gegen die Regel (#274). Nur beim Zuhören, sonst steht ein Grund da.
    private func updateDiagnosis() {
        guard isListening, let listeningSince, let box else {
            diagnosis = nil
            return
        }
        let elapsed = ContinuousClock.now - listeningSince
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        diagnosis = SpeechDiagnosis.hint(
            buffers: box.bufferCount, results: resultCount,
            secondsListening: seconds,
            modelStatus: modelStatus, microphone: microphoneGranted, speech: speechGranted
        )
    }

    /// Fixed results are kept, the volatile one replaces the previous volatile one.
    private func collect(from transcriber: SpeechTranscriber, run: Int) async {
        var fixed = ""
        do {
            for try await result in transcriber.results {
                if run == self.run { resultCount += 1 }
                let text = String(result.text.characters)
                if result.isFinal {
                    fixed += text
                    transcript = fixed.trimmingCharacters(in: .whitespaces)
                } else {
                    transcript = (fixed + text).trimmingCharacters(in: .whitespaces)
                }
                Self.logger.notice("Erkannt: \(self.transcript, privacy: .public)")
            }
        } catch is CancellationError {
            return
        } catch {
            recognitionFailed(error.localizedDescription)
        }
    }

    /// Die Erkennung oder die Tonumwandlung meldet einen Fehlschlag. Die App darf dann nicht
    /// äußerlich weiter zuhören, während nichts ankommt (2026-09-19): das Zuhören endet sichtbar.
    private func recognitionFailed(_ message: String) {
        Self.logger.notice("Erkennung abgebrochen: \(message, privacy: .public)")
        guard isListening else { return }
        let heardNothing = transcript.isEmpty
        stop()
        if heardNothing {
            state = .unavailable(String(localized: "Speech recognition is not available. You can type instead."))
        }
    }

    /// Der Rückruf hier ist `nonisolated`, weil der Audio-Tap vom Echtzeit-Strang des Audiosystems kommt.
    /// Läge der Abschluss in der `@MainActor`-Klasse, erbte er deren Hauptstrang-Bindung, Swift
    /// prüfte sie beim Aufruf und bräche den Prozess ab (`dispatch_assert_queue` → `brk #0x1`).
    /// Als `@Sendable`-Parameter einer `nonisolated`-Funktion erbt er keine Bindung; der Sprung
    /// zurück auf den Hauptstrang passiert ausdrücklich im `Task { @MainActor in … }` des Aufrufers.
    /// `installAudioTap` (iOS 27) wirft, statt abzustürzen; die Puffergröße liegt mit 100 ms am
    /// unteren Rand des Bereichs, den Apple angibt (100–400 ms).
    private nonisolated static func installTap(
        on input: AVAudioInputNode,
        feeding box: ConverterBox,
        onLevel: @escaping @Sendable (Float) -> Void
    ) throws {
        let format = input.outputFormat(forBus: 0)
        logger.notice("Audio-Eingang: \(format.sampleRate, privacy: .public) Hz, \(format.channelCount, privacy: .public) Kanäle")
        let frames = AVAudioFrameCount(max(format.sampleRate, 8_000) / 10)
        try input.installAudioTap(onBus: 0, bufferSize: frames, format: format) { readOnly, time in
            let buffer = AVAudioPCMBuffer(copying: readOnly)
            onLevel(Waveform.level(of: buffer))
            box.feed(buffer, at: time)
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

/// The converter is fed from the audio thread only; it turns each buffer into the analyzer's format
/// (`AnalyzerInputConverter`, iOS 27) and throws on a wrong format instead of delivering silently nothing.
private final class ConverterBox: @unchecked Sendable {
    private let converter: AnalyzerInputConverter
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private let onFailure: @Sendable (String) -> Void
    private let lock = NSLock()
    private var buffers = 0
    private var failed = false

    /// Der Zählerstand für die Kurzdiagnose (#274), unter derselben Sperre wie `feed`.
    var bufferCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return buffers
    }

    init(
        _ converter: AnalyzerInputConverter,
        feeding continuation: AsyncStream<AnalyzerInput>.Continuation,
        onFailure: @escaping @Sendable (String) -> Void
    ) {
        self.converter = converter
        self.continuation = continuation
        self.onFailure = onFailure
    }

    /// Belegt, dass überhaupt Ton ankommt und umgewandelt wird: die erste Meldung sofort, danach
    /// alle 100 Puffer. Ohne das lässt sich „Mikrofon hört zu" nicht von „es kommt nichts an"
    /// unterscheiden — beides sieht auf dem Bildschirm gleich aus.
    func feed(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        lock.lock()
        defer { lock.unlock() }
        guard !failed else { return }
        let inputs: [AnalyzerInput]
        do {
            inputs = try converter.convert(buffer, at: time)
        } catch {
            failed = true
            SpeechCapture.logger.error("Stufe 3 — Umwandlung gescheitert: \(error, privacy: .public)")
            onFailure(error.localizedDescription)
            return
        }
        for input in inputs { continuation.yield(input) }
        buffers += 1
        if buffers == 1 { LaunchTimings.mark(.firstBuffer) }
        if buffers == 1 || buffers % 100 == 0 {
            SpeechCapture.logger.notice("Ton kommt an: \(self.buffers, privacy: .public) Puffer, zuletzt \(buffer.frameLength, privacy: .public) Bilder, \(inputs.count, privacy: .public) umgewandelt")
        }
    }
}
