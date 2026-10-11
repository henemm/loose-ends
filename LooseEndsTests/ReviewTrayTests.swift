import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("New as the review tray (#188)") struct ReviewTrayTests {
    @Test("Unsorted and unchecked tasks need a look; sorted ones only a nod")
    @MainActor func needsLook() async throws {
        let store = try TestStore()
        let unsorted = TaskItem(rawText: "Dachrinne")
        let unchecked = TaskItem(rawText: "zahnarzt termin")
        unchecked.status = .unverified
        let sorted = TaskItem(rawText: "Rasen mähen")
        sorted.status = .active
        [unsorted, unchecked, sorted].forEach(store.context.insert)

        #expect(ViewRules.needsLook(unsorted))
        #expect(ViewRules.needsLook(unchecked))
        #expect(!ViewRules.needsLook(sorted))
        #expect(ViewRules.reviewReason(of: unsorted) == .notSortedYet)
        #expect(ViewRules.reviewReason(of: unchecked) == .titleNotChecked)
    }

    @Test("A title the AI rewrote shows the raw text as the value before")
    @MainActor func titleChanged() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "mähen Rasen")
        task.status = .active
        task.title = "Rasen mähen"
        task.titleSourceRaw = FieldSource.ai.rawValue
        store.context.insert(task)

        #expect(ViewRules.reviewReason(of: task) == .titleChanged(from: "mähen Rasen"))
    }

    @Test("A title the user typed is not reported as the AI's change")
    @MainActor func userTitle() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "mähen Rasen")
        task.status = .active
        task.title = "Rasen mähen"
        task.titleSourceRaw = FieldSource.user.rawValue
        store.context.insert(task)

        #expect(ViewRules.reviewReason(of: task) == .sortedByAI)
    }

    @Test("Looks right marks the AI's changes as seen: the task leaves New, the revision stays")
    @MainActor func looksRight() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Rasen mähen")
        task.status = .active
        store.context.insert(task)
        let revision = Revision(task: task, field: .duration, oldValue: nil, newValue: "15", author: .ai)
        store.context.insert(revision)
        try store.context.save()
        #expect(ViewRules.tasks(for: .new, in: [task]).count == 1)

        _ = RevisionService.markSeen(task)

        #expect(ViewRules.tasks(for: .new, in: [task]).isEmpty)
        #expect((task.revisions ?? []).count == 1)
    }

    @Test("Looks right in the detail takes an unchecked or unsorted task out of New (#318)")
    @MainActor func looksRightFromDetail() async throws {
        let store = try TestStore()
        let unchecked = TaskItem(rawText: "zahnarzt termin")
        unchecked.title = "Zahnarzt Termin"
        unchecked.status = .unverified
        let unsorted = TaskItem(rawText: "Dachrinne")
        unsorted.title = "Dachrinne"
        let untitled = TaskItem(rawText: "…")
        [unchecked, unsorted, untitled].forEach(store.context.insert)
        try store.context.save()
        #expect(ViewRules.tasks(for: .new, in: [unchecked, unsorted, untitled]).count == 3)

        [unchecked, unsorted, untitled].forEach { TaskActions.confirmReview($0) }

        #expect(unchecked.status == .active)
        #expect(unsorted.status == .active)
        #expect(untitled.status == .unprocessed, "no title, nothing to vouch for")
        #expect(ViewRules.tasks(for: .new, in: [unchecked, unsorted, untitled]).map(\.id) == [untitled.id])
    }
}
