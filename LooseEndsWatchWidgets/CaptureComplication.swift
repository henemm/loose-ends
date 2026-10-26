import SwiftUI
import WidgetKit
// In the test target ThreadShape comes from the app module (internal, hence @testable); in the watch
// widget target it is compiled in from LooseEnds/Views/Thread.swift (#355).
#if canImport(LooseEnds)
@testable import LooseEnds
#endif

struct CaptureComplicationEntry: TimelineEntry {
    let date: Date
}

/// Nothing on the complication changes: one entry, never reloaded.
struct CaptureComplicationProvider: TimelineProvider {
    static func timeline() -> Timeline<CaptureComplicationEntry> {
        Timeline(entries: [CaptureComplicationEntry(date: .now)], policy: .never)
    }

    func placeholder(in context: Context) -> CaptureComplicationEntry {
        CaptureComplicationEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (CaptureComplicationEntry) -> Void) {
        completion(CaptureComplicationEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaptureComplicationEntry>) -> Void) {
        completion(Self.timeline())
    }
}

/// The logo's knot on the watch face (#355). Tapping it opens the watch app, whose only scene is capture.
struct CaptureComplicationView: View {
    enum Face: Sendable {
        case circular, corner
    }

    let face: Face

    var body: some View {
        ZStack {
            if face == .circular {
                AccessoryWidgetBackground()
            }
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                ThreadShape(form: .knot)
                    .stroke(style: StrokeStyle(lineWidth: side * 0.09, lineCap: .round, lineJoin: .round))
                    .padding(side * 0.2)
            }
            .widgetAccentable()
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Capture")
        .modifier(CornerLabel(face: face))
    }
}

/// The corner face carries its name along the bezel; the label exists on watchOS only.
private struct CornerLabel: ViewModifier {
    let face: CaptureComplicationView.Face

    func body(content: Content) -> some View {
        #if os(watchOS)
        if face == .corner {
            content.widgetLabel("Capture")
        } else {
            content
        }
        #else
        content
        #endif
    }
}

#if os(watchOS)
/// Reads the family the system shows and hands it on, so the view itself stays testable on iOS.
private struct CaptureComplicationFamilyView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        CaptureComplicationView(face: family == .accessoryCorner ? .corner : .circular)
            .containerBackground(.clear, for: .widget)
            // The app opens on "Now"; the complication goes to capture (#699). Same link as
            // `NextUpWidgetActions.captureURL`, which this target cannot see (no `Shared/`).
            .widgetURL(URL(string: "looseends://capture"))
    }
}

struct CaptureComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CaptureComplication", provider: CaptureComplicationProvider()) { _ in
            CaptureComplicationFamilyView()
        }
        .configurationDisplayName("Capture")
        .description("Opens capture.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}
#endif
