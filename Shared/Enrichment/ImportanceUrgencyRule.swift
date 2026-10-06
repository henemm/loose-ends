import Foundation

/// The rule step for importance and urgency (#117, part of #112 alternative 1): keywords instead of
/// a model call, after the same pattern as `DueDateRule` (#95). Rules before the model (CLAUDE.md).
///
/// Two independent functions, not one triple: importance and urgency are orthogonal fields in the
/// data model and in `ViewRules.byUrgencyThenImportance` — "urgent but unimportant" is valid.
/// Neither takes a reference date: a function without a date parameter cannot read `capturedAt`,
/// which is the structural guarantee for "the age of a note is not a signal" (#117, AC-5).
///
/// Only `.high`, never `.medium` or `.low`: there is no reliable textual marker for "middling", and
/// inventing one would be exactly the fallback default that #111 exposed in the old FocusBlox
/// "truth". No hit means `nil`.
///
/// Pure `Foundation` on purpose: `Shared/` also compiles into the watch, the widgets and the share
/// extension, where `FoundationModels` does not exist.
enum ImportanceUrgencyRule {
    /// A keyword hit is deterministically there or not — an in-between number would be an invented
    /// one, as in `DueDateRule`.
    static let confidence = 1.0

    /// The importance the rule stands behind, or nothing.
    static func matchImportance(in text: String) -> EnrichmentDraft.Guess<Importance>? {
        guard let signal = ImportanceSignal.allCases.first(where: { $0.matches(text) }) else { return nil }
        return EnrichmentDraft.Guess(.high, confidence: confidence, reason: signal.reason)
    }

    /// The urgency the rule stands behind, or nothing.
    static func matchUrgency(in text: String) -> EnrichmentDraft.Guess<Urgency>? {
        guard let signal = UrgencySignal.allCases.first(where: { $0.matches(text) }) else { return nil }
        return EnrichmentDraft.Guess(.high, confidence: confidence, reason: signal.reason)
    }

    /// Where the keyword behind `matchImportance` stands, for marking it in the field editor (#101).
    static func importanceTrigger(in text: String) -> Range<String.Index>? {
        ImportanceSignal.allCases.lazy.compactMap { $0.range(in: text) }.first
    }

    /// Where the keyword behind `matchUrgency` stands (#101).
    static func urgencyTrigger(in text: String) -> Range<String.Index>? {
        UrgencySignal.allCases.lazy.compactMap { $0.range(in: text) }.first
    }

    /// Where the word stands that says the importance outright ("wichtig"), for striking it from the
    /// title (#217). Only that word: "Rechnung" or "Finanzamt" also set the importance, but they are
    /// what the task is about and stay in the title.
    static func importanceMarker(in text: String) -> Range<String.Index>? {
        ImportanceSignal.explicit.range(in: text)
    }

    /// Where the word stands that says the urgency outright ("dringend", "sofort"), for the title
    /// (#217). A deadline word ("Frist", "Mahnung") is content and stays.
    static func urgencyMarker(in text: String) -> Range<String.Index>? {
        UrgencySignal.immediacy.range(in: text)
    }

    /// The keyword of this signal that stands earliest in the text.
    private static func firstRange(of keywords: [String], in text: String) -> Range<String.Index>? {
        keywords.compactMap { range(of: $0, in: text) }.min { $0.lowerBound < $1.lowerBound }
    }

    /// Like `firstRange`, but an occurrence the note negates does not count (#214, #220): "nicht
    /// wichtig", "not so important", "nicht dringend". "unwichtig" never gets here — the word boundary keeps it out.
    private static func firstUnnegatedRange(of keywords: [String], in text: String) -> Range<String.Index>? {
        var found: [Range<String.Index>] = []
        for keyword in keywords {
            var start = text.startIndex
            while let hit = range(of: keyword, in: text, from: start) {
                if !isNegated(hit, in: text) {
                    found.append(hit)
                    break
                }
                start = hit.upperBound
            }
        }
        return found.min { $0.lowerBound < $1.lowerBound }
    }

    private static let negations: Set<String> = [
        "nicht", "kein", "keine", "nie", "not", "never", "isnt", "arent", "wasnt", "dont", "doesnt",
    ]
    private static let intensifiers: Set<String> = ["so", "sehr", "besonders", "ganz", "too", "very", "that"]

