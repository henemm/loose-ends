import Testing
@testable import LooseEnds

/// The marking of the contents index (#476, #583).
@Suite("Contents index") struct ContentsIndexTests {
    @Test("The Start line is marked while no view is open; a view's line only while that view is (#583)")
    @MainActor func startLineMarking() {
        let start = IndexLine(id: "viewRow_start", title: "Start", count: 0, opensStart: true) {}
        let due = IndexLine(id: "viewRow_due", title: "Due", count: 4, target: .system(.due)) {}

        #expect(ContentsIndex.isOpen(start, selected: nil))
        #expect(!ContentsIndex.isOpen(start, selected: .system(.due)))
        #expect(ContentsIndex.isOpen(due, selected: .system(.due)))
        #expect(!ContentsIndex.isOpen(due, selected: nil))
        #expect(!ContentsIndex.isOpen(due, selected: .system(.next)))
    }
}
