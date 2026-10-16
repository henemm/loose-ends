import SwiftUI

/// The sizes of the iPhone start screen, taken from the draft ("Startseite: drei Alternativen",
/// #421/#426) in points at the standard text size (Henning, 2026-10-16: the app looked unlike the
/// draft). They grow with Dynamic Type at half the system's rate: at the standard size the screen
/// is the draft, at Henning's "xxLarge" (body 21 instead of 17 pt) it grows 12 % instead of 24 %,
/// and the accessibility sizes still get larger text.
struct StartMetrics: Equatable, Sendable {
    let factor: CGFloat

    init(_ size: DynamicTypeSize) {
        factor = Self.factor(for: size)
    }

    /// Half the system's growth of body text, measured from the standard size ("Large", 17 pt).
    static func factor(for size: DynamicTypeSize) -> CGFloat {
        1 + (bodyPoints(size) / 17 - 1) / 2
    }

    /// Body text per Dynamic Type size, as iOS sets it.
    static func bodyPoints(_ size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall: 14
        case .small: 15
        case .medium: 16
        case .large: 17
        case .xLarge: 19
        case .xxLarge: 21
        case .xxxLarge: 23
        case .accessibility1: 28
        case .accessibility2: 33
        case .accessibility3: 40
        case .accessibility4: 47
        case .accessibility5: 53
        @unknown default: 17
        }
    }

    func callAsFunction(_ points: CGFloat) -> CGFloat { (points * factor).rounded() }

    // The draft's type, in points at the standard size.
    var headline: Font { .system(size: self(30), weight: .medium, design: .serif) }
    var caption: Font { .system(size: self(11), weight: .semibold) }
    /// 0.12 em of the 11 pt caption.
    var captionTracking: CGFloat { self(11) * 0.12 }
    var inbox: Font { .system(size: self(15), weight: .semibold) }
    var indexLine: Font { .system(size: self(19), design: .serif) }
    var indexCount: Font { .system(size: self(14)).monospacedDigit() }
    var word: Font { .system(size: self(16), design: .serif) }
    var wordCount: Font { .system(size: self(12)).monospacedDigit() }
    var rowTitle: Font { .system(size: self(18), design: .serif) }
    var rowMeta: Font { .system(size: self(12.5)) }
    var margin: Font { .system(size: self(12), weight: .medium).monospacedDigit() }

    // The draft's space.
    /// Left and right edge of the screen's content.
    var edge: CGFloat { 20 }
    var marginWidth: CGFloat { self(52) }
}

extension EnvironmentValues {
    /// Set on the start screen's rows only, so a list opened from there keeps the system sizes.
    @Entry var startMetrics: StartMetrics?
}

extension View {
    /// A start screen row: no list inset above or below, the draft's edges at the sides; the row sets
    /// its own space, so the gaps are the draft's and not the list's (#463).
    func startRow(_ metrics: StartMetrics) -> some View {
        listRowInsets(EdgeInsets(top: 0, leading: metrics.edge, bottom: 0, trailing: metrics.edge))
    }
}
