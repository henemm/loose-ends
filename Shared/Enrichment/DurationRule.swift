import Foundation
import OSLog

/// The rule step for the duration (#441): a stated length — "20 Minuten", "eine halbe Stunde",
/// "2 hours" — sorted into the next bucket up. Only what is said, never a length guessed from the
/// task; "in 2 Stunden" is a point in time, not a length, and stays out. No hit means `nil`.
///
/// Pure `Foundation`, like `ImportanceUrgencyRule`: `Shared/` compiles into the watch and widgets.
enum DurationRule {
    static let confidence = 1.0
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Enrichment")

    // The words live in `Shared/Language/` (Epic #750). Spoken lengths come longest phrase first, so
    // "eine halbe Stunde" is not read as "eine Stunde".
    private static var phrases: [(phrase: String, minutes: Int)] { LanguagePacks.durationPhrases }
    private static var minuteUnits: [String] { LanguagePacks.minuteUnits }
    private static var hourUnits: [String] { LanguagePacks.hourUnits + LanguagePacks.abbreviatedHourUnits }

    /// Words that turn a length into a point in time: "in 2 Stunden", "nach 10 Minuten".
    private static var pointInTime: Set<String> { Set(LanguagePacks.pointInTime) }

    /// The bucket the text names, with the words that said it.
    static func match(in text: String) -> (guess: EnrichmentDraft.Guess<DurationBucket>, range: Range<String.Index>)? {
        guard let (minutes, range) = length(in: text) else { return nil }
        let guess = EnrichmentDraft.Guess(bucket(for: minutes), confidence: confidence,
                                          reason: String(localized: "From the length named in your words."))
        return (guess, range)
    }

    /// Up to the next bucket: 20 minutes is "30 min", 45 minutes "1 h".
    static func bucket(for minutes: Int) -> DurationBucket {
        switch minutes {
        case ...5: .minutes5
        case ...15: .minutes15
        case ...30: .minutes30
        case ...60: .hour1
        default: .hours2plus
        }
    }

    private static func length(in text: String) -> (Int, Range<String.Index>)? {
        let lower = text.lowercased()
        guard lower.count == text.count else { return nil }
        if let hit = number(in: lower) { return (hit.0, converted(hit.1, from: lower, to: text)) }
        for (phrase, minutes) in phrases {
            guard let range = word(phrase, in: lower), !isPointInTime(before: range, in: lower) else { continue }
            return (minutes, converted(range, from: lower, to: text))
        }
        return nil
    }

    /// "20 Minuten", "1,5 Std", "2h": a number, optional space, a unit.
    private static func number(in text: String) -> (Int, Range<String.Index>)? {
        let units = (minuteUnits + hourUnits).joined(separator: "|")
        let pattern = #"(\d+(?:[.,]\d+)?)\s?("# + units + #")(?![\p{L}])"#
        let regex: Regex<AnyRegexOutput>
        do {
            regex = try Regex(pattern)
        } catch {
            logger.error("Duration pattern failed: \(error, privacy: .public)")
            return nil
        }
        for found in text.matches(of: regex) {
            // A number glued to a word ("A4", "x10") is no length.
            if found.range.lowerBound > text.startIndex {
                let before = text[text.index(before: found.range.lowerBound)]
                if before.isLetter || before.isNumber { continue }
            }
            guard !isPointInTime(before: found.range, in: text),
                  let numberRange = found.output[1].range, let unitRange = found.output[2].range,
                  let value = Double(text[numberRange].replacingOccurrences(of: ",", with: ".")) else { continue }
            let unit = String(text[unitRange])
            let minutes = hourUnits.contains(unit) ? value * 60 : value
            guard minutes > 0 else { continue }
            return (Int(minutes.rounded(.up)), found.range)
        }
        return nil
    }

    private static func isPointInTime(before range: Range<String.Index>, in text: String) -> Bool {
        let before = text[..<range.lowerBound].split(whereSeparator: { $0.isWhitespace })
        return before.last.map { pointInTime.contains(String($0)) } ?? false
    }

    private static func word(_ phrase: String, in text: String) -> Range<String.Index>? {
        var start = text.startIndex
        while let range = text.range(of: phrase, range: start..<text.endIndex) {
            let beforeOK = range.lowerBound == text.startIndex || !text[text.index(before: range.lowerBound)].isLetter
            let afterOK = range.upperBound == text.endIndex || !text[range.upperBound].isLetter
            if beforeOK && afterOK { return range }
            start = range.upperBound
        }
        return nil
    }

    /// Lowercasing kept the length (checked above), so offsets carry over to the original.
    private static func converted(_ range: Range<String.Index>, from lower: String, to text: String) -> Range<String.Index> {
        let start = text.index(text.startIndex, offsetBy: lower.distance(from: lower.startIndex, to: range.lowerBound))
        let end = text.index(start, offsetBy: lower.distance(from: range.lowerBound, to: range.upperBound))
        return start..<end
    }
}
