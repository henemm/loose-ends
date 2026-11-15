import Foundation
import SwiftData
import XCTest
@testable import LooseEnds

/// What Claude changed (#622 Schnitt 2): a Claude revision is a user revision with the reason "Claude"
/// (Schnitt 1). The detail reads the latest one through `RevisionService`, the change list names Claude
/// as the author, and the unseen badge never counts it.
@MainActor
final class RevisionServiceClaudeTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func task(in store: TestStore) throws -> TaskItem {
        let task = TaskItem(rawText: "Zahnarzt anrufen")
        store.context.insert(task)
        try store.context.save()
        return task
    }

    @discardableResult
    private func revision(on task: TaskItem, _ field: RevisedField = .dueDate, author: FieldSource,
                          reason: String?, minutesAgo: Double) -> Revision {
        let revision = Revision(task: task, field: field, oldValue: nil, newValue: "x", author: author, reason: reason)
        revision.createdAt = now.addingTimeInterval(-minutesAgo * 60)
        task.revisions = (task.revisions ?? []) + [revision]
        return revision
    }

    // MARK: AC-1

    func testLatestClaudeChangeIsTheNewerOne() throws {
        let store = try TestStore()
        let task = try task(in: store)
        revision(on: task, author: .user, reason: OrderExecutor.reason, minutesAgo: 30)
        let newer = revision(on: task, .status, author: .user, reason: OrderExecutor.reason, minutesAgo: 5)
        revision(on: task, .title, author: .ai, reason: "Names the job.", minutesAgo: 1)

        XCTAssertEqual(RevisionService.lastClaudeChange(on: task)?.id, newer.id)
    }

    func testNoRevisionsMeansNoClaudeChange() throws {
        let store = try TestStore()
        let task = try task(in: store)

        XCTAssertNil(RevisionService.lastClaudeChange(on: task))
    }

    // MARK: AC-2

    func testAutomaticAndPlainUserRevisionsAreNotClaude() throws {
        let store = try TestStore()
        let task = try task(in: store)
        let ai = revision(on: task, .title, author: .ai, reason: "Names the job.", minutesAgo: 3)
        let rule = revision(on: task, .dueDate, author: .rule, reason: nil, minutesAgo: 2)
        let user = revision(on: task, .duration, author: .user, reason: nil, minutesAgo: 1)

        XCTAssertNil(RevisionService.lastClaudeChange(on: task))
        XCTAssertFalse(RevisionService.isByClaude(ai))
        XCTAssertFalse(RevisionService.isByClaude(rule))
        XCTAssertFalse(RevisionService.isByClaude(user))
    }

    func testTheMarkNeedsUserAndReasonClaude() throws {
        let store = try TestStore()
        let task = try task(in: store)
        let siri = revision(on: task, author: .user, reason: "Siri", minutesAgo: 2)
        let aiNamedClaude = revision(on: task, .title, author: .ai, reason: OrderExecutor.reason, minutesAgo: 1)

        XCTAssertFalse(RevisionService.isByClaude(siri))
        XCTAssertFalse(RevisionService.isByClaude(aiNamedClaude))
        XCTAssertNil(RevisionService.lastClaudeChange(on: task))
    }

    // MARK: AC-9

    func testUnseenBadgeIgnoresClaude() throws {
        let store = try TestStore()
        let task = try task(in: store)
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: now, hasTime: false)
        _ = try OrderExecutor.execute(order, in: store.context, now: now, calendar: .current)
        task.title = "Zahnarzt: anrufen"
        task.titleSourceRaw = FieldSource.ai.rawValue
        revision(on: task, .title, author: .ai, reason: "Names the job.", minutesAgo: 1)

        XCTAssertNotNil(RevisionService.lastClaudeChange(on: task), "the order left a Claude revision")
        XCTAssertEqual(RevisionService.automaticFields(on: task), [.title])
    }

    // MARK: AC-6

    func testAuthorWordNamesClaude() throws {
        let store = try TestStore()
        let task = try task(in: store)
        let claude = revision(on: task, author: .user, reason: OrderExecutor.reason, minutesAgo: 2)
        let user = revision(on: task, .duration, author: .user, reason: nil, minutesAgo: 1)
        let ai = revision(on: task, .title, author: .ai, reason: "Names the job.", minutesAgo: 1)

        XCTAssertEqual(FieldFormatting.author(of: claude), "Claude")
        XCTAssertEqual(FieldFormatting.author(of: user), FieldFormatting.author(.user))
        XCTAssertEqual(FieldFormatting.author(of: ai), FieldFormatting.author(.ai))
    }
}