    /// A negation right before the keyword, or before an intensifier right before it ("nicht so
    /// wichtig"). Two words back without the intensifier is too far: "Nicht vergessen: wichtig".
    private static func isNegated(_ hit: Range<String.Index>, in text: String) -> Bool {
        let before = text[..<hit.lowerBound]
            .split(whereSeparator: { $0.isWhitespace })
            .suffix(2)
            .map { String($0.lowercased().filter(\.isLetter)) }
        guard let last = before.last else { return false }
        if negations.contains(last) { return true }
        return before.count == 2 && intensifiers.contains(last) && negations.contains(before[0])
    }

    /// Declaration order is the priority order when a note carries several signals of one field, so
    /// the same text always yields the same reason.
    private enum ImportanceSignal: CaseIterable {
        case explicit, money, official, peopleWaiting

        var keywords: [String] {
            switch self {
            case .explicit:
                ["sehr wichtig", "wichtig", "wichtige", "wichtiger", "wichtiges", "wichtigen", "wichtigem",
                 "very important", "important"]
            case .money:
                ["euro", "eur", "€", "betrag", "rechnung", "rechnungen", "kredit", "gehalt", "zahlung",
                 "überweisung", "invoice", "amount", "payment", "salary", "loan"]
            case .official:
                ["finanzamt", "amt", "behörde", "gericht", "anwalt", "anwältin", "notar", "vertrag",
                 "steuer", "steuererklärung", "bußgeld", "tax", "official", "contract", "court", "lawyer"]
            case .peopleWaiting:
                ["wartet auf", "warten auf", "erwartet eine antwort", "erwartet antwort",
                 "is waiting for", "are waiting for", "waiting for", "is expecting"]
            }
        }

        /// Shown to the user in the task detail and the field editor, one sentence per category.
        var reason: String {
            switch self {
            case .explicit: String(localized: "From the word “important” in the note.")
            case .money: String(localized: "From an amount of money in the note.")
            case .official: String(localized: "From official or legal language in the note.")
            case .peopleWaiting: String(localized: "From someone waiting for this in the note.")
            }
        }

        /// Where this signal stands earliest; the outright word only where the note does not negate it.
        func range(in text: String) -> Range<String.Index>? {
            self == .explicit
                ? ImportanceUrgencyRule.firstUnnegatedRange(of: keywords, in: text)
                : ImportanceUrgencyRule.firstRange(of: keywords, in: text)
        }

        func matches(_ text: String) -> Bool { range(in: text) != nil }
    }

    private enum UrgencySignal: CaseIterable {
        case deadline, immediacy

        var keywords: [String] {
            switch self {
            case .deadline:
                ["frist", "fristen", "kündigungsfrist", "stichtag", "spätestens", "mahnung",
                 "deadline", "reminder", "cancellation"]
            case .immediacy:
                ["dringend", "dringlich", "sofort", "jetzt", "umgehend", "unverzüglich", "eilt",
                 "asap", "urgent", "urgently", "immediately"]
            }
        }

        var reason: String {
            switch self {
            case .immediacy: String(localized: "From an urgency word in the note.")
            case .deadline: String(localized: "From a deadline reference in the note.")
            }
        }

        /// Where this signal stands earliest; the outright word only where the note does not negate
        /// it ("nicht dringend", #220). A deadline word stays as it is: "keine Frist" is rare.
        func range(in text: String) -> Range<String.Index>? {
            self == .immediacy
                ? ImportanceUrgencyRule.firstUnnegatedRange(of: keywords, in: text)
                : ImportanceUrgencyRule.firstRange(of: keywords, in: text)
        }

        func matches(_ text: String) -> Bool { range(in: text) != nil }
    }

    /// Case-insensitive and at word boundaries, so "Amt" does not fire inside "Beamtenrecht". A
    /// keyword that starts or ends with a symbol ("€") gets no boundary on that side — "250€" is
    /// one word to the regex engine.
    private static func range(of keyword: String, in text: String, from start: String.Index? = nil) -> Range<String.Index>? {
        var pattern = NSRegularExpression.escapedPattern(for: keyword)
        if keyword.first?.isLetter == true || keyword.first?.isNumber == true {
            pattern = "(?<![\\p{L}\\p{N}])" + pattern
        }
        if keyword.last?.isLetter == true || keyword.last?.isNumber == true {
            pattern += "(?![\\p{L}\\p{N}])"
        }
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive],
                          range: (start ?? text.startIndex)..<text.endIndex)
    }
}
