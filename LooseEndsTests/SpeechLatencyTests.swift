import AVFoundation
import Foundation
import Speech
import Testing
@testable import LooseEnds

/// Time to the first word (#274, #279 A). Without `.fastResults` the analyzer gathered ~12 s of sound before
/// its first result, reproduced on the Mac on 2026-10-09; Henning saw "Ergebnisse: 0" after 7 s on the iPhone.
/// The fixture is fed through the app's own transcriber in 100 ms packets in real time, like the microphone.
@Suite("Speech latency (#274)", .serialized) struct SpeechLatencyTests {
    /// The fixture (`say -v Anna`, 8.7 s) starts with 1 s of silence.
    static let speechStart = 1.0
    static let keyWords = ["zahnarzt", "unterlagen", "steuererklärung", "thomas"]

    @Test("The app's transcriber asks for fast results")
    func makeTranscriberReportsFastResults() {
        // SpeechTranscriber does not expose its options (SDK 27), so the test checks the constant
        // that makeTranscriber(locale:) uses as its only source.
        #expect(SpeechCapture.transcriberReportingOptions.contains(.volatileResults))
        #expect(SpeechCapture.transcriberReportingOptions.contains(.fastResults))
    }

    @Test("The first word arrives within 3 s of speech start", .timeLimit(.minutes(1)))
    func firstWordArrivesWithinThreeSecondsOfSpeechStart() async throws {
        let run = try await Self.measuredRun()
        let first = try #require(run.firstResult, "no result at all")
        let delay = first - Self.speechStart
        print("[#274] first result \(String(format: "%.2f", first)) s after feed start, \(String(format: "%.2f", delay)) s after speech start")
        #expect(delay < 3, "first word \(delay) s after speech start")
    }

    @Test("The final text keeps the key words", .timeLimit(.minutes(1)))
    func finalTextContainsKeyWords() async throws {
        let run = try await Self.measuredRun()
        print("[#274] final text: \(run.finalText)")
        let text = run.finalText.lowercased()
        for word in Self.keyWords {
            #expect(text.contains(word), "missing \"\(word)\" in \"\(run.finalText)\"")
        }
    }

    struct Run: Sendable {
        var firstResult: Double?
        var finalText = ""
    }

    /// One pass for both tests: the stretch takes ~10 s.
    private static let shared = Task<Run, Error> { try await measure() }

    private static func measuredRun() async throws -> Run {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de_DE")) else {
            try Test.cancel("Sprache de_DE wird hier nicht unterstützt")
        }
        let status = await AssetInventory.status(forModules: [SpeechCapture.makeTranscriber(locale: locale)])
        guard status == .installed else {
            try Test.cancel("Sprachmodell de_DE nicht installiert (\(status)) — Zeittest übersprungen")
        }
        return try await shared.value
    }

    private static func measure() async throws -> Run {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de_DE")) else {
            return Run()
        }
        let transcriber = SpeechCapture.makeTranscriber(locale: locale)
        let url = try #require(Bundle(for: SpeechFixtureAnchor.self).url(forResource: "speech-de", withExtension: "m4a"),
                               "speech-de.m4a is not in the test bundle")
        let file = try AVAudioFile(forReading: url)
        let best = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        let format = try #require(best)
        let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.start(inputSequence: stream)

        let clock = ContinuousClock()
        let feedStart = clock.now
        let collector = Task { () throws -> Run in
            var run = Run()
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if run.firstResult == nil, !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    run.firstResult = Self.seconds(clock.now - feedStart)
                }
                if result.isFinal { run.finalText += text }
            }
            return run
        }
        try await feed(file, as: format, into: input)
        input.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        return try await collector.value
    }

    /// 100 ms packets, converted to the analyzer's format, one every 100 ms.
    private static func feed(_ file: AVAudioFile, as format: AVAudioFormat,
                             into input: AsyncStream<AnalyzerInput>.Continuation) async throws {
        let source = file.processingFormat
        let converter = try #require(AVAudioConverter(from: source, to: format))
        let chunk = AVAudioFrameCount(source.sampleRate / 10)
        let outCapacity = AVAudioFrameCount(Double(chunk) * format.sampleRate / source.sampleRate) + 64
        while file.framePosition < file.length {
            let packet = try #require(AVAudioPCMBuffer(pcmFormat: source, frameCapacity: chunk))
            try file.read(into: packet, frameCount: chunk)
            let converted = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outCapacity))
            var handed = false
            var error: NSError?
            converter.convert(to: converted, error: &error) { _, status in
                if handed { status.pointee = .noDataNow; return nil }
                handed = true
                status.pointee = .haveData
                return packet
            }
            if let error { throw error }
            input.yield(AnalyzerInput(buffer: converted))
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}

/// `Bundle(for:)` needs a class; Swift Testing suites are structs.
private final class SpeechFixtureAnchor {}
