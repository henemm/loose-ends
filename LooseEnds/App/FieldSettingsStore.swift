import Foundation
import Observation
import OSLog

/// Holds which fields a task offers (#538, rule 7): one choice for the detail, the word line and the
/// start page's groups. Kept in `UserDefaults` and mirrored to the iCloud key-value store, so a switch
/// on one device reaches the others, like the reminder time (#311). Under the UI tests every switch is
/// on, so every editor stays reachable; `--ui-testing-fields-standard` runs them with the standard.
@MainActor @Observable final class FieldSettingsStore {
    static let key = "offeredFields"
    static let standardArgument = "--ui-testing-fields-standard"

    private(set) var settings: DetailFieldSettings
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let cloud: any FieldSettingsCloud
    @ObservationIgnored private var observer: (any NSObjectProtocol)?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Settings")

    init(defaults: UserDefaults = .standard, cloud: any FieldSettingsCloud = NSUbiquitousKeyValueStore.default) {
        self.defaults = defaults
        self.cloud = cloud
        settings = DetailFieldSettings(stored: defaults.stringArray(forKey: Self.key))
    }

    /// The app's own. Under the UI tests a fresh store each launch (their own defaults suite, wiped at
    /// start, no iCloud), so a switch one test flips never reaches the next; everything on unless the
    /// test asks for the standard.
    static func forApp(arguments: [String] = ProcessInfo.processInfo.arguments) -> FieldSettingsStore {
        guard ModelContainerFactory.isUITesting else { return FieldSettingsStore() }
        let suite = "com.henning.looseends.ui-testing-fields"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        let store = FieldSettingsStore(defaults: defaults, cloud: SilentCloud())
        if !arguments.contains(standardArgument) {
            store.settings = .everything
        }
        return store
    }

    /// Starts taking over the other devices' choice; nothing under tests.
    func activate() {
        guard !ModelContainerFactory.isRunningTests, !ModelContainerFactory.isUITesting, observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.takeCloud() }
        }
        takeCloud()
    }

    func set(_ field: DetailField, on: Bool) {
        guard !field.isFixed, settings.isOn(field) != on else { return }
        settings = settings.setting(field, on: on)
        defaults.set(settings.stored, forKey: Self.key)
        cloud.setOfferedFields(settings.stored)
    }

    /// Another device chose (or this launch is the first to see it): take it over. Returns whether
    /// the local choice changed.
    @discardableResult
    func takeCloud() -> Bool {
        guard let stored = cloud.offeredFields else { return false }
        let next = DetailFieldSettings(stored: stored)
        guard next != settings else { return false }
        settings = next
        defaults.set(stored, forKey: Self.key)
        return true
    }
}

/// The part of the iCloud key-value store the field settings use; unit tests hand in their own.
@MainActor
protocol FieldSettingsCloud {
    var offeredFields: [String]? { get }
    func setOfferedFields(_ fields: [String])
}

/// No iCloud under the UI tests: nothing read, nothing written.
@MainActor
private final class SilentCloud: FieldSettingsCloud {
    var offeredFields: [String]? { nil }
    func setOfferedFields(_ fields: [String]) {}
}

extension NSUbiquitousKeyValueStore: FieldSettingsCloud {
    var offeredFields: [String]? { array(forKey: FieldSettingsStore.key) as? [String] }

    func setOfferedFields(_ fields: [String]) {
        set(fields, forKey: FieldSettingsStore.key)
    }
}
