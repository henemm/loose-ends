import Foundation

/// Lifecycle of a task. Every view filters on this first.
enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case unprocessed   // captured, enrichment not yet run
    case unverified    // enrichment ran, title below confidence threshold
    case active
    case parked
    case done
}

enum CaptureChannel: String, Codable, CaseIterable, Sendable {
    case siri, watch, control, share, mail, app, actionButton
}

/// Who set a derived field last.
enum FieldSource: String, Codable, Sendable {
    case ai, user
}

enum Importance: String, Codable, CaseIterable, Sendable { case low, medium, high }
enum Urgency: String, Codable, CaseIterable, Sendable { case low, medium, high }
enum Energy: String, Codable, CaseIterable, Sendable { case low, medium, high }

enum DurationBucket: String, Codable, CaseIterable, Sendable {
    case minutes5, minutes15, minutes30, hour1, hours2plus

    var isQuick: Bool { self == .minutes5 || self == .minutes15 }
}

/// Fields that can carry a revision entry.
enum RevisedField: String, Codable, CaseIterable, Sendable {
    case title, dueDate, importance, urgency, duration, energy, contexts, people, project, blockedBy, repeatRule
}

/// System and user views. Rules live in ViewRules.
enum ViewKind: String, Codable, CaseIterable, Sendable {
    case next, new, due, quick, old, waiting, repeating, parked, done, context, project

    var isSystem: Bool { self != .context && self != .project }

    var titleKey: String.LocalizationValue {
        switch self {
        case .next: "Next up"
        case .new: "New"
        case .due: "Due"
        case .quick: "Quick"
        case .old: "Old"
        case .waiting: "Waiting"
        case .repeating: "Repeating"
        case .parked: "Parked"
        case .done: "Done"
        case .context: "Context"
        case .project: "Project"
        }
    }
}
