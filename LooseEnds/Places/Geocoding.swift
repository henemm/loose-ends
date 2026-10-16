import CoreLocation
import Foundation
import MapKit

/// Address to coordinate for Siri's places without one (#25 Schnitt 2b-1). Needs no location permission.
enum Geocoding {
    /// An unusable address or no hit gives nil (`SiriCapture` makes that `placeNotFound`); network errors go up.
    static let live: SiriCapture.Geocode = { address in
        guard let request = MKGeocodingRequest(addressString: address) else { return nil }
        let items = try await request.mapItems
        return coordinate(in: items)
    }

    /// The first hit with a valid coordinate; MapKit sorts by relevance.
    static func coordinate(in items: [MKMapItem]) -> SiriCapture.Coordinate? {
        items.lazy
            .map(\.location.coordinate)
            .first(where: CLLocationCoordinate2DIsValid)
            .map { SiriCapture.Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
