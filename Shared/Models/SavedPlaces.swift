import Foundation
import OSLog

/// Home and work, set once by the user and offered at the top of the place sheet (#241, Schnitt 3b).
/// A plain value kept in the iCloud key-value store, not a model: two places need no schema. A slot
/// never reaches into tasks: a task that carries its place keeps it when the slot changes.
struct SavedPlaces: Codable, Equatable, Sendable {
    enum Slot: String, CaseIterable, Sendable { case home, work }

    /// One saved place: name and coordinate, no event (the task decides arrive or leave).
    struct Spot: Codable, Equatable, Sendable {
        let name: String
        let latitude: Double
        let longitude: Double

        private enum CodingKeys: String, CodingKey { case name, latitude, longitude }

        init?(name: String, latitude: Double, longitude: Double) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }
            self.name = trimmed
            self.latitude = latitude
            self.longitude = longitude
        }

        /// Decoding runs through the same checks: an impossible stored spot fails the whole value.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            guard let spot = Spot(
                name: try container.decode(String.self, forKey: .name),
                latitude: try container.decode(Double.self, forKey: .latitude),
                longitude: try container.decode(Double.self, forKey: .longitude)
            ) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid spot"))
            }
            self = spot
        }
    }

    private(set) var home: Spot?
    private(set) var work: Spot?

    static let empty = SavedPlaces(home: nil, work: nil)
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Place")

    func spot(_ slot: Slot) -> Spot? {
        switch slot {
        case .home: home
        case .work: work
        }
    }

    /// The other slot stays; nil clears this one.
    func setting(_ slot: Slot, to spot: Spot?) -> SavedPlaces {
        var next = self
        switch slot {
        case .home: next.home = spot
        case .work: next.work = spot
        }
        return next
    }

    /// The slot as a task's place with the asked event; nil while the slot is empty.
    func place(_ slot: Slot, event: TaskPlace.Event) -> TaskPlace? {
        guard let spot = spot(slot) else { return nil }
        return TaskPlace(name: spot.name, latitude: spot.latitude, longitude: spot.longitude, event: event)
    }

    var encoded: Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        do {
            return try encoder.encode(self)
        } catch {
            Self.logger.error("Encoding saved places failed: \(error, privacy: .public)")
            return Data()
        }
    }

    /// Missing or damaged data reads as nothing saved.
    static func decode(_ data: Data?) -> SavedPlaces {
        guard let data else { return .empty }
        do {
            return try JSONDecoder().decode(SavedPlaces.self, from: data)
        } catch {
            logger.error("Saved places unreadable, reading as empty: \(error, privacy: .public)")
            return .empty
        }
    }
}
