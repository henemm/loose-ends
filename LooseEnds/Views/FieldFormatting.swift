import Foundation

/// Human-readable labels and values for the derived fields, shared by detail and revision views.
enum FieldFormatting {
    static func label(_ field: RevisedField) -> String {
        switch field {
        case .title: String(localized: "Title")
        case .dueDate: String(localized: "Due")
        case .importance: String(localized: "Importance")
        case .urgency: String(localized: "Urgency")
        case .duration: String(localized: "Duration")
        case .energy: String(localized: "Energy")
        case .contexts: String(localized: "Contexts")
        case .people: String(localized: "People")
        case .project: String(localized: "Project")
        case .blockedBy: String(localized: "Blocked by")
        case .repeatRule: String(localized: "Repeat")
        }
    }

    /// The encoded value of a field as the user reads it; nil when the field is empty.
    static func value(_ encoded: String?, for field: RevisedField, hasTime: Bool = false) -> String? {
        guard let encoded, !encoded.isEmpty else { return nil }
        switch field {
        case .title, .project:
            return encoded
        case .dueDate:
            guard let date = ISO8601DateFormatter().date(from: encoded) else { return nil }
            return date.formatted(date: .abbreviated, time: hasTime ? .shortened : .omitted)
        case .importance, .urgency, .energy:
            return level(encoded)
        case .duration:
            return DurationBucket(rawValue: encoded).map(duration)
        case .contexts, .people, .blockedBy:
            let names = FieldCodec.decode(encoded)
            return names.isEmpty ? nil : names.joined(separator: ", ")
        case .repeatRule:
            return encoded
        }
    }

    static func level(_ raw: String) -> String? {
        switch raw {
        case "low": String(localized: "Low")
        case "medium": String(localized: "Medium")
        case "high": String(localized: "High")
        default: nil
        }
    }

    static func duration(_ bucket: DurationBucket) -> String {
        switch bucket {
        case .minutes5: String(localized: "5 min")
        case .minutes15: String(localized: "15 min")
        case .minutes30: String(localized: "30 min")
        case .hour1: String(localized: "1 h")
        case .hours2plus: String(localized: "2 h+")
        }
    }

    static func author(_ source: FieldSource) -> String {
        switch source {
        case .ai: String(localized: "AI")
        case .user: String(localized: "You")
        }
    }
}
