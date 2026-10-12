// Wegwerf-Versuch #274: Zeit bis zum ersten Ergebnis von SpeechAnalyzer, mit und ohne gleichzeitige
// Foundation-Models-Last. Ton wird in Echtzeit (100-ms-Pakete) gefüttert wie vom Mikrofon.
import AVFoundation
import Foundation
import FoundationModels
import Speech

@main
struct Probe {
    static func main() async throws {
        let args = CommandLine.arguments
        let path = args[1]
        let mode = args[2]  // "idle" | "load" | "mainblock"
        let runs = Int(args[3]) ?? 3
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de_DE")) else {
            print("locale unsupported"); return
        }
        let probeT = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
        print("asset status:", await AssetInventory.status(forModules: [probeT]))
        print("model availability:", SystemLanguageModel.default.availability)

        var load: Task<Void, Never>?
        if mode == "load" {
            load = Task.detached {
                var n = 0
                while !Task.isCancelled {
                    let s = LanguageModelSession()
                    do {
                        _ = try await s.respond(to: "Schreibe eine ausführliche Geschichte über einen Garten, 300 Wörter.")
                        n += 1
                    } catch { print("fm error", error); try? await Task.sleep(for: .seconds(1)) }
                }
            }
            try await Task.sleep(for: .seconds(3))
        }
        for i in 1...runs {
            let r = try await once(path: path, locale: locale, blockMain: mode == "mainblock")
            print(String(format: "%@ run %d: analyzerStart %.3f s, firstResult %.3f s after feed start, firstFinal %.3f s, results %d, text: %@",
                         mode, i, r.start, r.first, r.final, r.count, r.text))
        }
        load?.cancel()
    }

    struct R { var start = 0.0; var first = -1.0; var final = -1.0; var count = 0; var text = "" }

    static func once(path: String, locale: Locale, blockMain: Bool) async throws -> R {
        let clock = ContinuousClock()
        let v = ProcessInfo.processInfo.environment["V"] ?? "base"
        let t: SpeechTranscriber
        switch v {
        case "fast": t = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
        case "prog": t = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        default: t = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults], attributeOptions: [])
        }
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        let fmt = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [t])!
        let (stream, cont) = AsyncStream<AnalyzerInput>.makeStream()
        let analyzer = SpeechAnalyzer(modules: [t])
        if ProcessInfo.processInfo.environment["PREP"] == "1" { try await analyzer.prepareToAnalyze(in: fmt) }
        let t0 = clock.now
        try await analyzer.start(inputSequence: stream)
        var r = R()
        r.start = (clock.now - t0).seconds
        let feedStart = clock.now
        let collector = Task { () -> R in
            var x = R()
            for try await res in t.results {
                x.count += 1
                if ProcessInfo.processInfo.environment["LOG"] == "1" { print(String(format: "  +%.2f %@ %@", (clock.now - feedStart).seconds, res.isFinal ? "F" : "v", String(res.text.characters))) }
                if x.first < 0 { x.first = (clock.now - feedStart).seconds }
                if res.isFinal && x.final < 0 { x.final = (clock.now - feedStart).seconds }
                if res.isFinal { x.text += String(res.text.characters) }
            }
            return x
        }
        // Echtzeit füttern
        let src = file.processingFormat
        let conv = AVAudioConverter(from: src, to: fmt)!
        let chunk = AVAudioFrameCount(src.sampleRate / 10)
        while file.framePosition < file.length {
            let inBuf = AVAudioPCMBuffer(pcmFormat: src, frameCapacity: chunk)!
            try file.read(into: inBuf, frameCount: chunk)
            let outBuf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(Double(chunk) * fmt.sampleRate / src.sampleRate) + 64)!
            var fed = false
            _ = conv.convert(to: outBuf, error: nil) { _, status in
                if fed { status.pointee = .noDataNow; return nil }
                fed = true; status.pointee = .haveData; return inBuf
            }
            if ProcessInfo.processInfo.environment["TS"] == "1" {
                cont.yield(AnalyzerInput(buffer: outBuf, bufferStartTime: CMTime(value: CMTimeValue(file.framePosition - Int64(inBuf.frameLength)), timescale: CMTimeScale(src.sampleRate))))
            } else { cont.yield(AnalyzerInput(buffer: outBuf)) }
            try await Task.sleep(for: .milliseconds(100))
        }
        // 2 s Stille nachschieben
        cont.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        let x = try await collector.value
        r.first = x.first; r.final = x.final; r.count = x.count; r.text = x.text
        _ = blockMain
        return r
    }
}

extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
