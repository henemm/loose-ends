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

    @Test("The detail's Looks right (#349): sorted and unchecked tasks can be confirmed, unsorted ones cannot")
    @MainActor func canConfirm() async throws {
        let store = try TestStore()
        let unsorted = TaskItem(rawText: "Dachrinne")
        let unchecked = TaskItem(rawText: "zahnarzt termin")
        unchecked.status = .unverified
        unchecked.title = "Zahnarzt Termin"
        let untitled = TaskItem(rawText: "ähm")
        untitled.status = .unverified
        let sorted = TaskItem(rawText: "Rasen mähen")
        sorted.status = .active
        let seen = TaskItem(rawText: "Müll raus")
        seen.status = .active
        [unsorted, unchecked, untitled, sorted, seen].forEach(store.context.insert)
        store.context.insert(Revision(task: sorted, field: .duration, oldValue: nil, newValue: "15", author: .rule))
        try store.context.save()

        #expect(!ViewRules.canConfirm(unsorted), "nothing to confirm, and confirming would stop the sorting")
        #expect(ViewRules.canConfirm(unchecked))
        #expect(!ViewRules.canConfirm(untitled), "no title to vouch for")
        #expect(ViewRules.canConfirm(sorted))
        #expect(!ViewRules.isInNew(seen))
        #expect(!ViewRules.canConfirm(seen), "not in New")
    }

    @Test("Confirming an unchecked title vouches for it: the task leaves New, the revisions stay")
    @MainActor func confirmUnchecked() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "zahnarzt termin")
        task.status = .unverified
        task.title = "Zahnarzt Termin"
        store.context.insert(task)
        store.context.insert(Revision(task: task, field: .contexts, oldValue: nil, newValue: "Telefon", author: .rule))
        try store.context.save()
        #expect(ViewRules.isInNew(task))

        TaskActions.confirmReview(task)

        #expect(task.status == .active)
        #expect(!ViewRules.isInNew(task))
        #expect(ViewRules.tasks(for: .new, in: [task]).isEmpty)
        #expect((task.revisions ?? []).count == 1)
    }

    @Test("Confirming leaves an unsorted task to the sorting")
    @MainActor func confirmUnsorted() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Dachrinne")
        store.context.insert(task)

        TaskActions.confirmReview(task)

        #expect(task.status == .unprocessed)
        #expect(ViewRules.isInNew(task))
    }

    @Test("New lists exactly the tasks isInNew accepts; subtasks stay out")
    @MainActor func newMatchesIsInNew() async throws {
        let store = try TestStore()
        let parent = TaskItem(rawText: "Umzug")
        parent.status = .active
        let child = TaskItem(rawText: "Kartons")
        child.parent = parent
        let done = TaskItem(rawText: "erledigt")
        done.status = .done
        let fresh = TaskItem(rawText: "Dachrinne")
        [parent, child, done, fresh].forEach(store.context.insert)
        try store.context.save()

        let all = [parent, child, done, fresh]
        #expect(Set(ViewRules.tasks(for: .new, in: all).map(\.id)) == Set(all.filter(ViewRules.isInNew).map(\.id)))
        #expect(ViewRules.tasks(for: .new, in: all).map(\.id) == [fresh.id])
        #expect(!ViewRules.isInNew(child))
    }
}
