import Foundation

/// The rule-only leave-one-out test for Annahme B1 (Spike #69, Issue #131): for every task, the k
/// most similar *other* tasks vote on one field, and the answer is checked against the truth and
/// against a constant computed from the corpus. No model, no embedding, no device — plain word
/// overlap, because "Regeln vor Modell" means the simple mechanism is built or refuted first.
///
/// Style follows `RuleBaseline`/`ImportanceUrgencyRule`: a pure `enum`, and no hit means `nil`,
/// never a forced default. No class name, threshold or percentage is hard-wired; every number the
/// report shows is computed from the data that was passed in.
enum LeaveOneOut {

    /// The word set similarity is measured over: tokenised and normalised with the shared
    /// `RawTextWords` (#136, the same one `RecognitionRule` uses in the product), filtered to words of
    /// four characters or more.
    ///
    /// The length filter is the point *here*. `RawTextWords.words(in:)` filters nothing, so without it
    /// German function words ("eine", "für", "mit", "der") would carry the similarity and every task
    /// would look like every other — the neighbours would be noise. Four is the same threshold
    /// `TitleCheck.foreignWords` already uses, not a new value invented here. `RecognitionRule` does
    /// **not** filter, because it compares for equality, where the filter would merge "Tee holen" with
    /// "Bad holen".
    static func similarityWords(_ text: String) -> Set<String> {
        Set(RawTextWords.words(in: text).map(RawTextWords.normalized).filter { $0.count >= 4 })
    }

