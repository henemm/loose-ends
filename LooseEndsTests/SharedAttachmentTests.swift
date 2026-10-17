import Foundation
import Testing
@testable import LooseEnds

/// A shared photo or file before it is saved (#399): title, photo name, size and count.
@Suite("Shared attachment") struct SharedAttachmentTests {
    private func attachment(_ name: String, bytes: Int = 10, type: String = "com.adobe.pdf") -> SharedAttachment {
        SharedAttachment(
            fileURL: URL(fileURLWithPath: "/tmp/\(name)"),
            fileName: name,
            typeIdentifier: type,
            byteCount: bytes,
            status: .ready
        )
    }

    @Test("A file name becomes a readable title without its extension")
    func title() {
        #expect(SharedAttachment.title(fromFileName: "Befund_Dr-Meier.pdf") == "Befund Dr Meier")
        #expect(SharedAttachment.title(fromFileName: "a__b - c.pdf") == "a b c")
        #expect(SharedAttachment.title(fromFileName: "  Rechnung 2026 .pdf") == "Rechnung 2026")
        #expect(SharedAttachment.title(fromFileName: ".pdf") == "")
        #expect(SharedAttachment.title(fromFileName: "___.pdf") == "")
    }

    @Test("A photo is named like one added in the detail: prefix, date and time, the type's extension")
    func photoName() {
        let date = Date(timeIntervalSince1970: 1_792_000_000)
        let stamp = date.formatted(date: .numeric, time: .shortened)
        #expect(SharedAttachment.photoFileName(typeIdentifier: "public.heic", at: date, prefix: "Photo") == "Photo \(stamp).heic")
        #expect(SharedAttachment.photoFileName(typeIdentifier: "not a type", at: date, prefix: "Photo") == "Photo \(stamp).jpg")
        #expect(SharedAttachment.photoFileName(typeIdentifier: "public.jpeg", at: date).hasPrefix("Photo "))
    }

    @Test("Up to 50 MB is ready, more is too large and takes none of the ten places")
    func size() {
        let input = [
            attachment("a.pdf", bytes: AttachmentKind.maximumBytes),
            attachment("b.pdf", bytes: AttachmentKind.maximumBytes + 1),
            attachment("c.pdf", bytes: 1),
        ]
        let result = SharedAttachment.classify(input)
        #expect(result.map(\.status) == [.ready, .tooLarge, .ready])
        #expect(result.map(\.fileName) == ["a.pdf", "b.pdf", "c.pdf"])

        let crowded = (1...10).map { attachment("\($0).pdf") } + [attachment("big.pdf", bytes: AttachmentKind.maximumBytes + 1)]
        #expect(SharedAttachment.classify(crowded).last?.status == .tooLarge, "too large wins over the count")
        let withBigFirst = [attachment("big.pdf", bytes: AttachmentKind.maximumBytes + 1)] + (1...10).map { attachment("\($0).pdf") }
        #expect(SharedAttachment.classify(withBigFirst).filter { $0.status == .ready }.count == 10)
    }

    @Test("Ten are attached, the eleventh and twelfth are over the limit, order is kept")
    func limit() {
        let input = (1...12).map { attachment("\($0).pdf") }
        let result = SharedAttachment.classify(input)
        #expect(SharedAttachment.maximumCount == 10)
        #expect(result.prefix(10).allSatisfy { $0.status == .ready })
        #expect(result.suffix(2).map(\.status) == [.overLimit, .overLimit])
        #expect(result.map(\.fileName) == input.map(\.fileName))
    }

    @Test("Size check by byte count matches the check by data")
    func fitsByteCount() {
        #expect(AttachmentKind.fits(byteCount: AttachmentKind.maximumBytes))
        #expect(!AttachmentKind.fits(byteCount: AttachmentKind.maximumBytes + 1))
    }
}
