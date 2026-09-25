import Foundation

/// The rule-only zero line for the convention test in Annahme B1 (Spike #69, Ticket A): can three
/// past corrections predict the context of a fourth note with plain string handling — no model, no
/// embedding? Whatever a later retrieval (Ticket B) scores has to beat this number first.
///
/// Style follows `ImportanceUrgencyRule`: a pure `enum`, and no hit means `nil`, never a forced
/// default. Nothing here is hard-wired to a keyword list; the pairings come from the corpus.
enum RuleBaseline {
    /// The context the three corrections imply for the probe, or `nil` if they imply none.
    ///
    /// A word the probe shares with a correction is the reconstruction of "this is what led to that
    /// context". Every *correction* that shares at least one word casts exactly one vote for its
    /// context — the majority is counted over the three corrections, not weighted by how many words
    /// happen to overlap, so two corrections for "Garten" beat one wordier one for "Keller" (AC-3).
    /// A tie falls to the context seen first, so the answer never depends on dictionary order.
    static func predict(pattern: ConventionCorpus.Pattern) -> String? {
        let probeWords = Set(TitleCheck.words(in: pattern.probe.text).map(TitleCheck.normalized))
        var contextsInOrder: [String] = []
        var votes: [String: Int] = [:]

        for correction in pattern.corrections {
            let words = Set(TitleCheck.words(in: correction.text).map(TitleCheck.normalized))
            guard !words.intersection(probeWords).isEmpty else { continue }
            if votes[correction.context] == nil { contextsInOrder.append(correction.context) }
            votes[correction.context, default: 0] += 1   // one correction, one vote (AC-3)
        }

        var best: (context: String, votes: Int)?
        for context in contextsInOrder {
            let count = votes[context] ?? 0
            if best == nil || count > best!.votes { best = (context, count) }
        }
        return best?.context   // nil when no probe word appears in any correction (AC-4)
    }

    struct Outcome: Sendable {
        let patternID: String
        let predicted: String?
        let expected: String
        var correct: Bool { predicted == expected }
    }

    static func evaluate(patterns: [ConventionCorpus.Pattern]) -> [Outcome] {
        patterns.map { pattern in
            Outcome(patternID: pattern.id,
                    predicted: predict(pattern: pattern),
                    expected: pattern.probe.expectedContext)
        }
    }
}
