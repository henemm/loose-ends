import Foundation

/// The title a task gets at capture, without the model (#202): the raw text, cleaned and cut to at
/// most twelve words. Only words of the raw text, nothing invented; the model may refine it later.
///
/// Words a rule reads into a field leave the title (#217): the due date with its time and the small
/// words leading into it ("bis Freitag", "um 15 Uhr"), and the words that say importance or urgency
/// outright ("wichtig", "dringend"), and a phone number, which the rule step puts into the note (#439).
/// They stand in their fields already. Content words that also set
/// a field ("Rechnung", "Frist") stay. If nothing is left, the title keeps every word.
enum TitleRule {
    static let maxWords = 12

    private static let closingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", "…"]

    /// Small words that only lead into the date or time and go with it (Henning, 2026-10-06, #217):
    /// "bis Freitag", "bis zum 15.", "ab Montag", "by Friday", "at 5pm".
    private static var leadIns: Set<String> { Set(LanguagePacks.titleLeadIns) }

    /// Left alone between two struck words: "dringend und wichtig".
    private static var connectors: Set<String> { Set(LanguagePacks.titleConnectors) }

    /// Punctuation right after a struck word goes with it ("Morgen, wichtig: …"); quotes and
    /// brackets stay, they belong to the next word.
    private static let strippedSeparators: Set<Character> = [",", ";", ":", ".", "!", "?", "-", "–", "—"]

    /// `reference` is the moment of capture: only a date the rule step can resolve from it is struck.
    static func title(from rawText: String, reference: Date = Date(), calendar: Calendar = .current) -> String? {
        // A phone number goes to the note (#439): it leaves the title whole, "+" and "/" included.
        let withoutPhones = PhoneRule.removing(from: rawText)
        let stripped = strippingRuleWords(from: withoutPhones, reference: reference, calendar: calendar)
        return cleaned(stripped.contains { $0.isLetter || $0.isNumber } ? stripped : rawText)
    }

    /// Whether a model title comes from the note (#460): at least one of its content words (four
    /// letters or more) stands in the note, a word start being enough ("Anruf" for "anrufen"). The
    /// model was handed the notes of past tasks as examples and copied one onto an unrelated note
    /// ("Das ist jetzt nur ein Test …" became "Eløb Frühbucher anmelden"). A title without content
    /// words passes: there is nothing to check.
    static func isFromNote(_ title: String, rawText: String) -> Bool {
        let noteWords = RawTextWords.words(in: rawText).map(RawTextWords.normalized).filter { $0.count >= 4 }
        let content = RawTextWords.words(in: title).map(RawTextWords.normalized).filter { $0.count >= 4 }
        guard !content.isEmpty else { return true }
        return content.contains { word in noteWords.contains { $0.hasPrefix(word) || word.hasPrefix($0) } }
    }

    /// Whether a model title takes a word from a past task's note (#607): a content word (four letters or
    /// more) that does not stand in this note but in one of the notes the model was handed as examples.
    /// "Cider kaltstellen" became "Cider kaltstellen und Altpapier Altglas wegbringen"; one word of the
    /// note was enough for `isFromNote`. A word the note lacks is rephrasing, allowed; one an example
    /// carries is a copy. Word starts count both ways, as in `isFromNote`.
    static func borrows(_ title: String, rawText: String, pastNotes: [String]) -> Bool {
        let noteWords = contentWords(in: rawText)
        let pastWords = Set(pastNotes.flatMap { contentWords(in: $0) })
        guard !pastWords.isEmpty else { return false }
        func matches(_ word: String, _ other: String) -> Bool { word.hasPrefix(other) || other.hasPrefix(word) }
        return contentWords(in: title).contains { word in
            !noteWords.contains { matches(word, $0) } && pastWords.contains { matches(word, $0) }
        }
    }

    private static func contentWords(in text: String) -> [String] {
        RawTextWords.words(in: text).map(RawTextWords.normalized).filter { $0.count >= 4 }
    }

    /// Month and weekday names the model may not bring into a title on its own (#507): it was handed the
    /// capture day and wrote it into "Blumen gießen muss" as "Blumen 17. Oktober, gießen".
    private static var dateWords: Set<String> { Set(LanguagePacks.titleDateWords.map(RawTextWords.normalized)) }

    /// Whether a model title names a date the note does not: a month or weekday name, or a number, that
    /// does not stand in the note (#507). The due date is the rules' job (#95); a date in the title is the
    /// capture day leaking in.
    static func addsDate(_ title: String, rawText: String) -> Bool {
        let note = Set(RawTextWords.words(in: rawText).map(RawTextWords.normalized))
        return RawTextWords.words(in: title).map(RawTextWords.normalized).contains { word in
            !note.contains(word) && (dateWords.contains(word) || word.allSatisfy(\.isNumber))
        }
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
        for span in DueDateRule.match(in: text, reference: reference, calendar: calendar)?.spans ?? [] {
            struck.formUnion(withLeadIns(span, in: words))
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
