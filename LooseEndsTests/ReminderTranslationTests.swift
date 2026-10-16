import CoreLocation
import Foundation
import GeoToolbox
import SwiftData
import Testing
@testable import LooseEnds

/// Siri's SDK types onto `SiriCapture.Input` (#25 Schnitt 2a): a pure translation, no container.
/// Two tests also run the result through `prepare`/`commit`, so the chain is proven, not just the half step.
@Suite("Reminders-Übersetzung (#25 Schnitt 2a)")
@MainActor
struct ReminderTranslationTests {
    private let gregorian = Calendar(identifier: .gregorian)
    private let link = URL(string: "https://a.de/x")!
    private let otherLink = URL(string: "https://b.de")!

    private func day(_ hour: Int? = nil, minute: Int? = nil, calendar: Calendar? = nil) -> DateComponents {
        DateComponents(calendar: calendar ?? gregorian, year: 2026, month: 10, day: 20, hour: hour, minute: minute)
    }

    private func place(
        name: String? = nil, coordinate: CLLocationCoordinate2D? = nil, address: String? = nil,
        event: LocationTriggerEvent = .arrive
    ) -> LocationTriggerEntity {
        var representations: [PlaceDescriptor.PlaceRepresentation] = []
        if let coordinate { representations.append(.coordinate(coordinate)) }
        if let address { representations.append(.address(address)) }
        return LocationTriggerEntity(
            id: "t", place: PlaceDescriptor(representations: representations, commonName: name), event: event
        )
    }

    // MARK: AC-1

    @Test("Titel und Notiz kommen als einfacher Text an, leere Notiz wird nil (AC-1)")
    func titleAndNoteTranslate() {
        let input = ReminderTranslation.input(title: "Steuer", note: AttributedString("Belege holen"))
        #expect(input.title == "Steuer")
        #expect(input.notes == "Belege holen")
        #expect(ReminderTranslation.input(title: "Steuer", note: AttributedString("")).notes == nil)
        #expect(ReminderTranslation.input(title: "Steuer", note: nil).notes == nil)
    }

    // MARK: AC-2, AC-3

    @Test("Ohne Stunde: Tag um 00:00, keine Uhrzeit (AC-2)")
    func dateWithoutTimeHasNoTime() {
        let input = ReminderTranslation.input(title: "x", dueDate: day())
        #expect(input.due == gregorian.date(from: DateComponents(year: 2026, month: 10, day: 20)))
        #expect(input.dueHasTime == false)
    }

    @Test("Mit Stunde, ohne Minute: Uhrzeit, Minute 0 (AC-2)")
    func dateWithHourHasTime() {
        let input = ReminderTranslation.input(title: "x", dueDate: day(9))
        #expect(input.due == gregorian.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9, minute: 0)))
        #expect(input.dueHasTime == true)
    }

