import Foundation
import MapKit

/// One hit of the place search: what the sheet lists and what becomes the task's place.
struct PlaceHit: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let locality: String?
    let latitude: Double
    let longitude: Double

    /// "Bauhaus, Hamburg-Altona": the locality only when the name does not already carry it.
    var placeName: String {
        guard let locality, !locality.isEmpty, !name.localizedCaseInsensitiveContains(locality) else { return name }
        return "\(name), \(locality)"
    }

    func place(_ event: TaskPlace.Event) -> TaskPlace? {
        TaskPlace(name: placeName, latitude: latitude, longitude: longitude, event: event)
    }
}

/// Addresses and businesses for the place sheet (#241). Needs no location permission.
protocol PlaceSearching: Sendable {
    func places(matching query: String) async throws -> [PlaceHit]
}

enum PlaceSearch {
    /// UI tests run without network and without Apple's search service: they get fixed hits.
    static var current: any PlaceSearching {
        ModelContainerFactory.isUITesting ? FixedPlaceSearch() : MapKitPlaceSearch()
    }
}

struct MapKitPlaceSearch: PlaceSearching {
    func places(matching query: String) async throws -> [PlaceHit] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.enumerated().compactMap { index, item in
            let coordinate = item.location.coordinate
            guard let name = item.name, CLLocationCoordinate2DIsValid(coordinate) else { return nil }
            return PlaceHit(
                id: "\(index)-\(name)",
                name: name,
                locality: item.addressRepresentations?.cityName,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
        }
    }
}

struct FixedPlaceSearch: PlaceSearching {
    static let hits = [
        PlaceHit(id: "altona", name: "Bauhaus", locality: "Hamburg-Altona", latitude: 53.5561, longitude: 9.9285),
        PlaceHit(id: "wandsbek", name: "Bauhaus", locality: "Hamburg-Wandsbek", latitude: 53.5713, longitude: 10.0703),
    ]

    func places(matching query: String) async throws -> [PlaceHit] {
        Self.hits.filter { $0.placeName.localizedCaseInsensitiveContains(query) }
    }
}
