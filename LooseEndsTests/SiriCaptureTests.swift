import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Geocoding stand-in (#25 Schnitt 1): answers with a fixed hit or none and counts the calls.
final class GeocodeFake: @unchecked Sendable {
    let hit: SiriCapture.Coordinate?
    private(set) var calls: [String] = []

    init(hit: SiriCapture.Coordinate? = nil) { self.hit = hit }

    var function: SiriCapture.Geocode {
        { [self] address in
            calls.append(address)
            return hit
        }
    }
}

/// Siri's reminder onto a new task (#25 Schnitt 1): `prepare` checks everything and writes nothing,
/// `commit` writes one task. Every test holds its own `TestStore`.
@Suite("Siri-Erfassung (#25 Schnitt 1)")
@MainActor
struct SiriCaptureTests {
    private let linkA = URL(string: "https://a.de")!
    private let linkASlash = URL(string: "https://a.de/")!
    private let linkB = URL(string: "https://b.de/x")!
    private let gregorian = Calendar(identifier: .gregorian)

    /// 2026-10-16 09:00 local, whole seconds so the ISO 8601 round trip of the revision is exact.
    private var nineTomorrow: Date {
        gregorian.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 9, minute: 0))!
    }

    private var weekly: Calendar.RecurrenceRule {
        Calendar.RecurrenceRule(calendar: gregorian, frequency: .weekly)
    }

    private var home: SiriCapture.Place {
        SiriCapture.Place(
            name: "Zuhause", address: nil,
            coordinate: SiriCapture.Coordinate(latitude: 51.99563, longitude: 7.71357), event: .arrive
        )
    }

    private func revisions(of field: RevisedField, on task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.field == field }
    }

    private func tasks(in context: ModelContext) throws -> [TaskItem] {
        try context.fetch(FetchDescriptor<TaskItem>())
    }

    private func projects(in context: ModelContext) throws -> [Project] {
        try context.fetch(FetchDescriptor<Project>())
    }

    /// Both steps in the order Schnitt 2 uses.
    @discardableResult
    private func capture(
        _ input: SiriCapture.Input, in context: ModelContext, geocode: GeocodeFake = GeocodeFake()
    ) async throws -> TaskItem {
        let prepared = try await SiriCapture.prepare(input, in: context, geocode: geocode.function)
        return try SiriCapture.commit(prepared, in: context)
    }

    // MARK: AC-1

    @Test("Nur ein Titel: eine Aufgabe, Kanal Siri, Rohtext = Titel, keine Revision, kein Projekt (AC-1)")
    func titleOnlyCreatesTask() async throws {
        let store = try TestStore()
        let task = try await capture(SiriCapture.Input(title: "Steuererklärung abgeben"), in: store.context)

        let all = try tasks(in: store.context)
        #expect(all.count == 1)
        #expect(all.first?.id == task.id)
        #expect(task.capturedVia == .siri)
        #expect(task.rawText == "Steuererklärung abgeben")
        #expect((task.revisions ?? []).isEmpty)
        #expect(task.project == nil)
        #expect(try projects(in: store.context).isEmpty)
        #expect(!store.context.hasChanges, "commit saves")
    }

    // MARK: AC-2

    @Test("Alle Felder landen auf der Aufgabe und sind nach dem Neuladen gespeichert (AC-2)")
    func allFieldsLandOnTheTask() async throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()

        var input = SiriCapture.Input(title: "Steuererklärung abgeben")
        input.notes = "Belege holen"
        input.due = nineTomorrow
        input.dueHasTime = true
        input.listName = "Büro"
        input.recurrence = weekly
        input.place = home
        input.urls = [linkB]
        input.isFlagged = true
        input.tags = ["garten"]
        let id = try await capture(input, in: store.context).id

        // A fresh context reads what reached the store, not the objects still in memory.
        let fresh = ModelContext(store.container)
        let task = try #require(try fresh.fetch(FetchDescriptor<TaskItem>()).first { $0.id == id })
        #expect(task.rawText == "Steuererklärung abgeben\nBelege holen")
        #expect(task.title == TitleRule.title(from: "Steuererklärung abgeben", reference: task.capturedAt))
        #expect(task.capturedVia == .siri)
        #expect(task.dueDate == nineTomorrow)
        #expect(task.dueHasTime == true)
        #expect(task.project?.name == "Büro")
        #expect(task.repeatRule == RepeatRule(frequency: .weekly, interval: 1))
        #expect(task.place == TaskPlace(name: "Zuhause", latitude: 51.99563, longitude: 7.71357, event: .arrive))
        #expect(task.sourceURL == linkB)
        #expect(task.importance == .high)
        #expect((task.contexts ?? []).map(\.name) == ["Garten"])
    }

    // MARK: AC-3, AC-12

    struct FailingCase: Sendable, CustomTestStringConvertible {
        let label: String
        let input: SiriCapture.Input
        let expected: SiriCaptureError
        var testDescription: String { label }
    }

    /// Every case also carries a new list, a known tag and a flag: none of it may be written.
    nonisolated private static func failing(_ label: String, _ expected: SiriCaptureError, _ change: (inout SiriCapture.Input) -> Void) -> FailingCase {
        var input = SiriCapture.Input(title: "Rasen mähen")
        input.listName = "Neue Liste"
        input.tags = ["Garten"]
        input.isFlagged = true
        change(&input)
        return FailingCase(label: label, input: input, expected: expected)
    }

    nonisolated static let failingCases: [FailingCase] = {
        let gregorian = Calendar(identifier: .gregorian)
        return [
            failing("leerer Titel", .emptyTitle) { $0.title = "   " },
            failing("zwei Links", .multipleLinks(2)) {
                $0.urls = [URL(string: "https://a.de")!, URL(string: "https://b.de/x")!]
            },
            failing("unbekanntes Tag", .unknownTag("Bürro")) { $0.tags = ["Garten", "Bürro"] },
            failing("nicht abbildbare Wiederholung", .unmappableRepeat([.frequency])) {
                $0.recurrence = Calendar.RecurrenceRule(calendar: gregorian, frequency: .hourly)
            },
            failing("Ort nicht gefunden", .placeNotFound) {
                $0.place = SiriCapture.Place(name: nil, address: "Nirgendwo 1", coordinate: nil, event: .arrive)
            },
            failing("ungültige Koordinate", .invalidPlace) {
                $0.place = SiriCapture.Place(
                    name: "Pol", address: nil, coordinate: SiriCapture.Coordinate(latitude: 91, longitude: 0), event: .arrive
                )
            },
            failing("Abschnitt mit Inhalt", .unsupported(.section)) { $0.section = "Einkauf" },
            failing("Bilder mit Inhalt", .unsupported(.images)) { $0.imageCount = 1 },
        ]
    }()

    @Test("Jeder Fehler wirft in prepare, hinterlässt keine Aufgabe, kein Projekt, keine Änderung (AC-3, AC-12)",
          arguments: failingCases)
    func everyErrorLeavesNoTaskAndNoChanges(_ failing: FailingCase) async throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        store.context.insert(Project(name: "Haus", sortOrder: 0))
        try store.context.save()
        let geocode = GeocodeFake(hit: nil)

        await #expect(throws: failing.expected) {
            try await SiriCapture.prepare(failing.input, in: store.context, geocode: geocode.function)
        }

        #expect(try tasks(in: store.context).isEmpty)
        #expect(try projects(in: store.context).map(\.name) == ["Haus"])
        #expect(try store.context.fetchCount(FetchDescriptor<Revision>()) == 0)
        #expect(!store.context.hasChanges)
    }

    @Test("prepare schreibt auch bei Erfolg nichts: keine Aufgabe, kein Projekt, keine Änderung (AC-12)")
    func prepareWritesNothingEvenOnSuccess() async throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()

        var input = SiriCapture.Input(title: "Steuererklärung abgeben")
        input.notes = "Belege holen"
        input.due = nineTomorrow
        input.dueHasTime = true
        input.listName = "Neue Liste"
        input.recurrence = weekly
        input.place = SiriCapture.Place(name: nil, address: "Markt 1, Münster", coordinate: nil, event: .depart)
        input.urls = [linkA]
        input.isFlagged = true
        input.tags = ["Garten"]
        let geocode = GeocodeFake(hit: SiriCapture.Coordinate(latitude: 51.96, longitude: 7.63))

        _ = try await SiriCapture.prepare(input, in: store.context, geocode: geocode.function)

        #expect(!store.context.hasChanges)
        #expect(try tasks(in: store.context).isEmpty)
        #expect(try projects(in: store.context).isEmpty)
        #expect(try store.context.fetchCount(FetchDescriptor<Revision>()) == 0)
    }

    // MARK: AC-4

    @Test("Eine Koordinate braucht kein Geocoding (AC-4)")
    func coordinateNeedsNoGeocoding() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Blumen gießen")
        input.place = SiriCapture.Place(
            name: "Zuhause", address: "Markt 1, Münster",
            coordinate: SiriCapture.Coordinate(latitude: 51.99563, longitude: 7.71357), event: .arrive
        )
        let geocode = GeocodeFake(hit: SiriCapture.Coordinate(latitude: 1, longitude: 1))

        let task = try await capture(input, in: store.context, geocode: geocode)

        #expect(geocode.calls.isEmpty)
        #expect(task.place == TaskPlace(name: "Zuhause", latitude: 51.99563, longitude: 7.71357, event: .arrive))
    }

    @Test("Nur eine Adresse: genau ein Geocoding-Aufruf, der Name ist die Adresse (AC-4)")
    func addressOnlyGeocodesOnce() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Brot kaufen")
        input.place = SiriCapture.Place(name: nil, address: "Markt 1, Münster", coordinate: nil, event: .depart)
        let geocode = GeocodeFake(hit: SiriCapture.Coordinate(latitude: 51.96, longitude: 7.63))

        let task = try await capture(input, in: store.context, geocode: geocode)

        #expect(geocode.calls == ["Markt 1, Münster"])
        #expect(task.place == TaskPlace(name: "Markt 1, Münster", latitude: 51.96, longitude: 7.63, event: .depart))
    }

    @Test("Adresse ohne Treffer ist placeNotFound (AC-4)")
    func addressWithoutHitIsPlaceNotFound() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Brot kaufen")
        input.place = SiriCapture.Place(name: "Bäcker", address: "Nirgendwo 1", coordinate: nil, event: .arrive)
        let geocode = GeocodeFake(hit: nil)

        await #expect(throws: SiriCaptureError.placeNotFound) {
            try await SiriCapture.prepare(input, in: store.context, geocode: geocode.function)
        }
        #expect(geocode.calls.count == 1)
        #expect(try tasks(in: store.context).isEmpty)
    }

    // MARK: AC-5

    @Test("Datum, Wiederholung, Ort und Liste: je eine Nutzer-Revision mit Grund Siri, Ort mit Herkunft user (AC-5)")
    func siriValuesAreUserRevisionsWithReasonSiri() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Steuererklärung abgeben")
        input.due = nineTomorrow
        input.dueHasTime = true
        input.recurrence = weekly
        input.place = home
        input.listName = "Büro"

        let task = try await capture(input, in: store.context)

        for field in [RevisedField.dueDate, .repeatRule, .place, .project] {
            let found = revisions(of: field, on: task)
            #expect(found.count == 1, "\(field)")
            #expect(found.first?.author == .user, "\(field)")
            #expect(found.first?.reason == "Siri", "\(field)")
        }
        #expect(task.placeSourceRaw == FieldSource.user.rawValue)
        #expect(task.dueSourceRaw == FieldSource.user.rawValue)
    }

    // MARK: AC-6

    @Test("Wiederholung ohne Datum erfindet keine Fälligkeit (AC-6)")
    func repeatWithoutDateInventsNoDate() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Pflanzen gießen")
        input.recurrence = weekly

        let task = try await capture(input, in: store.context)

        #expect(task.repeatRule == RepeatRule(frequency: .weekly, interval: 1))
        #expect(task.dueDate == nil)
        #expect(revisions(of: .dueDate, on: task).isEmpty)
    }

    // MARK: AC-7

    /// An earlier task with the same raw text in another context: the recognition would take it over.
    private func earlierTask(_ rawText: String, context taskContext: TaskContext, in context: ModelContext) {
        let task = TaskItem(rawText: rawText)
        task.status = .active
        task.processedAt = Date(timeIntervalSince1970: 1_700_000_000)
        task.contexts = [taskContext]
        task.contextsSourceRaw = FieldSource.user.rawValue
        context.insert(task)
    }

    @Test("Der erste Veredelungsdurchlauf lässt Datum, Wiederholung, Ort, Link, Markierung und Tags stehen (AC-7)")
    func siriValuesSurviveFirstEnrichmentPass() async throws {
        let store = try TestStore()
        let garden = TaskContext(name: "Garten", sortOrder: 0)
        let office = TaskContext(name: "Büro", sortOrder: 1)
        store.context.insert(garden)
        store.context.insert(office)
        // The note carries words the rule step reads: a weekday (due date), "wichtig" (importance),
        // and the earlier task offers another context by recognition.
        let raw = "Rasen mähen\nwichtig, bis Freitag"
        earlierTask(raw, context: office, in: store.context)
        try store.context.save()

        var input = SiriCapture.Input(title: "Rasen mähen")
        input.notes = "wichtig, bis Freitag"
        input.due = nineTomorrow
        input.dueHasTime = true
        input.recurrence = weekly
        input.place = home
        input.urls = [linkB]
        input.isFlagged = true
        input.tags = ["Garten"]
        let task = try await capture(input, in: store.context)
        #expect(task.rawText == raw)

        var draft = EnrichmentDraft()
        draft.importance = EnrichmentDraft.Guess(.low, confidence: 0.9, reason: "Stub.")
        draft.duration = EnrichmentDraft.Guess(.minutes30, confidence: 0.9, reason: "Stub.")
        draft.contexts = EnrichmentDraft.Guess(["Büro"], confidence: 0.9, reason: "Stub.")
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(draft: draft), container: store.container)

        await coordinator.processPending()

        #expect(task.processedAt != nil, "the pass ran")
        #expect(task.dueDate == nineTomorrow)
        #expect(task.dueHasTime == true)
        #expect(task.dueSourceRaw == FieldSource.user.rawValue)
        #expect(task.repeatRule == RepeatRule(frequency: .weekly, interval: 1))
        #expect(task.place == TaskPlace(name: "Zuhause", latitude: 51.99563, longitude: 7.71357, event: .arrive))
        #expect(task.sourceURL == linkB)
        #expect(task.importance == .high)
        #expect((task.contexts ?? []).map(\.name) == ["Garten"])
    }

    @Test("Der erste Veredelungsdurchlauf lässt Siris Liste stehen, auch wenn das Modell ein anderes Projekt nennt (AC-7)")
    func siriProjectSurvivesFirstEnrichmentPass() async throws {
        let store = try TestStore()
        store.context.insert(Project(name: "Haus", sortOrder: 0))
        try store.context.save()

        var input = SiriCapture.Input(title: "Rasen mähen")
        input.listName = "Büro"
        let task = try await capture(input, in: store.context)

        var draft = EnrichmentDraft()
        draft.project = EnrichmentDraft.Guess("Haus", confidence: 0.9, reason: "Stub.")
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(draft: draft), container: store.container)

        await coordinator.processPending()

        #expect(task.processedAt != nil, "the pass ran")
        #expect(task.project?.name == "Büro")
    }

    // MARK: AC-8

    @Test("CaptureService.save behält Signatur und Verhalten (AC-8)")
    func saveSignatureUnchanged() throws {
        // The exact argument set from before this cut; a changed signature does not compile.
        let save: (String, CaptureChannel, URL?, ModelContext) throws -> TaskItem = CaptureService.save(_:via:sourceURL:in:)
        let store = try TestStore()

        let task = try save("  Rasen mähen am Samstag \n", .share, linkB, store.context)

        #expect(task.rawText == "Rasen mähen am Samstag")
        #expect(task.capturedVia == .share)
        #expect(task.sourceURL == linkB)
        #expect(task.title == TitleRule.title(from: "Rasen mähen am Samstag", reference: task.capturedAt))
        #expect(task.titleSourceRaw == nil)
        #expect((task.revisions ?? []).isEmpty)
        #expect(task.project == nil)
        #expect(task.dueDate == nil, "save sets no due date; the rule step does")
        #expect(!store.context.hasChanges, "save saves")
        #expect(try tasks(in: store.context).count == 1)

        let plain = try CaptureService.save("Brot kaufen", via: .app, in: store.context)
        #expect(plain.sourceURL == nil)
        #expect(throws: CaptureError.emptyText) { try CaptureService.save("   ", via: .siri, in: store.context) }
        #expect(try tasks(in: store.context).count == 2)
    }

    // MARK: AC-9

    @Test("Eine unbekannte Liste legt genau ein Projekt an, die Aufgabe liegt darin (AC-9)")
    func unknownListCreatesProject() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Ablage machen")
        input.listName = "Büro"

        let task = try await capture(input, in: store.context)

        let all = try projects(in: store.context)
        #expect(all.map(\.name) == ["Büro"])
        #expect(task.project?.id == all.first?.id)
    }

    @Test("Ein vorhandenes Projekt gleichen Namens wird benutzt, kein Doppel (AC-9)",
          arguments: ["büro", "BÜRO ", "Buro"])
    func existingProjectIsReusedByNameKey(_ listName: String) async throws {
        let store = try TestStore()
        let office = Project(name: "Büro", sortOrder: 0)
        store.context.insert(office)
        try store.context.save()
        var input = SiriCapture.Input(title: "Ablage machen")
        input.listName = listName

        let task = try await capture(input, in: store.context)

        #expect(try projects(in: store.context).count == 1)
        #expect(task.project?.id == office.id)
    }

    @Test("Bei gleichnamigen Projekten gilt das mit der kleinsten sortOrder (AC-9)")
    func duplicateProjectsPickSmallestSortOrder() async throws {
        let store = try TestStore()
        let later = Project(name: "Büro", sortOrder: 7)
        let first = Project(name: "büro", sortOrder: 2)
        store.context.insert(later)
        store.context.insert(first)
        try store.context.save()
        var input = SiriCapture.Input(title: "Ablage machen")
        input.listName = "Büro"

        let task = try await capture(input, in: store.context)

        #expect(try projects(in: store.context).count == 2)
        #expect(task.project?.id == first.id)
    }

    @Test("Ein leerer Listenname legt kein Projekt an (AC-9)")
    func blankListNameCreatesNoProject() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Ablage machen")
        input.listName = "  "

        let task = try await capture(input, in: store.context)

        #expect(task.project == nil)
        #expect(try projects(in: store.context).isEmpty)
    }

    // MARK: AC-10

    @Test("Die Notiz hängt am Rohtext, nicht am Titel (AC-10)")
    func noteIsAppendedToRawTextButNotToTitle() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Steuer")
        input.notes = "Belege holen"

        let task = try await capture(input, in: store.context)

        #expect(task.rawText == "Steuer\nBelege holen")
        #expect(task.title == "Steuer")
    }

    // MARK: AC-11

    @Test("Ein Link mit und ohne Schrägstrich zählt einmal (AC-11)")
    func linkWithAndWithoutTrailingSlashCountsOnce() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Artikel lesen")
        input.urls = [linkA, linkASlash]

        let task = try await capture(input, in: store.context)

        let url = try #require(task.sourceURL)
        #expect(url == linkA || url == linkASlash)
    }

    @Test("Leere Tags lehnen nichts ab und setzen nichts (AC-11)")
    func emptyTagsAreIgnored() async throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()
        var input = SiriCapture.Input(title: "Artikel lesen")
        input.tags = ["", " "]

        let task = try await capture(input, in: store.context)

        #expect((task.contexts ?? []).isEmpty)
        #expect(revisions(of: .contexts, on: task).isEmpty)
        #expect((task.revisions ?? []).isEmpty)
    }

    // MARK: F5, leere Anhänge

    @Test("Ein leerer Abschnitt und keine Bilder lehnen nichts ab (F5)")
    func emptySectionAndNoImagesAreAccepted() async throws {
        let store = try TestStore()
        var input = SiriCapture.Input(title: "Milch kaufen")
        input.section = "  "
        input.imageCount = 0

        let task = try await capture(input, in: store.context)

        #expect(task.rawText == "Milch kaufen")
    }
}
