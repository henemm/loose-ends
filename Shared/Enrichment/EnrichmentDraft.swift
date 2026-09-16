import Foundation

/// What the model proposes for one task. Every field is optional and carries a confidence (0…1)
/// and a one-sentence reason; `EnrichmentWriter` decides what crosses the threshold (ADR-3).
struct EnrichmentDraft: Equatable, Sendable {
    struct Guess<Value: Equatable & Sendable>: Equatable, Sendable {
        var value: Value
        var confidence: Double
        var reason: String

        init(_ value: Value, confidence: Double, reason: String) {
            self.value = value
            self.confidence = confidence
            self.reason = reason
        }
    }

    var title: Guess<String>?
    var dueDate: Guess<Date>?
    var dueHasTime = false
    var importance: Guess<Importance>?
    var urgency: Guess<Urgency>?
    var duration: Guess<DurationBucket>?
    var energy: Guess<Energy>?
    var contexts: Guess<[String]>?
    var people: Guess<[String]>?
    var project: Guess<String>?
}

/// Everything the model gets to see. The coordinator builds it, so an enricher stays stateless.
struct EnrichmentInput: Sendable {
    var rawText: String
    var capturedAt: Date
    var contextVocabulary: [String]
    var projectNames: [String]
    var examples: [EnrichmentExample]
}

/// A past task with its final attributes: learning by retrieval, not training (ADR-5).
struct EnrichmentExample: Sendable {
    var rawText: String
    var title: String?
    var importance: Importance?
    var urgency: Urgency?
    var duration: DurationBucket?
    var energy: Energy?
    var contexts: [String]
}

/// The seam between the pipeline and a language model. Tests use a stub (ADR-11).
protocol TaskEnricher: Sendable {
    /// Non-nil when the model cannot run right now (no Apple Intelligence, device locked, limit).
    var unavailableReason: String? { get }
    func enrich(_ input: EnrichmentInput) async throws -> EnrichmentDraft
}

/// Parsing shared by every model adapter, kept plain so it is unit-testable without a model.
enum EnrichmentParsing {
    /// "2026-09-19" plus optional "14:30" into a date in the given calendar. Empty or malformed → nil.
    static func dueDate(day: String, time: String, calendar: Calendar = .current) -> (date: Date, hasTime: Bool)? {
        let dayParts = day.split(separator: "-").compactMap { Int($0) }
        guard dayParts.count == 3 else { return nil }
        var components = DateComponents(year: dayParts[0], month: dayParts[1], day: dayParts[2])
        let timeParts = time.split(separator: ":").compactMap { Int($0) }
        let hasTime = timeParts.count == 2 && (0..<24).contains(timeParts[0]) && (0..<60).contains(timeParts[1])
        if hasTime {
            components.hour = timeParts[0]
            components.minute = timeParts[1]
        }
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        return (date, hasTime)
    }

    static func clamp(_ confidence: Double) -> Double {
        min(max(confidence, 0), 1)
    }
}
