import Foundation

/// The words one language contributes to the rules (Epic #750). One file per language holds them;
/// `LanguagePacks.shipped` is the one list of shipped languages. Every word is stored folded
/// (lowercase, no diacritics: "nachste", "ubermorgen"), exactly as `ExpressionText.folded` yields it.
/// The rules check all shipped languages at once, like the Denglisch notes in the corpus need.
struct LanguagePack: Sendable {
    /// ISO 639-1, "en", "de".
    let code: String
    /// English name, for the model prompt test (#757).
    let name: String
    let numbers: [String: Int]
    /// 1 = Sunday, like `Calendar`.
    let weekdays: [String: Int]
    let months: [String: Int]
    let relativeDays: [String: Int]
    let nextWords: [String]
    let dayUnits: [String]
    let weekUnits: [String]
    let dayPrepositions: [String]
    let ordinalSuffixes: [String]
    let repetitions: [String]
    /// Words that mark a number as a time of day: "um 7", "at 7".
    let timeCues: [String]
    /// The word after an hour that makes it a clock time: "acht Uhr". Empty where a language has none.
    let clockWords: [String]
    /// Number words that count as "one" before the clock word and need a cue: "um eine Uhr", not "eine Uhr kaufen".
    let timeArticles: [String]
    /// The only cues after which such an article counts as an hour ("um eine Uhr", not "auf eine Uhr").
    let articleCues: [String]
    /// Hours dictation spells out beyond `numbers` (twelve): "dreizehn" … "dreiundzwanzig", "null".
    let spelledHours: [String: Int]
    let hourUnits: [String]
    /// Hour abbreviations only the duration rule reads ("hrs"); the time rule never took them.
    let abbreviatedHourUnits: [String]
    let minuteUnits: [String]
    /// Lengths without a number after "in", in minutes, as the words each takes.
    let spokenOffsets: [[String]: Int]
    /// Spoken lengths without a number, in minutes ("eine halbe stunde").
    let durationPhrases: [String: Int]
    /// Words before a length that make it a point in time: "in 2 Stunden".
    let pointInTime: [String]
}

enum LanguagePacks {
    static let shipped: [LanguagePack] = [.english, .german]

    /// Test hook (#755): tests plug a pack in. Product code reads only `active`. Written from tests on
    /// the main thread before any rule runs, never from the product, hence `nonisolated(unsafe)`.
    nonisolated(unsafe) static var active: [LanguagePack] = shipped

    static var numbers: [String: Int] { merged(\.numbers) }
    static var weekdays: [String: Int] { merged(\.weekdays) }
    static var months: [String: Int] { merged(\.months) }
    static var relativeDays: [String: Int] { merged(\.relativeDays) }
    static var nextWords: [String] { list(\.nextWords) }
    static var dayUnits: [String] { list(\.dayUnits) }
    static var weekUnits: [String] { list(\.weekUnits) }
    static var dayPrepositions: [String] { list(\.dayPrepositions) }
    static var ordinalSuffixes: [String] { list(\.ordinalSuffixes) }
    static var repetitions: [String] { list(\.repetitions) }

    static var timeCues: [String] { list(\.timeCues) }
    static var clockWords: [String] { list(\.clockWords) }
    static var timeArticles: [String] { list(\.timeArticles) }
    static var articleCues: [String] { list(\.articleCues) }
    static var spelledHours: [String: Int] { merged(\.spelledHours) }
    static var hourUnits: [String] { list(\.hourUnits) }
    static var abbreviatedHourUnits: [String] { list(\.abbreviatedHourUnits) }
    static var minuteUnits: [String] { list(\.minuteUnits) }
    static var pointInTime: [String] { list(\.pointInTime) }
    /// Longest phrase first (words, then characters), so "eine halbe stunde" is read before "eine stunde".
    static var spokenOffsets: [(words: [String], minutes: Int)] {
        merged(\.spokenOffsets).map { (words: $0.key, minutes: $0.value) }
            .sorted { ($0.words.count, $0.words.joined(separator: " ").count) > ($1.words.count, $1.words.joined(separator: " ").count) }
    }
    static var durationPhrases: [(phrase: String, minutes: Int)] {
        merged(\.durationPhrases).map { (phrase: $0.key, minutes: $0.value) }
            .sorted { (wordCount($0.phrase), $0.phrase.count) > (wordCount($1.phrase), $1.phrase.count) }
    }

    private static func wordCount(_ phrase: String) -> Int { phrase.split(separator: " ").count }

    /// A word may stand in two packs ("april"), but never with two values.
    private static func merged<Key: Hashable>(_ key: KeyPath<LanguagePack, [Key: Int]>) -> [Key: Int] {
        active.reduce(into: [:]) { result, pack in
            result.merge(pack[keyPath: key]) { old, new in
                precondition(old == new, "Wort mit zwei Werten in zwei Packs")
                return old
            }
        }
    }

    /// Longest first, duplicates removed.
    private static func list(_ key: KeyPath<LanguagePack, [String]>) -> [String] {
        var seen = Set<String>()
        return active.flatMap { $0[keyPath: key] }
            .filter { seen.insert($0).inserted }
            .sorted { $0.count > $1.count }
    }
}
