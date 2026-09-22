import Foundation

/// Spike #65 Schritt 2 (#108): agreement across several runs of the same note as an uncertainty
/// signal — does the model answer the same thing five times when it is right, and waver when it
/// is wrong? A different signal from the model's self-reported confidence (#23), which is an
/// assertion rather than a measurement.
///
/// Pure counting over values that were already measured: no model call, no platform import, no
/// file access. The grouping by `entryID` and the truth lookup stay with the caller (the gated
/// report test), so this file has no dependency on `Corpus.Entry` either.
enum SelfConsistency {
    // MARK: - Single-value fields (importance, urgency, duration, energy)

    /// The most frequent non-nil answer across the runs of one note, or nil when no run answered.
    /// A run that returned nothing does not outvote the ones that did — it only lowers agreement.
    static func majority(_ values: [String?]) -> String? {
        counted(values.compactMap { $0 })
    }

    /// The share of *all* runs of that note that gave the majority answer. All runs, not just the
    /// answering ones: a note the model only answered twice out of five is not unanimous.
    static func agreement(_ values: [String?]) -> Double {
        guard !values.isEmpty, let majority = majority(values) else { return 0 }
        return Double(values.filter { $0 == majority }.count) / Double(values.count)
    }

    // MARK: - Set field (contexts)

    /// Same as `majority`, but every answer counts as a set: ["a","b"] and ["b","a"] are the same
    /// answer, because the model's ordering carries no meaning.
    static func majoritySet(_ values: [[String]]) -> Set<String>? {
        counted(values.map(Set.init))
    }

    static func agreementSet(_ values: [[String]]) -> Double {
        guard !values.isEmpty, let majority = majoritySet(values) else { return 0 }
        return Double(values.filter { Set($0) == majority }.count) / Double(values.count)
    }

    /// The most frequent element; ties are broken by the value itself so the result is stable
    /// across runs of the report instead of depending on dictionary order.
    private static func counted<Value: Hashable & Comparable>(_ values: [Value]) -> Value? {
        var counts: [Value: Int] = [:]
        for value in values { counts[value, default: 0] += 1 }
        return counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key
    }

    private static func counted(_ values: [Set<String>]) -> Set<String>? {
        var counts: [Set<String>: Int] = [:]
        for value in values { counts[value, default: 0] += 1 }
        return counts.max {
            ($0.value, $1.key.sorted().joined(separator: "\u{1}"))
                < ($1.value, $0.key.sorted().joined(separator: "\u{1}"))
        }?.key
    }

    // MARK: - Hit rate over coverage

    /// One note: how unanimous the runs were, and whether the majority answer matches the truth.
    struct Outcome {
        var agreement: Double
        var correct: Bool
    }

    /// Agreement is the axis here, where `FocusBloxCalibrationTests` uses the confidence threshold.
    static let thresholds: [Double] = [0.6, 0.8, 1.0]

    /// One row per threshold: how many notes reach that agreement (coverage) and how many of those
    /// the majority answer got right (hit rate). No recall column — without a confidence threshold
    /// there is no second, independent denominator to divide by.
    static func table(field: String, outcomes: [Outcome]) -> String {
        var lines = ["### \(field) (\(outcomes.count) Aufgaben mit bekanntem Wert)", "",
                     "| Einstimmigkeit | Abdeckung | Trefferquote |", "|---|---|---|"]
        for threshold in thresholds {
            let covered = outcomes.filter { $0.agreement >= threshold }
            let coverage = outcomes.isEmpty ? "–"
                : String(format: "%.0f%%", 100 * Double(covered.count) / Double(outcomes.count))
            let hitRate = covered.isEmpty ? "–"
                : String(format: "%.0f%%", 100 * Double(covered.filter(\.correct).count) / Double(covered.count))
            lines.append("| \(threshold) | \(coverage) | \(hitRate) |")
        }
        return lines.joined(separator: "\n")
    }
}
