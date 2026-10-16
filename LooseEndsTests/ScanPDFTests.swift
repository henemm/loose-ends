import CoreGraphics
import Foundation
import Testing
@testable import LooseEnds

/// Scanned pages become one PDF attachment (#442).
@Suite("Scan PDF") struct ScanPDFTests {
    /// A grey page of the given pixels.
    static func page(width: Int, height: Int) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(gray: 0.8, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    @Test("Every page becomes a PDF page sized at 150 dpi")
    func pages() throws {
        let data = try #require(ScanPDF.pdf(from: [Self.page(width: 1240, height: 1754), Self.page(width: 300, height: 150)]))
        let document = try #require(CGPDFDocument(CGDataProvider(data: data as CFData)!))
        #expect(document.numberOfPages == 2)
        let first = try #require(document.page(at: 1)).getBoxRect(.mediaBox)
        #expect(abs(first.width - 595.2) < 0.1)
        #expect(abs(first.height - 841.92) < 0.1)
        #expect(AttachmentKind.fits(data))
    }

    @Test("No pages, no PDF")
    func empty() {
        #expect(ScanPDF.pdf(from: []) == nil)
    }

    @Test("The name says scan and ends in .pdf")
    func name() {
        let name = ScanPDF.fileName(at: Date(timeIntervalSince1970: 0), prefix: "Scan")
        #expect(name.hasPrefix("Scan "))
        #expect(name.hasSuffix(".pdf"))
    }
}
