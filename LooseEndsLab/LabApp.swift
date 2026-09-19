import BackgroundTasks
import SwiftUI

/// A separate, throwaway app for measuring the on-device model (Issue #67 and the spikes after it).
///
/// It exists because the measurement must not occupy Henning's phone: he opens it when it suits
/// him, taps once, and can leave at any moment. Nothing here touches the real app's data — no app
/// group, no CloudKit, no shared store. Deleting this app deletes the whole measurement.
@main
struct LabApp: App {
    @State private var runner: MeasurementRunner

    init() {
        let runner = MeasurementRunner()
        _runner = State(initialValue: runner)
        // Wildcard identifier, as the scheduler requires for continued processing.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "\(MeasurementRunner.taskIdentifierPrefix).*", using: nil) { task in
            guard let task = task as? BGContinuedProcessingTask else { return }
            Task { @MainActor in runner.adopt(task) }
        }
    }

    var body: some Scene {
        WindowGroup {
            LabView(runner: runner)
        }
    }
}

struct LabView: View {
    @Bindable var runner: MeasurementRunner

    var body: some View {
        NavigationStack {
            Form {
                Section("Messreihe") {
                    LabeledContent("Sätze", value: "\(runner.done) von \(runner.total)")
                    ProgressView(value: runner.progress)
                    if runner.run.failedAttempts > 0 {
                        LabeledContent("Fehlversuche", value: "\(runner.run.failedAttempts), davon gedrosselt: \(runner.run.rateLimitedAttempts)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Zustand") {
                    Text(statusText)
                    if let reason = runner.modelUnavailableReason {
                        Text("Apple Intelligence antwortet nicht: \(reason)")
                            .foregroundStyle(.red)
                    }
                    if !runner.lastNote.isEmpty {
                        Text(runner.lastNote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(runner.done == 0 ? "Messen" : "Weitermessen") { runner.start() }
                        .disabled(runner.state == .running || runner.state == .finished || runner.modelUnavailableReason != nil)
                    Button("Anhalten") { runner.stop() }
                        .disabled(runner.state != .running)
                } footer: {
                    Text("Nach dem Tippen läuft die Messung weiter, auch wenn du die App verlässt — sichtbar in der Dynamic Island und dort jederzeit abbrechbar. Von selbst startet nichts. Jeder gemessene Satz ist sofort gesichert, ein Abbruch kostet nichts.")
                }
            }
            .navigationTitle("Loose Ends Labor")
        }
    }

    private var statusText: String {
        switch runner.state {
        case .idle: return "Bereit."
        case .running: return "Misst …"
        case .paused(let reason): return reason
        case .finished: return "Fertig. Die Ergebnisse werden beim nächsten Mal im selben WLAN abgeholt."
        }
    }
}
