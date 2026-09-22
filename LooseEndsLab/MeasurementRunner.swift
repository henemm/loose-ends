import Foundation
import Observation
import SwiftUI
import UIKit
import os

/// Runs the corpus through the on-device model, one note at a time, only while the app is open.
///
/// The phone is Henning's everyday device, not a test bench: a run may be interrupted at any
/// moment — he locks the phone, switches apps, Apple throttles the model. So the runner owns
/// exactly one rule: measure one note, write the file, then check whether it is still allowed to
/// continue. Nothing is held in memory that would be lost.
///
/// It never measures in the background (#83): on battery Apple rate-limits background requests
/// after a handful of calls, so a background run only ever produced failures. Instead the screen
/// is kept awake while measuring, and leaving the foreground pauses the run.
///
/// Everything the runner does goes into the same file as the results, as events with a
/// timestamp — otherwise a bug in this class and a condition of the system look identical.
@MainActor
@Observable
final class MeasurementRunner {
    enum State: Equatable {
        case idle
        case running
        case waiting(Int)
        case paused(String)
        case finished
    }

    private(set) var state: State = .idle
    private(set) var run: MeasurementRun
    private(set) var entries: [Corpus.Entry] = []
    private(set) var lastNote: String = ""

    var done: Int { MeasurementProgress.done(in: run) }
    var total: Int { MeasurementProgress.total(entries: entries.count, runsPerEntry: runsPerEntry) }
    var progress: Double { MeasurementProgress.progress(done: done, total: total) }
    var resultPath: String { store.url.lastPathComponent }
    var isActive: Bool {
        switch state {
        case .running, .waiting: return true
        default: return false
        }
    }

    private let store: MeasurementStore
    private let runsPerEntry: Int
    private let enricher = FoundationModelsEnricher()
    private let logger = Logger(subsystem: "com.henning.looseends.lab", category: "measurement")
    private var task: Task<Void, Never>?

    init(name: String = "date-title", arguments: [String] = CommandLine.arguments,
         corpusFileName: String = Corpus.fileName, runsPerEntry: Int = 1) {
        self.store = MeasurementStore(name: name, in: MeasurementStore.documents)
        self.run = store.load(name: name)
        self.runsPerEntry = runsPerEntry
        self.entries = (try? Corpus.load(fileName: corpusFileName)) ?? []
        if !entries.isEmpty && run.remaining(from: entries, runsPerEntry: runsPerEntry).isEmpty { state = .finished }
        log("app", "gestartet; Argumente: \(arguments.dropFirst().joined(separator: " ")); Korpus: \(entries.count) Sätze")
        log("model", enricher.unavailableReason.map { "nicht verfügbar: \($0)" } ?? "verfügbar")
    }

    var modelUnavailableReason: String? { enricher.unavailableReason }

    // MARK: - Starting and stopping

    func start(trigger: String) {
        guard !isActive, !entries.isEmpty else { return }
        state = .running
        UIApplication.shared.isIdleTimerDisabled = true
        log("start", "\(trigger); \(done) von \(total) erledigt")
        task = Task { [weak self] in await self?.measureRemaining() }
    }

    func stop(_ reason: String = "Angehalten") {
        guard isActive else { return }
        task?.cancel()
        task = nil
        UIApplication.shared.isIdleTimerDisabled = false
        state = .paused(reason)
        log("stop", reason)
    }

    /// Every scene change is an event; leaving the foreground pauses the run and keeps its state.
    func scene(_ phase: ScenePhase) {
        let name: String
        switch phase {
        case .active: name = "vordergrund"
        case .inactive: name = "inaktiv"
        default: name = "hintergrund"
        }
        log("scene", name)
        if phase != .active { stop("App verlassen — der Stand bleibt erhalten.") }
    }

    // MARK: - The loop

