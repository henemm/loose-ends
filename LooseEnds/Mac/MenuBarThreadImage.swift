import CoreGraphics
import Foundation

/// The menu bar symbol (#366): the logo's knot, black on transparent, drawn from the same curve as
/// `ThreadShape`. Platform neutral so the simulator tests can check what is drawn; only the
/// Template wrapper below is macOS.
enum MenuBarThreadRaster {
    /// Height of the symbol in points (menu bar images are about 18 pt).
    static let pointHeight = 18
    /// Clear space around the thread, in points.
    private static let margin = 1.0
    /// The logo's stroke: 72 on the 1024 grid the curve is defined on (`docs/design/logo/README.md`).
    private static let lineWidth = 72.0

    private static let points = ThreadShape.curvePoints(form: .knot)
    private static let bounds: CGRect = {
        let xs = points.map(\.x), ys = points.map(\.y)
        let minX = xs.min() ?? 0, minY = ys.min() ?? 0
        return CGRect(x: minX, y: minY, width: (xs.max() ?? 1) - minX, height: (ys.max() ?? 1) - minY)
    }()

    /// Curve units per pixel at 1x: the stroked curve fills the height inside the margin.
    private static let unitScale = (Double(pointHeight) - 2 * margin) / (bounds.height + lineWidth)
    /// Width in points, whole so that 2x is exactly twice 1x.
    static let pointWidth = Int(((bounds.width + lineWidth) * unitScale + 2 * margin).rounded(.up))

    /// Where a raw curve point lands in the image at `scale`, row 0 = top (curve y points down).
    static func pixelPosition(of curvePoint: CGPoint, scale: Int) -> CGPoint {
        let factor = unitScale * Double(scale)
        return CGPoint(
            x: Double(pointWidth * scale) / 2 + (curvePoint.x - bounds.midX) * factor,
            y: Double(pointHeight * scale) / 2 + (curvePoint.y - bounds.midY) * factor
        )
    }

    /// The knot at `scale` (1 or 2): RGBA, premultiplied, black on transparent.
    static func cgImage(scale: Int) -> CGImage? {
        let width = pointWidth * scale, height = pointHeight * scale
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // Flip so drawing coordinates are the pixel positions above (row 0 = top).
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.setShouldAntialias(true)
        context.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.setLineWidth(lineWidth * unitScale * Double(scale))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.addLines(between: points.map { pixelPosition(of: $0, scale: scale) })
        context.strokePath()
        return context.makeImage()
    }
}

#if os(macOS)
import AppKit
import OSLog

/// The Template wrapper: the system tints it black in a light menu bar and white in a dark one.
@MainActor
enum MenuBarThreadImage {
    static let image: NSImage = {
        let size = NSSize(width: MenuBarThreadRaster.pointWidth, height: MenuBarThreadRaster.pointHeight)
        let image = NSImage(size: size)
        for scale in [1, 2] {
            guard let cgImage = MenuBarThreadRaster.cgImage(scale: scale) else {
                Logger(subsystem: "com.henning.looseends", category: "MenuBar")
                    .error("Menu bar thread could not be drawn at \(scale)x")
                continue
            }
            let representation = NSBitmapImageRep(cgImage: cgImage)
            representation.size = size
            image.addRepresentation(representation)
        }
        image.isTemplate = true
        return image
    }()
}
#endif
