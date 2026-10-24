// Wegwerf-Versuch #293: Liefert SpeechAnalyzer Text, wenn das Recht „Spracherkennung“ nie erfragt
// oder abgelehnt ist? Kein Mikrofon: Ton aus einer Datei (per `say`), damit nur das Speech-Recht zählt.
// Modi: status | deny (fragt einmal, Henning tippt „Nicht erlauben“) | transcribe (fragt NIE).
import AVFoundation
import Foundation
import Speech

@main
struct Probe {
    nonisolated(unsafe) static var lines: [String] = []
    static func log(_ s: String) { lines.append(s); print(s) }

    static func main() async {
        let mode = CommandLine.arguments.dropFirst().first ?? "transcribe"
        log("mode \(mode), speech status vorher: \(name(SFSpeechRecognizer.authorizationStatus()))")
        switch mode {
        case "status": break
        case "deny":
            let s = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
            log("requestAuthorization → \(name(s))")
        default:
            do { try await transcribe() } catch { log("FEHLER: \(error)") }
        }
        log("speech status nachher: \(name(SFSpeechRecognizer.authorizationStatus()))")
        let out = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("result-\(mode).txt")
        do { try lines.joined(separator: "\n").write(to: out, atomically: true, encoding: .utf8) } catch { print("write failed \(error)") }
        exit(0)
    }

    static func transcribe() async throws {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "de_DE")) else {
            log("locale unsupported"); return
        }
        let t = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
        log("asset status: \(await AssetInventory.status(forModules: [t]))")
        let url = Bundle.main.url(forResource: "satz", withExtension: "aiff")!
        let file = try AVAudioFile(forReading: url)
        let analyzer = SpeechAnalyzer(modules: [t])
        let collector = Task { () -> String in
            var text = ""
            for try await r in t.results where r.isFinal { text += String(r.text.characters) }
            return text
        }
        let last = try await analyzer.analyzeSequence(from: file)
        if let last { try await analyzer.finalizeAndFinish(through: last) } else { await analyzer.cancelAndFinishNow() }
        let text = try await collector.value
        log("TEXT: «\(text.trimmingCharacters(in: .whitespaces))»")
    }

    static func name(_ s: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: "notDetermined"
        case .denied: "denied"
        case .restricted: "restricted"
        case .authorized: "authorized"
        @unknown default: "unknown"
        }
    }
}
