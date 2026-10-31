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

    /// The earliest time that names itself as one — "Uhr", a colon, am/pm, "halb", "half past" — or
    /// nothing. Without a day the time alone sets the due date (#679), and there "um 5" may be "um 5
    /// Euro": only the cue before the number is not enough.
    func explicitTime(in text: String) -> (hour: Int, minute: Int)? {
        guard let match = Self.earliest(in: ExpressionText.words(in: text)), match.isExplicit else { return nil }
        return (hour: match.hour, minute: match.minute)
    }

    /// The word indices of the time `time(in:)` picks, its cue ("um", "at") included, for striking
    /// it from the title (#217). Indices into `ExpressionText.words`.
    func span(in text: String) -> Range<Int>? {
        let words = ExpressionText.words(in: text)
        guard let match = Self.earliest(in: words) else { return nil }
        let start = Self.cues.contains(ExpressionText.word(words, match.index - 1)) ? match.index - 1 : match.index
        return start..<(match.index + match.count)
    }

    /// "in 1 Stunde", "in 20 Minuten", "in einer halben Stunde", "in an hour" (#679): the minutes from
    /// now and the word indices, "in" included. The first such phrase in the text.
    func offset(in text: String) -> (minutes: Int, span: Range<Int>)? {
        let words = ExpressionText.words(in: text)
        for index in words.indices where words[index].text == "in" {
            if let (minutes, count) = Self.offset(after: index, in: words) {
                return (minutes, index..<(index + 1 + count))
            }
        }
        return nil
    }

    private struct Match {
        let hour: Int
        let minute: Int
        let index: Int
        /// How many words the time spans from `index`, without the cue before it.
        let count: Int
        /// Named as a time by its own words, not only by a cue before it ("um 12").
        var isExplicit = true
    }

    private static func earliest(in words: [ExpressionWord]) -> Match? {
        for index in words.indices {
            if let match = half(at: index, in: words) ?? clock(at: index, in: words) ?? spelled(at: index, in: words) {
                return match
            }
        }
        return nil
    }

    // MARK: - Rules

    private static var cues: [String] { LanguagePacks.timeCues }

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
        var isExplicit = hasCue
        var after = index + 1
        let minutes = ExpressionText.word(words, index + 1)
        if words[index].trailing == ":", minutes.count == 2, let parsed = Int(minutes) {
            minute = parsed
            hasCue = true
            isExplicit = true
            after = index + 2
        }
        let following = ExpressionText.word(words, after)
        var end = after
        if LanguagePacks.clockWords.contains(following) {
            hasCue = true
            isExplicit = true
            end = after + 1
        }
        if marker == nil, following == "am" || following == "pm" {
            marker = following
            hasCue = true
            isExplicit = true
            end = after + 1
        }
        if cues.contains(ExpressionText.word(words, index - 1)) { hasCue = true }
        guard hasCue else { return nil }
        if let marker {
            guard (1...12).contains(hour) else { return nil }
            hour = hour % 12 + (marker == "pm" ? 12 : 0)
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return Match(hour: hour, minute: minute, index: index, count: end - index, isExplicit: isExplicit)
    }

    /// Hours dictation spells out: the shared number words reach twelve, "dreizehn" to "dreiundzwanzig"
    /// and "null" come on top. Folded like `ExpressionText` folds words (no diacritics).
    private static var spelledHours: [String: Int] {
        LanguagePacks.numbers.merging(LanguagePacks.spelledHours) { current, _ in current }
    }

    /// "um neunzehn Uhr", "acht Uhr" (#70: dictation writes numbers out). Only with "Uhr" after it,
    /// and "ein/eine … Uhr" only after "um": "eine Uhr kaufen" is a clock, not a time.
    private static func spelled(at index: Int, in words: [ExpressionWord]) -> Match? {
        let text = ExpressionText.word(words, index)
        guard let hour = spelledHours[text], (0...23).contains(hour),
              LanguagePacks.clockWords.contains(ExpressionText.word(words, index + 1)) else { return nil }
        // An article hour ("eine Uhr") counts only right after its cue ("um"): "eine Uhr kaufen" is a clock.
        if LanguagePacks.timeArticles.contains(text),
           !LanguagePacks.articleCues.contains(ExpressionText.word(words, index - 1)) { return nil }
        return Match(hour: hour, minute: 0, index: index, count: 2)
    }

    private static var hourUnits: [String] { LanguagePacks.hourUnits }
    private static var minuteUnits: [String] { LanguagePacks.minuteUnits }

    /// The minutes and the number of words after "in" at `index`, or nothing.
    private static func offset(after index: Int, in words: [ExpressionWord]) -> (Int, Int)? {
        for (phrase, minutes) in LanguagePacks.spokenOffsets
        where phrase.indices.allSatisfy({ ExpressionText.word(words, index + 1 + $0) == phrase[$0] }) {
            return (minutes, phrase.count)
        }
        guard let count = ExpressionText.number(ExpressionText.word(words, index + 1)), count > 0 else { return nil }
        let unit = ExpressionText.word(words, index + 2)
        if hourUnits.contains(unit), count <= 23 { return (count * 60, 2) }
        if minuteUnits.contains(unit), count <= 600 { return (count, 2) }
        return nil
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
