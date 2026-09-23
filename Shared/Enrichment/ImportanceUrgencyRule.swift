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

    /// Declaration order is the priority order when a note carries several signals of one field, so
    /// the same text always yields the same reason.
    private enum ImportanceSignal: CaseIterable {
        case money, official, peopleWaiting

        var keywords: [String] {
            switch self {
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
            case .money: String(localized: "From an amount of money in the note.")
            case .official: String(localized: "From official or legal language in the note.")
            case .peopleWaiting: String(localized: "From someone waiting for this in the note.")
            }
        }

        func matches(_ text: String) -> Bool { keywords.contains { ImportanceUrgencyRule.contains($0, in: text) } }
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

        func matches(_ text: String) -> Bool { keywords.contains { ImportanceUrgencyRule.contains($0, in: text) } }
    }

    /// Case-insensitive and at word boundaries, so "Amt" does not fire inside "Beamtenrecht". A
    /// keyword that starts or ends with a symbol ("€") gets no boundary on that side — "250€" is
    /// one word to the regex engine.
    private static func contains(_ keyword: String, in text: String) -> Bool {
        var pattern = NSRegularExpression.escapedPattern(for: keyword)
        if keyword.first?.isLetter == true || keyword.first?.isNumber == true {
            pattern = "(?<![\\p{L}\\p{N}])" + pattern
        }
        if keyword.last?.isLetter == true || keyword.last?.isNumber == true {
            pattern += "(?![\\p{L}\\p{N}])"
        }
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
