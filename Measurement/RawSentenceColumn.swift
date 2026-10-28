import Foundation

/// #88 Teil 2, Schnitt A: Henning's own raw sentences as a second measuring source. Pure counting over
/// results that were already measured: no model call, no `import LooseEnds`, so it compiles into the lab
/// app and both test bundles. `TitleRule` and `DurationRule` are not in the lab target, so the rule
/// column is handed in as closures. The report carries counts and rates only, never a sentence.
enum RawSentenceColumn {
    /// Below this many corrected sentences a criterion shows "zu wenig" instead of a rate.
    static let minimumCorrected = 30

    /// One line of `docs/reference/loose-ends-rawtexts.json`.
    struct Sentence: Decodable, Sendable {
        var id: String
        var rawText: String
        var titleBefore: String
        var titleUser: String?
        var durationUser: String?
        var capturedAt: String
        var lang: String?

        /// Truth tier 1 for the title: the user's title has words, and their sequence differs from the
        /// app's. An empty title is no correction: a failed run could never be told apart from it.
        var titleCorrected: Bool {
            guard let titleUser else { return false }
            let user = RawSentenceColumn.wordSequence(titleUser)
            return !user.isEmpty && user != RawSentenceColumn.wordSequence(titleBefore)
        }

        var durationCorrected: Bool { durationUser != nil }
    }

    struct Tiers {
        var titleCorrected: [Sentence]
        var titleUncorrected: [Sentence]
        var durationCorrected: [Sentence]
        var durationUncorrected: [Sentence]
    }

    struct TitleRow: Equatable, Sendable {
        var corrected: Int
        var modelHits: Int
        var ruleHits: Int
        /// Failed calls on the corrected sentences; a failed call counts as a miss.
        var errors: Int
        var uncorrected: Int
    }

    struct DurationRow: Equatable, Sendable {
        var corrected: Int
        var modelHits: Int
        var ruleHits: Int
        var uncorrected: Int
    }

    static func decode(_ data: Data) throws -> [Sentence] {
        try JSONDecoder().decode([Sentence].self, from: data)
    }

    /// The words of a text, normalized and in order: the strict title comparison.
    static func wordSequence(_ text: String) -> String {
        RawTextWords.words(in: text).map(RawTextWords.normalized).joined(separator: " ")
    }

    /// Folds sentences with the same word set into one. The representative is the first one with a
    /// correction (title or duration), otherwise the first of the file; the file order stays. A sentence
    /// without words has no word set to compare and always stays on its own.
    static func distinct(_ sentences: [Sentence]) -> (kept: [Sentence], before: Int, after: Int) {
        var kept: [Sentence] = []
        var slot: [Set<String>: Int] = [:]
        for sentence in sentences {
            let key = Set(RawTextWords.words(in: sentence.rawText).map(RawTextWords.normalized))
            guard !key.isEmpty, let index = slot[key] else {
                if !key.isEmpty { slot[key] = kept.count }
                kept.append(sentence)
                continue
            }
            let corrected = { (s: Sentence) in s.titleCorrected || s.durationCorrected }
            if !corrected(kept[index]) && corrected(sentence) { kept[index] = sentence }
        }
        return (kept, sentences.count, kept.count)
    }

    static func tiers(_ sentences: [Sentence]) -> Tiers {
        Tiers(titleCorrected: sentences.filter(\.titleCorrected),
              titleUncorrected: sentences.filter { !$0.titleCorrected },
              durationCorrected: sentences.filter(\.durationCorrected),
              durationUncorrected: sentences.filter { !$0.durationCorrected })
    }

    /// Model and rule over the same corrected sentences, those that occur in the run. Per sentence the
    /// majority of the normalized titles over its answered runs counts, as for the duration (AC-6); a
    /// failed run is never a hit, and without one answered run the sentence is a miss. `errors` counts
    /// the failed calls.
    static func titleRow(results: [MeasurementResult], sentences: [Sentence],
                         ruleTitle: (String) -> String?) -> TitleRow {
        let byID = Dictionary(grouping: results, by: \.entryID)
        let measured = tiers(sentences).titleCorrected.filter { byID[$0.id] != nil }
        var row = TitleRow(corrected: measured.count, modelHits: 0, ruleHits: 0, errors: 0,
                           uncorrected: tiers(sentences).titleUncorrected.filter { byID[$0.id] != nil }.count)
        for sentence in measured {
            let runs = byID[sentence.id] ?? []
            let truth = wordSequence(sentence.titleUser ?? "")
            let titles = runs.filter { $0.error == nil }.map { wordSequence($0.title ?? "") }
            row.errors += runs.count - titles.count
            if !titles.isEmpty, SelfConsistency.majority(titles) == truth { row.modelHits += 1 }
            if ruleTitle(sentence.rawText).map(wordSequence) == truth { row.ruleHits += 1 }
        }
        return row
    }

    /// Majority duration over the answered runs (`SelfConsistency.majority`) against `durationUser`,
    /// the rule over the same sentences that occur in the run.
    static func durationRow(results: [MeasurementResult], sentences: [Sentence],
                            ruleDuration: (String) -> String?) -> DurationRow {
        let byID = Dictionary(grouping: results, by: \.entryID)
        let measured = tiers(sentences).durationCorrected.filter { byID[$0.id] != nil }
        var row = DurationRow(corrected: measured.count, modelHits: 0, ruleHits: 0,
                              uncorrected: tiers(sentences).durationUncorrected.filter { byID[$0.id] != nil }.count)
        for sentence in measured {
            let answered = (byID[sentence.id] ?? []).filter { $0.error == nil }
            if SelfConsistency.majority(answered.map(\.duration)) == sentence.durationUser { row.modelHits += 1 }
            if ruleDuration(sentence.rawText) == sentence.durationUser { row.ruleHits += 1 }
        }
        return row
    }

    /// The section as Markdown: counts and rates only, never a sentence or a title.
    static func render(before: Int, after: Int, title: TitleRow, duration: DurationRow) -> String {
        [
            "## Echte Rohsätze", "",
            "Quelle: Hennings eigene Erfassungen, vom Nutzer korrigierte Sätze als Wahrheit.", "",
            "Sätze vor/nach Entduplizierung: \(before) / \(after)", "",
            "| Kriterium | korrigiert | Modell | Regel | Fehlgeschlagene Aufrufe |", "|---|---|---|---|---|",
            "| Titel | \(title.corrected) | \(cell(title.modelHits, of: title.corrected)) | "
                + "\(cell(title.ruleHits, of: title.corrected)) | \(title.errors) |",
            "| Dauer | \(duration.corrected) | \(cell(duration.modelHits, of: duration.corrected)) | "
                + "\(cell(duration.ruleHits, of: duration.corrected)) | – |", "",
            "| nicht korrigiert | Sätze | Wertung |", "|---|---|---|",
            "| Titel | \(title.uncorrected) | kein Beleg, nicht gewertet |",
            "| Dauer | \(duration.uncorrected) | kein Beleg, nicht gewertet |",
        ].joined(separator: "\n")
    }

    private static func cell(_ hits: Int, of total: Int) -> String {
        if total == 0 { return "–" }
        if total < minimumCorrected { return "zu wenig (\(total) von mindestens \(minimumCorrected))" }
        return "\(hits)/\(total) (\(String(format: "%.0f", Double(hits) / Double(total) * 100)) %)"
    }
}
