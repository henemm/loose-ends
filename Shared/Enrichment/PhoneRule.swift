import Foundation

/// A phone number in the dictated text goes to the note, not the title (#439, Henning 2026-10-15:
/// "Automatisch in die Notiz"). `NSDataDetector` finds it, the same rule the note uses for its links
/// (`NoteLinks`); no model. The title rule strips the number, the rule step writes it to the note.
enum PhoneRule {
    /// The numbers as written, in order of appearance.
    static func numbers(in text: String) -> [String] {
        ranges(in: text).map { String(text[$0]) }
    }

    /// Where the numbers stand in the text, for stripping them from the title.
    static func ranges(in text: String) -> [Range<String.Index>] {
        NoteLinks.hits(in: text).filter { $0.kind == .phone }.map(\.range)
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
}
