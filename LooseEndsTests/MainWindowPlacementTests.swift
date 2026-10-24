import CoreGraphics
import Foundation
import Testing
@testable import LooseEnds

/// The Mac main window opens inside the visible screen (#593): on the 1024 pt CI screen it opened 1200 pt
/// wide in some runs. The rule is platform neutral and tested here; the scene modifier is macOS only.
@Suite("Main window placement (#593)") struct MainWindowPlacementTests {
    @Test("A screen narrower than the wish gets a window as wide as the screen")
    func smallScreenLimitsTheSize() {
        let visible = CGRect(x: 0, y: 31, width: 1024, height: 737)
        let frame = MainWindowPlacement.frame(visible: visible)
        #expect(frame.size == CGSize(width: 1024, height: 737))
    }

    @Test("A large screen keeps 1200 x 780")
    func largeScreenKeepsTheWish() {
        let visible = CGRect(x: 0, y: 38, width: 2056, height: 1291)
        let frame = MainWindowPlacement.frame(visible: visible)
        #expect(frame.size == CGSize(width: 1200, height: 780))
    }

    @Test("The minimum size wins over a screen smaller than it")
    func minimumSizeWins() {
        let visible = CGRect(x: 0, y: 25, width: 700, height: 480)
        let frame = MainWindowPlacement.frame(visible: visible)
        #expect(frame.size == CGSize(width: 760, height: 520))
    }

    @Test("The window is centred in a visible area that does not start at zero")
    func centredInVisibleArea() {
        let visible = CGRect(x: 80, y: 38, width: 1600, height: 1000)
        let frame = MainWindowPlacement.frame(visible: visible)
        #expect(frame.midX == visible.midX)
        #expect(frame.midY == visible.midY)
        #expect(visible.contains(frame))
    }

    @Test("A window as large as the visible area lies exactly on it")
    func fullSizeLiesOnTheArea() {
        let visible = CGRect(x: 0, y: 31, width: 1024, height: 737)
        let frame = MainWindowPlacement.frame(visible: visible)
        #expect(frame == visible)
    }

    @Test("A window larger than the area starts at its top left corner")
    func oversizeStartsTopLeft() {
        let visible = CGRect(x: 10, y: 25, width: 700, height: 480)
        let frame = MainWindowPlacement.frame(visible: visible)
        #expect(frame.origin == visible.origin)
    }
}
