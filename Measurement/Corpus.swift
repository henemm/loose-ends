import Foundation

/// The date/title fidelity corpus (Issue #67) and the deterministic checks over it.
///
/// Truth is stored as a **rule**, never as a fixed date: Apple's Reminders (#78) always resolves
/// relative expressions against the real current date and cannot be told a capture date, so a
/// corpus with baked-in dates would be useless for the comparison — and unrepeatable here.
/// Every rule is evaluated against the reference day of the run and yields the *set* of dates a
/// correct answer may have, so genuinely ambiguous wording ("am Wochenende", "nächsten Freitag")
/// does not count as a miss.
///
/// Compiled into both test bundles; the JSON sits next to this file and is bundled as a resource.
enum Corpus {
    static let fileName = "date-title-corpus"

    /// The sentence form of a note with no `form` key: "time, object, verb", the shape the first
    /// 203 sentences were written in.
    static let standardForm = "standard"

    /// Every sentence form the corpus may use — Henning's shapes from his FocusBlox notes (#82).
    /// A closed list, because the report gives one rate per form: a typo in the JSON would open a
    /// row of one sentence and read like a finding.
    static let forms = ["standard", "stichwort", "ich-satz", "nebensatz", "frage", "diktat",
                        "zeit-hinten", "zwei-aufgaben", "denglisch", "tippfehler", "praefix",
                        "diktat-name"]

    struct Entry: Decodable, Sendable, Identifiable {
        var id: String
        var lang: String
        var text: String
        var date: DateExpectation?
        var time: String?
        /// Only read by #78 (Reminders benchmark); Loose Ends does not extract recurrence yet.
        var repeatRule: String?
        /// Optional in the JSON, so they decode as optional: Swift's synthesized decoding does
        /// not fall back to a property's default value when the key is missing.
        private var entityList: [String]?
        private var peopleList: [String]?
        /// How the note is built (#82). Kept in the JSON instead of being guessed from the text: a
        /// classifier inside the measuring instrument would be a second source of error, and the
        /// form is what the report splits every rate by. A missing key means `standard`.
        private var formName: String?
        /// The real values a note carried in FocusBlox (#108). Only the FocusBlox export writes
        /// them; for the date/title corpus they stay nil, which is why every one is optional.
        var importanceTruth: String?
        var urgencyTruth: String?
        var durationTruth: String?
        var energyTruth: String?
        var contextsTruth: [String]?
        var entities: [String] { entityList ?? [] }
        var people: [String] { peopleList ?? [] }
        var form: String { formName ?? Corpus.standardForm }

        enum CodingKeys: String, CodingKey {
            case id, lang, text, date, time
            case entityList = "entities"
            case peopleList = "people"
            case repeatRule = "repeat"
            case formName = "form"
            case importanceTruth, urgencyTruth, durationTruth, energyTruth, contextsTruth
        }

        /// A recurring note implies a first occurrence, so it can neither prove nor disprove an
        /// invented date. It stays out of both date measurements.
        var countsForDateMeasurement: Bool { repeatRule == nil }
    }

    enum DateExpectation: Decodable, Sendable, Equatable {
        case offsetDays(Int)
        /// The coming occurrence of that weekday ("am Freitag", "kommenden Freitag").
        case weekday(Int)
        /// Strictly the following calendar week ("nächste Woche Freitag").
        case weekdayNextWeek(Int)
        /// "nächsten Freitag" / "next Friday" — German and English both use this for the coming
        /// occurrence *and* for the one a week later. Both are accepted.
        case weekdayEitherNext(Int)
        case endOfMonth
        case dayOfMonth(Int)
        case weekend
        /// Any day of the month `value` months ahead ("nächsten Monat" names no day).
        case monthRange(Int)
        case dayAndMonth(day: Int, month: Int)

