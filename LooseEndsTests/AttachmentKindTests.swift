import Foundation
import Testing
@testable import LooseEnds

/// How an attachment shows and what it may weigh (#442).
@Suite("Attachment kind") struct AttachmentKindTests {
    @Test("Photos, PDFs and other documents get their symbol")
    func symbols() {
        #expect(AttachmentKind.symbol(for: "public.jpeg") == "photo")
        #expect(AttachmentKind.symbol(for: "public.heic") == "photo")
        #expect(AttachmentKind.symbol(for: "com.adobe.pdf") == "doc.richtext")
        #expect(AttachmentKind.symbol(for: "public.plain-text") == "doc")
        #expect(AttachmentKind.symbol(for: "not a type") == "doc")
    }

    @Test("Up to 50 MB fits, more does not")
    func size() {
        #expect(AttachmentKind.fits(Data(count: 10)))
        #expect(AttachmentKind.fits(Data(count: AttachmentKind.maximumBytes)))
        #expect(!AttachmentKind.fits(Data(count: AttachmentKind.maximumBytes + 1)))
    }
}
