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

    @Test("Nothing shared is empty, not a crash")
    func nothing() {
        #expect(SharedContent.make(texts: [], urls: [], mails: []) == .empty)
    }
}
