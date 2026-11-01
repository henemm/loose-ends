import Foundation

/// A phone number in the dictated text goes to the note, not the title (#439, Henning 2026-10-15:
/// "Automatisch in die Notiz"). A rule, not the detector (#786): `NSDataDetector` also took bare digit
/// runs ("Police 30021988") for numbers on iPhone and iPad, not on the Mac, so the rule scans the text
/// itself and comes out the same on every device; no model. The title rule strips the number, the
/// rule step writes it to the note.
enum PhoneRule {
    /// The numbers as written, in order of appearance.
    static func numbers(in text: String) -> [String] {
        ranges(in: text).map { String(text[$0]) }
    }

    /// Where the numbers stand in the text, for stripping them from the title. A number opens with "+",
    /// "0" or "(" before a digit, or has the North American shape 3-3-4; it stands free (no letter or
    /// "+" before it) and holds 7 to 15 ASCII digits. A run of groups that is no number is skipped whole,
    /// so no number is cut out of its middle ("DE89 3704 0044 …").
    static func ranges(in text: String) -> [Range<String.Index>] {
        let chars = Array(text)
        let indices = Array(text.indices) + [text.endIndex]
        var found: [Range<String.Index>] = []
        var index = 0
        while index < chars.count {
            let char = chars[index]
            let opensRun = isDigit(char) || char == "+" || char == "("
            guard opensRun, index == 0 || !isDigit(chars[index - 1]) else {
                index += 1
                continue
            }
            let candidate = candidateEnd(in: chars, from: index)
            guard candidate.end > index else {
                index += 1
                continue
            }
            let free = index == 0 || !(chars[index - 1].isLetter || chars[index - 1] == "+")
            let opened = opensLikeNumber(chars, at: index)
            let date = isDateShaped(groups: candidate.groups, separators: candidate.separators)
            if free, !date, isValid(digits: candidate.digits, groups: candidate.groups, opened: opened) {
                found.append(indices[index]..<indices[candidate.end])
            }
            index = candidate.end
        }
        return found
    }

    /// The text without its phone numbers, for the title.
    static func removing(from text: String) -> String {
        var result = text
        for range in ranges(in: text).reversed() {
            result.removeSubrange(range)
        }
        return result
    }

    /// The note the rule writes: one number per line.
    static func note(from text: String) -> String? {
        let found = numbers(in: text)
        return found.isEmpty ? nil : found.joined(separator: "\n")
    }

    static var reason: String { String(localized: "From a phone number in the note.") }

    // MARK: - Scanner

    /// Reads digit groups and the separators between them from `start`. `end` stands after the last
    /// digit (or ")"): a separator counts only when another group follows, so a trailing " -" or ","
    /// stays out. `groups` holds each group's digit count, a group in brackets is one of its own;
    /// `separators` holds the text between two groups as written ("/", " ", " - ").
    private static func candidateEnd(
        in chars: [Character], from start: Int
    ) -> (end: Int, digits: Int, groups: [Int], separators: [String]) {
        var index = chars[start] == "+" ? start + 1 : start
        var end = start
        var groups: [Int] = []
        var separators: [String] = []
        while let group = groupEnd(in: chars, from: index) {
            groups.append(group.digits)
            end = group.end
            index = separatorEnd(in: chars, from: end) ?? end
            if groupEnd(in: chars, from: index) == nil { break }
            separators.append(String(chars[end..<index]))
        }
        return (end, groups.reduce(0, +), groups, separators)
    }

    /// A date, never a number (#786): the first three groups hold 1–2, 1–2 and 2 or 4 digits and the
    /// two marks between them are both "/" or both "-", without spaces ("01/02/2026", "05-03-26"),
    /// whatever follows ("01/02/2026 10:30"). Spaces alone make no date ("01 23 4567" is a number).
    private static func isDateShaped(groups: [Int], separators: [String]) -> Bool {
        guard groups.count >= 3, separators.count >= 2 else { return false }
        let dayAndMonth = (1...2).contains(groups[0]) && (1...2).contains(groups[1])
        let mark = separators[0]
        return dayAndMonth && [2, 4].contains(groups[2]) && ["/", "-"].contains(mark) && separators[1] == mark
    }

    /// 7 to 15 digits (E.164) for a number that opens with "+", "0" or "("; the North American shape
    /// 3-3-4 also without. A date is ruled out before (`isDateShaped`).
    private static func isValid(digits: Int, groups: [Int], opened: Bool) -> Bool {
        if groups == [3, 3, 4] { return true }
        return opened && (7...15).contains(digits)
    }

    /// One group: ASCII digits, or digits in brackets ("(0)", "(555)").
    private static func groupEnd(in chars: [Character], from start: Int) -> (end: Int, digits: Int)? {
        let bracketed = start < chars.count && chars[start] == "("
        var index = bracketed ? start + 1 : start
        let first = index
        while index < chars.count, isDigit(chars[index]) { index += 1 }
        let digits = index - first
        guard digits > 0 else { return nil }
        if bracketed {
            guard index < chars.count, chars[index] == ")" else { return nil }
            index += 1
        }
        return (index, digits)
    }

    /// A space, "/", "-" or "–", the mark optionally with a space on either side. A dot is no separator.
    private static func separatorEnd(in chars: [Character], from start: Int) -> Int? {
        var index = start
        if index < chars.count, isSpace(chars[index]) { index += 1 }
        if index < chars.count, ["/", "-", "\u{2013}"].contains(chars[index]) {
            index += 1
            if index < chars.count, isSpace(chars[index]) { index += 1 }
        }
        return index > start ? index : nil
    }

    /// "+", "0" or "(" followed by a digit; a lone "0" opens nothing.
    private static func opensLikeNumber(_ chars: [Character], at index: Int) -> Bool {
        guard ["+", "0", "("].contains(chars[index]), index + 1 < chars.count else { return false }
        return isDigit(chars[index + 1])
    }

    private static func isDigit(_ char: Character) -> Bool {
        char.isASCII && char.isNumber
    }

    private static func isSpace(_ char: Character) -> Bool {
        char == " " || char == "\u{00A0}" || char == "\u{202F}"
    }
}
