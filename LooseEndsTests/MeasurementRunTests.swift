import Foundation
import Testing
@testable import LooseEnds
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The result file must let a reader tell the app's own doings from the model's answers (#83):
/// every run carries its lifecycle as events, every failure its typed kind, and pacing after a
/// failure is a rule, not a reflex.
@Suite("Messlauf-Datei und Taktung")
struct MeasurementRunTests {
    @Test("Alte Ergebnisdatei ohne Ereignisse bleibt lesbar")
    func oldFileDecodes() throws {
        let json = """
        {"name":"date-title","startedAt":"2026-09-20T05:21:00Z","results":[
          {"entryID":"de-heute-1","capturedAt":"2026-09-20T07:00:00Z","finishedAt":"2026-09-20T05:22:01Z",
           "seconds":12.1,"conditions":{"appState":"inaktiv","power":"akku","batteryPercent":75,
           "lowPowerMode":false,"thermal":"normal","device":"iPhone17,1","systemVersion":"27.0"},
           "dueHasTime":false,"people":[],"title":"Mülltonne rausstellen"}]}
        """
        let run = try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: Data(json.utf8))
        #expect(run.results.count == 1)
        #expect(run.events.isEmpty)
        #expect(run.results[0].errorKind == nil)
    }

    @Test("Ereignisse und Fehlerart überleben Schreiben und Lesen")
    func eventsRoundTrip() throws {
        var run = MeasurementRun(name: "t", startedAt: Date(timeIntervalSince1970: 0))
        run.log("app", "gestartet mit --measure", at: Date(timeIntervalSince1970: 1))
        run.log("scene", "hintergrund", at: Date(timeIntervalSince1970: 2))
        var result = MeasurementResult(entryID: "x", capturedAt: Date(), finishedAt: Date(), seconds: 0,
                                       conditions: Conditions(appState: "vordergrund", power: "strom", batteryPercent: 50,
                                                              lowPowerMode: false, thermal: "normal", device: "d", systemVersion: "27"))
        result.error = "boom"
        result.errorKind = "rateLimited"
        run.results.append(result)
        let data = try MeasurementStore.coder.encoder.encode(run)
        let back = try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: data)
        #expect(back.events.map(\.kind) == ["app", "scene"])
        #expect(back.events[1].note == "hintergrund")
        #expect(back.results[0].errorKind == "rateLimited")
        #expect(back.results[0].wasRateLimited)
    }

    @Test("Nach einem Fehlschlag wird gewartet, nach dreien angehalten")
    func pacing() {
        #expect(MeasurementPacing.delayBeforeNext(consecutiveFailures: 0) == 0)
        #expect(MeasurementPacing.delayBeforeNext(consecutiveFailures: 1) == 60)
        #expect(MeasurementPacing.delayBeforeNext(consecutiveFailures: 2) == 60)
        #expect(MeasurementPacing.delayBeforeNext(consecutiveFailures: 3) == nil)
    }

    @Test("Die Labor-App meldet keine Hintergrundmodi mehr an")
    func noBackgroundModes() throws {
        let yaml = try String(contentsOf: MeasurementFiles.repositoryRoot.appendingPathComponent("project.yml"), encoding: .utf8)
        guard let start = yaml.range(of: "\n  LooseEndsLab:\n"),
              let end = yaml.range(of: "\n  LooseEndsTests:\n") else {
            Issue.record("Lab-Target nicht in project.yml gefunden"); return
        }
        let target = yaml[start.upperBound..<end.lowerBound]
        #expect(!target.contains("UIBackgroundModes"))
        #expect(!target.contains("BGTaskSchedulerPermittedIdentifiers"))
    }

    @Test("Fehlerart wird typisiert erkannt, nicht per Textvergleich")
    func errorKinds() {
        #expect(MeasurementErrorKind.classify(NSError(domain: "x", code: 1)) == "andere")
        #if canImport(FoundationModels)
        let context = LanguageModelSession.GenerationError.Context(debugDescription: "t")
        #expect(MeasurementErrorKind.classify(LanguageModelSession.GenerationError.rateLimited(context)) == "rateLimited")
        #expect(MeasurementErrorKind.classify(LanguageModelSession.GenerationError.guardrailViolation(context)) == "guardrail")
        #endif
    }
}