        private enum CodingKeys: String, CodingKey { case rule, value, weekday, day, month }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rule = try container.decode(String.self, forKey: .rule)
            func intValue() throws -> Int { try container.decode(Int.self, forKey: .value) }
            func weekdayValue() throws -> Int {
                let name = try container.decode(String.self, forKey: .weekday)
                guard let index = Corpus.weekdayNames.firstIndex(of: name.lowercased()) else {
                    throw DecodingError.dataCorruptedError(forKey: .weekday, in: container, debugDescription: "unknown weekday \(name)")
                }
                return index + 1   // Calendar counts Sunday as 1
            }
            switch rule {
            case "offsetDays": self = .offsetDays(try intValue())
            case "weekday": self = .weekday(try weekdayValue())
            case "weekdayNextWeek": self = .weekdayNextWeek(try weekdayValue())
            case "weekdayEitherNext": self = .weekdayEitherNext(try weekdayValue())
            case "endOfMonth": self = .endOfMonth
            case "dayOfMonth": self = .dayOfMonth(try intValue())
            case "weekend": self = .weekend
            case "monthRange": self = .monthRange(try intValue())
            case "dayAndMonth":
                self = .dayAndMonth(day: try container.decode(Int.self, forKey: .day),
                                    month: try container.decode(Int.self, forKey: .month))
            default:
                throw DecodingError.dataCorruptedError(forKey: .rule, in: container, debugDescription: "unknown rule \(rule)")
            }
        }
    }

    static let weekdayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]

    // MARK: - Loading

    /// Bundled as a test resource on device; on the Mac the file next to this source also works,
    /// which keeps the corpus usable from a plain script run.
    static func load(fileName: String = Corpus.fileName, calendar: Calendar = .current) throws -> [Entry] {
        let bundled = Bundle(for: CorpusAnchor.self).url(forResource: fileName, withExtension: "json")
        let onDisk = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("\(fileName).json")
        guard let url = bundled ?? (FileManager.default.fileExists(atPath: onDisk.path) ? onDisk : nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
    }

    /// Which corpus a run measures against, taken from the launch arguments (`--corpus <name>`).
    /// Without the flag the date/title corpus stays the default, so Henning's own copy of the lab
    /// app is unaffected.
    static func corpusFileName(from arguments: [String], flag: String = "--corpus") -> String {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return Corpus.fileName
        }
        return arguments[index + 1]
    }

    /// How often every note is measured (`--runs <n>`, #108). Without the flag — or with a value
    /// that is not a number — it stays at one run per note, so Henning's own copy of the lab app
    /// behaves exactly as before.
    static func runsPerEntry(from arguments: [String], flag: String = "--runs") -> Int {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1),
              let runs = Int(arguments[index + 1]) else {
            return 1
        }
        return runs
    }
}

/// `Bundle(for:)` needs a class; Swift Testing suites are structs.
final class CorpusAnchor: NSObject {}

// MARK: - Evaluating a rule against the day of the run

extension Corpus.DateExpectation {
    /// Every day that a correct answer may name, as start-of-day dates.
    func acceptedDays(reference: Date, calendar: Calendar) -> Set<Date> {
        let day = calendar.startOfDay(for: reference)
        func shifted(_ days: Int) -> Date { calendar.date(byAdding: .day, value: days, to: day)! }
        func nextOccurrence(of weekday: Int, allowToday: Bool) -> Date {
            let current = calendar.component(.weekday, from: day)
            var delta = (weekday - current + 7) % 7
            if delta == 0 && !allowToday { delta = 7 }
            return shifted(delta)
        }

        switch self {
        case .offsetDays(let value):
            return [shifted(value)]
        case .weekday(let weekday):
            // Said on the day itself, "am Freitag" may mean today or the next one.
            let today = calendar.component(.weekday, from: day) == weekday
            return today ? [day, shifted(7)] : [nextOccurrence(of: weekday, allowToday: false)]
        case .weekdayNextWeek(let weekday):
            return [Self.inFollowingWeek(weekday, from: day, calendar: calendar)]
        case .weekdayEitherNext(let weekday):
            return [nextOccurrence(of: weekday, allowToday: false),
                    Self.inFollowingWeek(weekday, from: day, calendar: calendar)]
        case .endOfMonth:
            let range = calendar.range(of: .day, in: .month, for: day)!
            var components = calendar.dateComponents([.year, .month], from: day)
            components.day = range.count
            return [calendar.date(from: components)!]
        case .dayOfMonth(let value):
            return [Self.nextDayOfMonth(value, from: day, calendar: calendar)]
        case .weekend:
            let saturday = nextOccurrence(of: 7, allowToday: true)
            let sunday = nextOccurrence(of: 1, allowToday: true)
            return [saturday, sunday]
        case .monthRange(let months):
            guard let start = calendar.date(byAdding: .month, value: months, to: day),
                  let interval = calendar.dateInterval(of: .month, for: start),
                  let count = calendar.range(of: .day, in: .month, for: start)?.count else { return [] }
            let first = calendar.startOfDay(for: interval.start)
            return Set((0..<count).map { calendar.date(byAdding: .day, value: $0, to: first)! })
        case .dayAndMonth(let dayNumber, let month):
            var components = calendar.dateComponents([.year], from: day)
            components.month = month
            components.day = dayNumber
            let thisYear = calendar.date(from: components)!
            if thisYear >= day { return [thisYear] }
            components.year! += 1
            return [calendar.date(from: components)!]
        }
    }

