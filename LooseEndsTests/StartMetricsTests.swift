import SwiftUI
import Testing
@testable import LooseEnds

/// The start screen grows with Dynamic Type at half the system's rate (Henning, 2026-10-16, #463).
@Suite("Start metrics") struct StartMetricsTests {
    @Test("At the standard size the draft's points stand as they are")
    func standard() {
        let metrics = StartMetrics(.large)
        #expect(metrics.factor == 1)
        #expect(metrics(30) == 30)
        #expect(metrics(19) == 19)
    }

    @Test("Two steps up grows half as much as body text")
    func xxLarge() {
        // Body 21 instead of 17: the system grows 23.5 %, the start screen 11.8 %.
        let metrics = StartMetrics(.xxLarge)
        #expect(abs(metrics.factor - 1.1176) < 0.001)
        #expect(metrics(30) == 34)
    }

    @Test("Smaller sizes shrink, accessibility sizes still grow")
    func ends() {
        #expect(StartMetrics(.xSmall).factor < 1)
        #expect(StartMetrics(.accessibility5).factor > StartMetrics(.accessibility1).factor)
    }
}
