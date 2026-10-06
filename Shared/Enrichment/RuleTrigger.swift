import Foundation

/// The words a rule read a field from, for marking them in the raw text of the field editor
/// (#101): "bis **Freitag** wichtig …". Asks the same parsers the rule step asks, so the marking
/// shows what the rule saw. Recognition (#136) has no single trigger — the whole text matched —
/// and gets nil, as does every field no rule sets.
enum RuleTrigger {
    static func range(of field: RevisedField, in rawText: String, calendar: Calendar = .current) -> Range<String.Index>? {
        switch field {
        case .dueDate:
            guard let span = DateExpressionParser(calendar: calendar).span(in: rawText) else { return nil }
            let words = ExpressionText.wordRanges(in: rawText)
            guard words.indices.contains(span.lowerBound), words.indices.contains(span.upperBound - 1) else { return nil }
            return words[span.lowerBound].lowerBound..<words[span.upperBound - 1].upperBound
        case .importance:
            return ImportanceUrgencyRule.importanceTrigger(in: rawText)
        case .urgency:
            return ImportanceUrgencyRule.urgencyTrigger(in: rawText)
        default:
            return nil
        }
    }
}
