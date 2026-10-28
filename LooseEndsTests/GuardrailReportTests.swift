import Foundation
import Testing
@testable import LooseEnds

/// The counting behind the guardrail report (#71, Schnitt 1). Pure: staged probes, no model, no file.
/// The model run itself (`RealModelGuardrailTests`) is gated and never runs here.
@Suite("Guardrail report (#71)")
struct GuardrailReportTests {
    /// `count` texts of one set, each measured `runs` times; `refused` of them fail with `kind` in every run.
    private func texts(_ set: String, count: Int, lang: String = "de", group: String = "g1", runs: Int = 2,
                       refused: Int = 0, kind: String = MeasurementErrorKind.guardrail,
                       prefix: String? = nil) -> [GuardrailProbe] {
        let p = prefix ?? set
        return (0..<count).flatMap { index in
            (1...runs).map { run in
                GuardrailProbe(id: "\(p)-\(index)", menge: set, sprache: lang, gruppe: group,
                               text: "Text \(p)-\(index)", durchlauf: run,
                               fehlerart: index < refused ? kind : nil)
            }
        }
    }

    /// The full corpus of the spec: 100 touchy and 287 everyday texts.
    private func corpus(refusedTouchy: Int = 0, refusedEveryday: Int = 0) -> [GuardrailProbe] {
        texts("heikel", count: 100, refused: refusedTouchy) + texts("alltag", count: 287, refused: refusedEveryday)
    }

    @Test("Every error kind lands in its own column; only guardrail and refusal count as refused")
    func kindsAreSeparated() {
        let kinds = [MeasurementErrorKind.guardrail, MeasurementErrorKind.refusal, MeasurementErrorKind.rateLimited,
                     MeasurementErrorKind.timeout, MeasurementErrorKind.contextWindow, MeasurementErrorKind.other]
        let probes = kinds.enumerated().map { index, kind in
            GuardrailProbe(id: "k-\(index)", menge: "alltag", sprache: "de", gruppe: "g", text: nil, durchlauf: 1, fehlerart: kind)
        } + texts("alltag", count: 4, runs: 1, prefix: "ok")
        let total = GuardrailReport(probes: probes).total

        #expect(total.byKind[MeasurementErrorKind.guardrail] == 1)
        #expect(total.byKind[MeasurementErrorKind.refusal] == 1)
        #expect(total.byKind[MeasurementErrorKind.rateLimited] == 1)
        #expect(total.byKind[MeasurementErrorKind.timeout] == 1)
        #expect(total.byKind[MeasurementErrorKind.contextWindow] == 1)
        #expect(total.byKind[MeasurementErrorKind.other] == 1)
        #expect(total.refusedProbes == 2)
        #expect(total.excludedProbes == 4)
        #expect(total.probes == 10)
    }

    @Test("Rate limit and timeout never raise the refusal rate and leave the denominator")
    func rateLimitAndTimeoutDoNotCount() {
        let probes = texts("alltag", count: 10, runs: 1, refused: 3, kind: MeasurementErrorKind.rateLimited, prefix: "rl")
            + texts("alltag", count: 10, runs: 1, refused: 2, kind: MeasurementErrorKind.timeout, prefix: "to")
            + texts("alltag", count: 20, runs: 1, prefix: "ok")
        let total = GuardrailReport(probes: probes).total

        #expect(total.hitTexts == 0)
        #expect(total.textRate == 0)
        #expect(total.probeRate == 0)
        // 3 + 2 texts failed in their only run, so they are not measured texts at all.
        #expect(total.texts == 35)
        #expect(total.excludedProbes == 5)
    }

    @Test("No hit in 387 texts: rate 0, Wilson bound about 1.0 %, rule-of-three hint 3/387")
    func zeroHits() throws {
        let total = GuardrailReport(probes: corpus()).total

        #expect(total.texts == 387)
        #expect(total.hitTexts == 0)
        #expect(total.textRate == 0)
        #expect(abs(total.upperBound - 0.0098) < 0.0003)
        let hint = try #require(total.ruleOfThree)
        #expect(abs(hint - 3.0 / 387.0) < 0.000_001)
    }

