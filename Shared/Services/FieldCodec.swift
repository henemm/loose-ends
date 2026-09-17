import Foundation

/// One encoding for every derived field, shared by the enrichment writer and the revision service,
/// so a revision's old value can always be applied back to the task (ADR-6).
///
/// Strings stay plain, dates are ISO 8601, enums use their raw value, lists are JSON arrays of
/// names, a project is its name. `blockedBy` and `repeatRule` are not revisable in this slice.
enum FieldCodec {
    static func encode(_ field: RevisedField, of task: TaskItem) -> String? {
        switch field {
        case .title: return task.title
        case .dueDate: return task.dueDate?.ISO8601Format()
        case .importance: return task.importanceRaw
        case .urgency: return task.urgencyRaw
        case .duration: return task.durationRaw
        case .energy: return task.energyRaw
        case .contexts: return encode((task.contexts ?? []).map(\.name))
        case .people: return encode(task.people)
        case .project: return task.project?.name
        case .blockedBy: return encode((task.blockedBy ?? []).map(\.id.uuidString))
        case .repeatRule: return nil
        }
    }

    /// Applies an encoded value. The field's source becomes `source`; the confidence is cleared
    /// because it belonged to the model's guess, not to this value.
    static func apply(
        _ encoded: String?,
        to field: RevisedField,
        of task: TaskItem,
        as source: FieldSource,
        contexts available: [TaskContext],
        projects: [Project]
    ) {
        let sourceRaw = source.rawValue
        switch field {
        case .title:
            task.title = nonEmpty(encoded)
            task.titleSourceRaw = task.title == nil ? nil : sourceRaw
            task.titleConfidence = nil
        case .dueDate:
            task.dueDate = encoded.flatMap { ISO8601DateFormatter().date(from: $0) }
            if task.dueDate == nil { task.dueHasTime = false }
            task.dueSourceRaw = task.dueDate == nil ? nil : sourceRaw
            task.dueConfidence = nil
        case .importance:
            task.importance = encoded.flatMap(Importance.init(rawValue:))
            task.importanceSourceRaw = task.importance == nil ? nil : sourceRaw
            task.importanceConfidence = nil
        case .urgency:
            task.urgency = encoded.flatMap(Urgency.init(rawValue:))
            task.urgencySourceRaw = task.urgency == nil ? nil : sourceRaw
            task.urgencyConfidence = nil
        case .duration:
            task.duration = encoded.flatMap(DurationBucket.init(rawValue:))
            task.durationSourceRaw = task.duration == nil ? nil : sourceRaw
            task.durationConfidence = nil
        case .energy:
            task.energy = encoded.flatMap(Energy.init(rawValue:))
            task.energySourceRaw = task.energy == nil ? nil : sourceRaw
            task.energyConfidence = nil
        case .contexts:
            let names = decode(encoded)
            task.contexts = available.filter { names.contains($0.name) }
            task.contextsSourceRaw = (task.contexts ?? []).isEmpty ? nil : sourceRaw
            task.contextsConfidence = nil
        case .people:
            task.people = decode(encoded)
            task.peopleSourceRaw = task.people.isEmpty ? nil : sourceRaw
            task.peopleConfidence = nil
        case .project:
            task.project = encoded.flatMap { name in projects.first { $0.name == name } }
        case .blockedBy, .repeatRule:
            break
        }
    }

    static func encode(_ names: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(names) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// A malformed or missing list reads as empty; nothing here can throw at the caller.
    static func decode(_ encoded: String?) -> [String] {
        guard let encoded, let data = encoded.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return names
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
