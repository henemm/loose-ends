import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// A line under a task reads its own due date and tag word by rule, like a task at capture; the
/// on-device model never sees it (#565, Henning 2026-10-20).
@Suite("Subtask rules") struct SubtaskRulesTests {
    /// A Tuesday morning, so "am Freitag" is three days ahead and "am Samstag" four.
    private var tuesday: Date {
        get throws {
            try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9)))
        }
    }

    /// A task the model has seen: nothing for the pass to do but its lines.
    @MainActor
    private func parent(in context: ModelContext) -> TaskItem {
        let task = TaskItem(rawText: "Auto in die Werkstatt")
        task.title = "Auto in die Werkstatt"
        task.status = .active
        task.processedAt = Date()
        task.rulesAppliedAt = Date()
        context.insert(task)
        return task
    }

    private func authors(of task: TaskItem) -> [FieldSource] {
        (task.revisions ?? []).map(\.author)
    }

    @Test("A new line gets its due date and tag from the rules")
    @MainActor func rulesFillALine() async throws {
        let store = try TestStore()
        let phone = TaskContext(name: "Telefon", sortOrder: 0)
        store.context.insert(phone)
        let auto = parent(in: store.context)
        let now = try tuesday
        let line = try Subtasks.add("Werkstatt anrufen am Freitag", to: auto, in: store.context, now: now)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(container: store.container)

        await coordinator.processPending()

        let due = try #require(line.dueDate)
        #expect(Calendar.current.component(.weekday, from: due) == 6, "am Freitag → Friday")
        #expect(due > now && due < now.addingTimeInterval(4 * 86_400))
        #expect(line.dueHasTime == false)
        #expect(line.dueSourceRaw == FieldSource.rule.rawValue)
        #expect((line.contexts ?? []).map(\.name) == ["Telefon"])
        #expect(line.contextsSourceRaw == FieldSource.rule.rawValue)
        #expect(line.rulesAppliedAt != nil)
        #expect(line.processedAt == nil, "the model marker stays empty (ADR-4)")
        #expect(line.title == "Werkstatt anrufen am Freitag", "the line keeps its words as title")
        #expect(authors(of: line) == [.rule, .rule])
        #expect(Subtasks.traits(of: line, now: now).contains(.tag("Telefon")))

        await coordinator.processPending()
        #expect(authors(of: line).count == 2, "the second pass adds no revision")
    }

    @Test("A bare line only gets the marker; a line the user dated keeps its date; a done line is left alone")
    @MainActor func guardsAndMarker() async throws {
        let store = try TestStore()
        let auto = parent(in: store.context)
        let now = try tuesday
        let bare = try Subtasks.add("Kartons holen", to: auto, in: store.context, now: now)
        let dated = try Subtasks.add("Reifen wechseln am Freitag", to: auto, in: store.context, now: now)
        let own = try #require(Calendar.current.date(byAdding: .day, value: 10, to: now))
        dated.dueDate = own
        dated.dueSourceRaw = FieldSource.user.rawValue
        let done = try Subtasks.add("Termin machen am Freitag", to: auto, in: store.context, now: now)
        Subtasks.toggle(done, now: now)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(container: store.container)

        await coordinator.processPending()

        #expect(bare.rulesAppliedAt != nil, "no hit still marks the step as done (#144)")
        #expect(bare.dueDate == nil && (bare.contexts ?? []).isEmpty && (bare.revisions ?? []).isEmpty)
        #expect(dated.dueDate == own, "a date the user set stays")
        #expect(dated.dueSourceRaw == FieldSource.user.rawValue)
        #expect(dated.rulesAppliedAt != nil)
        #expect(done.rulesAppliedAt == nil && done.dueDate == nil, "a done line is not read")
    }

    @Test("Analyze again on a line runs the two rules only")
    @MainActor func reanalysisRulesOnly() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten", sortOrder: 0)
        store.context.insert(garden)
        let auto = parent(in: store.context)
        let now = try tuesday
        let line = try Subtasks.add("Hecke schneiden am Samstag", to: auto, in: store.context, now: now)
        try store.context.save()
        let coordinator = EnrichmentCoordinator(container: store.container)

        let result = await coordinator.reanalyze(line)

        #expect(result == .finished(changed: 2))
        let due = try #require(line.dueDate)
        #expect(Calendar.current.component(.weekday, from: due) == 7, "am Samstag → Saturday")
        #expect((line.contexts ?? []).map(\.name) == ["Garten"])
        #expect(line.duration == nil && line.title == "Hecke schneiden am Samstag", "no duration, the title stays the line's words")
        #expect(line.rulesAppliedAt != nil && line.processedAt == nil)

        let again = await coordinator.reanalyze(line)
        #expect(again == .finished(changed: 0), "the same result adds no revision")
    }
}