    /// The weekday inside the calendar week after the reference week.
    private static func inFollowingWeek(_ weekday: Int, from day: Date, calendar: Calendar) -> Date {
        var week = calendar
        week.firstWeekday = 2   // Monday, as German and British usage assume
        guard let thisWeek = week.dateInterval(of: .weekOfYear, for: day),
              let nextWeekStart = week.date(byAdding: .day, value: 7, to: week.startOfDay(for: thisWeek.start)) else { return day }
        let startWeekday = week.component(.weekday, from: nextWeekStart)
        return week.date(byAdding: .day, value: (weekday - startWeekday + 7) % 7, to: nextWeekStart)!
    }

    /// The next time that day-of-month comes around, today included.
    private static func nextDayOfMonth(_ value: Int, from day: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.year, .month], from: day)
        components.day = value
        if let candidate = calendar.date(from: components), candidate >= day { return candidate }
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: day)!
        var next = calendar.dateComponents([.year, .month], from: nextMonth)
        next.day = value
        return calendar.date(from: next)!
    }
}

// MARK: - Deterministic title checks

/// Title fidelity is checked without a model and without judgement: what the note states must
/// survive, and no fact may appear that the note does not carry.
enum TitleCheck {
    /// Lowercased and stripped of diacritics, so "Özdemir" matches "özdemir" and "Muell" is still
    /// not "Müll" (a real change of the text, which should count).
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
    }

    static func preserves(entity: String, in title: String) -> Bool {
        normalized(title).contains(normalized(entity))
    }

    /// Digit groups the title states but the note does not — the hardest kind of wrong: a number
    /// that looks like a fact.
    static func inventedNumbers(title: String, rawText: String) -> [String] {
        numbers(in: title).filter { !numbers(in: rawText).contains($0) }
    }

    static func numbers(in text: String) -> Set<String> {
        Set(text.split(whereSeparator: { !$0.isNumber }).map(String.init))
    }

    /// "Andrea" dictated and written back as "Andreas": a name close to one in the note but not
    /// the same. One or two edits apart, and not present in the note itself.
    static func alteredNames(title: String, rawText: String, people: [String]) -> [String] {
        let rawWords = Set(words(in: rawText).map(normalized))
        let expected = people.flatMap { words(in: $0) }.map(normalized).filter { $0.count >= 3 }
        return words(in: title).filter { word in
            let candidate = normalized(word)
            guard !rawWords.contains(candidate) else { return false }
            return expected.contains { (1...2).contains(editDistance(candidate, $0)) }
        }
    }

    /// Weak, broad signal: content words in the title that the note never used. Rephrasing shows
    /// up here too, so this is reported for context and never used as a threshold.
    static func foreignWords(title: String, rawText: String) -> [String] {
        let rawWords = Set(words(in: rawText).map(normalized))
        return words(in: title).filter { word in
            let candidate = normalized(word)
            return candidate.count >= 4 && !rawWords.contains { $0.hasPrefix(candidate) || candidate.hasPrefix($0) }
        }
    }

    static func words(in text: String) -> [String] {
        text.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" }).map(String.init)
    }

    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs), right = Array(rhs)
        guard !left.isEmpty else { return right.count }
        var previous = Array(0...right.count)
        for (i, l) in left.enumerated() {
            var current = [i + 1] + [Int](repeating: 0, count: right.count)
            for (j, r) in right.enumerated() {
                current[j + 1] = l == r ? previous[j] : min(previous[j], previous[j + 1], current[j]) + 1
            }
            previous = current
        }
        return previous[right.count]
    }
}
