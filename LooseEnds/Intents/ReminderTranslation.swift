import Foundation
import GeoToolbox

/// Siri's reminder fields (SDK types of the reminders schema) onto `SiriCapture.Input` (#25 Schnitt 2a).
/// Pure: no container, no checks. Rejecting is `SiriCapture.prepare`'s job.
enum ReminderTranslation {
    static func input(
        title: String,
        note: AttributedString? = nil,
        dueDate: DateComponents? = nil,
        list: ListEntity? = nil,
        recurrence: Calendar.RecurrenceRule? = nil,
        locationTrigger: LocationTriggerEntity? = nil,
        urls: [URL] = [],
        isFlagged: Bool? = nil,
        tags: Set<String> = [],
        section: SectionEntity? = nil,
        imageCount: Int = 0
    ) -> SiriCapture.Input {
        var input = SiriCapture.Input(title: title)
        let notes = note.map { String($0.characters) } ?? ""
        input.notes = notes.isEmpty ? nil : notes
        if let dueDate, let due = date(from: dueDate) {
            input.due = due
            input.dueHasTime = dueDate.hour != nil
        }
        input.listName = list.flatMap { $0.id == ListEntity.inboxID ? nil : $0.name }
        input.recurrence = recurrence
        input.place = locationTrigger.map(place(from:))
        input.urls = urls
        input.isFlagged = isFlagged
        input.tags = Array(tags)
        input.section = section?.name
        input.imageCount = imageCount
        return input
    }

    /// Year, month and day are required, otherwise no date (and no error, spec 2a). With an hour the
    /// time counts (a missing minute is 0); without, midnight. Siri's calendar and time zone win.
    static func date(from parts: DateComponents) -> Date? {
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        var calendar = parts.calendar ?? Calendar.current
        if let timeZone = parts.timeZone { calendar.timeZone = timeZone }
        let hour = parts.hour
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour ?? 0, minute: hour == nil ? 0 : parts.minute ?? 0
        ))
    }

    /// The coordinate comes before the address; the address stays as an addition.
    static func place(from trigger: LocationTriggerEntity) -> SiriCapture.Place {
        let coordinate = trigger.place.coordinate.map {
            SiriCapture.Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        let event: TaskPlace.Event = switch trigger.event {
        case .arrive: .arrive
        case .depart: .depart
        }
        return SiriCapture.Place(
            name: trigger.place.commonName, address: trigger.place.address, coordinate: coordinate, event: event
        )
    }
}
