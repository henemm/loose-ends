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
        _runner = State(initialValue: MeasurementRunner(
            corpusFileName: Corpus.corpusFileName(from: CommandLine.arguments),
            runsPerEntry: Corpus.runsPerEntry(from: CommandLine.arguments)))
    }

    var body: some Scene {
        WindowGroup {
            LabView(runner: runner)
        }
    }
}

struct LabView: View {
    @Bindable var runner: MeasurementRunner
    @Environment(\.scenePhase) private var scenePhase

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
                    Button(runner.done == 0 ? "Messen" : "Weitermessen") { runner.start(trigger: "Tipp") }
                        .disabled(runner.isActive || runner.state == .finished || runner.modelUnavailableReason != nil)
                    Button("Anhalten") { runner.stop() }
                        .disabled(!runner.isActive)
                } footer: {
                    Text("Misst nur, solange die App offen ist; der Bildschirm bleibt dabei an. Am besten am Strom. Verlässt du die App oder sperrst das Gerät, hält die Messung an und macht beim nächsten Tippen weiter. Jeder gemessene Satz ist sofort gesichert.")
                }
            }
            .navigationTitle("Loose Ends Labor")
        }
        .onChange(of: scenePhase) { _, phase in runner.scene(phase) }
        .task {
            // Only for a run driven from the Mac (simctl/devicectl launch). Henning's own copy is
            // never launched with this argument, so nothing starts without his tap there.
            if CommandLine.arguments.contains("--measure") { runner.start(trigger: "--measure") }
        }
    }

    private var statusText: String {
        switch runner.state {
        case .idle: return "Bereit."
        case .running: return "Misst …"
        case .waiting(let seconds): return "Wartet \(seconds) s nach einem Fehlschlag …"
        case .paused(let reason): return reason
        case .finished: return "Fertig. Die Ergebnisse werden beim nächsten Mal im selben WLAN abgeholt."
        }
    }
}
