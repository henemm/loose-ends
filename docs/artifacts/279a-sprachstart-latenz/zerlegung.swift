// Wegwerf-Messaufbau #279 A: zerlegt die Wartezeit bis zum ersten Wort und zeichnet die Schübe auf.
// Nachbau des App-Wegs aus SpeechCapture.begin: Transcriber → AnalyzerInputConverter → SpeechAnalyzer.start →
// Ton in 48 kHz mono, 100-ms-Pakete in Echtzeit, mit AVAudioTime wie vom Mikrofon-Tap. Vor dem Satz 1 s Stille
// (der Nutzer spricht nicht im selben Moment, in dem die Erfassung aufgeht). Kein Ton wird abgespielt.
//
// Aufruf: zerlegung <aiff> <variante> <öffnungen>
// Varianten: app (heute), prep (prepareToAnalyze vor start), keep (Options .processLifetime),
//            prepkeep (beides), direct (ohne Konverter, direkt im Analyzer-Format), dict (DictationTranscriber
//            progressiveShortDictation), prog (SpeechTranscriber .progressiveTranscription), fin (app + finalize alle
//            300 ms), dictff (Dictation + volatile + frequentFinalization)
import AVFoundation
import Foundation
import Speech

@main
struct Zerlegung {
    static func main() async throws {
        let args = CommandLine.arguments
        let variant = args[2]
        let openings = Int(args[3]) ?? 3
        let audio = try loadMono48k(path: args[1], leadingSilence: Double(ProcessInfo.processInfo.environment["SIL"] ?? "1.0") ?? 1.0)
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de_DE")) else {
            print("locale unsupported"); return
        }
        for i in 1...openings {
            try await once(index: i, variant: variant, locale: locale, audio: audio)
            try await Task.sleep(for: .milliseconds(800))
        }
    }

    /// Ton einmal vorab in 48 kHz mono Float32 umrechnen, mit Stille davor — so wie das Mikrofon liefert.
    static func loadMono48k(path: String, leadingSilence: Double) throws -> (buffer: AVAudioPCMBuffer, onset: Double) {
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
        let src = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
        try file.read(into: src)
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
        let conv = AVAudioConverter(from: file.processingFormat, to: fmt)!
        let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(Double(file.length) * 48_000 / file.processingFormat.sampleRate) + 1024)!
        var fed = false
        _ = conv.convert(to: out, error: nil) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true; status.pointee = .haveData; return src
        }
        let pad = AVAudioFrameCount(leadingSilence * 48_000)
        let all = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: pad + out.frameLength)!
        all.frameLength = pad + out.frameLength
        let dst = all.floatChannelData![0]
        for k in 0..<Int(pad) { dst[k] = 0 }
        let s = out.floatChannelData![0]
        var onset = -1.0
        for k in 0..<Int(out.frameLength) {
            dst[Int(pad) + k] = s[k]
            if onset < 0, abs(s[k]) > 0.02 { onset = Double(Int(pad) + k) / 48_000 }
        }
        return (all, onset)
    }

    static func makeModule(_ variant: String, locale: Locale) -> any SpeechModule {
        switch variant {
        case "dict":
            return DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
        case "dictff":
            return DictationTranscriber(locale: locale, contentHints: [.shortForm], transcriptionOptions: [],
                                        reportingOptions: [.volatileResults, .frequentFinalization], attributeOptions: [])
        case "prog":
            return SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        default:
            return SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults],
                                     attributeOptions: [])
        }
    }

    final class Clock: @unchecked Sendable { let t0 = ContinuousClock.now; func now() -> Double { (ContinuousClock.now - t0).seconds } }

    static func once(index: Int, variant: String, locale: Locale, audio: (buffer: AVAudioPCMBuffer, onset: Double)) async throws {
        let c = Clock()
        let module = makeModule(variant, locale: locale)
        let status = await AssetInventory.status(forModules: [module])
        let tStatus = c.now()
        let converter = try await AnalyzerInputConverter.converter(compatibleWith: [module])
        let tConverter = c.now()
        let keep = variant == "keep" || variant == "prepkeep"
        let options = keep ? SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime) : nil
        let analyzer = SpeechAnalyzer(modules: [module], options: options)
        let best = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module])
        if variant.hasPrefix("prep") { try await analyzer.prepareToAnalyze(in: best) }
        let tPrep = c.now()
        let (stream, cont) = AsyncStream<AnalyzerInput>.makeStream()
        try await analyzer.start(inputSequence: stream)
        let tStart = c.now()

        let feedStart = c.now()
        let collector = Task { () -> [(Double, Bool, Int, String)] in
            var events: [(Double, Bool, Int, String)] = []
            var fixed = ""
            func words(_ s: String) -> Int { s.split(whereSeparator: \.isWhitespace).count }
            if let t = module as? SpeechTranscriber {
                for try await r in t.results {
                    let text = String(r.text.characters)
                    let shown = r.isFinal ? (fixed + text) : (fixed + text)
                    if r.isFinal { fixed += text }
                    events.append((c.now() - feedStart, r.isFinal, words(shown), shown))
                }
            } else if let t = module as? DictationTranscriber {
                for try await r in t.results {
                    let text = String(r.text.characters)
                    let shown = fixed + text
                    if r.isFinal { fixed += text }
                    events.append((c.now() - feedStart, r.isFinal, words(shown), shown))
                }
            }
            return events
        }

        // Echtzeit füttern wie der Tap: 100 ms je Paket, Hostzeit dazu.
        let chunk = 4_800
        let total = Int(audio.buffer.frameLength)
        let fmt = audio.buffer.format
        var pos = 0
        var tick = ContinuousClock.now
        let direct = variant == "direct"
        let directConv = direct ? AVAudioConverter(from: fmt, to: best!)! : nil
        while pos < total {
            let n = min(chunk, total - pos)
            let b = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(n))!
            b.frameLength = AVAudioFrameCount(n)
            memcpy(b.floatChannelData![0], audio.buffer.floatChannelData![0] + pos, n * 4)
            if let directConv, let best {
                let o = AVAudioPCMBuffer(pcmFormat: best, frameCapacity: AVAudioFrameCount(Double(n) * best.sampleRate / 48_000) + 64)!
                var fed = false
                _ = directConv.convert(to: o, error: nil) { _, st in
                    if fed { st.pointee = .noDataNow; return nil }
                    fed = true; st.pointee = .haveData; return b
                }
                cont.yield(AnalyzerInput(buffer: o))
            } else {
                let time = AVAudioTime(sampleTime: AVAudioFramePosition(pos), atRate: 48_000)
                for input in try converter.convert(b, at: time) { cont.yield(input) }
            }
            pos += n
            if variant == "fin", (pos / chunk) % 3 == 0 {
                Task { do { try await analyzer.finalize(through: nil) } catch { print("finalize", error) } }
            }
            tick = tick.advanced(by: .milliseconds(100))
            try await Task.sleep(until: tick)
        }
        // Nachlauf: 2 s weiter Stille wie ein offenes Mikrofon, dann Ende.
        let silence = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(chunk))!
        silence.frameLength = AVAudioFrameCount(chunk)
        for k in 0..<chunk { silence.floatChannelData![0][k] = 0 }
        for _ in 0..<20 {
            if direct, let directConv, let best {
                let o = AVAudioPCMBuffer(pcmFormat: best, frameCapacity: 2_000)!
                var fed = false
                _ = directConv.convert(to: o, error: nil) { _, st in
                    if fed { st.pointee = .noDataNow; return nil }
                    fed = true; st.pointee = .haveData; return silence
                }
                cont.yield(AnalyzerInput(buffer: o))
            } else {
                let time = AVAudioTime(sampleTime: AVAudioFramePosition(pos), atRate: 48_000)
                for input in try converter.convert(silence, at: time) { cont.yield(input) }
            }
            pos += chunk
            tick = tick.advanced(by: .milliseconds(100))
            try await Task.sleep(until: tick)
        }
        cont.finish()
        try await analyzer.finalizeAndFinishThroughEndOfInput()
        let events = try await collector.value

        let onset = audio.onset
        let firstWord = events.first { $0.2 > 0 }.map { $0.0 - onset } ?? -1
        // Schübe: Zeitpunkte, an denen die sichtbare Wortzahl wächst, und um wie viel.
        // Ein Schub = alle Zuwächse innerhalb von 50 ms.
        var steps: [(Double, Int)] = []
        var last = 0
        for e in events where e.2 > last {
            if let l = steps.last, e.0 - onset - l.0 < 0.05 { steps[steps.count - 1].1 += e.2 - last } else { steps.append((e.0 - onset, e.2 - last)) }
            last = e.2
        }
        let gaps = zip(steps.dropFirst(), steps).map { $0.0 - $1.0 }
        let maxGap = gaps.max() ?? 0
        let maxJump = steps.map(\.1).max() ?? 0
        print(String(format: "%@ #%d  status %.3f  konverter %.3f  prep %.3f  start %.3f  | Start gesamt %.3f s | erstes Wort %.2f s nach Sprechbeginn | Ergebnisse %d, Schübe %d, größter Schub %d Wörter, längste Pause %.2f s  [%@]",
                     variant, index, tStatus, tConverter - tStatus, tPrep - tConverter, tStart - tPrep, tStart,
                     firstWord, events.count, steps.count, maxJump, maxGap, String(describing: status)))
        if ProcessInfo.processInfo.environment["LOG"] == "1" {
            print("    " + steps.map { String(format: "%.2f:+%d", $0.0, $0.1) }.joined(separator: "  "))
            if let lastText = events.last?.3 { print("    Text: \(lastText)") }
        }
        _ = feedStart
    }
}

extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
