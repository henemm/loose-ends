import Foundation
import Testing
@testable import LooseEnds

/// The store behind home and work (#241, Schnitt 3b): defaults, iCloud key-value store, other devices.
@Suite("SavedPlacesStore (#241)") struct SavedPlacesStoreTests {
    @MainActor
    final class Cloud: SavedPlacesCloud {
        var savedPlaces: Data?
        func setSavedPlaces(_ data: Data?) { savedPlaces = data }
    }

    @MainActor
    private func fixture() throws -> (store: SavedPlacesStore, defaults: UserDefaults, cloud: Cloud) {
        let defaults = try #require(UserDefaults(suiteName: "SavedPlacesStoreTests-\(UUID().uuidString)"))
        let cloud = Cloud()
        return (SavedPlacesStore(defaults: defaults, cloud: cloud), defaults, cloud)
    }

    private func spot(_ name: String) throws -> SavedPlaces.Spot {
        try #require(SavedPlaces.Spot(name: name, latitude: 53.55, longitude: 9.93))
    }

    @Test("Nothing stored is empty; setting a slot writes the defaults and iCloud")
    @MainActor func setWrites() throws {
        let (store, defaults, cloud) = try fixture()
        #expect(store.places == .empty)
        let home = try spot("Zuhause")
        store.set(.home, to: home)
        #expect(store.places.spot(.home) == home)
        #expect(SavedPlaces.decode(defaults.data(forKey: SavedPlacesStore.key)).spot(.home) == home)
        #expect(SavedPlaces.decode(cloud.savedPlaces).spot(.home) == home)
        let fresh = SavedPlacesStore(defaults: defaults, cloud: cloud)
        #expect(fresh.places.spot(.home) == home, "read back from the defaults")
    }

    @Test("Another device's value is taken over; the same value again reports no change")
    @MainActor func takeCloudAdoptsOtherDevicesValue() throws {
        let (store, defaults, cloud) = try fixture()
        let work = try spot("Büro")
        cloud.savedPlaces = SavedPlaces.empty.setting(.work, to: work).encoded
        #expect(store.takeCloud())
        #expect(store.places.spot(.work) == work)
        #expect(SavedPlaces.decode(defaults.data(forKey: SavedPlacesStore.key)).spot(.work) == work)
        #expect(store.takeCloud() == false)
    }

    @Test("The last writer wins; no merge of two values")
    @MainActor func lastWriterWins() throws {
        let (store, _, cloud) = try fixture()
        store.set(.home, to: try spot("Hier"))
        cloud.savedPlaces = SavedPlaces.empty.setting(.home, to: try spot("Dort")).encoded
        #expect(store.takeCloud())
        #expect(store.places.spot(.home)?.name == "Dort")
        #expect(store.places.spot(.work) == nil)
    }
}
