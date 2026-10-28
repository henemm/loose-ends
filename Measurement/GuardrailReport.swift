import Foundation

/// One call of the guardrail run (#71): which text, which run, and what failed, if anything.
/// `text` is nil for the everyday set in the raw data, which carries personal sentences.
struct GuardrailProbe: Codable, Sendable, Equatable {
    var id: String
    var menge: String
    var sprache: String
    var gruppe: String
    var text: String?
    var durchlauf: Int
    var fehlerart: String?

    /// Only these two are the model saying no. A rate limit or timeout says nothing about the text.
    var isRefused: Bool {
        fehlerart == MeasurementErrorKind.guardrail || fehlerart == MeasurementErrorKind.refusal
    }

    var isExcluded: Bool { fehlerart != nil && !isRefused }

    /// Which text this probe measured. Ids are only unique within one set, so the slice keys go along.
    var textKey: String { "\(menge)/\(gruppe)/\(sprache)/\(id)" }
}

/// The counting behind `docs/reference/modell-guardrails.md`. Pure: probes in, rates out.
/// Counted per text, since refusals are not deterministic (forum 793876): a text refused in any
/// run is a hit. Excluded probes leave the denominator instead of passing as answered.
struct GuardrailReport: Sendable {
    static let threshold = 0.01

    struct Slice: Sendable {
        var texts = 0
        var hitTexts = 0
        var probes = 0
        var refusedProbes = 0
        var excludedProbes = 0
        var byKind: [String: Int] = [:]

        var textRate: Double { texts == 0 ? 0 : Double(hitTexts) / Double(texts) }
        var probeRate: Double {
            let measured = probes - excludedProbes
            return measured == 0 ? 0 : Double(refusedProbes) / Double(measured)
        }
        /// Wilson score interval, upper end at 95 %, over texts.
        var upperBound: Double { GuardrailReport.wilsonUpper(hits: hitTexts, of: texts) }
        /// With zero hits the rule of three gives the simpler bound 3/n.
        var ruleOfThree: Double? { hitTexts == 0 && texts > 0 ? 3.0 / Double(texts) : nil }

        init(probes list: [GuardrailProbe]) {
            probes = list.count
            refusedProbes = list.filter(\.isRefused).count
            excludedProbes = list.filter(\.isExcluded).count
            for kind in list.compactMap(\.fehlerart) { byKind[kind, default: 0] += 1 }
            let byText = Dictionary(grouping: list, by: \.textKey)
            let measured = byText.values.filter { runs in runs.contains { !$0.isExcluded } }
            texts = measured.count
            hitTexts = measured.filter { runs in runs.contains(where: \.isRefused) }.count
        }
    }

    enum Frequency: String, Sendable { case always, sometimes }

    struct Hit: Sendable {
        var id: String
        var text: String?
        var menge: String
        var gruppe: String
        var sprache: String
        var frequency: Frequency
        /// The kind per run in run order, "ok" where the run went through.
        var kindsPerRun: [String]
    }

    struct Threshold: Sendable {
        var isUnder: Bool
        var upperBoundAbove: Bool
    }

    let total: Slice
    let byMenge: [String: Slice]
    let bySprache: [String: Slice]
    let byGruppe: [String: Slice]
    let hits: [Hit]

    /// Judged on all texts together; the sets alone are too small to carry 1 %.
    var threshold: Threshold {
        Threshold(isUnder: total.textRate <= Self.threshold, upperBoundAbove: total.upperBound > Self.threshold)
    }

    init(probes: [GuardrailProbe]) {
        total = Slice(probes: probes)
        byMenge = Self.slices(probes, by: \.menge)
        bySprache = Self.slices(probes, by: \.sprache)
        byGruppe = Self.slices(probes, by: \.gruppe)
        hits = Self.hits(in: probes)
    }

    private static func slices(_ probes: [GuardrailProbe], by key: KeyPath<GuardrailProbe, String>) -> [String: Slice] {
        Dictionary(grouping: probes) { $0[keyPath: key] }.mapValues { Slice(probes: $0) }
    }

    /// Hits in the order their texts first appear.
    private static func hits(in probes: [GuardrailProbe]) -> [Hit] {
        var order: [String] = []
        var runs: [String: [GuardrailProbe]] = [:]
        for probe in probes {
            let key = probe.textKey
            if runs[key] == nil { order.append(key) }
            runs[key, default: []].append(probe)
        }
        return order.compactMap { key in
            guard let list = runs[key]?.sorted(by: { $0.durchlauf < $1.durchlauf }),
                  let first = list.first, list.contains(where: \.isRefused) else { return nil }
            return Hit(id: first.id, text: first.text, menge: first.menge, gruppe: first.gruppe, sprache: first.sprache,
                       frequency: list.allSatisfy(\.isRefused) ? .always : .sometimes,
                       kindsPerRun: list.map { $0.fehlerart ?? "ok" })
        }
    }

    static func wilsonUpper(hits: Int, of n: Int, z: Double = 1.96) -> Double {
        guard n > 0 else { return 0 }
        let count = Double(n)
        let p = Double(hits) / count
        let z2 = z * z
        let centre = p + z2 / (2 * count)
        let spread = z * (p * (1 - p) / count + z2 / (4 * count * count)).squareRoot()
        return (centre + spread) / (1 + z2 / count)
    }
}

/// From the runner's result file to probes (#71 Schnitt 2b-1). Pure: no file, no model.
extension GuardrailProbe {
    struct Translation: Equatable {
        var probes: [GuardrailProbe]
        /// Calls of the corpus × runs that have no result at all.
        var missing: Int
        /// Results that belong to no entry of the corpus or to a run outside `0..<runsPerEntry`.
        var unknown: Int
    }

    /// One probe per entry and run, in corpus order. Of several results for the same call the last one in the file
    /// counts (the file is chronological; a repeat after a rate limit replaces the earlier one).
    static func probes(from run: MeasurementRun, corpus: [Corpus.Entry], runsPerEntry: Int) -> Translation {
        let ids = Set(corpus.map(\.id))
        var latest: [String: [Int: MeasurementResult]] = [:]
        var unknown = 0
        for result in run.results {
            guard ids.contains(result.entryID), (0..<max(runsPerEntry, 0)).contains(result.runIndex) else {
                unknown += 1
                continue
            }
            latest[result.entryID, default: [:]][result.runIndex] = result
        }
        var probes: [GuardrailProbe] = []
        var missing = 0
        for entry in corpus {
            for runIndex in 0..<max(runsPerEntry, 0) {
                guard let result = latest[entry.id]?[runIndex] else {
                    missing += 1
                    continue
                }
                probes.append(probe(entry: entry, result: result))
            }
        }
        return Translation(probes: probes, missing: missing, unknown: unknown)
    }

    private static func probe(entry: Corpus.Entry, result: MeasurementResult) -> GuardrailProbe {
        let kind = result.error == nil && result.errorKind == nil ? nil : (result.errorKind ?? MeasurementErrorKind.other)
        return GuardrailProbe(id: entry.id, menge: entry.id.hasPrefix("alltag-") ? "alltag" : "heikel",
                              sprache: entry.lang, gruppe: entry.form, text: entry.text,
                              durchlauf: result.runIndex + 1, fehlerart: kind)
    }

    /// The raw data never carries the everyday wording (personal sentences); the touchy texts keep theirs.
    static func withoutEverydayWording(_ probes: [GuardrailProbe]) -> [GuardrailProbe] {
        probes.map { probe in
            var copy = probe
            if copy.menge != "heikel" { copy.text = nil }
            return copy
        }
    }
}
