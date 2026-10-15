import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The note (#439): what in it can be tapped, and that writing it is a user revision.
@Suite("Note") struct NoteLinksTests {
    @Test("A phone number dials with digits and a leading plus only")
    func phoneURL() {
        #expect(NoteLinks.phoneURL("02 51 / 4 65 56")?.absoluteString == "tel:025146556")
        #expect(NoteLinks.phoneURL("+49 251 46556")?.absoluteString == "tel:+4925146556")
        #expect(NoteLinks.phoneURL("—") == nil)
    }

    @Test("A link and a mail address in the note become links")
    func linksAndMail() {
        let text = "Befund unter https://example.com/befund, Rückfragen an praxis@example.com"
        let hits = NoteLinks.hits(in: text)
        #expect(hits.contains { $0.kind == .link && $0.url.absoluteString == "https://example.com/befund" })
        #expect(hits.contains { $0.kind == .mail && $0.url.absoluteString == "mailto:praxis@example.com" })
    }

    @Test("A phone number in the note becomes a tel: link")
    func phoneInNote() {
        let hits = NoteLinks.hits(in: "Praxis: +49 251 465560")
        #expect(hits.contains { $0.kind == .phone && $0.url.absoluteString.hasPrefix("tel:+49") })
    }

    @Test("The attributed note carries the link on exactly the found words")
    func attributed() {
        let text = "Siehe https://example.com"
        let attributed = NoteLinks.attributed(text)
        let linked = attributed.runs.filter { $0.link != nil }.map { String(attributed[$0.range].characters) }
        #expect(linked == ["https://example.com"])
    }

    @Test("Writing the note is a user revision; clearing it empties the source")
    @MainActor func revision() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Hautarzt anrufen")
        store.context.insert(task)

        let written = RevisionService.set(.notes, to: "0251 46556", on: task, contexts: [], projects: [])
        #expect(written?.field == .notes)
        #expect(written?.author == .user)
        #expect(task.notes == "0251 46556")
        #expect(task.notesSourceRaw == FieldSource.user.rawValue)

        RevisionService.set(.notes, to: nil, on: task, contexts: [], projects: [])
        #expect(task.notes == nil)
        #expect(task.notesSourceRaw == nil)
        #expect(RevisionService.set(.notes, to: nil, on: task, contexts: [], projects: []) == nil)
    }
}
