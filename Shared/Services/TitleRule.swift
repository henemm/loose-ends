import Foundation

/// The title a task gets at capture, without the model (#202): the raw text, cleaned and cut to at
/// most twelve words. Only words of the raw text, nothing invented; the model may refine it later.
/// Idempotent: applying it to its own result changes nothing.
enum TitleRule {
    static let maxWords = 12

    private static let closingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", "…"]

    static func title(from rawText: String) -> String? {
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
}
