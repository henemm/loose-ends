import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Read from your words or guessed by Apple Intelligence (#101): the rules write the origin `rule`,
/// the model keeps `ai`, and everything written before stays readable.
@Suite("Field origin") struct FieldOriginTests {
    /// A Wednesday at noon, so "bis Freitag" resolves to a fixed day in any time zone.
    @MainActor
    private func capture(_ rawText: String, in store: TestStore) throws -> TaskItem {
        let task = TaskItem(rawText: rawText)
        task.capturedAt = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12)))
        store.context.insert(task)
        try store.context.save()
        return task
    }

    private func titleOnly(_ title: String) -> StubEnricher {
        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess(title, confidence: 0.9, reason: "Stub.")
        return StubEnricher(draft: draft)
    }

    @Test("Old records stay readable; unknown text reads as AI, as before (AC-1)")
    func legacyRecordsStayReadable() {
        let legacy = Revision(task: nil, field: .dueDate, oldValue: nil, newValue: nil, author: .ai)
        #expect(legacy.author == .ai)
        legacy.authorRaw = "rule"
        #expect(legacy.author == .rule)
        legacy.authorRaw = "something else"
        #expect(legacy.author == .ai)
        #expect(FieldSource.ai.isAutomatic && FieldSource.rule.isAutomatic && !FieldSource.user.isAutomatic)
        #expect(FieldSource.isAutomatic("ai") && FieldSource.isAutomatic("rule"))
        #expect(!FieldSource.isAutomatic("user") && !FieldSource.isAutomatic(nil) && !FieldSource.isAutomatic("x"))
    }

    @Test("Due date, importance and urgency from a rule carry the rule origin; the title stays AI (AC-2)")
    @MainActor func rulesWriteRuleModelWritesAI() async throws {
        let store = try TestStore()
        let task = try capture("bis Freitag dringend Steuererklärung abgeben", in: store)

        await EnrichmentCoordinator(enricher: titleOnly("Steuererklärung abgeben"), container: store.container).processPending()

        #expect(task.dueSourceRaw == FieldSource.rule.rawValue)
        #expect(task.importanceSourceRaw == FieldSource.rule.rawValue)
        #expect(task.urgencySourceRaw == FieldSource.rule.rawValue)
        #expect(task.titleSourceRaw == FieldSource.ai.rawValue)
        let revisions = task.revisions ?? []
        for field in [RevisedField.dueDate, .importance, .urgency] {
            #expect(revisions.first { $0.field == field }?.author == .rule, "\(field)")
        }
        #expect(revisions.first { $0.field == .title }?.author == .ai)

        #expect(RevisionService.origin(of: .dueDate, on: task) == .rule)
        #expect(RevisionService.origin(of: .title, on: task) == .ai)
        #expect(RevisionService.automaticFields(on: task) == [.title, .dueDate, .importance, .urgency])
        #expect(task.hasUnseenAutomaticRevisions)
        #expect(RevisionService.markSeen(task) == 4, "rule revisions are marked seen like AI ones")
        #expect(!task.hasUnseenAutomaticRevisions)
    }

    @Test("A rule value resets like an AI value, as a user revision (AC-3)")
    @MainActor func ruleValueResets() async throws {
        let store = try TestStore()
        let task = try capture("bis Freitag Geschenk besorgen", in: store)
        await EnrichmentCoordinator(enricher: titleOnly("Geschenk besorgen"), container: store.container).processPending()
        let rule = try #require(RevisionService.firstAutomaticRevision(of: .dueDate, on: task))
        #expect(rule.author == .rule)

        let reset = RevisionService.revert(rule, on: task, contexts: [], projects: [])

        #expect(task.dueDate == nil)
        #expect(task.dueSourceRaw == nil)
        #expect(reset.author == .user)
        #expect(RevisionService.origin(of: .dueDate, on: task) == nil)
    }

    @Test("A field a rule set before #101 still counts as automatic, as AI (AC-1)")
    func legacyRuleValueStaysAutomatic() throws {
        let task = TaskItem(rawText: "bis Freitag Geschenk besorgen")
        task.dueDate = Date()
        task.dueSourceRaw = FieldSource.ai.rawValue
        task.importance = .high
        task.importanceSourceRaw = FieldSource.user.rawValue
        #expect(RevisionService.origin(of: .dueDate, on: task) == .ai)
        #expect(RevisionService.automaticFields(on: task) == [.dueDate])
    }

    @Test("Recognition names the earlier task and carries the rule origin (AC-4)")
    @MainActor func recognitionNamesTheEarlierTask() async throws {
        let store = try TestStore()
        let earlier = TaskItem(rawText: "Rasen mähen")
        earlier.capturedAt = try #require(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 12)))
        earlier.status = .active
        earlier.processedAt = earlier.capturedAt
        earlier.duration = .minutes30
        earlier.durationSourceRaw = FieldSource.user.rawValue
        store.context.insert(earlier)
        let fresh = try capture("Rasen mähen", in: store)

        await EnrichmentCoordinator(enricher: titleOnly("Rasen mähen"), container: store.container).processPending()

        #expect(fresh.duration == .minutes30)
        #expect(fresh.durationSourceRaw == FieldSource.rule.rawValue)
        let revision = try #require((fresh.revisions ?? []).first { $0.field == .duration })
        #expect(revision.author == .rule)
        #expect(revision.reason == RecognitionRule.reason(rawText: "Rasen mähen", capturedAt: earlier.capturedAt))
        #expect(revision.reason?.contains("Rasen mähen") == true)
    }
}
