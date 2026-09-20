import Foundation
#if canImport(FoundationModels) && !os(watchOS)
import FoundationModels
#endif

/// One note, measured once, with the conditions it was measured under.
///
/// A run is not a session: it is assembled from however many slices the device allowed, spread
/// over hours or days. So every record carries its own `capturedAt` — the truth for a relative
/// date ("morgen") is only defined against the day that note was actually measured — and its own
/// `conditions`, so the report can show whether the numbers move with foreground, power or heat
/// instead of assuming they don't.
struct MeasurementResult: Codable, Sendable {
    var entryID: String
    var capturedAt: Date
    var finishedAt: Date
    var seconds: Double
    var conditions: Conditions

    /// What the model returned. Everything nil with `error` set means the call failed.
    var title: String?
    var dueDate: Date?
    var dueHasTime: Bool = false
    var people: [String] = []
    var error: String?
    /// The typed class of the failure (`MeasurementErrorKind`), so the report never has to guess
    /// from the message what went wrong. Missing in files written before #83.
    var errorKind: String?

    var succeeded: Bool { error == nil }
    var wasRateLimited: Bool {
        if let errorKind { return errorKind == MeasurementErrorKind.rateLimited }
        return error?.localizedCaseInsensitiveContains("rate limit") ?? false
    }
}

/// The state of the device at the moment of one measurement. Plain strings: this type is written
/// on the phone and read on the Mac, and must survive a change of enum cases in between.
struct Conditions: Codable, Sendable, Hashable {
    var appState: String      // "vordergrund", "hintergrund", "inaktiv"
    var power: String         // "strom", "akku"
    var batteryPercent: Int
    var lowPowerMode: Bool
    var thermal: String       // "normal", "fair", "serious", "critical"
    var device: String
    var systemVersion: String

    /// What the report groups by: everything that Apple names as a reason to throttle or slow down.
    var summary: String { "\(appState), \(power)\(lowPowerMode ? ", Stromsparmodus" : "")\(thermal == "normal" ? "" : ", \(thermal)")" }
}

/// One line of the app's own life: what it did or what happened to it, and when.
///
/// Without these, a bug in the app and a condition of the system look the same in the file
/// (#83). Kinds are plain strings for the same reason as `Conditions`.
struct MeasurementEvent: Codable, Sendable {
    var at: Date
    var kind: String   // "app", "model", "start", "stop", "scene", "failure", "wait", "finished"
    var note: String
}

/// The result file: written on the phone after every single note and every event, read on the Mac.
///
/// Written that often on purpose — a slice can end at any moment, because the user puts the
/// phone away or locks it, and nothing measured or observed may be lost.
struct MeasurementRun: Codable, Sendable {
    var name: String
    var startedAt: Date
    var results: [MeasurementResult] = []
    var events: [MeasurementEvent] = []

    init(name: String, startedAt: Date) {
        self.name = name
        self.startedAt = startedAt
    }

    private enum CodingKeys: String, CodingKey { case name, startedAt, results, events }

    /// Files from before #83 have no `events`; they must stay readable.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        results = try container.decodeIfPresent([MeasurementResult].self, forKey: .results) ?? []
        events = try container.decodeIfPresent([MeasurementEvent].self, forKey: .events) ?? []
    }

    mutating func log(_ kind: String, _ note: String = "", at date: Date = Date()) {
        events.append(MeasurementEvent(at: date, kind: kind, note: note))
    }

    var succeeded: [MeasurementResult] { results.filter(\.succeeded) }
    var doneIDs: Set<String> { Set(succeeded.map(\.entryID)) }
    var failedAttempts: Int { results.count - succeeded.count }
    var rateLimitedAttempts: Int { results.filter(\.wasRateLimited).count }

    /// Notes still to do — a note that only ever failed stays on the list and is tried again in a
    /// later slice, which is exactly how a throttled run finishes itself over time.
    func remaining(from entries: [Corpus.Entry]) -> [Corpus.Entry] {
        let done = doneIDs
        return entries.filter { !done.contains($0.id) }
    }
}

/// How the run paces itself after failures. A rule, so it can be read and tested, instead of the
/// reflex "fire the next note at once" that burned Apple's whole retry budget in one second.
enum MeasurementPacing {
    static let giveUpAfterConsecutiveFailures = 3
    static let waitAfterFailure: TimeInterval = 60

    /// Seconds to wait before the next note, or nil when the run should stop and keep its state.
    static func delayBeforeNext(consecutiveFailures: Int) -> TimeInterval? {
        if consecutiveFailures >= giveUpAfterConsecutiveFailures { return nil }
        return consecutiveFailures == 0 ? 0 : waitAfterFailure
    }
}

/// The typed class of a model failure, as a stable string for the file.
enum MeasurementErrorKind {
    static let rateLimited = "rateLimited"
    static let guardrail = "guardrail"
    static let assetsUnavailable = "assetsUnavailable"
    static let contextWindow = "contextWindow"
    static let decoding = "decoding"
    static let unsupported = "unsupported"
    static let refusal = "refusal"
    static let concurrent = "concurrent"
    static let timeout = "timeout"
    static let other = "andere"

    static func classify(_ error: Error) -> String {
        #if canImport(FoundationModels) && !os(watchOS)
        if let generation = error as? LanguageModelSession.GenerationError {
            switch generation {
            case .rateLimited: return rateLimited
            case .guardrailViolation: return guardrail
            case .assetsUnavailable: return assetsUnavailable
            case .exceededContextWindowSize: return contextWindow
            case .decodingFailure: return decoding
            case .unsupportedGuide, .unsupportedLanguageOrLocale: return unsupported
            case .refusal: return refusal
            case .concurrentRequests: return concurrent
            @unknown default: return other
            }
        }
        // `LanguageModelError` replaces `GenerationError` in the iOS 27 SDK (Xcode 27, Swift 6.4).
        // CI still builds with Xcode 26, where the type does not exist, so this is a compile-time
        // guard, not `#available`.
        #if compiler(>=6.4)
        if let model = error as? LanguageModelError {
            switch model {
            case .rateLimited: return rateLimited
            case .guardrailViolation: return guardrail
            case .contextSizeExceeded: return contextWindow
            case .refusal: return refusal
            case .timeout: return timeout
            case .unsupportedCapability, .unsupportedTranscriptContent,
                 .unsupportedGenerationGuide, .unsupportedLanguageOrLocale: return unsupported
            @unknown default: return other
            }
        }
        #endif
        #endif
        return other
    }
}

/// Reads and writes the run file. On the phone that is the app's Documents folder, which
/// `devicectl` can copy from without the user doing anything.
struct MeasurementStore: Sendable {
    let url: URL

    init(name: String, in directory: URL) {
        self.url = directory.appendingPathComponent("\(name).json")
    }

    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var coder: (encoder: JSONEncoder, decoder: JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (encoder, decoder)
    }

    func load(name: String) -> MeasurementRun {
        guard let data = try? Data(contentsOf: url),
              let run = try? Self.coder.decoder.decode(MeasurementRun.self, from: data) else {
            return MeasurementRun(name: name, startedAt: Date())
        }
        return run
    }

    func save(_ run: MeasurementRun) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Self.coder.encoder.encode(run).write(to: url, options: .atomic)
    }
}