    @Test("One hit in 387 texts: about 0.26 %, Wilson bound about 1.4 %, no rule-of-three hint")
    func oneHit() {
        let total = GuardrailReport(probes: corpus(refusedEveryday: 1)).total

        #expect(total.hitTexts == 1)
        #expect(abs(total.textRate - 1.0 / 387.0) < 0.000_001)
        #expect(abs(total.upperBound - 0.0145) < 0.0005)
        #expect(total.ruleOfThree == nil)
    }

    @Test("A hundred texts alone cannot carry the threshold: zero hits still leave the bound at about 3.7 %")
    func hundredAlone() {
        let report = GuardrailReport(probes: corpus())
        let touchy = report.byMenge["heikel"]
        #expect(touchy?.texts == 100)
        #expect(abs((touchy?.upperBound ?? 0) - 0.037) < 0.001)
    }

    @Test("A text refused in every run is 'always', in some runs 'sometimes'; hits list text, set, group, language and kind per run")
    func alwaysAndSometimes() throws {
        var probes = corpus()
        // heikel-0 refused in both runs (always), heikel-1 only in run 2 (sometimes, run 1 fine).
        probes = probes.map { probe in
            var copy = probe
            if probe.id == "heikel-0" { copy.fehlerart = MeasurementErrorKind.guardrail }
            if probe.id == "heikel-1", probe.durchlauf == 2 { copy.fehlerart = MeasurementErrorKind.refusal }
            return copy
        }
        let report = GuardrailReport(probes: probes)

        #expect(report.total.hitTexts == 2)
        let always = try #require(report.hits.first { $0.id == "heikel-0" })
        #expect(always.frequency == .always)
        #expect(always.text == "Text heikel-0")
        #expect(always.menge == "heikel")
        #expect(always.gruppe == "g1")
        #expect(always.sprache == "de")
        #expect(always.kindsPerRun == [MeasurementErrorKind.guardrail, MeasurementErrorKind.guardrail])
        let sometimes = try #require(report.hits.first { $0.id == "heikel-1" })
        #expect(sometimes.frequency == .sometimes)
        #expect(sometimes.kindsPerRun == ["ok", MeasurementErrorKind.refusal])
        // Per run the rate is lower than per text: 3 of 774 runs.
        #expect(report.total.refusedProbes == 3)
        #expect(report.total.probes == 774)
        #expect(abs(report.total.probeRate - 3.0 / 774.0) < 0.000_001)
    }

    @Test("Rates are reported per set, per language and per group")
    func slices() {
        let probes = texts("heikel", count: 10, lang: "de", group: "kuendigung", refused: 1)
            + texts("heikel", count: 10, lang: "en", group: "medizin")
            + texts("alltag", count: 20, lang: "de", group: "alltag")
        let report = GuardrailReport(probes: probes)

        #expect(report.byMenge["heikel"]?.texts == 20)
        #expect(report.byMenge["heikel"]?.hitTexts == 1)
        #expect(report.byMenge["alltag"]?.hitTexts == 0)
        #expect(report.bySprache["de"]?.texts == 30)
        #expect(report.bySprache["de"]?.hitTexts == 1)
        #expect(report.bySprache["en"]?.hitTexts == 0)
        #expect(report.byGruppe["kuendigung"]?.hitTexts == 1)
        #expect(report.byGruppe["kuendigung"]?.texts == 10)
        #expect(report.byGruppe["medizin"]?.hitTexts == 0)
        #expect(report.total.texts == 40)
    }

    @Test("The 1 % threshold is judged on the total: 4 of 387 is over, 3 of 387 is under but not ruled out")
    func threshold() {
        let four = GuardrailReport(probes: corpus(refusedTouchy: 2, refusedEveryday: 2)).threshold
        #expect(four.isUnder == false)
        #expect(four.upperBoundAbove == true)

        let three = GuardrailReport(probes: corpus(refusedTouchy: 1, refusedEveryday: 2)).threshold
        #expect(three.isUnder == true)
        #expect(three.upperBoundAbove == true)

        // Both sets are shown next to it, but the touchy ones alone do not decide.
        let report = GuardrailReport(probes: corpus(refusedTouchy: 1))
        #expect(report.byMenge["heikel"]?.textRate == 0.01)
        #expect(report.threshold.isUnder == true)
    }

