import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The star with the place in "Next up" at the end of a row (#509).
@Suite("Next up rank") struct NextRankTests {
    @MainActor private func task(_ text: String, rank: Double?, status: TaskStatus = .active, store: TestStore) -> TaskItem {
        let item = TaskItem(rawText: text)
        item.status = status
        item.nextRank = rank
        store.context.insert(item)
        return item
    }

    @Test("Ranks count 1, 2, 3 in the order of Next up; a task without a rank gets none")
    @MainActor func ranksFollowTheOrder() throws {
        let store = try TestStore()
        let third = task("Dritte", rank: 30, store: store)
        let first = task("Erste", rank: 10, store: store)
        let second = task("Zweite", rank: 20, store: store)
        let none = task("Ohne", rank: nil, store: store)
        let ranks = ViewRules.nextRanks(in: [third, first, second, none])
        #expect(ranks[first.id] == 1)
        #expect(ranks[second.id] == 2)
        #expect(ranks[third.id] == 3)
        #expect(ranks[none.id] == nil)
    }

    @Test("Blocked, done and parked tasks take no place; a lined up subtask takes its own")
    @MainActor func onlyWhatShowsInNextUp() throws {
        let store = try TestStore()
        let first = task("Erste", rank: 10, store: store)
        let blocker = task("Blocker", rank: nil, store: store)
        let blocked = task("Wartet", rank: 15, store: store)
        blocked.blockedBy = [blocker]
        let done = task("Fertig", rank: 12, status: .done, store: store)
        let parked = task("Geparkt", rank: 13, status: .parked, store: store)
        let parent = task("Eltern", rank: nil, store: store)
        let sub = task("Unter", rank: 14, store: store)
        sub.parent = parent
        let last = task("Letzte", rank: 20, store: store)
        let ranks = ViewRules.nextRanks(in: [first, blocker, blocked, done, parked, parent, sub, last])
        #expect(ranks[first.id] == 1)
        #expect(ranks[sub.id] == 2, "a subtask lined up as next stands in Next up like a task (Henning, 2026-10-27)")
        #expect(ranks[last.id] == 3)
        #expect(ranks[blocked.id] == nil)
        #expect(ranks[done.id] == nil)
        #expect(ranks[parked.id] == nil)
    }
}