    private func measureRemaining() async {
        var consecutiveFailures = 0
        for (entry, runIndex) in run.remaining(from: entries, runsPerEntry: runsPerEntry) {
            if Task.isCancelled { return }
            lastNote = entry.text
            let result = await measure(entry, runIndex: runIndex)
            run.results.append(result)
            if let kind = result.errorKind { run.log("failure", "\(entry.id): \(kind)") }
            save()
            if Task.isCancelled { return }

            consecutiveFailures = result.succeeded ? 0 : consecutiveFailures + 1
            guard let delay = MeasurementPacing.delayBeforeNext(consecutiveFailures: consecutiveFailures) else {
                stop(result.wasRateLimited
                     ? "Apple drosselt gerade. Später weiter — der Stand bleibt erhalten."
                     : "Das Modell antwortet nicht (\(result.errorKind ?? MeasurementErrorKind.other)). Später weiter — der Stand bleibt erhalten.")
                return
            }
            if delay > 0 {
                state = .waiting(Int(delay))
                log("wait", "\(Int(delay)) s nach Fehlschlag")
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                state = .running
            }
        }
        state = .finished
        UIApplication.shared.isIdleTimerDisabled = false
        log("finished", "\(done) von \(total)")
    }

    private func measure(_ entry: Corpus.Entry, runIndex: Int) async -> MeasurementResult {
        // Nine in the morning of today: the note is measured as if captured today, which is what
        // every relative date in the corpus is resolved against.
        let calendar = Calendar.current
        let capturedAt = calendar.date(byAdding: .hour, value: 9, to: calendar.startOfDay(for: Date()))!
        let conditions = Conditions.current()
        let started = Date()
        let input = EnrichmentInput(rawText: entry.text, capturedAt: capturedAt,
                                    contextVocabulary: [], projectNames: [], examples: [])
        var result = MeasurementResult(entryID: entry.id, capturedAt: capturedAt, finishedAt: started,
                                       seconds: 0, conditions: conditions, runIndex: runIndex)
        do {
            let draft = try await enricher.enrich(input)
            result.title = draft.title?.value
            result.dueDate = draft.dueDate?.value
            result.dueHasTime = draft.dueHasTime
            result.people = draft.people?.value ?? []
        } catch {
            result.error = "\(error)"
            result.errorKind = MeasurementErrorKind.classify(error)
            logger.error("Satz \(entry.id, privacy: .public) fehlgeschlagen (\(result.errorKind ?? "", privacy: .public)): \(error, privacy: .public)")
        }
        result.finishedAt = Date()
        result.seconds = result.finishedAt.timeIntervalSince(started)
        return result
    }

    // MARK: - Persistence

    private func log(_ kind: String, _ note: String = "") {
        run.log(kind, note)
        save()
    }

    private func save() {
        do {
            try store.save(run)
        } catch {
            logger.error("Ergebnisdatei nicht geschrieben: \(error, privacy: .public)")
            task?.cancel()
            task = nil
            UIApplication.shared.isIdleTimerDisabled = false
            state = .paused("Ergebnisse lassen sich nicht sichern.")
        }
    }
}

extension Conditions {
    @MainActor
    static func current() -> Conditions {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let state: String
        switch UIApplication.shared.applicationState {
        case .active: state = "vordergrund"
        case .background: state = "hintergrund"
        default: state = "inaktiv"
        }
        let power = device.batteryState == .unplugged || device.batteryState == .unknown ? "akku" : "strom"
        let thermal: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "normal"
        case .fair: thermal = "fair"
        case .serious: thermal = "serious"
        case .critical: thermal = "critical"
        @unknown default: thermal = "unbekannt"
        }
        return Conditions(
            appState: state,
            power: power,
            batteryPercent: device.batteryLevel < 0 ? -1 : Int((device.batteryLevel * 100).rounded()),
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermal: thermal,
            device: Conditions.hardwareIdentifier,
            systemVersion: device.systemVersion)
    }

    static let hardwareIdentifier: String = {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
        }
    }()
}
