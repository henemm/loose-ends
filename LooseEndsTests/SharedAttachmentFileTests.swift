import Foundation
import Testing
@testable import LooseEnds

/// The share extension's file handling (#442 Schnitt 2): which type is an attachment, copying out of the
/// handler's short-lived file, the 50 MB rule and cleaning up. Real files in a temp folder, no `NSItemProvider`.
@Suite("Shared attachment file") struct SharedAttachmentFileTests {
    private let date = Date(timeIntervalSince1970: 1_792_000_000)

    private func write(_ text: String, named name: String, in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data(text.utf8).write(to: url)
        return url
    }

    @Test("A photo or file type is an attachment; text, links and mail are not")
    func typeChoice() {
        #expect(SharedAttachmentFile.attachmentType(registered: ["public.jpeg", "public.image"]) == "public.jpeg")
        #expect(SharedAttachmentFile.attachmentType(registered: ["com.adobe.pdf", "public.file-url"]) == "com.adobe.pdf")
        #expect(SharedAttachmentFile.attachmentType(registered: ["public.plain-text"]) == nil)
        #expect(SharedAttachmentFile.attachmentType(registered: ["public.url"]) == nil)
        #expect(SharedAttachmentFile.attachmentType(registered: ["public.file-url"]) == nil)
        #expect(SharedAttachmentFile.attachmentType(registered: ["public.email-message"]) == nil)
        #expect(SharedAttachmentFile.attachmentType(registered: []) == nil)
    }

    @Test("Adopting copies the file, keeps name, type and size, and never overwrites a namesake")
    func copies() throws {
        let source = try SharedAttachmentFile.makeDirectory()
        let otherSource = try SharedAttachmentFile.makeDirectory()
        let target = try SharedAttachmentFile.makeDirectory()
        defer {
            SharedAttachmentFile.remove(source)
            SharedAttachmentFile.remove(otherSource)
            SharedAttachmentFile.remove(target)
        }
        let first = try write("eins", named: "Rechnung.pdf", in: source)
        let second = try write("zwei!", named: "Rechnung.pdf", in: otherSource)

        let a = try SharedAttachmentFile.adopt(first, typeIdentifier: "com.adobe.pdf", suggestedName: "Rechnung.pdf",
                                               into: target, at: date, photoPrefix: "Photo")
        let b = try SharedAttachmentFile.adopt(second, typeIdentifier: "com.adobe.pdf", suggestedName: "Rechnung.pdf",
                                               into: target, at: date, photoPrefix: "Photo")

        #expect(a.fileName == "Rechnung.pdf")
        #expect(a.typeIdentifier == "com.adobe.pdf")
        #expect(a.byteCount == 4)
        #expect(a.fileURL != first)
        #expect(a.fileURL.path.hasPrefix(target.path))
        #expect(try String(contentsOf: a.fileURL, encoding: .utf8) == "eins")
        #expect(b.byteCount == 5)
        #expect(b.fileURL != a.fileURL)
        #expect(try String(contentsOf: b.fileURL, encoding: .utf8) == "zwei!")
    }

    @Test("The name is the suggested one, else the source's, else a photo name or File")
    func names() {
        let stamp = date.formatted(date: .numeric, time: .shortened)
        func name(_ suggested: String?, _ source: String, _ type: String) -> String {
            SharedAttachmentFile.fileName(suggested: suggested, sourceName: source, typeIdentifier: type,
                                          at: date, photoPrefix: "Photo")
        }
        #expect(name("IMG_4821.heic", "x.tmp", "public.heic") == "IMG_4821.heic")
        #expect(name(nil, "scan.pdf", "com.adobe.pdf") == "scan.pdf")
        #expect(name("  ", "scan.pdf", "com.adobe.pdf") == "scan.pdf")
        #expect(name(nil, "", "public.heic") == "Photo \(stamp).heic")
        #expect(name(nil, "", "com.adobe.pdf") == "File")
    }

    @Test("A file over 50 MB is not copied; it is reported with its real size and classified too large")
    func tooLarge() throws {
        let source = try SharedAttachmentFile.makeDirectory()
        let target = try SharedAttachmentFile.makeDirectory()
        defer {
            SharedAttachmentFile.remove(source)
            SharedAttachmentFile.remove(target)
        }
        let big = source.appendingPathComponent("Film.mov")
        FileManager.default.createFile(atPath: big.path, contents: nil)
        let handle = try FileHandle(forWritingTo: big)
        try handle.truncate(atOffset: UInt64(AttachmentKind.maximumBytes + 1))
        try handle.close()

        let adopted = try SharedAttachmentFile.adopt(big, typeIdentifier: "com.apple.quicktime-movie",
                                                     suggestedName: "Film.mov", into: target, at: date, photoPrefix: "Photo")

        #expect(adopted.byteCount == AttachmentKind.maximumBytes + 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: target.path).isEmpty)
        #expect(SharedAttachment.classify([adopted]).first?.status == .tooLarge)
    }

    @Test("A missing source throws")
    func missingSource() throws {
        let target = try SharedAttachmentFile.makeDirectory()
        defer { SharedAttachmentFile.remove(target) }
        let gone = URL(fileURLWithPath: "/tmp/does-not-exist-\(UUID().uuidString).pdf")
        #expect(throws: (any Error).self) {
            try SharedAttachmentFile.adopt(gone, typeIdentifier: "com.adobe.pdf", suggestedName: "a.pdf",
                                           into: target, at: date, photoPrefix: "Photo")
        }
    }

    @Test("The folder starts empty, remove deletes it with its content and a second remove does not throw")
    func cleanUp() throws {
        let folder = try SharedAttachmentFile.makeDirectory()
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        _ = try write("x", named: "a.txt", in: folder)
        SharedAttachmentFile.remove(folder)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
        SharedAttachmentFile.remove(folder)
    }
}
