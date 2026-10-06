import Foundation

/// Recognising a raw text that was captured before (#136, ADR-5 as rewritten on 2026-09-27):
/// learning is recognition, not training. A task whose raw text carries the same normalised word set
/// as an earlier one takes over that one's **contexts and duration** — silently, confidence 1.0, rule
/// marker (#101), one `Revision` per field, written by `EnrichmentCoordinator`.
///
/// **Energy deliberately not** (#112): neighbours beat the constant on no reading there. The field is
/// structurally absent from `Candidate` and `Match`, so the rule cannot set it at all.
///
/// Equality of the word set, not a similarity threshold: measured on the 287 real tasks equality is
/// 100 % exact on both fields against 100 %/97.2 % for Jaccard ≥ 0.34, there is nothing to calibrate,
/// and the comparison is a dictionary lookup instead of a scan over all pairs. **No four-character
/// filter** either (unlike `LeaveOneOut.similarityWords`, where it keeps German function words from
/// drowning a similarity search): with an equality comparison it would merge "Tee holen" with "Bad
/// holen" and "30 Minuten Sport" with "60 Minuten Sport". A wrongly set context is invisible to the
/// user, so the rule decides for strictness.
///
/// Pure rule after the pattern of `DueDateRule` (#95) and `ImportanceUrgencyRule` (#117): an `enum`,
/// no state, no SwiftData. The coordinator hands the comparison set in.
enum RecognitionRule {
    /// An equality hit is deterministically there or not — an in-between number would be invented.
    static let confidence = 1.0

    /// What the rule needs of an already processed task — not a `TaskItem`, so the rule stays free of
    /// SwiftData.
    struct Candidate: Sendable {
        var id: UUID
        var rawText: String
        var duration: DurationBucket?
        var durationSourceRaw: String?
        var contextNames: [String]?
        var contextsSourceRaw: String?
    }

    /// Which candidate won (the coordinator takes its `TaskContext` objects over) and the guess.
    struct FieldMatch<Value: Equatable & Sendable>: Sendable {
        var sourceID: UUID
        var guess: EnrichmentDraft.Guess<Value>
    }

    struct Match: Sendable {
        var duration: FieldMatch<DurationBucket>?
        var contexts: FieldMatch<[String]>?
    }

    /// `nil` when no candidate carries the same word set, when the text holds no word at all, or when
    /// no candidate of the hit group has either value.
    static func match(rawText: String, in pool: [Candidate]) -> Match? {
        let key = wordSet(of: rawText)
        guard !key.isEmpty else { return nil }
        let hits = pool.filter { wordSet(of: $0.rawText) == key }
        guard !hits.isEmpty else { return nil }

        // One sentence for both fields: there is only one mechanism here, unlike the five categories
        // of #117 — "the same text has been captured before".
        let reason = String(localized: "From a raw text captured before, word for word.")
        let match = Match(
            duration: winner(among: hits, source: \.durationSourceRaw, value: \.duration, reason: reason),
            contexts: winner(among: hits, source: \.contextsSourceRaw,
                             value: { $0.contextNames.flatMap { $0.isEmpty ? nil : $0 } },
                             reason: reason)
        )
        return match.duration == nil && match.contexts == nil ? nil : match
    }

    /// The revision's reason, naming the earlier task (#101): "Like “Rasen mähen” from 12 Sep."
    static func reason(rawText: String, capturedAt: Date) -> String {
        let day = capturedAt.formatted(.dateTime.day().month(.abbreviated))
        return String(localized: "Like “\(rawText)” from \(day).")
    }

    /// The word set a raw text is recognised by. Case, diacritics, punctuation and word order do not
    /// matter, because the product processes dictated text (#82/#88); a different word does.
    static func wordSet(of text: String) -> Set<String> {
        Set(RawTextWords.words(in: text).map(RawTextWords.normalized))
    }

    /// An AI-set value is no source at all (#215). Among the rest a user-set value beats any other,
    /// per field separately (ADR-5: "corrections by the user stay first-class examples"), then
    /// ascending `id.uuidString` — so the result never depends on the fetch order.
    private static func winner<Value: Equatable & Sendable>(
        among hits: [Candidate],
        source: (Candidate) -> String?,
        value: (Candidate) -> Value?,
        reason: String
    ) -> FieldMatch<Value>? {
        // A model guess is no source (#215): taken over, it would come back with the rule marker,
        // "from your words", and look surer than it is.
        let withValue = hits.compactMap { candidate -> (candidate: Candidate, value: Value)? in
            guard source(candidate) != FieldSource.ai.rawValue else { return nil }
            return value(candidate).map { (candidate, $0) }
        }
        let best = withValue.min { lhs, rhs in
            let lhsByUser = source(lhs.candidate) == FieldSource.user.rawValue
            let rhsByUser = source(rhs.candidate) == FieldSource.user.rawValue
            if lhsByUser != rhsByUser { return lhsByUser }
            return lhs.candidate.id.uuidString < rhs.candidate.id.uuidString
        }
        guard let best else { return nil }
        return FieldMatch(sourceID: best.candidate.id,
                          guess: EnrichmentDraft.Guess(best.value, confidence: confidence, reason: reason))
    }
}
