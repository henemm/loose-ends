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
    // No energy: it is set by hand only (#112).
    var contexts: Guess<[String]>?
    var project: Guess<String>?

    /// Four of the five fields the FocusBlox export knows the truth for, as plain strings (#108);
    /// energy left the model with #112. Pure pass-through for the measurement code: the lab app's
    /// `MeasurementRunner` reads a model draft through it, and `MeasurementRunTests` test it via the
    /// app module. No product code calls it.
    var selfConsistencyValues: (importance: String?, urgency: String?, duration: String?,
                                contexts: [String]) {
        (importance?.value.rawValue, urgency?.value.rawValue, duration?.value.rawValue,
         contexts?.value ?? [])
    }
}
