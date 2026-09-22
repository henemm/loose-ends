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

    // MARK: - Spike #65 Schritt 1: Mehrfachläufe je Satz (AC-2, AC-3, AC-4, AC-5)

    private static func entry(_ id: String) -> Corpus.Entry {
        try! JSONDecoder().decode(Corpus.Entry.self, from: Data("""
        {"id":"\(id)","lang":"de","text":"Testsatz \(id)"}
        """.utf8))
    }

    private static func result(entryID: String, runIndex: Int) -> MeasurementResult {
        MeasurementResult(entryID: entryID, capturedAt: Date(), finishedAt: Date(), seconds: 0,
                          conditions: Conditions(appState: "vordergrund", power: "strom", batteryPercent: 50,
                                                 lowPowerMode: false, thermal: "normal", device: "d", systemVersion: "27"),
                          runIndex: runIndex)
    }

    @Test("Zwei erfolgreiche Läufe: der dritte Lauf ist noch offen, mit aufsteigendem Index (AC-2)")
    func remainingCountsRunsPerEntry() {
        var run = MeasurementRun(name: "t", startedAt: Date())
        run.results = [Self.result(entryID: "x", runIndex: 0), Self.result(entryID: "x", runIndex: 1)]
        let open = run.remaining(from: [Self.entry("x")], runsPerEntry: 3)
        #expect(open.count == 1)
        #expect(open.first?.runIndex == 2)
    }

    @Test("Drei erfolgreiche Läufe bei runsPerEntry 3: der Satz ist vollständig erledigt (AC-2)")
    func remainingEmptyWhenRunsPerEntryReached() {
        var run = MeasurementRun(name: "t", startedAt: Date())
        run.results = [Self.result(entryID: "x", runIndex: 0), Self.result(entryID: "x", runIndex: 1),
                       Self.result(entryID: "x", runIndex: 2)]
        #expect(run.remaining(from: [Self.entry("x")], runsPerEntry: 3).isEmpty)
    }

    @Test("Alte Ergebnisdatei ohne runIndex-Feld dekodiert als 0 und gilt einlaufig als erledigt (AC-3)")
    func oldResultWithoutRunIndexDefaultsToZero() throws {
        let json = """
        {"name":"date-title","startedAt":"2026-09-20T05:21:00Z","results":[
          {"entryID":"x","capturedAt":"2026-09-20T07:00:00Z","finishedAt":"2026-09-20T05:22:01Z",
           "seconds":12.1,"conditions":{"appState":"inaktiv","power":"akku","batteryPercent":75,
           "lowPowerMode":false,"thermal":"normal","device":"iPhone17,1","systemVersion":"27.0"},
           "dueHasTime":false,"people":[],"title":"Mülltonne rausstellen"}]}
        """
        let run = try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: Data(json.utf8))
        #expect(run.results[0].runIndex == 0)
        #expect(run.remaining(from: [Self.entry("x")]).isEmpty)
    }

    @Test("Gesamtzahl, erledigte und Fortschritt rechnen über Läufe, nicht über Sätze (AC-4)")
    func progressCountsRuns() {
        var run = MeasurementRun(name: "t", startedAt: Date())
        #expect(MeasurementProgress.total(entries: 2, runsPerEntry: 3) == 6)
        #expect(MeasurementProgress.done(in: run) == 0)
        #expect(MeasurementProgress.progress(done: 0, total: 6) == 0)
        run.results = [Self.result(entryID: "a", runIndex: 0), Self.result(entryID: "a", runIndex: 1),
                       Self.result(entryID: "b", runIndex: 0), Self.result(entryID: "b", runIndex: 1)]
        #expect(MeasurementProgress.done(in: run) == 4)
        #expect(MeasurementProgress.progress(done: 4, total: 6) == 4.0 / 6.0)
    }

    @Test("Aufeinanderfolgende Läufe desselben Satzes bekommen aufsteigende Indizes (AC-5)")
    func sequentialRunsGetAscendingIndex() {
        var run = MeasurementRun(name: "t", startedAt: Date())
        let entries = [Self.entry("x")]
        let first = run.remaining(from: entries, runsPerEntry: 2)
        #expect(first.first?.runIndex == 0)
        run.results.append(Self.result(entryID: "x", runIndex: first.first!.runIndex))
        let second = run.remaining(from: entries, runsPerEntry: 2)
        #expect(second.first?.runIndex == 1)
        run.results.append(Self.result(entryID: "x", runIndex: second.first!.runIndex))
        #expect(run.remaining(from: entries, runsPerEntry: 2).isEmpty)
    }

    // MARK: - Spike #65 Schritt 2 (#108): Selbstkonsistenz-Rohwerte (AC-2, AC-3)

    @Test("Ergebnisdatei ohne die fünf neuen Schlüssel dekodiert sie als nil/leer (AC-2)")
    func oldResultWithoutSelfConsistencyFieldsDecodes() throws {
        let json = """
        {"name":"focusblox","startedAt":"2026-09-22T05:21:00Z","results":[
          {"entryID":"fb-1","capturedAt":"2026-09-22T07:00:00Z","finishedAt":"2026-09-22T05:22:01Z",
           "seconds":12.1,"conditions":{"appState":"inaktiv","power":"akku","batteryPercent":75,
           "lowPowerMode":false,"thermal":"normal","device":"iPhone17,1","systemVersion":"27.0"},
           "dueHasTime":false,"people":[],"title":"Rechnung prüfen"}]}
        """
        let run = try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: Data(json.utf8))
        let result = run.results[0]
        #expect(result.importance == nil)
        #expect(result.urgency == nil)
        #expect(result.duration == nil)
        #expect(result.energy == nil)
        #expect(result.contexts == [])
    }

    @Test("Alle fünf neuen Rohwerte überleben Schreiben und Lesen (AC-2)")
    func selfConsistencyFieldsRoundTrip() throws {
        var result = Self.result(entryID: "fb-1", runIndex: 0)
        result.importance = "high"
        result.urgency = "low"
        result.duration = "minutes15"
        result.energy = "high"
        result.contexts = ["zuhause", "telefon"]
        var run = MeasurementRun(name: "t", startedAt: Date())
        run.results = [result]
        let data = try MeasurementStore.coder.encoder.encode(run)
        let back = try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: data)
        #expect(back.results[0].importance == "high")
        #expect(back.results[0].urgency == "low")
        #expect(back.results[0].duration == "minutes15")
        #expect(back.results[0].energy == "high")
        #expect(back.results[0].contexts == ["zuhause", "telefon"])
    }

    @Test("Der Selbstkonsistenz-Auszug eines EnrichmentDraft reicht alle fünf Werte unverändert durch (AC-3)")
    func draftSelfConsistencyValuesPassThrough() {
        let draft = EnrichmentDraft(
            importance: .init(.high, confidence: 0.9, reason: "x"),
            urgency: .init(.low, confidence: 0.9, reason: "x"),
            duration: .init(.minutes15, confidence: 0.9, reason: "x"),
            energy: .init(.high, confidence: 0.9, reason: "x"),
            contexts: .init(["zuhause", "telefon"], confidence: 0.9, reason: "x")
        )
        let fields = draft.selfConsistencyValues
        #expect(fields.importance == "high")
        #expect(fields.urgency == "low")
        #expect(fields.duration == "minutes15")
        #expect(fields.energy == "high")
        #expect(fields.contexts == ["zuhause", "telefon"])
    }

    @Test("Fehlende Guesses ergeben nil/leer, kein Absturz (AC-3)")
    func draftSelfConsistencyValuesWithMissingGuesses() {
        let fields = EnrichmentDraft().selfConsistencyValues
        #expect(fields.importance == nil)
        #expect(fields.urgency == nil)
        #expect(fields.duration == nil)
        #expect(fields.energy == nil)
        #expect(fields.contexts == [])
    }
}
