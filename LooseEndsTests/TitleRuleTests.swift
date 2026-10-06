import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("TitleRule (#202)") struct TitleRuleTests {
    // MARK: Rule

    @Test("Trims surrounding whitespace")
    func trims() {
        #expect(TitleRule.title(from: "  Rasen mähen  ") == "Rasen mähen")
    }

    @Test("Nothing left means no title", arguments: ["", "   ", "\n\t ", "...", "?!"])
    func emptyIsNil(input: String) {
        #expect(TitleRule.title(from: input) == nil)
    }

    @Test("Closing punctuation goes, also repeated and after a gap")
    func closingPunctuation() {
        #expect(TitleRule.title(from: "Zahnarzt anrufen.") == "Zahnarzt anrufen")
        #expect(TitleRule.title(from: "Zahnarzt anrufen…") == "Zahnarzt anrufen")
        #expect(TitleRule.title(from: "Zahnarzt anrufen. .") == "Zahnarzt anrufen")
        #expect(TitleRule.title(from: "Wann kommt der Handwerker?") == "Wann kommt der Handwerker")
        #expect(TitleRule.title(from: "Anruf, dann Mail") == "Anruf, dann Mail")
    }

    @Test("At most twelve words, no ellipsis, a comma on the twelfth word goes")
    func twelveWords() {
        let words = (1...30).map { "W\($0)" } // upper case: the rule raises the first letter (test 6)
        let twelve = words.prefix(12).joined(separator: " ")
        #expect(TitleRule.title(from: twelve) == twelve)
        #expect(TitleRule.title(from: words.prefix(13).joined(separator: " ")) == twelve)
        #expect(TitleRule.title(from: words.joined(separator: " ")) == twelve)
        let comma = (Array(words.prefix(11)) + ["W12,", "W13"]).joined(separator: " ")
        #expect(TitleRule.title(from: comma) == twelve)
    }

    @Test("First letter upper case, also umlauts; ß stays")
    func firstLetter() {
        #expect(TitleRule.title(from: "ärgerlich: Steuer abgeben") == "Ärgerlich: Steuer abgeben")
        #expect(TitleRule.title(from: "überweisen") == "Überweisen")
        #expect(TitleRule.title(from: "ßtraße prüfen") == "ßtraße prüfen")
    }

    @Test("A first character that is no letter leaves the text alone; only the first letter is raised")
    func nonLetterStart() {
        #expect(TitleRule.title(from: "3 Pakete abholen") == "3 Pakete abholen")
        #expect(TitleRule.title(from: "„Brief“ senden") == "„Brief“ senden")
        #expect(TitleRule.title(from: "#Steuer prüfen") == "#Steuer prüfen")
        #expect(TitleRule.title(from: "iPhone laden") == "IPhone laden")
    }

    @Test("Runs of blanks and line breaks become one space")
    func collapsesWhitespace() {
        #expect(TitleRule.title(from: "Rasen   mähen\nund   düngen") == "Rasen mähen und düngen")
    }

    @Test("The rule is idempotent and gives a real title for each of these inputs")
    func idempotent() {
        let inputs = ["  Rasen mähen  ", "Zahnarzt anrufen. .", "ärgerlich: Steuer abgeben", "Rasen   mähen\nund   düngen",
                      (1...20).map { "w\($0)" }.joined(separator: " "), "iPhone laden"]
        for input in inputs {
            let once = TitleRule.title(from: input)
            #expect(once != nil)
            #expect(once.flatMap { TitleRule.title(from: $0) } == once)
        }
    }

    // MARK: Rule words leave the title (#217)

    /// A Wednesday at noon, so every date below resolves in any time zone.
    private static let wednesday = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!

    /// The example table of the spec (#217): German and English, everything recognised, nothing
    /// recognised, the date in the middle, content words that stay.
    @Test("Words the rules read leave the title", arguments: [
        ("Morgen wichtig Steuerbescheid prüfen", "Steuerbescheid prüfen"),
        ("Geschenk für Anna bis Freitag besorgen", "Geschenk für Anna besorgen"),
        ("Bis zum 15. die Miete überweisen", "Die Miete überweisen"),
        ("Morgen um 15 Uhr Zahnarzt anrufen", "Zahnarzt anrufen"),
        ("Halb zwölf morgen Anna abholen", "Anna abholen"),
        ("Zahnarzt anrufen, dringend", "Zahnarzt anrufen"),
        ("Dringend und wichtig: Vertrag kündigen", "Vertrag kündigen"),
        ("Mit Anna am Samstag ins Kino gehen", "Mit Anna ins Kino gehen"),
        ("Steuererklärung nächsten Freitag abgeben", "Steuererklärung abgeben"),
        ("In 3 Tagen Reifen wechseln", "Reifen wechseln"),
        ("Am Wochenende Rasenmäher Ölwechsel", "Rasenmäher Ölwechsel"),
        ("Morgen: „Projekt X“ abgeben", "„Projekt X“ abgeben"),
        ("Call the bank tomorrow at 9am", "Call the bank"),
        ("Important: renew passport by Friday", "Renew passport"),
        ("Pay rent on the 12th", "Pay rent"),
        ("Urgent: call back the plumber", "Call back the plumber"),
    ])
    func ruleWordsLeave(raw: String, title: String) {
        #expect(TitleRule.title(from: raw, reference: Self.wednesday) == title)
    }

    @Test("What no rule reads stays, word for word", arguments: [
        "Rasen mähen",
        "Rechnung bezahlen",           // sets the importance, but is what the task is about
        "Kündigungsfrist prüfen",      // sets the urgency, same
        "Jeden Montag Blumen gießen",  // a repetition, no due date
        "Treffen um 15 Uhr",           // a time without a day sets no due date
        "Nicht wichtig: Keller aufräumen",
    ])
    func unreadWordsStay(raw: String) {
        #expect(TitleRule.title(from: raw, reference: Self.wednesday) == raw)
    }

    @Test("Nothing left after striking: the title keeps every word")
    func nothingLeftKeepsAll() {
        #expect(TitleRule.title(from: "Morgen wichtig", reference: Self.wednesday) == "Morgen wichtig")
        #expect(TitleRule.title(from: "Dringend!", reference: Self.wednesday) == "Dringend")
    }

    @Test("The twelve words count after striking")
    func twelveAfterStriking() {
        let words = (1...13).map { "W\($0)" }
        let raw = "Morgen " + words.joined(separator: " ")
        #expect(TitleRule.title(from: raw, reference: Self.wednesday) == words.prefix(12).joined(separator: " "))
    }

    @Test("Capture strikes the rule words; the raw text stays as said")
    @MainActor func captureStrikes() throws {
        let store = try TestStore()
        let raw = "Morgen wichtig Steuerbescheid prüfen"

        let task = try CaptureService.save(raw, via: .app, in: store.context)

        #expect(task.title == "Steuerbescheid prüfen")
        #expect(task.rawText == raw)
        #expect(task.titleSourceRaw == nil)
    }

    @Test("A model title that brings the struck words back is cut the same way; equal to the rule title, nothing is written")
    @MainActor func modelTitleIsStruckToo() throws {
        let store = try TestStore()
        let task = try CaptureService.save("Morgen wichtig Steuerbescheid prüfen", via: .app, in: store.context)

        modelTitle("Morgen wichtig Steuerbescheid prüfen", on: task)

        #expect(task.title == "Steuerbescheid prüfen")
        #expect(task.titleSourceRaw == nil, "the rule title stays, no AI marker")
        #expect(!(task.revisions ?? []).contains { $0.field == .title })

        modelTitle("Wichtig: Steuerbescheid vom Finanzamt prüfen", on: task)

        #expect(task.title == "Steuerbescheid vom Finanzamt prüfen")
        #expect(task.titleSourceRaw == FieldSource.ai.rawValue)
    }

    // MARK: Capture

    @Test("Capture sets the title from the rule: no AI marker, no revision, status unprocessed, raw text untouched")
    @MainActor func captureSetsTitle() throws {
        let store = try TestStore()
        let raw = "termin bei Auto Senger machen für Inspektion und Reifenwechsel."

        let task = try CaptureService.save(raw, via: .app, in: store.context)

        #expect(task.title == "Termin bei Auto Senger machen für Inspektion und Reifenwechsel")
        #expect(task.titleSourceRaw == nil)
        #expect(task.titleConfidence == nil)
        #expect((task.revisions ?? []).isEmpty)
        #expect(task.status == .unprocessed)
        #expect(task.rawText == raw)
        #expect(!RevisionService.automaticFields(on: task).contains(.title))
    }

    // MARK: Reset

    @MainActor
    private func modelTitle(_ value: String, on task: TaskItem) {
        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess(value, confidence: 0.9, reason: "Names the job.")
        EnrichmentWriter.apply(draft, to: task, contexts: [], projects: [])
    }

    @Test("Reset after the model title leads back to the rule title")
    @MainActor func resetAfterModel() throws {
        let store = try TestStore()
        let task = try CaptureService.save("termin bei Auto Senger machen für Inspektion und Reifenwechsel.", via: .app, in: store.context)
        let ruleTitle = try #require(task.title)
        modelTitle("Auto Senger: Inspektion", on: task)
        let first = try #require(RevisionService.firstAutomaticRevision(of: .title, on: task))
        #expect(first.oldValue == ruleTitle)
        #expect(RevisionService.automaticFields(on: task).contains(.title))

        let written = RevisionService.revert(first, on: task, contexts: [], projects: [])

        #expect(task.title == ruleTitle)
        #expect(task.titleSourceRaw == FieldSource.user.rawValue)
        #expect(written.author == .user)
        #expect(written.newValue == ruleTitle)
        #expect(!RevisionService.automaticFields(on: task).contains(.title))
    }

    @Test("Reset of an old task without a title leads to the cleaned raw text, via revert and via revertAll")
    @MainActor func resetLegacy() throws {
        let store = try TestStore()
        let one = TaskItem(rawText: "Rasen mähen.")
        let two = TaskItem(rawText: "Rasen mähen.")
        store.context.insert(one)
        store.context.insert(two)
        modelTitle("Rasen mähen", on: one)
        modelTitle("Rasen mähen", on: two)
        let first = try #require(RevisionService.firstAutomaticRevision(of: .title, on: one))
        #expect(first.oldValue == nil)

        RevisionService.revert(first, on: one, contexts: [], projects: [])
        RevisionService.revertAll(on: two, contexts: [], projects: [])

        #expect(one.title == "Rasen mähen")
        #expect(two.title == "Rasen mähen")
    }

    @Test("The legacy rule applies to the title only: a date with no earlier value stays empty")
    @MainActor func legacyRuleIsTitleOnly() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Rasen mähen.")
        store.context.insert(task)
        task.dueDate = Date()
        task.dueSourceRaw = FieldSource.ai.rawValue
        let revision = Revision(task: task, field: .dueDate, oldValue: nil, newValue: Date().ISO8601Format(), author: .ai, reason: "test")
        task.revisions = [revision]

        RevisionService.revert(revision, on: task, contexts: [], projects: [])

        #expect(task.dueDate == nil)
    }

    // MARK: displayTitle

    @Test("displayTitle shows the title whatever the status, the raw text only without a title")
    func displayTitle() {
        let unverified = TaskItem(rawText: "rasen mähen und so weiter")
        unverified.title = "Rasen mähen"
        unverified.status = .unverified
        #expect(unverified.displayTitle == "Rasen mähen")

        let legacy = TaskItem(rawText: "rasen mähen und so weiter")
        legacy.status = .unverified
        #expect(legacy.displayTitle == "rasen mähen und so weiter")

        let fresh = TaskItem(rawText: "rasen mähen.")
        fresh.title = "Rasen mähen"
        #expect(fresh.status == .unprocessed)
        #expect(fresh.displayTitle == "Rasen mähen")
    }

    // MARK: User empties the title

    @Test("A title the user emptied stays empty")
    @MainActor func userEmptiedTitleStaysEmpty() throws {
        let store = try TestStore()
        let task = try CaptureService.save("Rasen mähen", via: .app, in: store.context)

        RevisionService.set(.title, to: nil, on: task, contexts: [], projects: [])
        try store.context.save()

        #expect(task.title == nil)
        #expect(task.titleSourceRaw == nil)
    }
}
