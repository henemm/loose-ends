import CoreLocation
import Foundation
import GeoToolbox
import MapKit
import SwiftData
import Testing
@testable import LooseEnds

/// Siri's „Erinnerung erstellen“ (#25 Schnitt 2b-1). The core `create` runs with a store and a fake
/// geocoder the test holds; `perform` writes into a fresh store under tests, so it is only checked to run.
/// Every input is built with `ReminderTranslation.input`, the way `perform` builds it: the chain from
/// Siri's types to the stored task is proven, not just the half step (#136).
@Suite("Siri-Intent Erinnerung erstellen (#25 Schnitt 2b-1)")
@MainActor
struct CreateReminderIntentTests {
    private let gregorian = Calendar(identifier: .gregorian)
    private let link = URL(string: "https://a.de/x")!
    private static let home = CLLocationCoordinate2D(latitude: 51.99563, longitude: 7.71357)

    /// Records every address the core hands to the geocoder.
    actor GeocodeLog {
        private(set) var addresses: [String] = []
        func record(_ address: String) { addresses.append(address) }
    }

    private func geocode(_ log: GeocodeLog, answer: SiriCapture.Coordinate?) -> SiriCapture.Geocode {
        { address in
            await log.record(address)
            return answer
        }
    }

    private static let noGeocode: SiriCapture.Geocode = { _ in nil }

    private func nine() -> DateComponents {
        DateComponents(calendar: gregorian, year: 2026, month: 10, day: 20, hour: 9)
    }

    private static func trigger(
        coordinate: CLLocationCoordinate2D? = nil, address: String? = nil, event: LocationTriggerEvent = .arrive
    ) -> LocationTriggerEntity {
        var representations: [PlaceDescriptor.PlaceRepresentation] = []
        if let coordinate { representations.append(.coordinate(coordinate)) }
        if let address { representations.append(.address(address)) }
        return LocationTriggerEntity(
            id: "t", place: PlaceDescriptor(representations: representations, commonName: "Zuhause"), event: event
        )
    }

    private func tasks(in store: TestStore) throws -> [TaskItem] {
        try store.context.fetch(FetchDescriptor<TaskItem>())
    }

    // MARK: AC-1

    @Test("Titel und Notiz ergeben genau eine Aufgabe, Titel nur aus Siris Titel (AC-1)")
    func titleAndNoteLandInOneTask() async throws {
        let store = try TestStore()
        let input = ReminderTranslation.input(title: "Steuer", note: AttributedString("Belege holen"))

        let task = try await CreateReminderIntent.create(input, in: store.context, geocode: Self.noGeocode)

        #expect(try tasks(in: store).count == 1)
        #expect(task.rawText == "Steuer\nBelege holen")
        #expect(task.title == TitleRule.title(from: "Steuer", reference: task.capturedAt))
        #expect(task.capturedVia == .siri)
    }

    @Test("Fälligkeit mit Stunde trägt die Uhrzeit, ohne Stunde nicht (AC-1)")
    func dueDateLands() async throws {
        let store = try TestStore()
        let withHour = try await CreateReminderIntent.create(
            ReminderTranslation.input(title: "Steuer", dueDate: nine()), in: store.context, geocode: Self.noGeocode
        )
        #expect(withHour.dueDate == gregorian.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9)))
        #expect(withHour.dueHasTime == true)

        let dayOnly = DateComponents(calendar: gregorian, year: 2026, month: 10, day: 21)
        let withoutHour = try await CreateReminderIntent.create(
            ReminderTranslation.input(title: "Müll", dueDate: dayOnly), in: store.context, geocode: Self.noGeocode
        )
        #expect(withoutHour.dueHasTime == false)
    }

    @Test("Liste wird zum Projekt, der Eingang „Loose Ends“ lässt das Projekt leer (AC-1)")
    func listLandsAsProject() async throws {
        let store = try TestStore()
        let office = ListEntity(id: UUID().uuidString, name: "Büro")
        let inOffice = try await CreateReminderIntent.create(
            ReminderTranslation.input(title: "Steuer", list: office), in: store.context, geocode: Self.noGeocode
        )
        #expect(inOffice.project?.name == "Büro")

        let inInbox = try await CreateReminderIntent.create(
            ReminderTranslation.input(title: "Milch", list: .inbox), in: store.context, geocode: Self.noGeocode
        )
        #expect(inInbox.project == nil)
    }

    @Test("Markierung, Tag und Link landen auf der Aufgabe (AC-1)")
    func flagTagsAndUrlLand() async throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()