    @Test("An empty list gives an empty report, not a crash or NaN")
    func emptyReport() {
        let report = GuardrailReport(probes: [])
        #expect(report.total.texts == 0)
        #expect(report.total.textRate == 0)
        #expect(report.total.upperBound == 0)
        #expect(report.hits.isEmpty)
    }

    @Test("Probes survive a round trip through JSON in the raw-data format")
    func probeRoundTrip() throws {
        let probe = GuardrailProbe(id: "gr-001", menge: "heikel", sprache: "de", gruppe: "kuendigung",
                                   text: "Kündigung verschicken", durchlauf: 2, fehlerart: MeasurementErrorKind.refusal)
        let data = try JSONEncoder().encode([probe])
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"menge\""))
        #expect(json.contains("\"fehlerart\""))
        let back = try JSONDecoder().decode([GuardrailProbe].self, from: data)
        #expect(back == [probe])
    }

    // MARK: - #71 Schnitt 2b-1: Ergebnisse des Läufers werden zu Proben (AC-1 bis AC-5)

    private func entry(_ id: String, lang: String = "de", form: String = "g1", text: String? = nil) throws -> Corpus.Entry {
        let json: [String: String] = ["id": id, "lang": lang, "text": text ?? "Satz \(id)", "form": form]
        return try JSONDecoder().decode(Corpus.Entry.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func conditions(device: String = "iPhone17,1") -> Conditions {
        Conditions(appState: "vordergrund", power: "strom", batteryPercent: 80, lowPowerMode: false,
                   thermal: "normal", device: device, systemVersion: "27.0")
    }

    private func outcome(_ id: String, run: Int, kind: String? = nil, error: String? = nil, second: TimeInterval = 0) -> MeasurementResult {
        let at = Date(timeIntervalSince1970: 1_800_000_000 + second)
        return MeasurementResult(entryID: id, capturedAt: at, finishedAt: at, seconds: 1, conditions: conditions(),
                                 title: kind == nil && error == nil ? "T" : nil,
                                 error: error ?? (kind == nil ? nil : "boom"), errorKind: kind, runIndex: run)
    }

    private func run(_ results: [MeasurementResult]) -> MeasurementRun {
        var run = MeasurementRun(name: "guardrail-iphone", startedAt: Date(timeIntervalSince1970: 1_800_000_000))
        run.results = results
        return run
    }

    @Test("Erfolg, guardrail und refusal werden zu fehlerart nil, guardrail, refusal (AC-1)")
    func translatesSuccessAndRefusals() throws {
        let entries = [try entry("a"), try entry("b"), try entry("c")]
        let translation = GuardrailProbe.probes(
            from: run([outcome("a", run: 0), outcome("b", run: 0, kind: MeasurementErrorKind.guardrail),
                       outcome("c", run: 0, kind: MeasurementErrorKind.refusal)]),
            corpus: entries, runsPerEntry: 1)
        #expect(translation.probes.map(\.fehlerart) == [nil, MeasurementErrorKind.guardrail, MeasurementErrorKind.refusal])
        #expect(translation.probes.map(\.isRefused) == [false, true, true])
        #expect(translation.missing == 0)
        #expect(translation.unknown == 0)
    }

    @Test("Menge, Sprache, Gruppe, Text und Durchlauf kommen aus dem Korpuseintrag (AC-1)")
    func translatesFieldsFromTheEntry() throws {
        let entries = [try entry("gr-001", lang: "de", form: "kuendigung", text: "Vertrag kündigen"),
                       try entry("alltag-3", lang: "en", form: "alltag", text: "Call the dentist")]
        let translation = GuardrailProbe.probes(
            from: run([outcome("gr-001", run: 0), outcome("gr-001", run: 1), outcome("alltag-3", run: 0), outcome("alltag-3", run: 1)]),
            corpus: entries, runsPerEntry: 2)
        let touchy = translation.probes.filter { $0.id == "gr-001" }
        let everyday = translation.probes.filter { $0.id == "alltag-3" }
        #expect(touchy.map(\.menge) == ["heikel", "heikel"])
        #expect(touchy.map(\.durchlauf) == [1, 2])
        #expect(touchy.first?.sprache == "de")
        #expect(touchy.first?.gruppe == "kuendigung")
        #expect(touchy.first?.text == "Vertrag kündigen")
        #expect(everyday.map(\.menge) == ["alltag", "alltag"])
        #expect(everyday.first?.sprache == "en")
        #expect(everyday.first?.gruppe == "alltag")
        #expect(everyday.first?.text == "Call the dentist")
    }

    @Test("Drosselung und Zeitüberschreitung sind keine Ablehnung, ein Fehler ohne Typ heißt andere (AC-2)")
    func otherFailuresAreExcludedNotRefused() throws {
        let ids = ["rl", "to", "as", "cw", "none"]
        let entries = try ids.map { try entry($0) }
        let kinds = [MeasurementErrorKind.rateLimited, MeasurementErrorKind.timeout,
                     MeasurementErrorKind.assetsUnavailable, MeasurementErrorKind.contextWindow]
        let results = zip(ids, kinds).map { outcome($0, run: 0, kind: $1) } + [outcome("none", run: 0, error: "kaputt")]
        let probes = GuardrailProbe.probes(from: run(results), corpus: entries, runsPerEntry: 1).probes
        #expect(probes.count == 5)
        #expect(probes.allSatisfy { $0.isExcluded && !$0.isRefused })
        #expect(probes.last?.fehlerart == MeasurementErrorKind.other)
    }

    @Test("Fehlende Aufrufe und fremde Ergebnisse werden gezählt, nicht verschluckt (AC-3)")
    func missingAndUnknownAreCounted() throws {
        let entries = [try entry("a"), try entry("b")]
        let translation = GuardrailProbe.probes(
            from: run([outcome("a", run: 0), outcome("a", run: 1), outcome("b", run: 0),
                       outcome("zzz", run: 0), outcome("b", run: 2)]),
            corpus: entries, runsPerEntry: 2)
        #expect(translation.probes.count == 3)
        #expect(translation.missing == 1)
        #expect(translation.unknown == 2)
        #expect(!translation.probes.contains { $0.id == "b" && $0.durchlauf == 2 })
    }

    @Test("Bei zwei Ergebnissen desselben Aufrufs zählt das letzte (AC-3)")
    func lastResultOfACallWins() throws {
        let translation = GuardrailProbe.probes(
            from: run([outcome("a", run: 0, kind: MeasurementErrorKind.rateLimited, second: 0), outcome("a", run: 0, second: 60)]),
            corpus: [try entry("a")], runsPerEntry: 1)
        #expect(translation.probes.count == 1)
        #expect(translation.probes.first?.fehlerart == nil)
        #expect(translation.missing == 0)
    }

    @Test("Der Alltagswortlaut wird entfernt, die heiklen Texte bleiben (AC-4)")
    func everydayWordingIsDropped() {
        let probes = [GuardrailProbe(id: "gr-1", menge: "heikel", sprache: "de", gruppe: "g", text: "Heikel", durchlauf: 1, fehlerart: nil),
                      GuardrailProbe(id: "alltag-1", menge: "alltag", sprache: "de", gruppe: "alltag", text: "Privat", durchlauf: 1, fehlerart: nil)]
        let stored = GuardrailProbe.withoutEverydayWording(probes)
        #expect(stored.map(\.text) == ["Heikel", nil])
        #expect(stored.map(\.id) == ["gr-1", "alltag-1"])
    }

    @Test("Kette ohne Gerät: 774 Ergebnisse, ein Treffer; Rohdaten ohne Alltagswort, Zusammenfassung mit Treffer (AC-5)")
    func chainFromResultsToRawAndSummary() throws {
        var entries: [Corpus.Entry] = []
        for index in 1...100 { entries.append(try entry(String(format: "gr-%03d", index), form: "kuendigung", text: "Heikler Satz \(index)")) }
        for index in 0..<287 { entries.append(try entry("alltag-\(index)", form: "alltag", text: "Erkennungswort Alltagssatz \(index)")) }
        var results: [MeasurementResult] = []
        for item in entries {
            for runIndex in 0..<2 {
                let refused = item.id == "alltag-5"
                results.append(outcome(item.id, run: runIndex, kind: refused ? MeasurementErrorKind.guardrail : nil))
            }
        }
        #expect(results.count == 774)

        let translation = GuardrailProbe.probes(from: run(results), corpus: entries, runsPerEntry: 2)
        #expect(translation.missing == 0)
        #expect(translation.unknown == 0)
        let report = GuardrailReport(probes: translation.probes)
        #expect(report.total.texts == 387)
        #expect(report.total.hitTexts == 1)
        #expect(report.total.excludedProbes == 0)

        let head = RealModelGuardrailTests.Head(geraet: "iPhone17,1", system: "27.0", datum: Date(timeIntervalSince1970: 1_800_000_000),
                                                nurHeikel: false, durchlaeufe: 2)
        let raw = RealModelGuardrailTests.RawFile(kopf: head, proben: GuardrailProbe.withoutEverydayWording(translation.probes))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let rawText = String(decoding: try encoder.encode(raw), as: UTF8.self)
        #expect(!rawText.contains("Erkennungswort"))
        #expect(!rawText.contains("Alltagssatz"))
        #expect(rawText.contains("alltag-5"))
        #expect(rawText.contains("Heikler Satz 1"))

        let summary = RealModelGuardrailTests.summary(head: head, report: report)
        #expect(summary.contains("Erkennungswort Alltagssatz 5"))
        #expect(summary.contains("alltag-5"))
    }
}

#if canImport(FoundationModels) && !os(watchOS)
/// Der Bericht aus einer vom iPhone geholten Ergebnisdatei (#71 Schnitt 2b-1). Läuft nur mit gesetzten Pfaden und nie
/// im normalen Testlauf: ein Berichttest ohne Daten würde den Bericht im Simulator mit Nullen entwerten.
/// `LOOSEENDS_GUARDRAIL_IPHONE_RESULT` = Ergebnisdatei, `LOOSEENDS_GUARDRAIL_CORPUS` = Gerätekorpus (außerhalb des Repos),
/// `LOOSEENDS_GUARDRAIL_OUT` = Rohdaten (ohne Alltagswortlaut), `LOOSEENDS_GUARDRAIL_LOCAL` = Zusammenfassung mit Wortlaut.
private enum IphoneReportGate {
    static var environment: [String: String] { ProcessInfo.processInfo.environment }

    static var filesGiven: Bool {
        ["LOOSEENDS_GUARDRAIL_IPHONE_RESULT", "LOOSEENDS_GUARDRAIL_CORPUS"].allSatisfy { key in
            environment[key].map { !$0.isEmpty && FileManager.default.fileExists(atPath: $0) } ?? false
        }
    }
}

@Suite(
    "Guardrail report from the iPhone result file (#71)",
    .enabled(if: IphoneReportGate.filesGiven, "LOOSEENDS_GUARDRAIL_IPHONE_RESULT and LOOSEENDS_GUARDRAIL_CORPUS are not set")
)
struct IphoneGuardrailReportTests {
    private static var environment: [String: String] { IphoneReportGate.environment }

    @Test("Ergebnisdatei und Korpus werden vollständig zu Rohdaten und Zusammenfassung")
    func reportFromResultFile() throws {
        let resultPath = try #require(Self.environment["LOOSEENDS_GUARDRAIL_IPHONE_RESULT"])
        let corpusPath = try #require(Self.environment["LOOSEENDS_GUARDRAIL_CORPUS"])
        let run = try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: Data(contentsOf: URL(fileURLWithPath: resultPath)))
        let entries = try Corpus.entries(from: Data(contentsOf: URL(fileURLWithPath: corpusPath)))
        let translation = GuardrailProbe.probes(from: run, corpus: entries, runsPerEntry: 2)
        #expect(translation.missing == 0)
        #expect(translation.unknown == 0)

        let first = try #require(run.results.first)
        let last = try #require(run.results.last)
        let head = RealModelGuardrailTests.Head(geraet: first.conditions.device, system: first.conditions.systemVersion,
                                                datum: last.finishedAt, nurHeikel: false, durchlaeufe: 2)
        let report = GuardrailReport(probes: translation.probes)

        if let path = Self.environment["LOOSEENDS_GUARDRAIL_OUT"], !path.isEmpty {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let raw = RealModelGuardrailTests.RawFile(kopf: head, proben: GuardrailProbe.withoutEverydayWording(translation.probes))
            try encoder.encode(raw).write(to: url, options: .atomic)
        }
        if let path = Self.environment["LOOSEENDS_GUARDRAIL_LOCAL"], !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try RealModelGuardrailTests.summary(head: head, report: report).write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
#endif
