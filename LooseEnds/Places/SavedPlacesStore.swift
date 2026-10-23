import Foundation
import Observation
import OSLog

/// Holds home and work (#241, Schnitt 3b). Kept in `UserDefaults` and mirrored to the iCloud key-value
/// store under one key, so a slot set on one device reaches the others, like the field settings (#538).
/// The last writer wins; two values are never merged. Under the UI tests a fresh store each launch
/// (own defaults suite, wiped at start, no iCloud).
@MainActor @Observable final class SavedPlacesStore {
    static let key = "savedPlaces"

    private(set) var places: SavedPlaces
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let cloud: any SavedPlacesCloud
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init(defaults: UserDefaults = .standard, cloud: any SavedPlacesCloud = NSUbiquitousKeyValueStore.default) {
        self.defaults = defaults
        self.cloud = cloud
        places = SavedPlaces.decode(defaults.data(forKey: Self.key))
    }

    /// The app's one store, made on first use and taking over the other devices' value from then on.
    static let shared: SavedPlacesStore = {
        let store = forApp()
        store.activate()
        return store
    }()

    private static func forApp() -> SavedPlacesStore {
        guard ModelContainerFactory.isUITesting else { return SavedPlacesStore() }
        let suite = "com.henning.looseends.ui-testing-saved-places"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return SavedPlacesStore(defaults: defaults, cloud: SilentSavedPlacesCloud())
    }

    /// Starts taking over the other devices' value; nothing under tests.
    func activate() {
        guard !ModelContainerFactory.isRunningTests, !ModelContainerFactory.isUITesting, observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.takeCloud() }
        }
        takeCloud()
    }

    /// Sets or clears one slot. Never touches a task.
    func set(_ slot: SavedPlaces.Slot, to spot: SavedPlaces.Spot?) {
        let next = places.setting(slot, to: spot)
        guard next != places else { return }
        places = next
        let data = next.encoded
        defaults.set(data, forKey: Self.key)
        cloud.setSavedPlaces(data)
    }

    /// Another device wrote (or this launch is the first to see it): take it over. Returns whether the
    /// local value changed.
    @discardableResult
    func takeCloud() -> Bool {
        guard let data = cloud.savedPlaces else { return false }
        let next = SavedPlaces.decode(data)
        guard next != places else { return false }
        places = next
        defaults.set(data, forKey: Self.key)
        return true
    }
}

/// The part of the iCloud key-value store home and work use; unit tests hand in their own.
@MainActor
protocol SavedPlacesCloud {
    var savedPlaces: Data? { get }
    func setSavedPlaces(_ data: Data?)
}

/// No iCloud under the UI tests: nothing read, nothing written.
@MainActor
private final class SilentSavedPlacesCloud: SavedPlacesCloud {
    var savedPlaces: Data? { nil }
    func setSavedPlaces(_ data: Data?) {}
}

extension NSUbiquitousKeyValueStore: SavedPlacesCloud {
    var savedPlaces: Data? { data(forKey: SavedPlacesStore.key) }

    func setSavedPlaces(_ data: Data?) {
        if let data {
            set(data, forKey: SavedPlacesStore.key)
        } else {
            removeObject(forKey: SavedPlacesStore.key)
        }
    }
}
