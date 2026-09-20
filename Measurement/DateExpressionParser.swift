import Foundation

/// What a note says about *when*, as the rule itself — never as a date (#92, "rules before the
/// model"). The nine cases are the same nine `Corpus.DateExpectation` carries, so recognition
/// (this file) and truth (`Corpus.swift`) can be compared without sharing a line of code.
enum DateExpression: Equatable, Sendable {
    case offsetDays(Int)
    case weekday(Int)
    case weekdayNextWeek(Int)
    case weekdayEitherNext(Int)
    case endOfMonth
    case dayOfMonth(Int)
    case weekend
    case monthRange(Int)
    case dayAndMonth(day: Int, month: Int)
}

/// One word of the folded text plus the character that ended it — the trailing "." is what turns
/// a bare "15" into an ordinal "15." and a number into a day of the month.
struct ExpressionWord: Sendable {
    let text: String
    let trailing: Character?
}

/// Shared text handling for both rule parsers. Both languages are always checked at once: there is
/// no language field in the product, and the corpus has Denglisch notes.
enum ExpressionText {
    /// Lowercased and stripped of diacritics, like `TitleCheck.normalized`, so dictated notes
    /// ("ähm nächste woche freitag") read the same as written ones. Everything downstream works on
    /// the folded string, so folding can never shift a position out from under a match.
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
    }

    /// Letters and digits form words; every other character ends one. "1,5" and "18:45" therefore
    /// split into two words each, and the separator stays readable as `trailing`.
    static func words(in text: String) -> [ExpressionWord] {
        var words: [ExpressionWord] = []
        var current = ""
        for character in folded(text) {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else if !current.isEmpty {
                words.append(ExpressionWord(text: current, trailing: character))
                current = ""
            }
        }
        if !current.isEmpty { words.append(ExpressionWord(text: current, trailing: nil)) }
        return words
    }

    static func word(_ words: [ExpressionWord], _ index: Int) -> String {
        words.indices.contains(index) ? words[index].text : ""
    }

    static let numbers: [String: Int] = [
        "ein": 1, "eine": 1, "einer": 1, "einem": 1, "einen": 1, "eins": 1, "one": 1,
        "zwei": 2, "two": 2, "drei": 3, "three": 3, "vier": 4, "four": 4, "funf": 5, "five": 5,
        "sechs": 6, "six": 6, "sieben": 7, "seven": 7, "acht": 8, "eight": 8, "neun": 9, "nine": 9,
        "zehn": 10, "ten": 10, "elf": 11, "eleven": 11, "zwolf": 12, "twelve": 12,
    ]

    /// A digit group or a number word, nothing else: "4711" stays a number, "A-2291" never becomes one.
    static func number(_ text: String) -> Int? {
        Int(text) ?? numbers[text]
    }
}

/// The rule-based date parser: recognition by word, resolution by its own calendar arithmetic.
///
/// The arithmetic is deliberately *not* shared with `Corpus.DateExpectation.acceptedDays` — if both
/// sides used the same code, a mistake in it would confirm itself in the measurement.
struct DateExpressionParser: Sendable {
    let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// The earliest expression in the text; on a tie the more specific rule wins
    /// (dayAndMonth > dayOfMonth > weekdayNextWeek > weekdayEitherNext > weekday).
    func expression(in text: String) -> DateExpression? {
        let words = ExpressionText.words(in: text)
        var candidates: [Candidate] = []
        for index in words.indices {
            candidates += [Self.offsetMatch(at: index, in: words),
                           Self.weekdayMatch(at: index, in: words),
                           Self.monthMatch(at: index, in: words),
                           Self.numberMatch(at: index, in: words),
                           Self.weekendMatch(at: index, in: words)].compactMap { $0 }
        }
        return candidates
            .filter { !Self.isRepetition(before: $0.index, in: words) }
            .min { ($0.index, -$0.priority) < ($1.index, -$1.priority) }?
            .expression
    }

    /// The one day the parser stands behind. Ambiguous wording still resolves to a single day:
    /// weekend = Saturday, "nächsten Freitag" = the coming one, "nächsten Monat" = the first.
    func date(in text: String, reference: Date) -> Date? {
        expression(in: text).flatMap { resolve($0, reference: reference) }
    }

