import Foundation
import Testing
@testable import LooseEnds

/// #480 Schnitt 1: which key does what on the list's rows. The table lives in
/// `docs/specs/feat-480-schnitt-1-liste.md`; every row of it is a case here.
@Suite struct RowKeyActionTests {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()
    private var ids: [UUID] { [a, b, c] }

    private let allKeys: [RowKey] = [.up, .down, .space, .delete]

    // MARK: - Nothing happens

    @Test func textFocusIgnoresEveryKey() {
        for key in allKeys {
            #expect(RowKeyAction.resolve(key, textFocused: true, selection: b, ids: ids) == .ignore)
        }
    }

    @Test func emptyListIgnoresEveryKey() {
        for key in allKeys {
            #expect(RowKeyAction.resolve(key, textFocused: false, selection: nil, ids: []) == .ignore)
            #expect(RowKeyAction.resolve(key, textFocused: false, selection: a, ids: []) == .ignore)
        }
    }

    @Test func spaceAndDeleteNeedASelection() {
        #expect(RowKeyAction.resolve(.space, textFocused: false, selection: nil, ids: ids) == .ignore)
        #expect(RowKeyAction.resolve(.delete, textFocused: false, selection: nil, ids: ids) == .ignore)
    }

    @Test func aSelectionNoLongerInTheListCountsAsNone() {
        let gone = UUID()
        #expect(RowKeyAction.resolve(.space, textFocused: false, selection: gone, ids: ids) == .ignore)
        #expect(RowKeyAction.resolve(.delete, textFocused: false, selection: gone, ids: ids) == .ignore)
        #expect(RowKeyAction.resolve(.down, textFocused: false, selection: gone, ids: ids) == .select(a))
        #expect(RowKeyAction.resolve(.up, textFocused: false, selection: gone, ids: ids) == .select(c))
    }

    // MARK: - Moving

    @Test func downWithoutSelectionTakesTheFirstRow() {
        #expect(RowKeyAction.resolve(.down, textFocused: false, selection: nil, ids: ids) == .select(a))
    }

    @Test func upWithoutSelectionTakesTheLastRow() {
        #expect(RowKeyAction.resolve(.up, textFocused: false, selection: nil, ids: ids) == .select(c))
    }

    @Test func arrowsStepInTheMiddle() {
        #expect(RowKeyAction.resolve(.down, textFocused: false, selection: b, ids: ids) == .select(c))
        #expect(RowKeyAction.resolve(.up, textFocused: false, selection: b, ids: ids) == .select(a))
    }

    @Test func selectionStaysAtTheEdges() {
        #expect(RowKeyAction.resolve(.down, textFocused: false, selection: c, ids: ids) == .select(c))
        #expect(RowKeyAction.resolve(.up, textFocused: false, selection: a, ids: ids) == .select(a))
    }

    @Test func aSingleRowIsBothEdges() {
        #expect(RowKeyAction.resolve(.down, textFocused: false, selection: a, ids: [a]) == .select(a))
        #expect(RowKeyAction.resolve(.up, textFocused: false, selection: a, ids: [a]) == .select(a))
    }

    // MARK: - Doing

    @Test func spaceCompletesTheSelectedRow() {
        for selected in ids {
            #expect(RowKeyAction.resolve(.space, textFocused: false, selection: selected, ids: ids) == .complete(selected))
        }
    }

    @Test func deleteAsksAboutTheSelectedRow() {
        for selected in ids {
            #expect(RowKeyAction.resolve(.delete, textFocused: false, selection: selected, ids: ids) == .delete(selected))
        }
    }
}
