import Foundation

/// The rule-based time-of-day parser (#92), kept apart from the date parser because the two
/// languages disagree on "half": German "halb zwölf" is 11:30 (half *before* the full hour),
/// English "half past seven" is 07:30 (half *after* it).
///
/// A number only becomes a time with a cue — "Uhr", a colon, am/pm or one of "um/auf/at". Without
/// one, "Rechnung 4711", "Gleis 9" and "Zimmer 12" stay what they are.
struct TimeExpressionParser: Sendable {
    init() {}

    /// The earliest time in the text, or nothing.
    func time(in text: String) -> (hour: Int, minute: Int)? {
        Self.earliest(in: ExpressionText.words(in: text)).map { (hour: $0.hour, minute: $0.minute) }
    }

    /// The word indices of the time `time(in:)` picks, its cue ("um", "at") included, for striking
    /// it from the title (#217). Indices into `ExpressionText.words`.
    func span(in text: String) -> Range<Int>? {
        let words = ExpressionText.words(in: text)
        guard let match = Self.earliest(in: words) else { return nil }
        let start = Self.cues.contains(ExpressionText.word(words, match.index - 1)) ? match.index - 1 : match.index
        return start..<(match.index + match.count)
    }

    private struct Match {
        let hour: Int
        let minute: Int
        let index: Int
        /// How many words the time spans from `index`, without the cue before it.
        let count: Int
    }

    private static func earliest(in words: [ExpressionWord]) -> Match? {
        for index in words.indices {
            if let match = half(at: index, in: words) ?? clock(at: index, in: words) {
                return match
            }
        }
        return nil
    }

    // MARK: - Rules

    private static let cues = ["um", "auf", "at"]

    /// "halb zwölf" = 11:30, "half past seven" = 07:30.
    private static func half(at index: Int, in words: [ExpressionWord]) -> Match? {
        let text = ExpressionText.word(words, index)
        if text == "half", ExpressionText.word(words, index + 1) == "past",
           let hour = ExpressionText.number(ExpressionText.word(words, index + 2)), (1...12).contains(hour) {
            return Match(hour: hour % 12, minute: 30, index: index, count: 3)
        }
        guard text == "halb",
              let hour = ExpressionText.number(ExpressionText.word(words, index + 1)),
              (1...12).contains(hour) else { return nil }
        return Match(hour: hour == 1 ? 12 : hour - 1, minute: 30, index: index, count: 2)
    }

    /// "um 20 Uhr", "7:30", "at 5pm", "auf 10 Uhr", "um 12".
    private static func clock(at index: Int, in words: [ExpressionWord]) -> Match? {
        guard words.indices.contains(index), let (value, suffix) = digits(words[index].text) else { return nil }
        var hour = value
        var minute = 0
        var marker = suffix
        var hasCue = suffix != nil
        var after = index + 1
        let minutes = ExpressionText.word(words, index + 1)
        if words[index].trailing == ":", minutes.count == 2, let parsed = Int(minutes) {
            minute = parsed
            hasCue = true
            after = index + 2
        }
        let following = ExpressionText.word(words, after)
        var end = after
        if following == "uhr" {
            hasCue = true
            end = after + 1
        }
        if marker == nil, following == "am" || following == "pm" {
            marker = following
            hasCue = true
            end = after + 1
        }
        if cues.contains(ExpressionText.word(words, index - 1)) { hasCue = true }
        guard hasCue else { return nil }
        if let marker {
            guard (1...12).contains(hour) else { return nil }
            hour = hour % 12 + (marker == "pm" ? 12 : 0)
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return Match(hour: hour, minute: minute, index: index, count: end - index)
    }

    /// Leading digits plus an optional am/pm glued to them ("5pm"); "4th" is not a number here.
    private static func digits(_ text: String) -> (Int, String?)? {
        let leading = text.prefix(while: \.isNumber)
        guard let value = Int(leading) else { return nil }
        let rest = String(text.dropFirst(leading.count))
        if rest.isEmpty { return (value, nil) }
        guard rest == "am" || rest == "pm" else { return nil }
        return (value, rest)
    }
}
