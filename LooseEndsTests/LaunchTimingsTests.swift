import Foundation
import Testing
@testable import LooseEnds

/// Measuring points for the cold start into capture (#22): sections from timestamps, one file per
/// process, appended runs, and no file outside the probe build.
@Suite("Launch timings (#22)") struct LaunchTimingsTests {
    private static let points: [LaunchPoint: Double] = [
        .initStart: 120, .containerStart: 130, .containerEnd: 170, .initEnd: 180,
        .captureAppeared: 400, .speechStartCalled: 410, .modelReady: 450,
        .analyzerStarted: 600, .engineStarted: 700, .listening: 720,
    ]

    private static func run(_ kind: LaunchRun.Kind = .press, firstBuffer: Double? = nil) -> LaunchRun {
        var points = Self.points
        points[.firstBuffer] = firstBuffer
        return LaunchRun(kind: kind, build: "1.0 (42)", os: "27.0", device: "iPhone17,1",
                         zeroPoint: .processStart, points: points)
    }

    @Test("Sections are exact differences between points")
    func sections() {
        let sections = LaunchTimings.sections(from: Self.points)
        #expect(sections[.processToInit] == 120)
        #expect(sections[.initialization] == 60)
        #expect(sections[.container] == 40)
        #expect(sections[.initToCapture] == 220)
        #expect(sections[.captureToSpeechStart] == 10)
        #expect(sections[.modelCheck] == 40)
        #expect(sections[.analyzer] == 150)
        #expect(sections[.engine] == 100)
        #expect(sections[.total] == 720)
    }

    @Test("A missing point drops exactly its adjacent sections, nothing is guessed")
    func missingPoint() {
        var points = Self.points
        points[.modelReady] = nil
        let sections = LaunchTimings.sections(from: points)
        #expect(sections[.modelCheck] == nil)
        #expect(sections[.analyzer] == nil)
        #expect(sections[.engine] == 100)
        #expect(sections[.total] == 720)
    }

    @Test("Appending keeps earlier runs unchanged")
    func append() throws {
        let first = try LaunchTimings.append(Self.run(.automated), to: nil)
        #expect(!first.existingWasCorrupt)
        let second = try LaunchTimings.append(Self.run(.press, firstBuffer: 760), to: first.data)
        let third = try LaunchTimings.append(Self.run(), to: second.data)
        let runs = try JSONDecoder().decode([LaunchRun].self, from: third.data)
        #expect(runs.count == 3)
        #expect(runs[0] == Self.run(.automated))
        #expect(runs[1] == Self.run(.press, firstBuffer: 760))
    }

    @Test("A corrupt file is reported and the new run starts a fresh one")
    func corrupt() throws {
        let result = try LaunchTimings.append(Self.run(), to: Data("not json".utf8))
        #expect(result.existingWasCorrupt)
        let runs = try JSONDecoder().decode([LaunchRun].self, from: result.data)
        #expect(runs == [Self.run()])
    }

    @Test("Only the probe build counts as probe")
    func probe() {
        #expect(!LaunchTimings.isProbeBuild(bundleID: "com.henning.looseends"))
        #expect(LaunchTimings.isProbeBuild(bundleID: "com.henning.looseends.probe"))
        #expect(!LaunchTimings.isProbeBuild(bundleID: nil))
    }

    @Test("The launch argument marks a run as automated")
    func kind() {
        #expect(LaunchTimings.kind(arguments: ["LooseEnds", LaunchTimings.measureArgument]) == .automated)
        #expect(LaunchTimings.kind(arguments: ["LooseEnds"]) == .press)
    }

    @Test("Persisting under the product id creates no file; the probe id does")
    func persist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) } catch { Issue.record(error) }
        }
        let file = directory.appendingPathComponent(LaunchTimings.fileName)

        try LaunchTimings.persist(Self.run(), bundleID: "com.henning.looseends", directory: directory)
        #expect(!FileManager.default.fileExists(atPath: file.path))

        try LaunchTimings.persist(Self.run(), bundleID: "com.henning.looseends.probe", directory: directory)
        try LaunchTimings.persist(Self.run(), bundleID: "com.henning.looseends.probe", directory: directory)
        let runs = try JSONDecoder().decode([LaunchRun].self, from: Data(contentsOf: file))
        #expect(runs.count == 2)
    }

    @Test("Listening alone does not write; the first buffer after it writes once")
    func writeOnFirstBuffer() {
        let written = WrittenRuns()
        let recorder = LaunchRecorder(template: Self.run(), write: written.append)
        for (point, ms) in Self.points { recorder.mark(point, at: ms) }
        #expect(written.runs.isEmpty)
        recorder.mark(.firstBuffer, at: 760)
        recorder.mark(.firstBuffer, at: 800)
        recorder.mark(.listening, at: 900)
        recorder.timeoutElapsed(at: 5000)
        #expect(written.runs.count == 1)
        #expect(written.runs.first?.points[.firstBuffer] == 760)
        #expect(written.runs.first?.points[.listening] == 720)
    }

    @Test("Without a buffer the timeout writes once with no first buffer")
    func writeOnTimeout() {
        let written = WrittenRuns()
        let recorder = LaunchRecorder(template: Self.run(), write: written.append)
        for (point, ms) in Self.points { recorder.mark(point, at: ms) }
        recorder.timeoutElapsed(at: 720 + LaunchRecorder.bufferTimeout - 1)
        #expect(written.runs.isEmpty)
        recorder.timeoutElapsed(at: 720 + LaunchRecorder.bufferTimeout)
        recorder.mark(.firstBuffer, at: 4000)
        #expect(written.runs.count == 1)
        #expect(written.runs.first?.points[.firstBuffer] == nil)
    }

    @Test("A timeout before listening writes nothing")
    func timeoutBeforeListening() {
        let written = WrittenRuns()
        let recorder = LaunchRecorder(template: Self.run(), write: written.append)
        recorder.mark(.initStart, at: 120)
        recorder.timeoutElapsed(at: 10_000)
        #expect(written.runs.isEmpty)
    }
}

/// Collects what the recorder hands to its writer.
private final class WrittenRuns: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [LaunchRun] = []
    var runs: [LaunchRun] { lock.withLock { stored } }
    func append(_ run: LaunchRun) { lock.withLock { stored.append(run) } }
}
