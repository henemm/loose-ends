import Foundation
import OSLog
import os

/// A measuring point on the way from process start to listening capture (#22).
enum LaunchPoint: String, Codable, CodingKeyRepresentable, Sendable, CaseIterable {
    case initStart, containerStart, containerEnd, initEnd, captureAppeared, speechStartCalled
    case modelReady, analyzerStarted, engineStarted, listening, firstBuffer
}

/// One cold start: milliseconds since the zero point per measuring point, plus the sections between them.
struct LaunchRun: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case automated, press }
    enum ZeroPoint: String, Codable, Sendable { case processStart, firstPoint }

    let kind: Kind
    let build: String
    let os: String
    let device: String
    let zeroPoint: ZeroPoint
    let points: [LaunchPoint: Double]
    let sections: [LaunchTimings.Section: Double]

    init(kind: Kind, build: String, os: String, device: String, zeroPoint: ZeroPoint, points: [LaunchPoint: Double]) {
        (self.kind, self.build, self.os, self.device, self.zeroPoint) = (kind, build, os, device, zeroPoint)
        self.points = points
        sections = LaunchTimings.sections(from: points)
    }
}

/// Collects points in memory and hands the run to `write` exactly once: on the first buffer after
/// `listening`, or when `bufferTimeout` passed after `listening` without one. The first value per point wins.
final class LaunchRecorder: Sendable {
    static let bufferTimeout: Double = 3000

    private struct State: Sendable {
        var points: [LaunchPoint: Double] = [:]
        var written = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())
    private let template: LaunchRun
    private let write: @Sendable (LaunchRun) -> Void

    init(template: LaunchRun, write: @escaping @Sendable (LaunchRun) -> Void) {
        self.template = template
        self.write = write
    }

    func mark(_ point: LaunchPoint, at ms: Double) {
        let run = state.withLock { state -> LaunchRun? in
            guard state.points[point] == nil else { return nil }
            if point == .firstBuffer, state.points[.listening] == nil { return nil }
            state.points[point] = ms
            return point == .firstBuffer ? take(&state) : nil
        }
        if let run { write(run) }
    }

    func timeoutElapsed(at ms: Double) {
        let run = state.withLock { state -> LaunchRun? in
            guard let listening = state.points[.listening], ms >= listening + Self.bufferTimeout else { return nil }
            return take(&state)
        }
        if let run { write(run) }
    }

    private func take(_ state: inout State) -> LaunchRun? {
        guard !state.written else { return nil }
        state.written = true
        let t = template
        return LaunchRun(kind: t.kind, build: t.build, os: t.os, device: t.device, zeroPoint: t.zeroPoint, points: state.points)
    }
}

enum LaunchTimings {
    enum Section: String, Codable, CodingKeyRepresentable, Sendable, CaseIterable {
        case processToInit, initialization, container, initToCapture, captureToSpeechStart
        case modelCheck, analyzer, engine, total

        /// Start (nil = zero point) and end of the section.
        var bounds: (from: LaunchPoint?, to: LaunchPoint) {
            switch self {
            case .processToInit: (nil, .initStart)
            case .initialization: (.initStart, .initEnd)
            case .container: (.containerStart, .containerEnd)
            case .initToCapture: (.initEnd, .captureAppeared)
            case .captureToSpeechStart: (.captureAppeared, .speechStartCalled)
            case .modelCheck: (.speechStartCalled, .modelReady)
            case .analyzer: (.modelReady, .analyzerStarted)
            case .engine: (.analyzerStarted, .engineStarted)
            case .total: (nil, .listening)
            }
        }
    }

    struct Appended: Sendable {
        let data: Data
        let existingWasCorrupt: Bool
    }

    static let measureArgument = "-measureLaunch"
    static let fileName = "launch-timings.json"
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Launch")

    /// Differences between points; a missing point drops its adjacent sections, nothing is guessed.
    static func sections(from points: [LaunchPoint: Double]) -> [Section: Double] {
        var result: [Section: Double] = [:]
        for section in Section.allCases {
            guard let end = points[section.bounds.to] else { continue }
            guard let from = section.bounds.from else { result[section] = end; continue }
            if let start = points[from] { result[section] = end - start }
        }
        return result
    }

