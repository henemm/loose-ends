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
            return FieldCodec.decodeRepeat(encoded).map { repeatDescription($0) }
        }
    }

    /// "Weekly · Mon, Sat", "Every 2 months · after completion". Weekday names follow the calendar;
    /// the translated words follow `bundle` (the app's UI language by default). `bundle` exists so tests
    /// can pin a deterministic language, independent of the host machine's system language.
    static func repeatDescription(_ rule: RepeatRule, calendar: Calendar = .current, bundle: Bundle = .main) -> String {
        var parts = [intervalDescription(rule, bundle: bundle)]
        if rule.frequency == .weekly, let days = rule.weekdays, !days.isEmpty {
            let symbols = calendar.shortWeekdaySymbols
            let names = days.sorted().compactMap { day in symbols.indices.contains(day - 1) ? symbols[day - 1] : nil }
            if !names.isEmpty { parts.append(names.joined(separator: ", ")) }
        }
        if rule.basis == .fromCompletion {
            parts.append(String(localized: "after completion", bundle: bundle))
        }
        return parts.joined(separator: " · ")
    }

    static func intervalDescription(_ rule: RepeatRule, bundle: Bundle = .main) -> String {
        let n = max(rule.interval, 1)
        switch (rule.frequency, n) {
        case (.daily, 1): return String(localized: "Daily", bundle: bundle)
        case (.weekly, 1): return String(localized: "Weekly", bundle: bundle)
        case (.monthly, 1): return String(localized: "Monthly", bundle: bundle)
        case (.yearly, 1): return String(localized: "Yearly", bundle: bundle)
        case (.daily, _): return String(localized: "Every \(n) days", bundle: bundle)
        case (.weekly, _): return String(localized: "Every \(n) weeks", bundle: bundle)
        case (.monthly, _): return String(localized: "Every \(n) months", bundle: bundle)
        case (.yearly, _): return String(localized: "Every \(n) years", bundle: bundle)
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
