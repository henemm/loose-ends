import Foundation
import Testing
@testable import LooseEnds

/// The way back from a task opened by the sidebar's selection (#830).
@Suite("Detail back") struct DetailBackTests {
    private let task = ViewSelection.task(UUID())

    @Test("A task opened from the start page leads back to the start page")
    func fromStart() {
        var back = DetailBack()
        #expect(!back.isOffered)
        back.follow(from: nil, to: task)
        #expect(back.isOffered)
        #expect(back.destination == nil)
    }

    @Test("A task opened while a list was chosen leads back to that list")
    func fromList() {
        var back = DetailBack()
        back.follow(from: .system(.quick), to: task)
        #expect(back.isOffered)
        #expect(back.destination == .system(.quick))
    }

    @Test("Task to task keeps the first origin")
    func taskToTask() {
        var back = DetailBack()
        back.follow(from: .system(.due), to: task)
        back.follow(from: task, to: .task(UUID()))
        #expect(back.destination == .system(.due))
    }

    @Test("Leaving the task forgets the origin")
    func leaving() {
        var back = DetailBack()
        back.follow(from: nil, to: task)
        back.follow(from: task, to: .system(.new))
        #expect(!back.isOffered)
        back.follow(from: .system(.new), to: nil)
        #expect(!back.isOffered)
    }

    @Test("A task that opens while nothing was remembered leads to the start page")
    func taskWithoutOrigin() {
        var back = DetailBack()
        back.follow(from: task, to: .task(UUID()))
        #expect(back.isOffered)
        #expect(back.destination == nil)
    }
}
