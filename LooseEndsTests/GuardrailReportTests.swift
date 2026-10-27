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
}