    /// |a ∩ b| / |a ∪ b|, and `0` for an empty union — such a pair shares no words anyway, so the
    /// guard against dividing by zero costs no information.
    static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        let union = a.union(b)
        guard !union.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(union.count)
    }

    /// The k nearest *other* tasks, closest first. The leave-out (AC-1) follows from the
    /// `id != target.id` filter alone: the probe never even appears as a candidate. Ties break by
    /// ascending `id`, so the order never depends on `Set` iteration order (AC-2). Candidates with
    /// no shared word (Jaccard 0) are dropped rather than filling up `k` with noise.
    static func neighbors(of target: Corpus.Entry, in pool: [Corpus.Entry], k: Int) -> [Corpus.Entry] {
        let targetWords = similarityWords(target.text)
        let scored: [(entry: Corpus.Entry, score: Double)] = pool
            .filter { $0.id != target.id }
            .map { ($0, jaccard(targetWords, similarityWords($0.text))) }
            .filter { $0.1 > 0 }
        return scored
            .sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.entry.id < rhs.entry.id : lhs.score > rhs.score
            }
            .prefix(k)
            .map(\.entry)
    }

    /// One neighbour with a value, one vote; the value with the most votes wins. Neighbours without
    /// a value for this field are skipped and **not** replaced by more distant ones — a deliberate
    /// choice, so the same function serves all three fields without the caller pre-filtering.
    /// A tie falls to the value seen first, and because the neighbours arrive ranked, that is the
    /// value of the best-placed neighbour among those level on votes (AC-4). `nil` when no
    /// neighbour carries a value (AC-5).
    static func majority<Value: Hashable>(
        among neighbors: [Corpus.Entry],
        value: (Corpus.Entry) -> Value?
    ) -> Value? {
        var valuesInOrder: [Value] = []
        var votes: [Value: Int] = [:]

        for neighbor in neighbors {
            guard let candidate = value(neighbor) else { continue }
            if votes[candidate] == nil { valuesInOrder.append(candidate) }
            votes[candidate, default: 0] += 1
        }

        var best: (value: Value, votes: Int)?
        for candidate in valuesInOrder {
            let count = votes[candidate] ?? 0
            if best == nil || count > best!.votes { best = (candidate, count) }
        }
        return best?.value
    }

    /// The constant this test has to beat: the most frequent value in the pool, computed from the
    /// data (AC-6). Same counting and tie rule as `majority`, applied to the whole pool instead of
    /// k neighbours — no percentage and no class name lives in the code.
    static func baselineClass<Value: Hashable>(
        pool: [Corpus.Entry],
        value: (Corpus.Entry) -> Value?
    ) -> Value? {
        majority(among: pool, value: value)
    }

    /// A task's contexts as one class. `Set` equality already ignores the order in the JSON, so only
    /// the spelling needs normalising (AC-7): `["Computer", "Learning"]` and
    /// `["learning", "computer"]` are the same class, not a mismatch.
    static func contextClass(_ contexts: [String]) -> Set<String> {
        Set(contexts.map { $0.lowercased() })
    }

    /// A task's context truth as a value for `majority`/`baselineClass`, or `nil` when it carries
    /// none. Both `contextsTruth == nil` and `contextsTruth == []` mean the same thing: no context
    /// truth. The FocusBlox export writes the empty list, never `null` — 183 of 287 tasks — so
    /// treating `[]` as the class "no contexts" would put every untagged task into pool, neighbours
    /// and prediction, and the measurement would mostly score "correctly predicted nothing".
    /// One function for the pool filter and the value, so the two can never drift apart.
    static func contextValue(_ entry: Corpus.Entry) -> Set<String>? {
        guard let contexts = entry.contextsTruth, !contexts.isEmpty else { return nil }
        return contextClass(contexts)
    }

    // MARK: - Evaluating the pool

    struct Evaluation: Sendable {
        /// Per pool entry, in pool order — the pairing `mcNemar` needs.
        let ruleCorrect: [Bool]
        let total: Int
        let correct: Int
        let answered: Int
        let answeredCorrect: Int
        var withoutPrediction: Int { total - answered }
        /// The binding rate: a task without neighbours is a miss, not an omitted case. Otherwise a
        /// rule that almost never answers would look perfect.
        var rate: Double { total == 0 ? 0 : Double(correct) / Double(total) }
        var rateAmongAnswered: Double { answered == 0 ? 0 : Double(answeredCorrect) / Double(answered) }
    }

    static func evaluate<Value: Hashable>(
        pool: [Corpus.Entry],
        k: Int,
        value: (Corpus.Entry) -> Value?
    ) -> Evaluation {
        var ruleCorrect: [Bool] = []
        var answered = 0
        var answeredCorrect = 0

        for entry in pool {
            let predicted = majority(among: neighbors(of: entry, in: pool, k: k), value: value)
            let hit = predicted != nil && predicted == value(entry)
            ruleCorrect.append(hit)
            if predicted != nil {
                answered += 1
                if hit { answeredCorrect += 1 }
            }
        }

        return Evaluation(ruleCorrect: ruleCorrect,
                          total: pool.count,
                          correct: ruleCorrect.filter { $0 }.count,
                          answered: answered,
                          answeredCorrect: answeredCorrect)
    }

    // MARK: - McNemar

    struct McNemarResult: Sendable {
        /// Rule right where the constant is wrong.
        let b: Int
        /// Rule wrong where the constant is right.
        let c: Int
        let pValue: Double
    }

    /// Two-sided exact McNemar test over the paired tasks. Concordant pairs (both right or both
    /// wrong) drop out; `b + c == 0` means the two arms are indistinguishable, which is `p = 1`
    /// (AC-8). Otherwise the binomial tail with p = 0,5 on n = b + c, with the coefficients built
    /// iteratively as a ratio instead of through `n!`, so an n in the hundreds does not overflow.
    static func mcNemar(ruleCorrect: [Bool], baselineCorrect: [Bool]) -> McNemarResult {
        var b = 0
        var c = 0
        for (rule, baseline) in zip(ruleCorrect, baselineCorrect) {
            if rule && !baseline { b += 1 }
            if !rule && baseline { c += 1 }
        }
        let n = b + c
        guard n > 0 else { return McNemarResult(b: b, c: c, pValue: 1.0) }

        var coefficient = 1.0            // C(n, 0)
        var tail = 1.0
        for j in 0..<min(b, c) {
            coefficient *= Double(n - j) / Double(j + 1)
            tail += coefficient
        }
        let p = 2 * tail / pow(2.0, Double(n))
        return McNemarResult(b: b, c: c, pValue: min(1.0, p))
    }
}
