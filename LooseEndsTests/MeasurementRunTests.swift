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
        #if canImport(FoundationModels) && !os(watchOS)
        let text = "t"
        func kind(_ error: Error) -> String { MeasurementErrorKind.classify(error) }
        #expect(kind(LanguageModelError.rateLimited(.init(resetDate: nil, debugDescription: text))) == "rateLimited")
        #expect(kind(LanguageModelError.guardrailViolation(.init(debugDescription: text))) == "guardrail")
        #expect(kind(LanguageModelError.contextSizeExceeded(.init(contextSize: 10, tokenCount: 20, debugDescription: text))) == "contextWindow")
        #expect(kind(LanguageModelError.refusal(.init(explanation: text, debugDescription: text))) == "refusal")
        #expect(kind(LanguageModelError.timeout(.init(debugDescription: text))) == "timeout")
        #expect(kind(LanguageModelError.unsupportedGenerationGuide(.init(schemaName: nil, debugDescription: text))) == "unsupported")
        #expect(kind(SystemLanguageModel.Error.assetsUnavailable(.init(debugDescription: text))) == "assetsUnavailable")
        #expect(kind(LanguageModelSession.Error.concurrentRequests) == "concurrent")
        #expect(kind(GeneratedContent.ParsingError(rawContent: "x", debugDescription: text)) == "decoding")
        #expect(kind(LanguageModelSession.Error.transcriptMutationWhileResponding) == "andere")
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

    /// Plays one launch the way `MeasurementRunner.measureRemaining` does, every call a success.
    private static func callsOfOneLaunch(_ run: inout MeasurementRun, entries: [Corpus.Entry], runsPerEntry: Int,
                                         untilDone: Bool) -> [(id: String, runIndex: Int)] {
        var calls: [(id: String, runIndex: Int)] = []
        var passes = 0
        while true {
            let pass = run.pass(after: passes, from: entries, runsPerEntry: runsPerEntry, untilDone: untilDone)
            if pass.isEmpty { break }
            passes += 1
            for (entry, runIndex) in pass {
                calls.append((id: entry.id, runIndex: runIndex))
                run.results.append(Self.result(entryID: entry.id, runIndex: runIndex))
            }
        }
        return calls
    }

    @Test("Ein Latenz-Start mit --runs 2 misst alle 12 Aufrufe, erst dann endet er (#534 F001)")
    func latencyLaunchMakesEveryRun() {
        var run = MeasurementRun(name: "t", startedAt: Date())
        let entries = (1...6).map { Self.entry("lat-0\($0)") }
        let calls = Self.callsOfOneLaunch(&run, entries: entries, runsPerEntry: 2, untilDone: true)
        #expect(calls.count == 12)
        #expect(calls.map(\.runIndex) == Array(repeating: 0, count: 6) + Array(repeating: 1, count: 6))
        #expect(run.remaining(from: entries, runsPerEntry: 2).isEmpty)
    }

    @Test("Ohne --exit-when-done bleibt ein Start bei einem Durchgang, wie bisher (#534 F001)")
    func normalSliceMakesOnePass() {
        var run = MeasurementRun(name: "t", startedAt: Date())
        let entries = (1...6).map { Self.entry("lat-0\($0)") }
        let first = Self.callsOfOneLaunch(&run, entries: entries, runsPerEntry: 2, untilDone: false)
        #expect(first.count == 6)
        let second = Self.callsOfOneLaunch(&run, entries: entries, runsPerEntry: 2, untilDone: false)
        #expect(second.map(\.runIndex) == Array(repeating: 1, count: 6))
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

    @Test("Der Selbstkonsistenz-Auszug eines EnrichmentDraft reicht alle vier Werte unverändert durch (Energie seit #112 nicht mehr) (AC-3)")
    func draftSelfConsistencyValuesPassThrough() {
        let draft = EnrichmentDraft(
            importance: .init(.high, confidence: 0.9, reason: "x"),
            urgency: .init(.low, confidence: 0.9, reason: "x"),
            duration: .init(.minutes15, confidence: 0.9, reason: "x"),
            contexts: .init(["zuhause", "telefon"], confidence: 0.9, reason: "x")
        )
        let fields = draft.selfConsistencyValues
        #expect(fields.importance == "high")
        #expect(fields.urgency == "low")
        #expect(fields.duration == "minutes15")
        #expect(fields.contexts == ["zuhause", "telefon"])
    }

    @Test("Fehlende Guesses ergeben nil/leer, kein Absturz (AC-3)")
    func draftSelfConsistencyValuesWithMissingGuesses() {
        let fields = EnrichmentDraft().selfConsistencyValues
        #expect(fields.importance == nil)
        #expect(fields.urgency == nil)
        #expect(fields.duration == nil)
        #expect(fields.contexts == [])
    }

    // MARK: - #71 Schnitt 2a: Ablehnung des Modells ist ein Ergebnis (AC-1 bis AC-8)

    private static func failed(_ entryID: String, runIndex: Int = 0, kind: String) -> MeasurementResult {
        var result = Self.result(entryID: entryID, runIndex: runIndex)
        result.error = "boom"
        result.errorKind = kind
        return result
    }

    private static let refusalKinds = [MeasurementErrorKind.guardrail, MeasurementErrorKind.refusal]
    private static let silentKinds = [MeasurementErrorKind.rateLimited, MeasurementErrorKind.timeout,
                                      MeasurementErrorKind.assetsUnavailable, MeasurementErrorKind.contextWindow]

    @Test("Ohne Schalter bleibt ein abgelehnter Satz offen, auch mit untilDone (AC-1)")
    func refusalStaysOpenByDefault() {
        for kind in Self.refusalKinds {
            var run = MeasurementRun(name: "t", startedAt: Date())
            run.results = [Self.failed("x", kind: kind)]
            #expect(run.remaining(from: [Self.entry("x")]).count == 1)
            #expect(run.remaining(from: [Self.entry("x")], countRefusals: false).count == 1)
            #expect(run.pass(after: 3, from: [Self.entry("x")], untilDone: true).count == 1)
        }
    }

    @Test("Mit Schalter zählen guardrail und refusal als gemessen, die übrigen Fehlerarten nicht (AC-2)")
    func refusalCountsOnlyWithSwitch() {
        for kind in Self.refusalKinds {
            var run = MeasurementRun(name: "t", startedAt: Date())
            run.results = [Self.failed("x", kind: kind)]
            #expect(run.remaining(from: [Self.entry("x")], countRefusals: true).isEmpty)
        }
        for kind in Self.silentKinds + [MeasurementErrorKind.decoding, MeasurementErrorKind.other] {
            var run = MeasurementRun(name: "t", startedAt: Date())
            run.results = [Self.failed("x", kind: kind)]
            #expect(run.remaining(from: [Self.entry("x")], countRefusals: true).count == 1)
        }
    }

    @Test("Ein immer abgelehnter Satz hält einen untilDone-Start nicht endlos fest (AC-3)")
    func alwaysRefusedSentenceTerminates() {
        var run = MeasurementRun(name: "t", startedAt: Date())
        let entries = [Self.entry("ok"), Self.entry("nein")]
        var passes = 0
        while passes < 20 {
            let pass = run.pass(after: passes, from: entries, runsPerEntry: 2, untilDone: true, countRefusals: true)
            if pass.isEmpty { break }
            passes += 1
            for (entry, runIndex) in pass {
                run.results.append(entry.id == "nein"
                                   ? Self.failed(entry.id, runIndex: runIndex, kind: MeasurementErrorKind.guardrail)
                                   : Self.result(entryID: entry.id, runIndex: runIndex))
            }
        }
        #expect(passes == 2)
        #expect(run.results.count == 4)
    }

    @Test("Bei zwei Durchläufen zählt jeder abgelehnte Durchlauf einzeln (AC-4)")
    func eachRefusedRunCountsOnce() {
        var run = MeasurementRun(name: "t", startedAt: Date())
        let entries = [Self.entry("x")]
        run.results = [Self.failed("x", runIndex: 0, kind: MeasurementErrorKind.guardrail)]
        let open = run.remaining(from: entries, runsPerEntry: 2, countRefusals: true)
        #expect(open.count == 1)
        #expect(open.first?.runIndex == 1)
        run.results.append(Self.failed("x", runIndex: 1, kind: MeasurementErrorKind.refusal))
        #expect(run.remaining(from: entries, runsPerEntry: 2, countRefusals: true).isEmpty)

        var mixed = MeasurementRun(name: "t", startedAt: Date())
        mixed.results = [Self.result(entryID: "x", runIndex: 0),
                         Self.failed("x", runIndex: 1, kind: MeasurementErrorKind.guardrail)]
        #expect(mixed.remaining(from: entries, runsPerEntry: 2, countRefusals: true).isEmpty)
    }

    @Test("Eine Ablehnung ist mit Schalter kein Fehlversuch, alles andere bleibt einer (AC-5)")
    func pacingTreatsRefusalAsResult() {
        let ok = Self.result(entryID: "x", runIndex: 0)
        #expect(!MeasurementPacing.countsAsFailure(ok, countRefusals: false))
        #expect(!MeasurementPacing.countsAsFailure(ok, countRefusals: true))
        for kind in Self.refusalKinds {
            let refused = Self.failed("x", kind: kind)
            #expect(MeasurementPacing.countsAsFailure(refused, countRefusals: false))
            #expect(!MeasurementPacing.countsAsFailure(refused, countRefusals: true))
        }
        for kind in Self.silentKinds + [MeasurementErrorKind.decoding, MeasurementErrorKind.other] {
            let other = Self.failed("x", kind: kind)
            #expect(MeasurementPacing.countsAsFailure(other, countRefusals: false))
            #expect(MeasurementPacing.countsAsFailure(other, countRefusals: true))
        }
        #expect(MeasurementPacing.giveUpAfterConsecutiveFailures == 3)
        #expect(MeasurementPacing.waitAfterFailure == 60)
    }

    @Test("Der Fortschritt zählt mit Schalter abgelehnte Läufe mit, ohne ihn unverändert (AC-6)")
    func progressCountsRefusalsWithSwitch() {
        var run = MeasurementRun(name: "t", startedAt: Date())
        run.results = [Self.result(entryID: "a", runIndex: 0),
                       Self.failed("b", kind: MeasurementErrorKind.guardrail),
                       Self.failed("c", kind: MeasurementErrorKind.timeout)]
        #expect(MeasurementProgress.done(in: run) == 1)
        #expect(MeasurementProgress.done(in: run, countRefusals: false) == 1)
        #expect(MeasurementProgress.done(in: run, countRefusals: true) == 2)
    }

    @Test("--count-failures schaltet das Zählen ein, ohne Argument bleibt es aus (AC-7)")
    func countRefusalsArgument() {
        #expect(Corpus.countRefusals(from: ["Lab", "--measure", "--count-failures"]))
        #expect(!Corpus.countRefusals(from: ["Lab", "--measure", "--exit-when-done"]))
        #expect(!Corpus.countRefusals(from: []))
    }

    @Test("Ein Korpus in Documents wird gefunden, das Bündel hat Vorrang (AC-8)")
    func corpusIsFoundInDocuments() throws {
        let documents = try #require(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        let name = "kein-bundle-korpus-\(UUID().uuidString)"
        let file = documents.appendingPathComponent("\(name).json")
        try Data("[]".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(try Corpus.url(fileName: name).standardizedFileURL == file.standardizedFileURL)

        let shadow = documents.appendingPathComponent("\(Corpus.fileName).json")
        let existed = FileManager.default.fileExists(atPath: shadow.path)
        if !existed { try Data("[]".utf8).write(to: shadow) }
        defer { if !existed { try? FileManager.default.removeItem(at: shadow) } }
        #expect(try Corpus.url(fileName: Corpus.fileName).standardizedFileURL != shadow.standardizedFileURL)

        #expect(throws: CocoaError.self) { _ = try Corpus.url(fileName: "gibt-es-nirgends-\(UUID().uuidString)") }
    }
}
