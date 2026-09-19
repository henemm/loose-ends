import Foundation

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

    var succeeded: Bool { error == nil }
    var wasRateLimited: Bool { error?.localizedCaseInsensitiveContains("rate limit") ?? false }
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

/// The result file: written on the phone after every single note, read on the Mac.
///
/// Written after *every* note on purpose — a slice can end at any moment, because the user puts
/// the phone away or the system expires the task, and nothing measured may be lost.
struct MeasurementRun: Codable, Sendable {
    var name: String
    var startedAt: Date
    var results: [MeasurementResult] = []

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
