import Foundation

/// What a task offers (#538, Henning 2026-10-18, draft "Ordnung der Felder"): five groups, one order
/// everywhere: the set lines in the detail, the word line of the empty fields, and the list in the
/// settings. Seven rules: a section shows only with content; everything empty is offered in one word
/// line; the same order everywhere; dependent fields wait (repeat and calendar for a due date,
/// subtasks and waiting on for the top level); off means not offered, never hidden; fixed is what the
/// app stands on; one settings page "Fields" with a switch per field, the same on every device.
enum DetailField: String, CaseIterable, Codable, Sendable {
    // What: the content of the task itself.
    case notes, attachments
    // When: the one time that counts. Due is fixed; repeat and calendar hang on it.
    case dueDate, repeatRule, calendar, place
    // Weight: how heavy the task weighs.
    case importance, urgency, duration, energy
    // Filing: where the task is sorted in. The same switches steer the start page's groups.
    case contexts, project
    // Connection: what has to do with other tasks. Top level only.
    case subtasks, waitingOn
    // Drive (#642): the Knäuel and the beads, both off until wanted. Last, so existing orders stay.
    case knaeuel, counts

    enum Group: CaseIterable, Sendable {
        case what, when, weight, filing, connection, drive
    }

    var group: Group {
        switch self {
        case .notes, .attachments: .what
        case .dueDate, .repeatRule, .calendar, .place: .when
        case .importance, .urgency, .duration, .energy: .weight
        case .contexts, .project: .filing
        case .subtasks, .waitingOn: .connection
        case .knaeuel, .counts: .drive
        }
    }

    /// Fixed is what other parts of the app stand on (rule 6): without a due date no "Now", no
    /// notification, no margin. No switch, always offered while empty.
    var isFixed: Bool { self == .dueDate }

    /// Offered only once the task has a due date (rule 4): a repeat without a day has nothing to
    /// repeat, an event without a day no place in the calendar.
    var needsDueDate: Bool { self == .repeatRule || self == .calendar }

    /// Offered only on a top-level task (rule 4, ADR-8): one level of subtasks, no chains. The Knäuel
    /// and the beads are a task's, not a line's (#643, #645).
    var topLevelOnly: Bool { self == .subtasks || self == .waitingOn || group == .drive }

    /// The field editor behind the word, where one exists; the others open their own section, sheet
    /// or picker.
    var revisedField: RevisedField? {
        switch self {
        case .notes: .notes
        case .dueDate: .dueDate
        case .repeatRule: .repeatRule
        case .place: .place
        case .importance: .importance
        case .urgency: .urgency
        case .duration: .duration
        case .energy: .energy
        case .contexts: .contexts
        case .project: .project
        case .knaeuel: .knaeuel
        case .counts: .counts
        case .attachments, .calendar, .subtasks, .waitingOn: nil
        }
    }

    /// The field a revised field belongs to; nil for title, people and blockedBy (waiting on is set by
    /// hand, not read from words).
    init?(revised: RevisedField) {
        switch revised {
        case .notes: self = .notes
        case .dueDate: self = .dueDate
        case .repeatRule: self = .repeatRule
        case .place: self = .place
        case .importance: self = .importance
        case .urgency: self = .urgency
        case .duration: self = .duration
        case .energy: self = .energy
        case .contexts: self = .contexts
        case .project: self = .project
        case .knaeuel: self = .knaeuel
        case .counts: self = .counts
        case .title, .people, .blockedBy: return nil
        }
    }

    /// Every field with a switch, in the order of the groups.
    static let switchable: [DetailField] = allCases.filter { !$0.isFixed }

    /// The standard (Henning, 2026-10-18): on only Note, Attachments, Calendar, Duration and Tags.
    /// Everything else is off until switched on; the rules still set importance and urgency from the
    /// words, and what is set stays visible.
    static let standardOn: Set<DetailField> = [.notes, .attachments, .calendar, .duration, .contexts]
}

/// Which fields are offered (#538, rule 7): one choice for the detail, the word line and the start
/// page's groups, the same on every device.
struct DetailFieldSettings: Equatable, Sendable {
    /// The switchable fields that are on. Fixed fields are not in here; `isOn` answers for them.
    var on: Set<DetailField>

    static let standard = DetailFieldSettings(on: DetailField.standardOn)
    /// Every switch on: what the UI tests run with, so every editor stays reachable.
    static let everything = DetailFieldSettings(on: Set(DetailField.switchable))

    init(on: Set<DetailField>) {
        self.on = on.filter { !$0.isFixed }
    }

    /// The stored form: the names of the fields that are on. Nil (nothing stored yet) is the
    /// standard; an unknown name is ignored, so a newer device never breaks an older one.
    init(stored: [String]?) {
        guard let stored else {
            self = .standard
            return
        }
        self.init(on: Set(stored.compactMap(DetailField.init(rawValue:))))
    }

    var stored: [String] {
        on.map(\.rawValue).sorted()
    }

    func isOn(_ field: DetailField) -> Bool {
        field.isFixed || on.contains(field)
    }

    func setting(_ field: DetailField, on isOn: Bool) -> DetailFieldSettings {
        var next = self
        if isOn { next.on.insert(field) } else { next.on.remove(field) }
        return DetailFieldSettings(on: next.on)
    }
}

/// The rules of the detail (#538) as pure functions over a task's state.
enum DetailFields {
    /// What the task carries: the fields that show as set lines or sections, whatever the switches say
    /// (rule 5: off is not offered, never hidden).
    static func carried(by task: TaskItem) -> Set<DetailField> {
        var carried: Set<DetailField> = []
        if !(task.notes ?? "").isEmpty { carried.insert(.notes) }
        if !(task.attachments ?? []).isEmpty { carried.insert(.attachments) }
        if task.dueDate != nil { carried.insert(.dueDate) }
        if task.repeatRule != nil { carried.insert(.repeatRule) }
        if task.showInCalendar { carried.insert(.calendar) }
        if task.place != nil { carried.insert(.place) }
        if task.importance != nil { carried.insert(.importance) }
        if task.urgency != nil { carried.insert(.urgency) }
        if task.duration != nil { carried.insert(.duration) }
        if task.energy != nil { carried.insert(.energy) }
        if !(task.contexts ?? []).isEmpty { carried.insert(.contexts) }
        if task.project != nil { carried.insert(.project) }
        if !(task.subtasks ?? []).isEmpty { carried.insert(.subtasks) }
        if !(task.blockedBy ?? []).isEmpty { carried.insert(.waitingOn) }
        if task.isKnaeuel { carried.insert(.knaeuel) }
        if task.countsAt != nil { carried.insert(.counts) }
        return carried
    }

    /// The word line (rules 2 to 5): per group, in order, the fields that are on, empty on the task and
    /// whose conditions hold. A group without a word is left out, so the line reads as short sentences.
    static func offered(
        settings: DetailFieldSettings,
        carried: Set<DetailField>,
        hasDueDate: Bool,
        topLevel: Bool
    ) -> [[DetailField]] {
        DetailField.Group.allCases.compactMap { group in
            let words = DetailField.allCases.filter { field in
                field.group == group
                    && settings.isOn(field)
                    && !carried.contains(field)
                    && (!field.needsDueDate || hasDueDate)
                    && (!field.topLevelOnly || topLevel)
            }
            return words.isEmpty ? nil : words
        }
    }

    /// The same for a task.
    static func offered(settings: DetailFieldSettings, for task: TaskItem) -> [[DetailField]] {
        offered(settings: settings, carried: carried(by: task), hasDueDate: task.dueDate != nil, topLevel: task.parent == nil)
    }
}