    func resolve(_ expression: DateExpression, reference: Date) -> Date? {
        let day = calendar.startOfDay(for: reference)
        switch expression {
        case .offsetDays(let value): return shift(day, days: value)
        case .weekday(let weekday): return next(weekday, from: day, includingToday: true)
        case .weekdayEitherNext(let weekday): return next(weekday, from: day, includingToday: false)
        case .weekdayNextWeek(let weekday): return inFollowingWeek(weekday, from: day)
        case .endOfMonth: return endOfMonth(day)
        case .dayOfMonth(let value): return dayOfMonth(value, from: day)
        case .weekend: return next(7, from: day, includingToday: true)
        case .monthRange(let months): return firstDay(of: day, monthsAhead: months)
        case .dayAndMonth(let value, let month): return fixed(day: value, month: month, from: day)
        }
    }

    // MARK: - Recognition

    private struct Candidate {
        let index: Int
        let priority: Int
        let expression: DateExpression
    }

    private static let weekdays: [String: Int] = [
        "sonntag": 1, "sunday": 1, "montag": 2, "monday": 2, "dienstag": 3, "tuesday": 3,
        "mittwoch": 4, "wednesday": 4, "donnerstag": 5, "thursday": 5, "freitag": 6, "friday": 6,
        "samstag": 7, "sonnabend": 7, "saturday": 7,
    ]

    private static let months: [String: Int] = [
        "januar": 1, "january": 1, "februar": 2, "february": 2, "marz": 3, "march": 3,
        "april": 4, "mai": 5, "may": 5, "juni": 6, "june": 6, "juli": 7, "july": 7,
        "august": 8, "september": 9, "oktober": 10, "october": 10, "november": 11,
        "dezember": 12, "december": 12,
    ]

    private static let relativeDays = ["heute": 0, "today": 0, "morgen": 1, "tomorrow": 1, "ubermorgen": 2]
    private static let nextWords = ["nachste", "nachsten", "nachster", "nachstes", "nachstem", "next"]
    private static let dayUnits = ["tag", "tage", "tagen", "day", "days"]
    private static let weekUnits = ["woche", "wochen", "week", "weeks"]
    private static let dayPrepositions = ["am", "zum", "bis"]
    private static let ordinalSuffixes = ["st", "nd", "rd", "th"]
    private static let repetitions = ["jeden", "jede", "jeder", "jedes", "jedem", "every",
                                      "werktags", "taglich", "wochentlich", "monatlich", "jahrlich",
                                      "daily", "weekly", "monthly"]

    /// A repetition is not a date (#92): "Jeden Montag" and "Every day" name no single day.
    /// The block reaches three words back, so "Jeden ersten Montag im Monat" is caught too.
    private static func isRepetition(before index: Int, in words: [ExpressionWord]) -> Bool {
        (max(0, index - 3)..<index).contains { repetitions.contains(words[$0].text) }
    }

    private static func offsetMatch(at index: Int, in words: [ExpressionWord]) -> Candidate? {
        let text = ExpressionText.word(words, index)
        if text == "day", ExpressionText.word(words, index + 1) == "after",
           ExpressionText.word(words, index + 2) == "tomorrow" {
            return Candidate(index: index, priority: 4, expression: .offsetDays(2))
        }
        if let days = relativeDays[text] {
            return Candidate(index: index, priority: 4, expression: .offsetDays(days))
        }
        guard text == "in", let count = ExpressionText.number(ExpressionText.word(words, index + 1)) else { return nil }
        let unit = ExpressionText.word(words, index + 2)
        if dayUnits.contains(unit) { return Candidate(index: index, priority: 4, expression: .offsetDays(count)) }
        if weekUnits.contains(unit) { return Candidate(index: index, priority: 4, expression: .offsetDays(count * 7)) }
        return nil
    }

    /// A weekday counts wherever it stands ("Laternenumzug Freitag"), but what comes before it
    /// decides which of the three weekday rules applies.
    private static func weekdayMatch(at index: Int, in words: [ExpressionWord]) -> Candidate? {
        guard let weekday = weekdays[ExpressionText.word(words, index)] else { return nil }
        let previous = ExpressionText.word(words, index - 1)
        if previous == "woche", nextWords.contains(ExpressionText.word(words, index - 2)) {
            return Candidate(index: index - 2, priority: 3, expression: .weekdayNextWeek(weekday))
        }
        if nextWords.contains(previous) {
            return Candidate(index: index - 1, priority: 2, expression: .weekdayEitherNext(weekday))
        }
        return Candidate(index: index, priority: 1, expression: .weekday(weekday))
    }

