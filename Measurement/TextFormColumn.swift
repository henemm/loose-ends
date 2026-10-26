import Foundation

/// #88 Teil 2: the column "title and duration per text form" for a lab run over the text-form corpus
/// (`--corpus textform-corpus`). Pure counting over results that were already measured: no model call,
/// no `import LooseEnds`, so it compiles into the lab app and both test bundles. `TitleRule` is not in
/// the lab target, so the rule title is handed in as a closure.
enum TextFormColumn {
    /// The forms the adapter turns into notes. `mail` is left out: its body is no model input.
    static let forms = ["typed", "dictated", "english"]

    /// One form's title line: model titles and rule titles that carry every key word of the content.
    struct TitleRow: Equatable, Sendable {
        var form: String
        /// Every result of this form, failed calls included — a failed call counts as a miss.
        var notes: Int
        var modelHits: Int
        var errors: Int
        /// Distinct notes of this form the rule title was checked on.
        var ruleNotes: Int
        var ruleHits: Int
        var modelRate: Double? { notes == 0 ? nil : Double(modelHits) / Double(notes) }
        var ruleRate: Double? { ruleNotes == 0 ? nil : Double(ruleHits) / Double(ruleNotes) }
    }

    /// One form's duration line against `typed`. There is no duration truth in the corpus: `same` is
    /// agreement between forms, not a hit.
    struct DurationRow: Equatable, Sendable {
        var form: String
        var compared: Int
        var same: Int
        /// Contents without a majority duration in this form or in `typed`.
        var skipped: Int
        var rate: Double? { compared == 0 ? nil : Double(same) / Double(compared) }
    }

    /// The content id and the form of a note id `<content>.<form>`.
    static func split(_ entryID: String) -> (content: String, form: String) {
        guard let dot = entryID.lastIndex(of: ".") else { return (entryID, "") }
        return (String(entryID[..<dot]), String(entryID[entryID.index(after: dot)...]))
    }

    /// Whether a title carries every key word, compared on `RawTextWords.normalized` text.
    static func carriesAll(_ words: [String], title: String?) -> Bool {
        guard let title, !words.isEmpty else { return false }
        let folded = RawTextWords.normalized(title)
        return words.allSatisfy { folded.contains(RawTextWords.normalized($0)) }
    }

    /// The rule column is computed on the same notes the model column counts — the distinct notes of
    /// this form that occur in `results` — so both stand on the same ground and a form without results
    /// shows "–" in both, never a rule rate over notes the run did not reach.
    static func titleRows(results: [MeasurementResult], texts: [String: String], truthWords: [String: [String]],
                          ruleTitle: (String) -> String?) -> [TitleRow] {
        forms.map { form in
            let ofForm = results.filter { split($0.entryID).form == form }
            let hits = ofForm.filter { result in
                result.error == nil && carriesAll(truthWords[split(result.entryID).content] ?? [], title: result.title)
            }
            let noteIDs = Set(ofForm.map(\.entryID)).filter { texts[$0] != nil }
            let ruleHits = noteIDs.filter { id in
                carriesAll(truthWords[split(id).content] ?? [], title: texts[id].flatMap(ruleTitle))
            }
            return TitleRow(form: form, notes: ofForm.count, modelHits: hits.count,
                            errors: ofForm.filter { $0.error != nil }.count,
                            ruleNotes: noteIDs.count, ruleHits: ruleHits.count)
        }
    }

    /// Per content, the majority duration of `dictated` and `english` against the majority of `typed`
    /// (`SelfConsistency.majority`, failed calls left out). A content that occurs in the results but has
    /// no majority on either side is counted as skipped.
    static func durationRows(results: [MeasurementResult]) -> [DurationRow] {
        let answered = results.filter { $0.error == nil }
        func majority(_ content: String, _ form: String) -> String? {
            SelfConsistency.majority(answered.filter { $0.entryID == "\(content).\(form)" }.map(\.duration))
        }
        let contents = Set(results.map { split($0.entryID).content })
        return ["dictated", "english"].map { form in
            var row = DurationRow(form: form, compared: 0, same: 0, skipped: 0)
            for content in contents {
                guard let typed = majority(content, "typed"), let other = majority(content, form) else {
                    row.skipped += 1
                    continue
                }
                row.compared += 1
                if typed == other { row.same += 1 }
            }
            return row
        }
    }

    /// `truth.titleWords` per content id, read from the corpus file.
    static func titleWords(fileName: String) throws -> [String: [String]] {
        struct File: Decodable {
            struct Truth: Decodable { var titleWords: [String] }
            struct Content: Decodable { var id: String; var truth: Truth }
            var entries: [Content]
        }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: Corpus.url(fileName: fileName)))
        return Dictionary(uniqueKeysWithValues: file.entries.map { ($0.id, $0.truth.titleWords) })
    }

    /// The column as Markdown. An empty group shows "–", never a number.
    static func render(titleRows: [TitleRow], durationRows: [DurationRow]) -> String {
        var lines = ["### Titel je Textform (Anteil mit allen Schlüsselwörtern, Regel daneben)", "",
                     "| Form | Modell | Regel | Fehlgeschlagene Aufrufe |", "|---|---|---|---|"]
        for row in titleRows {
            lines.append("| \(row.form) | \(cell(row.modelHits, of: row.notes, rate: row.modelRate)) | "
                         + "\(cell(row.ruleHits, of: row.ruleNotes, rate: row.ruleRate)) | \(row.errors) |")
        }
        lines += ["", "### Dauer je Textform (gleich wie typed)", "",
                  "Der Korpus hat keine Wahrheit für die Dauer: die Zahl ist eine Übereinstimmung zwischen den "
                  + "Formen, keine Trefferquote.", "",
                  "| Form | gleich wie typed | nicht vergleichbar |", "|---|---|---|"]
        for row in durationRows {
            lines.append("| \(row.form) | \(cell(row.same, of: row.compared, rate: row.rate)) | \(row.skipped) |")
        }
        return lines.joined(separator: "\n")
    }

    private static func cell(_ hits: Int, of total: Int, rate: Double?) -> String {
        guard let rate else { return "–" }
        return "\(hits)/\(total) (\(String(format: "%.0f", rate * 100)) %)"
    }
}
