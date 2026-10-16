import Foundation

/// "Ergänzen" in the detail (#441): a sentence the user adds to an existing task, read by the same
/// rules as a capture — due date, duration, importance, urgency, contexts — and never by the model.
/// What the rules read becomes user revisions on "Apply" (the user said it, about this task); what
/// they did not read stays as `rest`, shown and not guessed at. The raw text is never touched.
struct Supplement: Equatable {
    var due: DueDateRule.Match?
    var duration: DurationBucket?
    var importance: Importance?
    var urgency: Urgency?
    /// Context names the sentence adds; the task's own contexts stay.
    var contexts: [String] = []
    /// The words no rule read, cleaned like a title; empty when everything was read.
    var rest = ""

    var isEmpty: Bool {
        due == nil && duration == nil && importance == nil && urgency == nil && contexts.isEmpty
    }

    /// `available` are the catalog's context names in catalog order; `current` the task's own.
    static func read(_ text: String, available: [String], current: [String] = [], reference: Date = Date(),
                     calendar: Calendar = .current) -> Supplement {
        var result = Supplement()
        result.due = DueDateRule.match(in: text, reference: reference, calendar: calendar)
        result.importance = ImportanceUrgencyRule.matchImportance(in: text)?.value
        result.urgency = ImportanceUrgencyRule.matchUrgency(in: text)?.value
        let duration = DurationRule.match(in: text)
        result.duration = duration?.guess.value
        let named = ContextWordRule.match(in: text, available: available)?.value ?? []
        result.contexts = named.filter { !current.contains($0) }

        var remaining = TitleRule.strippingRuleWords(from: text, reference: reference, calendar: calendar)
        if let duration = DurationRule.match(in: remaining) { remaining.removeSubrange(duration.range) }
        for name in named {
            if let word = ContextWordRule.trigger(in: remaining, contexts: [name]) { remaining.removeSubrange(word) }
        }
        // A comma left behind by a struck word is no word of its own.
        result.rest = remaining.split(whereSeparator: { $0.isWhitespace })
            .filter { $0.contains { $0.isLetter || $0.isNumber } }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?–—- "))
        return result
    }

    /// Writes what was read as user revisions; a field already holding the value writes nothing.
    /// Returns the fields that changed. The caller saves.
    @discardableResult
    func apply(to task: TaskItem, contexts: [TaskContext], projects: [Project], now: Date = Date(),
               calendar: Calendar = .current) -> [RevisedField] {
        var changed: [RevisedField] = []
        func set(_ field: RevisedField, _ encoded: String?) {
            if RevisionService.set(field, to: encoded, on: task, contexts: contexts, projects: projects, now: now) != nil {
                changed.append(field)
            }
        }
        if let due {
            let stored = due.hasTime ? due.guess.value : calendar.startOfDay(for: due.guess.value)
            let hadTime = task.dueHasTime
            set(.dueDate, stored.ISO8601Format())
            task.dueHasTime = due.hasTime
            if hadTime != due.hasTime, !changed.contains(.dueDate) { changed.append(.dueDate) }
        }
        if let duration { set(.duration, duration.rawValue) }
        if let importance { set(.importance, importance.rawValue) }
        if let urgency { set(.urgency, urgency.rawValue) }
        if !self.contexts.isEmpty {
            let names = (task.contexts ?? []).map(\.name) + self.contexts
            set(.contexts, FieldCodec.encode(names))
        }
        return changed
    }
}