    @Test("Die Zeitzone der DateComponents gilt, nicht die des Geräts (Risiko 4)")
    func calendarOfTheComponentsWins() throws {
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let input = ReminderTranslation.input(title: "x", dueDate: day(9, minute: 30, calendar: tokyo))
        let expected = tokyo.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9, minute: 30))
        #expect(input.due == expected)
    }

    @Test("Unvollständiges Datum ergibt kein Datum und keinen Fehler (AC-3)", arguments: [
        DateComponents(month: 10, day: 20, hour: 9),
        DateComponents(year: 2026, day: 20),
        DateComponents(year: 2026, month: 10),
        DateComponents(hour: 9),
    ])
    func incompleteDateIsDropped(parts: DateComponents) {
        let input = ReminderTranslation.input(title: "x", dueDate: parts)
        #expect(input.due == nil)
        #expect(input.dueHasTime == false)
    }

    // MARK: AC-4

    @Test("Listenname nur für echte Projekte, Eingang und keine Liste ergeben nil (AC-4)")
    func listNameFromList() {
        let office = ListEntity(id: UUID().uuidString, name: "Büro")
        #expect(ReminderTranslation.input(title: "x", list: office).listName == "Büro")
        #expect(ReminderTranslation.input(title: "x", list: .inbox).listName == nil)
        #expect(ReminderTranslation.input(title: "x", list: nil).listName == nil)
    }

    // MARK: AC-5

    @Test("Koordinate vor Adresse, die Adresse bleibt als Zusatz (AC-5)")
    func coordinateBeatsAddress() throws {
        let trigger = place(
            name: "Zuhause", coordinate: CLLocationCoordinate2D(latitude: 51.99563, longitude: 7.71357),
            address: "Musterweg 1, Ahlen"
        )
        let result = try #require(ReminderTranslation.input(title: "x", locationTrigger: trigger).place)
        #expect(result.coordinate == SiriCapture.Coordinate(latitude: 51.99563, longitude: 7.71357))
        #expect(result.address == "Musterweg 1, Ahlen")
        #expect(result.name == "Zuhause")
    }

    @Test("Nur Adresse: keine Koordinate, die Adresse bleibt (AC-5)")
    func addressOnlyKeepsAddress() throws {
        let result = try #require(ReminderTranslation.input(
            title: "x", locationTrigger: place(address: "Musterweg 1, Ahlen")
        ).place)
        #expect(result.coordinate == nil)
        #expect(result.address == "Musterweg 1, Ahlen")
        #expect(result.name == nil)
    }

    @Test("Ankommen und Verlassen werden zu arrive und depart (AC-5)")
    func eventMaps() {
        let coordinate = CLLocationCoordinate2D(latitude: 1, longitude: 2)
        let arrive = ReminderTranslation.input(title: "x", locationTrigger: place(coordinate: coordinate, event: .arrive))
        let depart = ReminderTranslation.input(title: "x", locationTrigger: place(coordinate: coordinate, event: .depart))
        #expect(arrive.place?.event == .arrive)
        #expect(depart.place?.event == .depart)
        #expect(ReminderTranslation.input(title: "x").place == nil)
    }

    // MARK: AC-6

    @Test("Markierung, Tags und Links kommen unverändert an, Tags als Menge (AC-6)")
    func flagTagsUrlsPassThrough() {
        let input = ReminderTranslation.input(
            title: "x", urls: [link, otherLink], isFlagged: true, tags: ["a", "b"]
        )
        #expect(input.isFlagged == true)
        #expect(Set(input.tags) == ["a", "b"])
        #expect(input.urls == [link, otherLink])
        #expect(ReminderTranslation.input(title: "x").isFlagged == nil)
    }

    @Test("Wiederholung wird unverändert durchgereicht (AC-6)")
    func recurrencePassesThrough() {
        let weekly = Calendar.RecurrenceRule(calendar: gregorian, frequency: .weekly)
        #expect(ReminderTranslation.input(title: "x", recurrence: weekly).recurrence == weekly)
    }

    @Test("Abschnitt mit Inhalt und Bilder erreichen SiriCapture und werden dort abgelehnt (AC-6)")
    func sectionAndImagesReachSiriCapture() async throws {
        let store = try TestStore()
        let section = SectionEntity(id: "s", name: "X", list: .inbox)
        let withSection = ReminderTranslation.input(title: "x", section: section)
        #expect(withSection.section == "X")
        await #expect(throws: SiriCaptureError.unsupported(.section)) {
            _ = try await SiriCapture.prepare(withSection, in: store.context, geocode: { _ in nil })
        }
        let withImages = ReminderTranslation.input(title: "x", imageCount: 2)
        #expect(withImages.imageCount == 2)
        await #expect(throws: SiriCaptureError.unsupported(.images)) {
            _ = try await SiriCapture.prepare(withImages, in: store.context, geocode: { _ in nil })
        }
        #expect(try store.context.fetch(FetchDescriptor<TaskItem>()).isEmpty)
    }

    // MARK: AC-7

    @Test("Vollständig übersetzte Eingabe ergibt über prepare und commit genau eine Aufgabe (AC-7)")
    func translatedInputRunsThroughSiriCapture() async throws {
        let store = try TestStore()
        let input = ReminderTranslation.input(
            title: "Steuer abgeben", note: AttributedString("Belege holen"), dueDate: day(9),
            list: ListEntity(id: UUID().uuidString, name: "Büro"),
            locationTrigger: place(
                name: "Zuhause", coordinate: CLLocationCoordinate2D(latitude: 51.99563, longitude: 7.71357)
            )
        )
        let prepared = try await SiriCapture.prepare(input, in: store.context, geocode: { _ in nil })
        let task = try SiriCapture.commit(prepared, in: store.context)

        let all = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(all.count == 1)
        #expect(task.rawText == "Steuer abgeben\nBelege holen")
        #expect(task.dueDate == gregorian.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9)))
        #expect(task.dueHasTime == true)
        #expect(task.project?.name == "Büro")
        #expect(task.place == TaskPlace(name: "Zuhause", latitude: 51.99563, longitude: 7.71357, event: .arrive))
    }
}
