import SwiftUI
import WidgetKit

/// Own file, so the test target can compile CaptureComplication.swift without a second @main (#355).
@main
struct LooseEndsWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CaptureComplication()
    }
}
