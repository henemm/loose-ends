import AppIntents
import SwiftUI
import WidgetKit

/// Control Center button: opens the app straight into the capture scene (ADR-9).
struct CaptureControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "Capture") {
            ControlWidgetButton(action: OpenCaptureIntent()) {
                Label("Capture", systemImage: "mic")
            }
        }
        .displayName("Capture")
    }
}
