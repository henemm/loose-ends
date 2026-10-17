import Foundation
import Testing
@testable import LooseEnds

@Suite("SharedContent") struct SharedContentTests {
    private let sampleMail = """
    From: Anna <anna@example.com>
    Subject: Angebot Dachrinne
     bis Freitag
    Message-ID: <abc123@example.com>
    Date: Wed, 16 Sep 2026 10:00:00 +0200

    Hallo Henning, anbei das Angebot.
    """

    @Test("A shared mail yields its subject, the message link and the mail channel")
    func mail() throws {
        let content = SharedContent.make(texts: [], urls: [], mails: [sampleMail])
        #expect(content.channel == .mail)
        #expect(content.prefill == "Angebot Dachrinne bis Freitag", "folded header lines are joined")
        #expect(content.sourceURL?.absoluteString == "message://%3Cabc123@example.com%3E")
    }

    @Test("Encoded subjects are decoded, base64 and quoted-printable alike")
    func encodedSubjects() {
        let base64 = "Subject: =?UTF-8?B?w5xiZXJ3ZWlzdW5nIGbDvHIgTcO8bGw=?=\n\nBody"
        #expect(SharedContent.subject(ofMail: base64) == "Überweisung für Müll")

        let quoted = "Subject: =?utf-8?Q?Termin_beim_Zahnarzt_=C3=A4ndern?=\n\nBody"
        #expect(SharedContent.subject(ofMail: quoted) == "Termin beim Zahnarzt ändern")

        let split = "Subject: =?UTF-8?Q?Erster?= =?UTF-8?Q?_Teil?=\n\nBody"
        #expect(SharedContent.subject(ofMail: split) == "Erster Teil", "space between encoded words is dropped")

        #expect(SharedContent.subject(ofMail: "From: x\n\nSubject: not a header") == nil, "the body is not searched")
    }

    @Test("A link with text keeps the text and attaches the link; a bare link becomes the text")
    func links() throws {
        let url = try #require(URL(string: "https://example.com/offer"))
        let withText = SharedContent.make(texts: ["  Angebot prüfen  "], urls: [url], mails: [])
        #expect(withText == SharedContent(prefill: "Angebot prüfen", sourceURL: url, channel: .share))

        let bare = SharedContent.make(texts: [""], urls: [url], mails: [])
        #expect(bare.prefill == "https://example.com/offer")
        #expect(bare.sourceURL == url)
    }

    @Test("A message link without the mail body still counts as mail")
    func messageLink() throws {
        let link = try #require(URL(string: "message://%3Cxyz@example.com%3E"))
        let content = SharedContent.make(texts: ["Rechnung"], urls: [link], mails: [])
        #expect(content.channel == .mail)
        #expect(content.sourceURL == link)
        #expect(content.prefill == "Rechnung")
    }

    // #24 AC-5: Mail's "Print → Share" hands over a PDF in the extension's temporary folder.
    @Test("A shared file link is neither the source nor the title")
    func fileLinkDropped() {
        let file = URL(fileURLWithPath: "/private/var/mobile/tmp/Mail-Druck.pdf")
        let content = SharedContent.make(texts: [], urls: [file], mails: [])
        #expect(content == SharedContent(prefill: "", sourceURL: nil, channel: .share))
    }

    @Test("A shared file link next to text keeps the text and no source")
    func fileLinkWithText() {
        let file = URL(fileURLWithPath: "/private/var/mobile/tmp/Mail-Druck.pdf")
        let content = SharedContent.make(texts: ["Rechnung"], urls: [file], mails: [])
        #expect(content.prefill == "Rechnung")
        #expect(content.sourceURL == nil)
    }

    @Test("A file link next to a message link leaves the message link as source")
    func fileLinkNextToMessageLink() throws {
        let file = URL(fileURLWithPath: "/private/var/mobile/tmp/Mail-Druck.pdf")
        let message = try #require(URL(string: "message://%3Cxyz@example.com%3E"))
        let content = SharedContent.make(texts: ["Rechnung"], urls: [file, message], mails: [])
        #expect(content.sourceURL == message)
        #expect(content.channel == .mail)
        #expect(content.prefill == "Rechnung")
    }

