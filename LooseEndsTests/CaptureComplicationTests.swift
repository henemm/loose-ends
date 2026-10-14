import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import Testing
import UniformTypeIdentifiers
import WidgetKit
@testable import LooseEnds

/// The watch complication draws the logo's knot (#355). Rendered here on iOS: the simulator cannot put a
/// complication on a watch face, so what it draws is proven by pixels, what tapping does by the watch.
@MainActor @Suite("Watch complication (#355)") struct CaptureComplicationTests {
    /// Bright pixels of a rendering in white on black: the knot, not the dim accessory background.
    private struct Bright {
        let width: Int
        let height: Int
        let lit: [Bool]

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
                context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
                context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
                return true
            }
            try #require(drawn, "no bitmap context")
            lit = stride(from: 0, to: buffer.count, by: 4).map { i in
                min(buffer[i], buffer[i + 1], buffer[i + 2]) > 200
            }
        }

        var share: Double { Double(lit.filter { $0 }.count) / Double(lit.count) }

        /// True when nothing bright lies within `band` pixels of the edge.
        func edgeIsClear(band: Int) -> Bool {
            for y in 0..<height {
                for x in 0..<width where x < band || y < band || x >= width - band || y >= height - band {
                    if lit[y * width + x] { return false }
                }
            }
            return true
        }
    }

    private func render(_ face: CaptureComplicationView.Face, size: CGSize) throws -> CGImage {
        let view = CaptureComplicationView(face: face)
            .foregroundStyle(.white)
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage, "nothing rendered for \(face)")
        try attach(image, named: "complication-\(face).png")
        return image
    }

    /// The renderings travel with the result bundle, so they can be looked at in acceptance (stage 2).
    private func attach(_ image: CGImage, named name: String) throws {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        try #require(CGImageDestinationFinalize(destination))
        Attachment.record(data as Data, named: name)
    }

    @Test("Round complication: the knot is drawn and stays off the edge")
    func circular() throws {
        let bright = try Bright(render(.circular, size: CGSize(width: 76, height: 76)))
        #expect(bright.share > 0, "nothing bright drawn")
        #expect(bright.edgeIsClear(band: 4), "the knot touches the edge")
    }

    @Test("Corner complication: the knot is drawn and stays off the edge")
    func corner() throws {
        let bright = try Bright(render(.corner, size: CGSize(width: 80, height: 40)))
        #expect(bright.share > 0, "nothing bright drawn")
        #expect(bright.edgeIsClear(band: 4), "the knot touches the edge")
    }

    @Test("At watch size the knot is a readable stroke: neither a hairline nor a blot",
          arguments: [(CaptureComplicationView.Face.circular, CGSize(width: 76, height: 76)), (.corner, CGSize(width: 80, height: 40))])
    func readable(face: CaptureComplicationView.Face, size: CGSize) throws {
        let share = try Bright(render(face, size: size)).share
        #expect(share >= 0.04, "\(face): only \(share) of the face is knot")
        #expect(share <= 0.4, "\(face): \(share) of the face is knot")
    }

    @Test("The provider hands out one entry and never reloads: nothing on it changes")
    func staticTimeline() {
        let timeline = CaptureComplicationProvider.timeline()
        #expect(timeline.entries.count == 1)
        #expect("\(timeline.policy)" == "\(TimelineReloadPolicy.never)")
    }
}
