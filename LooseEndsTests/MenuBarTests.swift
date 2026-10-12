#if os(macOS)
import Testing
@testable import LooseEnds

/// Mac menu bar (#356): the Dock icon only while a window of the list is open.
@Suite("Menüleiste: Dock-Symbol (#356)")
struct MenuBarTests {
    @Test("Ohne offenes Fenster kein Dock-Symbol, mit Fenster wieder da")
    func dockFollowsWindows() {
        #expect(!DockPolicy.showsDockIcon(openMainWindows: 0))
        #expect(DockPolicy.showsDockIcon(openMainWindows: 1))
        #expect(DockPolicy.showsDockIcon(openMainWindows: 3))
    }
}
#endif