    @Test("A web link still becomes the source")
    func webLinkStaysSource() throws {
        let url = try #require(URL(string: "https://example.com/rechnung"))
        let content = SharedContent.make(texts: ["Rechnung"], urls: [url], mails: [])
        #expect(content.sourceURL == url)
        #expect(content.channel == .share)
    }

    @Test("Nothing shared is empty, not a crash")
    func nothing() {
        #expect(SharedContent.make(texts: [], urls: [], mails: []) == .empty)
    }

    // #24 AC-1: the measuring line names types only, never what was shared.
    @Test("The probe line lists the type identifiers and the loaded kind, nothing else")
    func probeLine() {
        let line = SharedContent.probeLine(typeIdentifiers: ["public.url", "public.plain-text"], loaded: "url")
        #expect(line == "types=[public.url, public.plain-text] loaded=url")
    }

    @Test("The probe line states an attachment without types or a failed load plainly")
    func probeLineEmpty() {
        #expect(SharedContent.probeLine(typeIdentifiers: [], loaded: nil) == "types=[] loaded=none")
    }

    // MARK: - Attachments (#399)

    private func shared(_ name: String, type: String, status: SharedAttachment.Status = .ready) -> SharedAttachment {
        SharedAttachment(fileURL: URL(fileURLWithPath: "/tmp/\(name)"), fileName: name, typeIdentifier: type, byteCount: 10, status: status)
    }

    @Test("A shared file without text gives its readable name; photos alone leave the field empty")
    func attachmentPrefill() {
        let pdf = shared("Befund_Dr-Meier.pdf", type: "com.adobe.pdf")
        let photo = shared("IMG_0001.heic", type: "public.heic")

        let file = SharedContent.make(texts: [], urls: [], mails: [], attachments: [pdf])
        #expect(file.prefill == "Befund Dr Meier")
        #expect(file.attachments == [pdf])
        #expect(file.channel == .share)

        #expect(SharedContent.make(texts: [], urls: [], mails: [], attachments: [photo]).prefill == "")
        #expect(SharedContent.make(texts: [], urls: [], mails: [], attachments: [photo, pdf]).prefill == "Befund Dr Meier")

        for status in [SharedAttachment.Status.tooLarge, .overLimit] {
            let skipped = shared("Befund.pdf", type: "com.adobe.pdf", status: status)
            #expect(SharedContent.make(texts: [], urls: [], mails: [], attachments: [skipped]).prefill == "")
        }
    }

    @Test("Text, links and mail keep the lead over a shared file, which is still carried")
    func attachmentKeepsLead() throws {
        let pdf = shared("Befund.pdf", type: "com.adobe.pdf")
        let web = try #require(URL(string: "https://example.com/a"))
        let message = try #require(URL(string: "message://%3Cx@example.com%3E"))
        let file = URL(fileURLWithPath: "/tmp/Befund.pdf")
        let cases: [(texts: [String], urls: [URL], mails: [String])] = [
            (["Arzt anrufen"], [], []),
            ([], [web], []),
            ([], [message], []),
            ([], [], [sampleMail]),
            (["Arzt anrufen"], [file], []),
        ]
        for input in cases {
            let without = SharedContent.make(texts: input.texts, urls: input.urls, mails: input.mails)
            let with = SharedContent.make(texts: input.texts, urls: input.urls, mails: input.mails, attachments: [pdf])
            #expect(with.prefill == without.prefill)
            #expect(with.sourceURL == without.sourceURL)
            #expect(with.channel == without.channel)
            #expect(with.attachments == [pdf])
        }
        #expect(SharedContent.make(texts: ["x"], urls: [file], mails: [], attachments: [pdf]).sourceURL == nil, "a file link is still dropped")
    }
}
