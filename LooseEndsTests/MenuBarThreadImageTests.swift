import CoreGraphics
import Foundation
import Testing
@testable import LooseEnds

/// The menu bar symbol is the logo's knot (#366). The Template wrapper (`NSImage`) is macOS only and
/// proven by the Mac test build; what is drawn is platform neutral and tested here.
@Suite("Menu bar thread (#366)") struct MenuBarThreadImageTests {
    /// RGBA, premultiplied, row 0 = top of the image.
    private struct Pixels {
        let width: Int
        let height: Int
        let data: [UInt8]

        init(_ image: CGImage) throws {
            let width = image.width, height = image.height
            self.width = width
            self.height = height
            var buffer = [UInt8](repeating: 0, count: width * height * 4)
            let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
                guard let context = CGContext(
                    data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            try #require(drawn, "no bitmap context")
            data = buffer
        }

        func alpha(x: Int, y: Int) -> UInt8 {
            guard x >= 0, x < width, y >= 0, y < height else { return 0 }
            return data[(y * width + x) * 4 + 3]
        }

        func rgb(x: Int, y: Int) -> (UInt8, UInt8, UInt8) {
            let i = (y * width + x) * 4
            return (data[i], data[i + 1], data[i + 2])
        }
    }

    @Test("The shared curve has 121 points and starts and ends on the logo's formula")
    func curvePointsMatchFormula() throws {
        let points = ThreadShape.curvePoints(form: .knot)
        #expect(points.count == 121)
        let first = try #require(points.first), last = try #require(points.last)
        #expect(abs(first.x - (90 * -3.5 - 230 * sin(-3.5))) < 1e-9)
        #expect(abs(first.y - (-230 * cos(-3.5))) < 1e-9)
        #expect(abs(last.x - (90 * 3.0 - 230 * sin(3.0))) < 1e-9)
        #expect(abs(last.y - (-230 * cos(3.0))) < 1e-9)
    }

    @Test("The raster is 18 px high at 1x and 36 px at 2x")
    func rasterSize() throws {
        let one = try #require(MenuBarThreadRaster.cgImage(scale: 1))
        let two = try #require(MenuBarThreadRaster.cgImage(scale: 2))
        #expect(one.height == 18)
        #expect(two.height == 36)
        #expect(one.width > 0 && two.width > 0)
        // 2x is the same drawing, twice as large (±1 px rounding).
        #expect(abs(two.width - 2 * one.width) <= 2)
    }

    @Test("At 2x something is drawn, and a corner stays transparent")
    func rasterIsNotEmpty() throws {
        let pixels = try Pixels(#require(MenuBarThreadRaster.cgImage(scale: 2)))
        let drawn = (0..<pixels.height).flatMap { y in (0..<pixels.width).map { x in (x, y) } }
            .filter { pixels.alpha(x: $0.0, y: $0.1) > 0 }
        #expect(drawn.count > 20)
        #expect(pixels.alpha(x: 0, y: 0) == 0)
        #expect(pixels.alpha(x: pixels.width - 1, y: pixels.height - 1) == 0)
    }

    @Test("Every drawn pixel is black: the precondition of a Template image", arguments: [1, 2])
    func rasterIsBlackOnTransparent(scale: Int) throws {
        let pixels = try Pixels(#require(MenuBarThreadRaster.cgImage(scale: scale)))
        for y in 0..<pixels.height {
            for x in 0..<pixels.width where pixels.alpha(x: x, y: y) > 0 {
                let (r, g, b) = pixels.rgb(x: x, y: y)
                #expect(r == 0 && g == 0 && b == 0, "pixel \(x),\(y) is not black")
            }
        }
    }

    @Test("At 2x the knot's loop stays open: its middle is transparent, its ring is drawn")
    func crossingGapExistsAt2x() throws {
        let points = ThreadShape.curvePoints(form: .knot)
        let loop = try #require(Self.loop(in: points), "the knot curve has no self-crossing")
        let pixels = try Pixels(#require(MenuBarThreadRaster.cgImage(scale: 2)))

        let center = MenuBarThreadRaster.pixelPosition(of: loop.center, scale: 2)
        // The loop's free disc is ~4.2 px; 3.5 px keeps a margin for anti-aliasing at the stroke edge
        // while still failing as soon as the stroke is much thicker than intended.
        let radius = 3.5
        for y in Int(center.y - radius - 1)...Int(center.y + radius + 1) {
            for x in Int(center.x - radius - 1)...Int(center.x + radius + 1) {
                let dx = Double(x) + 0.5 - Double(center.x), dy = Double(y) + 0.5 - Double(center.y)
                guard (dx * dx + dy * dy).squareRoot() <= radius else { continue }
                #expect(pixels.alpha(x: x, y: y) == 0, "loop middle is closed at (\(x), \(y))")
            }
        }

        let ring = MenuBarThreadRaster.pixelPosition(of: loop.ringPoint, scale: 2)
        #expect(pixels.alpha(x: Int(ring.x.rounded()), y: Int(ring.y.rounded())) > 0, "loop ring is missing")
    }

    /// The closed loop of the polyline: first self-crossing, the polygon between the two passes.
    private static func loop(in points: [CGPoint]) -> (center: CGPoint, ringPoint: CGPoint)? {
        for i in 0..<(points.count - 1) {
            for j in (i + 2)..<(points.count - 1) {
                guard let cross = intersection(points[i], points[i + 1], points[j], points[j + 1]) else { continue }
                let ring = [cross] + Array(points[(i + 1)...j]) + [cross]
                let center = CGPoint(
                    x: ring.map(\.x).reduce(0, +) / CGFloat(ring.count),
                    y: ring.map(\.y).reduce(0, +) / CGFloat(ring.count)
                )
                return (center, ring[ring.count / 2])
            }
        }
        return nil
    }

    private static func intersection(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGPoint? {
        let r = CGPoint(x: b.x - a.x, y: b.y - a.y), s = CGPoint(x: d.x - c.x, y: d.y - c.y)
        let denominator = r.x * s.y - r.y * s.x
        guard abs(denominator) > 1e-12 else { return nil }
        let t = ((c.x - a.x) * s.y - (c.y - a.y) * s.x) / denominator
        let u = ((c.x - a.x) * r.y - (c.y - a.y) * r.x) / denominator
        guard (0...1).contains(t), (0...1).contains(u) else { return nil }
        return CGPoint(x: a.x + t * r.x, y: a.y + t * r.y)
    }
}
