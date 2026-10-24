import CoreGraphics
import Foundation

/// Where the Mac main window opens (#593): `.defaultSize` is only a wish, and on the 1024 pt CI screen the
/// window opened 1200 pt wide in some runs. Platform neutral so the simulator tests can check the rule; the
/// scene modifier that uses it is macOS only. Origin is the window's top left corner, y grows downward.
enum MainWindowPlacement {
    /// The start page with its right column needs about 1120 pt (#473, #514).
    static let preferredSize = CGSize(width: 1200, height: 780)
    /// Sidebar 220 + a 540 pt page (#480).
    static let minimumSize = CGSize(width: 760, height: 520)

    /// Per axis the wish limited to the visible area, never below the minimum; centred in the area, and
    /// from its top left corner on an axis where the minimum does not fit.
    static func frame(
        visible: CGRect, preferred: CGSize = preferredSize, minimum: CGSize = minimumSize
    ) -> CGRect {
        let width = max(minimum.width, min(preferred.width, visible.width))
        let height = max(minimum.height, min(preferred.height, visible.height))
        let x = width > visible.width ? visible.minX : visible.midX - width / 2
        let y = height > visible.height ? visible.minY : visible.midY - height / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
