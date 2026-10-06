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

/// Who set a derived field last. `rule` is read from the user's own words (`DueDateRule`,
/// `ImportanceUrgencyRule`, `RecognitionRule`), `ai` is guessed by the model (#101). Values a rule
/// set before #101 carry `ai` and stay readable as such.
enum FieldSource: String, Codable, Sendable {
    case ai, user, rule

    /// Set without the user: what the detail marks and the user can reset.
    var isAutomatic: Bool { self != .user }

    /// For the raw `*SourceRaw` columns; nil and unknown text are not automatic.
    static func isAutomatic(_ raw: String?) -> Bool {
        raw.flatMap(FieldSource.init(rawValue:))?.isAutomatic ?? false
    }
}

enum Importance: String, Codable, CaseIterable, Sendable { case low, medium, high }
enum Urgency: String, Codable, CaseIterable, Sendable { case low, medium, high }

/// Whether a task gives or takes energy, −3 … +3, set by hand only (#112). Stored as the number's
/// text ("-3" … "3") in the existing string field, so CloudKit sees no schema change. The old
/// values "low", "medium" and "high" answered another question (how much energy a task needs) and
/// read as empty (Henning, 2026-10-05).
enum Energy: Int, Codable, CaseIterable, Sendable {
    case takesVery = -3, takesClearly, takesLittle, neither, givesLittle, givesClearly, givesVery

    /// The text kept in `TaskItem.energyRaw` and in revisions.
    var stored: String { String(rawValue) }

    /// Nil for anything that is not a number from −3 to 3, the legacy words included.
    init?(stored: String) {
        guard let number = Int(stored) else { return nil }
        self.init(rawValue: number)
    }
}

enum DurationBucket: String, Codable, CaseIterable, Sendable {
    case minutes5, minutes15, minutes30, hour1, hours2plus

    var isQuick: Bool { self == .minutes5 || self == .minutes15 }
}

/// Fields that can carry a revision entry.
enum RevisedField: String, Codable, CaseIterable, Sendable {
    case title, dueDate, importance, urgency, duration, energy, contexts, people, project, blockedBy, repeatRule, place
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
        case .done: "Completed"
        case .context: "Context"
        case .project: "Project"
        }
    }

    /// The start screen's glyph for a view (#180). Grey, like every hierarchy sign (ADR-14).
    var symbol: String {
        switch self {
        case .next: "star"
        case .new: "tray"
        case .due: "calendar"
        case .quick: "hare"
        case .old: "hourglass"
        case .waiting: "clock"
        case .repeating: "repeat"
        case .parked: "moon.zzz"
        case .done: "checkmark.circle"
        case .context: "tag"
        case .project: "folder"
        }
    }
}
