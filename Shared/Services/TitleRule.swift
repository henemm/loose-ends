import Foundation

/// The title a task gets at capture, without the model (#202): the raw text, cleaned and cut to at
/// most twelve words. Only words of the raw text, nothing invented; the model may refine it later.
///
/// Words a rule reads into a field leave the title (#217): the due date with its time and the small
/// words leading into it ("bis Freitag", "um 15 Uhr"), and the words that say importance or urgency
/// outright ("wichtig", "dringend"). They stand in their fields already. Content words that also set
/// a field ("Rechnung", "Frist") stay. If nothing is left, the title keeps every word.
enum TitleRule {
    static let maxWords = 12

    private static let closingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", "…"]

    /// Small words that only lead into the date or time and go with it (Henning, 2026-10-06, #217):
    /// "bis Freitag", "bis zum 15.", "ab Montag", "by Friday", "at 5pm".
    private static let leadIns: Set<String> = ["bis", "am", "um", "ab", "zum", "by", "on", "at"]

    /// Left alone between two struck words: "dringend und wichtig".
    private static let connectors: Set<String> = ["und", "and"]

    /// Punctuation right after a struck word goes with it ("Morgen, wichtig: …"); quotes and
    /// brackets stay, they belong to the next word.
    private static let strippedSeparators: Set<Character> = [",", ";", ":", ".", "!", "?", "-", "–", "—"]

    /// `reference` is the moment of capture: only a date the rule step can resolve from it is struck.
    static func title(from rawText: String, reference: Date = Date(), calendar: Calendar = .current) -> String? {
        let stripped = strippingRuleWords(from: rawText, reference: reference, calendar: calendar)
        return cleaned(stripped.contains { $0.isLetter || $0.isNumber } ? stripped : rawText)
    }

    private static func cleaned(_ rawText: String) -> String? {
        let words = rawText.split(whereSeparator: { $0.isWhitespace })
        var text = words.prefix(maxWords).joined(separator: " ")
        while let last = text.last, closingPunctuation.contains(last) || last.isWhitespace {
            text.removeLast()
        }
        guard let first = text.first else { return nil }
        if first.isLetter {
            let upper = String(first).uppercased()
            if upper.count == 1 { text = upper + text.dropFirst() }
        }
        return text
    }

    /// The raw text without the words the rules set a field from. Asks the same rules the rule step
    /// asks (`DueDateRule`, `ImportanceUrgencyRule`), so a word only goes where its field gets set.
    static func strippingRuleWords(from text: String, reference: Date, calendar: Calendar = .current) -> String {
        let words = ExpressionText.words(in: text)
        let ranges = ExpressionText.wordRanges(in: text)
        guard words.count == ranges.count else { return text }

        var struck = Set<Int>()
        if let due = DueDateRule.match(in: text, reference: reference, calendar: calendar),
           let date = DateExpressionParser(calendar: calendar).span(in: text) {
            struck.formUnion(withLeadIns(date, in: words))
            if due.hasTime, let time = TimeExpressionParser().span(in: text) {
                struck.formUnion(withLeadIns(time, in: words))
            }
        }
        let markers = [ImportanceUrgencyRule.importanceMarker(in: text), ImportanceUrgencyRule.urgencyMarker(in: text)]
        for marker in markers.compactMap({ $0 }) {
            struck.formUnion(ranges.indices.filter { ranges[$0].overlaps(marker) })
        }
        for index in words.indices
        where connectors.contains(words[index].text) && struck.contains(index - 1) && struck.contains(index + 1) {
            struck.insert(index)
        }
        guard !struck.isEmpty else { return text }

        var result = ""
        var cursor = text.startIndex
        for index in struck.sorted() {
            result += text[cursor..<ranges[index].lowerBound]
            var end = ranges[index].upperBound
            while end < text.endIndex, text[end].isWhitespace || strippedSeparators.contains(text[end]) {
                end = text.index(after: end)
            }
            cursor = end
        }
        result += text[cursor...]
        return result
    }

    /// The span plus the lead-ins right before it; "on the 12th" and "by the 12th" take their "the".
    private static func withLeadIns(_ span: Range<Int>, in words: [ExpressionWord]) -> Range<Int> {
        var start = span.lowerBound
        while start > 0 {
            let previous = words[start - 1].text
            if leadIns.contains(previous) {
                start -= 1
            } else if previous == "the", start > 1, ["by", "on"].contains(words[start - 2].text) {
                start -= 2
            } else {
                break
            }
        }
        return start..<span.upperBound
    }
}
