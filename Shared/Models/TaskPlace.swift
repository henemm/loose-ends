import Foundation

/// Where a task reminds: one point on the map and whether arriving or leaving counts (#226).
/// Whole or not at all: a name without a coordinate would remind nowhere. Set only by the user or
/// by Siri, never guessed.
struct TaskPlace: Codable, Hashable, Sendable {
    enum Event: String, Codable, CaseIterable, Sendable { case arrive, depart }

    /// Fixed (Henning, 2026-10-06, F6); Siri hands over none.
    static let radius: Double = 150

    let name: String
    let latitude: Double
    let longitude: Double
    let event: Event

    private enum CodingKeys: String, CodingKey { case name, latitude, longitude, event }

    init?(name: String, latitude: Double, longitude: Double, event: Event) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
        self.name = trimmed
        self.latitude = latitude
        self.longitude = longitude
        self.event = event
    }

    /// Decoding runs through the same checks: a stored value that would fail them reads as no place.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let place = TaskPlace(
            name: try container.decode(String.self, forKey: .name),
            latitude: try container.decode(Double.self, forKey: .latitude),
            longitude: try container.decode(Double.self, forKey: .longitude),
            event: try container.decode(Event.self, forKey: .event)
        ) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid place"))
        }
        self = place
    }
}