        let task = try await CreateReminderIntent.create(
            ReminderTranslation.input(title: "Rasen", urls: [link], isFlagged: true, tags: ["garten"]),
            in: store.context, geocode: Self.noGeocode
        )
        #expect(task.importance == .high)
        #expect((task.contexts ?? []).map(\.name) == ["Garten"])
        #expect(task.sourceURL == link)
    }

    @Test("Wöchentliche Wiederholung wird zur Wiederholungsregel (AC-1)")
    func recurrenceLands() async throws {
        let store = try TestStore()
        let weekly = Calendar.RecurrenceRule(calendar: gregorian, frequency: .weekly)
        let task = try await CreateReminderIntent.create(
            ReminderTranslation.input(title: "Gießen", recurrence: weekly), in: store.context, geocode: Self.noGeocode
        )
        #expect(task.repeatRule == RepeatRule(frequency: .weekly, interval: 1))
    }

    @Test("Alle Felder außer Bildern und Abschnitt in einem Aufruf ergeben eine vollständige Aufgabe (AC-1)")
    func allElevenFieldsInOneCall() async throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()
        let input = ReminderTranslation.input(
            title: "Steuer abgeben", note: AttributedString("Belege holen"), dueDate: nine(),
            list: ListEntity(id: UUID().uuidString, name: "Büro"),
            recurrence: Calendar.RecurrenceRule(calendar: gregorian, frequency: .weekly),
            locationTrigger: Self.trigger(coordinate: Self.home), urls: [link], isFlagged: true, tags: ["Garten"],
            section: nil, imageCount: 0
        )
        let id = try await CreateReminderIntent.create(input, in: store.context, geocode: Self.noGeocode).id

        // A fresh context reads what reached the store, not the objects still in memory.
        let fresh = ModelContext(store.container)
        let all = try fresh.fetch(FetchDescriptor<TaskItem>())
        #expect(all.count == 1)
        let task = try #require(all.first { $0.id == id })
        #expect(task.rawText == "Steuer abgeben\nBelege holen")
        #expect(task.dueDate == gregorian.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9)))
        #expect(task.dueHasTime == true)
        #expect(task.project?.name == "Büro")
        #expect(task.repeatRule == RepeatRule(frequency: .weekly, interval: 1))
        #expect(task.place == TaskPlace(name: "Zuhause", latitude: 51.99563, longitude: 7.71357, event: .arrive))
        #expect(task.sourceURL == link)
        #expect(task.importance == .high)
        #expect((task.contexts ?? []).map(\.name) == ["Garten"])
    }

    // MARK: AC-2

    @Test("Koordinate wird ohne Geocoder übernommen, auch wenn eine Adresse dabei ist (AC-2)")
    func coordinateBeatsAddress() async throws {
        let store = try TestStore()
        let log = GeocodeLog()
        let task = try await CreateReminderIntent.create(
            ReminderTranslation.input(
                title: "Blumen", locationTrigger: Self.trigger(coordinate: Self.home, address: "Musterweg 1, Ahlen")
            ),
            in: store.context, geocode: geocode(log, answer: SiriCapture.Coordinate(latitude: 1, longitude: 2))
        )
        #expect(task.place == TaskPlace(name: "Zuhause", latitude: 51.99563, longitude: 7.71357, event: .arrive))
        #expect(await log.addresses.isEmpty)
    }

    @Test("Nur Adresse: genau ein Geocoder-Aufruf, der Ort trägt dessen Koordinate und das Ereignis (AC-2)")
    func addressOnlyUsesGeocode() async throws {
        let store = try TestStore()
        let log = GeocodeLog()
        let task = try await CreateReminderIntent.create(
            ReminderTranslation.input(
                title: "Blumen", locationTrigger: Self.trigger(address: "Musterweg 1, Ahlen", event: .depart)
            ),
            in: store.context, geocode: geocode(log, answer: SiriCapture.Coordinate(latitude: 52.1, longitude: 7.9))
        )
        #expect(task.place == TaskPlace(name: "Zuhause", latitude: 52.1, longitude: 7.9, event: .depart))
        #expect(await log.addresses == ["Musterweg 1, Ahlen"])
    }

    // MARK: AC-3

    enum Rejection: String, CaseIterable, Sendable {
        case images = "Bilder"
        case section = "Abschnitt mit Inhalt"
        case emptyTitle = "leerer Titel"
        case twoLinks = "zwei Links"
        case unknownTag = "unbekanntes Tag"
        case unmappableRepeat = "nicht abbildbare Wiederholung"
        case addressWithoutHit = "Adresse ohne Treffer"
        case geocodeThrows = "Geocoder wirft"

        var expected: SiriCaptureError {
            switch self {
            case .images: .unsupported(.images)
            case .section: .unsupported(.section)
            case .emptyTitle: .emptyTitle
            case .twoLinks: .multipleLinks(2)
            case .unknownTag: .unknownTag("Bürro")
            case .unmappableRepeat: .unmappableRepeat([.frequency])
            case .addressWithoutHit, .geocodeThrows: .placeNotFound
            }
        }
    }

    struct GeocodeFailure: Error {}

    /// Every case also carries a new list, a known tag and a flag: none of it may be written.
    private func input(for rejection: Rejection) -> SiriCapture.Input {
        let list = ListEntity(id: UUID().uuidString, name: "Neue Liste")
        func make(
            title: String = "Rasen mähen", urls: [URL] = [], tags: Set<String> = ["Garten"],
            recurrence: Calendar.RecurrenceRule? = nil, locationTrigger: LocationTriggerEntity? = nil,
            section: SectionEntity? = nil, imageCount: Int = 0
        ) -> SiriCapture.Input {
            ReminderTranslation.input(
                title: title, list: list, recurrence: recurrence, locationTrigger: locationTrigger, urls: urls,
                isFlagged: true, tags: tags, section: section, imageCount: imageCount
            )
        }
        return switch rejection {
        case .images: make(imageCount: 1)
        case .section: make(section: SectionEntity(id: "s", name: "Einkauf", list: .inbox))
        case .emptyTitle: make(title: "   ")
        case .twoLinks: make(urls: [URL(string: "https://a.de")!, URL(string: "https://b.de/x")!])
        case .unknownTag: make(tags: ["Garten", "Bürro"])
        case .unmappableRepeat: make(recurrence: Calendar.RecurrenceRule(calendar: gregorian, frequency: .hourly))
        case .addressWithoutHit: make(locationTrigger: Self.trigger(address: "Nirgendwo 1"))
        case .geocodeThrows: make(locationTrigger: Self.trigger(address: "Musterweg 1"))
        }
    }

    @Test("Abgelehnte Angaben werfen den passenden Fehler und hinterlassen weder Aufgabe noch Projekt (AC-3)",
          arguments: Rejection.allCases)
    func rejectedFieldsLeaveNoTask(_ rejection: Rejection) async throws {
        let store = try TestStore()
        store.context.insert(TaskContext(name: "Garten"))
        try store.context.save()
        let fails = rejection == .geocodeThrows
        let geocode: SiriCapture.Geocode = { @Sendable _ in
            if fails { throw GeocodeFailure() }
            return nil
        }

        await #expect(throws: rejection.expected) {
            _ = try await CreateReminderIntent.create(input(for: rejection), in: store.context, geocode: geocode)
        }
        let fresh = ModelContext(store.container)
        #expect(try fresh.fetch(FetchDescriptor<TaskItem>()).isEmpty)
        #expect(try fresh.fetch(FetchDescriptor<Project>()).isEmpty)
    }

    // MARK: AC-4

    @Test("Die Rückgabe-Entität entspricht der angelegten Aufgabe (AC-4)")
    func returnedEntityMatchesTask() async throws {
        let store = try TestStore()
        let task = try await CreateReminderIntent.create(
            ReminderTranslation.input(
                title: "Steuer abgeben", dueDate: nine(), list: ListEntity(id: UUID().uuidString, name: "Büro")
            ),
            in: store.context, geocode: Self.noGeocode
        )
        let entity = ReminderEntity(task: task)
        #expect(entity.id == task.id)
        #expect(entity.title == task.title)
        #expect(entity.list.name == "Büro")
        #expect(entity.dueDate?.day == 20)
        #expect(entity.dueDate?.hour == 9)
    }

    @Test("perform läuft ohne Fehler durch und liefert eine Erinnerung mit dem Titel (AC-4)")
    func performRunsEndToEnd() async throws {
        // Under tests `ModelContainerFactory.make()` hands out a fresh store on every call, so the task
        // itself is only checkable through the core above (see IntentExecutionTests).
        let intent = CreateReminderIntent()
        intent.title = "Heckenschere schärfen"

        let result = try await intent.perform()

        let entity = try #require(result.value)
        #expect(entity.title == TitleRule.title(from: "Heckenschere schärfen", reference: Date()))
    }

    // MARK: AC-5

    @Test("Geocoder nimmt den ersten gültigen Treffer, ohne Treffer oder mit ungültiger Koordinate nil (AC-5)")
    func geocodingPicksFirstValidHit() {
        func item(_ latitude: Double, _ longitude: Double) -> MKMapItem {
            MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: nil)
        }
        #expect(Geocoding.coordinate(in: [item(52.1, 7.9), item(48.1, 11.5)])
                == SiriCapture.Coordinate(latitude: 52.1, longitude: 7.9))
        #expect(Geocoding.coordinate(in: []) == nil)
        #expect(Geocoding.coordinate(in: [item(91, 0)]) == nil)
    }
}
