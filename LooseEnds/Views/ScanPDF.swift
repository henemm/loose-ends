import CoreGraphics
import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

/// The scanned pages as one PDF (#442): each page a JPEG at the given quality, on a page as large as
/// the image at 150 dpi. JPEG keeps a scan of many pages well under `AttachmentKind.maximumBytes`;
/// Quartz embeds the JPEG as it is. Pure over the images, so the unit test runs on the Mac.
enum ScanPDF {
    static let quality = 0.7
    static let dotsPerInch = 150.0
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    /// `nil` without pages or when a page cannot be encoded.
    static func pdf(from pages: [CGImage], quality: Double = ScanPDF.quality) -> Data? {
        guard !pages.isEmpty else { return nil }
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            logger.error("Creating the scan PDF failed")
            return nil
        }
        for page in pages {
            guard let jpeg = jpeg(page, quality: quality) else { return nil }
            var box = pageBox(for: page)
            context.beginPage(mediaBox: &box)
            context.draw(jpeg, in: box)
            context.endPage()
        }
        context.closePDF()
        return data as Data
    }

    /// The page in points: the image's pixels at `dotsPerInch`.
    static func pageBox(for image: CGImage) -> CGRect {
        let scale = 72 / dotsPerInch
        return CGRect(x: 0, y: 0, width: Double(image.width) * scale, height: Double(image.height) * scale)
    }

    /// "Scan 16.10.26, 14:30.pdf", in the device's format like a photo's name.
    static func fileName(at date: Date, prefix: String) -> String {
        prefix + " " + date.formatted(date: .numeric, time: .shortened) + ".pdf"
    }

    /// The page re-encoded as JPEG and read back, so the PDF carries the compressed bytes.
    private static func jpeg(_ image: CGImage, quality: Double) -> CGImage? {
        let encoded = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            encoded as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination),
              let provider = CGDataProvider(data: encoded as CFData),
              let decoded = CGImage(jpegDataProviderSource: provider, decode: nil, shouldInterpolate: true,
                                    intent: .defaultIntent) else {
            logger.error("Encoding a scanned page failed")
            return nil
        }
        return decoded
    }
}