    private static func monthMatch(at index: Int, in words: [ExpressionWord]) -> Candidate? {
        let text = ExpressionText.word(words, index)
        let following = ExpressionText.word(words, index + 1)
        if text == "monatsende" { return Candidate(index: index, priority: 4, expression: .endOfMonth) }
        if text == "ende", following == "des", ExpressionText.word(words, index + 2) == "monats" {
            return Candidate(index: index, priority: 4, expression: .endOfMonth)
        }
        if text == "end", following == "of" {
            let rest = ExpressionText.word(words, index + 2) == "the" ? index + 3 : index + 2
            if ExpressionText.word(words, rest) == "month" {
                return Candidate(index: index, priority: 4, expression: .endOfMonth)
            }
        }
        if nextWords.contains(text), ["monat", "monats", "month"].contains(following) {
            return Candidate(index: index, priority: 4, expression: .monthRange(1))
        }
        if let month = months[text], let day = ordinal(following), (1...31).contains(day) {
            return Candidate(index: index, priority: 5, expression: .dayAndMonth(day: day, month: month))
        }
        return nil
    }

    /// A number only becomes a day with an ordinal marker *and* a preposition: "bis zum 15.",
    /// "am 20.", "on the 12th". That is what keeps 4711, 250 Euro and Gleis 9 out.
    private static func numberMatch(at index: Int, in words: [ExpressionWord]) -> Candidate? {
        guard words.indices.contains(index) else { return nil }
        guard let value = ordinal(words[index]), (1...31).contains(value) else { return nil }
        if let month = months[ExpressionText.word(words, index + 1)] {
            return Candidate(index: index, priority: 5, expression: .dayAndMonth(day: value, month: month))
        }
        let previous = ExpressionText.word(words, index - 1)
        let english = previous == "the" && ["by", "on"].contains(ExpressionText.word(words, index - 2))
        guard dayPrepositions.contains(previous) || english else { return nil }
        return Candidate(index: index, priority: 4, expression: .dayOfMonth(value))
    }

    private static func weekendMatch(at index: Int, in words: [ExpressionWord]) -> Candidate? {
        let text = ExpressionText.word(words, index)
        guard text == "wochenende" || text == "weekend" else { return nil }
        return Candidate(index: index, priority: 4, expression: .weekend)
    }

    /// "15." or "12th" — a number that is marked as a day, unlike "15" on its own.
    private static func ordinal(_ word: ExpressionWord) -> Int? {
        if let value = Int(word.text), word.trailing == "." { return value }
        for suffix in ordinalSuffixes where word.text.hasSuffix(suffix) {
            if let value = Int(word.text.dropLast(suffix.count)) { return value }
        }
        return nil
    }

    /// The English form "on May 4th" / "on November 11": the month leads, the day follows.
    private static func ordinal(_ text: String) -> Int? {
        let digits = text.prefix(while: \.isNumber)
        guard let value = Int(digits) else { return nil }
        let rest = String(text.dropFirst(digits.count))
        return rest.isEmpty || ordinalSuffixes.contains(rest) ? value : nil
    }

    // MARK: - Resolution (its own arithmetic, on purpose)

    private func shift(_ day: Date, days: Int) -> Date? {
        calendar.date(byAdding: .day, value: days, to: day)
    }

    private func next(_ weekday: Int, from day: Date, includingToday: Bool) -> Date? {
        var delta = (weekday - calendar.component(.weekday, from: day) + 7) % 7
        if delta == 0 && !includingToday { delta = 7 }
        return shift(day, days: delta)
    }

    /// The week after this one, counted from Monday — German and British usage.
    private func inFollowingWeek(_ weekday: Int, from day: Date) -> Date? {
        let sinceMonday = (calendar.component(.weekday, from: day) + 5) % 7
        guard let monday = shift(day, days: 7 - sinceMonday) else { return nil }
        return shift(monday, days: (weekday + 5) % 7)
    }

    private func endOfMonth(_ day: Date) -> Date? {
        guard let range = calendar.range(of: .day, in: .month, for: day) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: day)
        components.day = range.count
        return calendar.date(from: components)
    }

    private func dayOfMonth(_ value: Int, from day: Date) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: day)
        components.day = value
        if let candidate = calendar.date(from: components), candidate >= day { return candidate }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: day) else { return nil }
        var following = calendar.dateComponents([.year, .month], from: nextMonth)
        following.day = value
        return calendar.date(from: following)
    }

    private func firstDay(of day: Date, monthsAhead months: Int) -> Date? {
        guard let target = calendar.date(byAdding: .month, value: months, to: day) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: target)
        components.day = 1
        return calendar.date(from: components)
    }

    private func fixed(day value: Int, month: Int, from day: Date) -> Date? {
        var components = calendar.dateComponents([.year], from: day)
        components.month = month
        components.day = value
        guard let thisYear = calendar.date(from: components) else { return nil }
        guard thisYear < day else { return thisYear }
        components.year = (components.year ?? 0) + 1
        return calendar.date(from: components)
    }
}
