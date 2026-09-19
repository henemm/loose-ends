import BackgroundTasks
import Foundation
import Observation
import SwiftUI
import UIKit
import os

/// Runs the corpus through the on-device model in slices.
///
/// The phone is Henning's everyday device, not a test bench: a run may be interrupted at any
/// moment — he leaves the app, the system expires the background task, Apple throttles the model.
/// So the runner owns exactly one rule: measure one note, write the file, then check whether it is
/// still allowed to continue. Nothing is held in memory that would be lost.
@MainActor
@Observable
final class MeasurementRunner {
    enum State: Equatable {
        case idle
        case running
        case paused(String)
        case finished
    }

    private(set) var state: State = .idle
    private(set) var run: MeasurementRun
    private(set) var entries: [Corpus.Entry] = []
    private(set) var lastNote: String = ""

    var done: Int { run.doneIDs.count }
    var total: Int { entries.count }
    var progress: Double { total == 0 ? 0 : Double(done) / Double(total) }
    var resultPath: String { store.url.lastPathComponent }

    private let store: MeasurementStore
    private let enricher = FoundationModelsEnricher()
    private let logger = Logger(subsystem: "com.henning.looseends.lab", category: "measurement")
    private var task: Task<Void, Never>?
    private var backgroundTask: BGContinuedProcessingTask?

    /// Apple throttles after a few calls on battery in the background. Three in a row means the
    /// budget is gone; carrying on would only produce failures, so the run pauses and keeps what
    /// it has.
    private static let giveUpAfterConsecutiveFailures = 3
    static let taskIdentifierPrefix = "com.henning.looseends.lab.measure"

    init(name: String = "date-title") {
        self.store = MeasurementStore(name: name, in: MeasurementStore.documents)
        self.run = store.load(name: name)
        self.entries = (try? Corpus.load()) ?? []
        if !entries.isEmpty && run.remaining(from: entries).isEmpty { state = .finished }
    }

    var modelUnavailableReason: String? { enricher.unavailableReason }

    // MARK: - Starting and stopping

    func start() {
        guard state != .running, !entries.isEmpty else { return }
        state = .running
        submitBackgroundTask()
        task = Task { [weak self] in await self?.measureRemaining() }
    }

    func stop(_ reason: String = "Angehalten") {
        task?.cancel()
        task = nil
        finishBackgroundTask(success: false)
        if case .finished = state {} else { state = .paused(reason) }
    }

    // MARK: - The loop

    private func measureRemaining() async {
        var consecutiveFailures = 0
        for entry in run.remaining(from: entries) {
            if Task.isCancelled { return }
            lastNote = entry.text
            let result = await measure(entry)
            run.results.append(result)
            save()
            updateBackgroundProgress()

            consecutiveFailures = result.succeeded ? 0 : consecutiveFailures + 1
            if consecutiveFailures >= Self.giveUpAfterConsecutiveFailures {
                let throttled = result.wasRateLimited
                stop(throttled ? "Apple drosselt gerade. Später weiter — der Stand bleibt erhalten."
                               : "Das Modell antwortet nicht. Später weiter — der Stand bleibt erhalten.")
                return
            }
        }
        state = .finished
        finishBackgroundTask(success: true)
    }

    private func measure(_ entry: Corpus.Entry) async -> MeasurementResult {
        // Nine in the morning of today: the note is measured as if captured today, which is what
        // every relative date in the corpus is resolved against.
        let calendar = Calendar.current
        let capturedAt = calendar.date(byAdding: .hour, value: 9, to: calendar.startOfDay(for: Date()))!
        let conditions = Conditions.current()
        let started = Date()
        let input = EnrichmentInput(rawText: entry.text, capturedAt: capturedAt,
                                    contextVocabulary: [], projectNames: [], examples: [])
        var result = MeasurementResult(entryID: entry.id, capturedAt: capturedAt, finishedAt: started,
                                       seconds: 0, conditions: conditions)
        do {
            let draft = try await enricher.enrich(input)
            result.title = draft.title?.value
            result.dueDate = draft.dueDate?.value
            result.dueHasTime = draft.dueHasTime
            result.people = draft.people?.value ?? []
        } catch {
            result.error = "\(error)"
            logger.error("Satz \(entry.id, privacy: .public) fehlgeschlagen: \(error, privacy: .public)")
        }
        result.finishedAt = Date()
        result.seconds = result.finishedAt.timeIntervalSince(started)
        return result
    }

    private func save() {
        do {
            try store.save(run)
        } catch {
            logger.error("Ergebnisdatei nicht geschrieben: \(error, privacy: .public)")
            stop("Ergebnisse lassen sich nicht sichern.")
        }
    }

    // MARK: - Staying alive while he puts the phone away

    /// Submitted only on his tap, and only from the foreground: the system shows the run in the
    /// Dynamic Island with a cancel button, so nothing ever measures unseen.
    private func submitBackgroundTask() {
        let request = BGContinuedProcessingTaskRequest(
            identifier: "\(Self.taskIdentifierPrefix).\(UUID().uuidString.prefix(8))",
            title: "Messreihe Datum und Titel",
            subtitle: "\(done) von \(total) Sätzen")
        request.strategy = .queue
        Task {
            do {
                try await BGTaskScheduler.shared.submitTaskRequest(request)
            } catch {
                // Not fatal: the run then simply stops when he leaves the app and resumes later.
                logger.notice("Hintergrundlauf abgelehnt: \(error, privacy: .public)")
            }
        }
    }

    func adopt(_ task: BGContinuedProcessingTask) {
        backgroundTask = task
        task.expirationHandler = { [weak self] in
            Task { @MainActor in self?.stop("Das System hat die Messung beendet. Später weiter.") }
        }
        updateBackgroundProgress()
        if state != .running { start() }
    }

    private func updateBackgroundProgress() {
        backgroundTask?.progress.totalUnitCount = Int64(total)
        backgroundTask?.progress.completedUnitCount = Int64(done)
    }

    private func finishBackgroundTask(success: Bool) {
        backgroundTask?.setTaskCompleted(success: success)
        backgroundTask = nil
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