    static func append(_ run: LaunchRun, to existing: Data?) throws -> Appended {
        var runs: [LaunchRun] = []
        var corrupt = false
        if let existing, !existing.isEmpty {
            do {
                runs = try JSONDecoder().decode([LaunchRun].self, from: existing)
            } catch {
                logger.error("Messdatei beschädigt: \(error, privacy: .public)")
                corrupt = true
            }
        }
        runs.append(run)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return Appended(data: try encoder.encode(runs), existingWasCorrupt: corrupt)
    }

    static func isProbeBuild(bundleID: String?) -> Bool { bundleID?.hasSuffix(".probe") ?? false }

    static func kind(arguments: [String]) -> LaunchRun.Kind {
        arguments.contains(measureArgument) ? .automated : .press
    }

    /// Appends the run to `directory/launch-timings.json`, in the probe build only; anything else touches no file.
    static func persist(_ run: LaunchRun, bundleID: String?, directory: URL) throws {
        guard isProbeBuild(bundleID: bundleID) else { return }
        let file = directory.appendingPathComponent(fileName)
        let existing = FileManager.default.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        let result = try append(run, to: existing)
        if result.existingWasCorrupt {
            let aside = "launch-timings.corrupt-\(Int(Date().timeIntervalSince1970)).json"
            try FileManager.default.moveItem(at: file, to: directory.appendingPathComponent(aside))
        }
        try result.data.write(to: file, options: .atomic)
    }
}

// MARK: - Product wiring: signposts always, the file only in the probe build.

extension LaunchTimings {
    private static let signposter = OSSignposter(subsystem: "com.henning.looseends", category: "Launch")
    private static let clock = LaunchClock.make()
    private static let queue = DispatchQueue(label: "com.henning.looseends.launch-timings", qos: .utility)
    private static let recorder = LaunchRecorder(template: template()) { run in
        queue.async { persistInDocuments(run) }
    }

    /// Cheap enough for the audio thread: a clock read, a signpost and a dictionary entry under a lock.
    static func mark(_ point: LaunchPoint) {
        let ms = clock.milliseconds()
        signposter.emitEvent("LaunchPoint", "\(point.rawValue, privacy: .public) \(ms, privacy: .public) ms")
        recorder.mark(point, at: ms)
        guard point == .listening else { return }
        queue.asyncAfter(deadline: .now() + .milliseconds(Int(LaunchRecorder.bufferTimeout) + 50)) {
            recorder.timeoutElapsed(at: clock.milliseconds())
        }
    }

    private static func persistInDocuments(_ run: LaunchRun) {
        do {
            try persist(run, bundleID: Bundle.main.bundleIdentifier, directory: URL.documentsDirectory)
        } catch {
            logger.error("Messdatei nicht geschrieben: \(error, privacy: .public)")
        }
    }

    private static func template() -> LaunchRun {
        let info = Bundle.main.infoDictionary ?? [:]
        let build = "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
        var system = utsname()
        uname(&system)
        let device = withUnsafeBytes(of: system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return LaunchRun(kind: kind(arguments: ProcessInfo.processInfo.arguments), build: build,
                         os: ProcessInfo.processInfo.operatingSystemVersionString, device: device,
                         zeroPoint: clock.zeroPoint, points: [:])
    }
}

/// Monotonic milliseconds since the process start (`kp_proc.p_starttime`), so the time before `main` counts.
/// The wall-clock offset is taken once; if `sysctl` fails, the zero point is the first measuring point.
private struct LaunchClock: Sendable {
    let zeroPoint: LaunchRun.ZeroPoint
    let origin: UInt64

    func milliseconds() -> Double {
        Double(DispatchTime.now().uptimeNanoseconds &- origin) / 1_000_000
    }

    static func make() -> LaunchClock {
        let now = DispatchTime.now().uptimeNanoseconds
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else {
            Logger(subsystem: "com.henning.looseends", category: "Launch")
                .error("Prozessstart nicht lesbar (errno \(errno, privacy: .public)), Nullpunkt = erster Messpunkt")
            return LaunchClock(zeroPoint: .firstPoint, origin: now)
        }
        let start = info.kp_proc.p_un.__p_starttime
        let started = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
        let elapsed = UInt64(max(0, Date().timeIntervalSince1970 - started) * 1_000_000_000)
        return LaunchClock(zeroPoint: .processStart, origin: now - min(elapsed, now))
    }
}
