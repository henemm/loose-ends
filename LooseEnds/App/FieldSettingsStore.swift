import Foundation
import Observation
import OSLog

/// Holds which fields a task offers (#538, rule 7): one choice for the detail, the word line and the
/// start page's groups. Kept in `UserDefaults` and mirrored to the iCloud key-value store, so a switch
/// on one device reaches the others, like the reminder time (#311). Under the UI tests every switch is
/// on, so every editor stays reachable; `--ui-testing-fields-standard` runs them with the standard.
@MainActor @Observable final class FieldSettingsStore {
    static let key = "offeredFields"
    /// "Dafür" (#647): one free sentence for the week, kept like the switches.
    static let rewardKey = "weekReward"
    /// "Perlen je Schnur" (#824): how many beads fill a string.
    static let stringLengthKey = "beadsPerString"
    /// "Neue Schnur beginnen" (#825): the moment of the last confirmation of a full string.
    static let stringSinceKey = "beadsStringSince"
    static let standardArgument = "--ui-testing-fields-standard"

    private(set) var settings: DetailFieldSettings
    /// "Dafür: Samstag Kino." without the "Dafür"; empty means no line.
    private(set) var reward: String
    /// Beads that fill a string (#824), always within `ViewRules.stringLengths`; five until set.
    private(set) var stringLength: Int
    /// When the user last confirmed a full string (#825); only beads after it count. Nil: never.
    private(set) var stringSince: Date?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let cloud: any FieldSettingsCloud
    @ObservationIgnored private var observer: (any NSObjectProtocol)?
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Settings")

    init(defaults: UserDefaults = .standard, cloud: any FieldSettingsCloud = NSUbiquitousKeyValueStore.default) {
        self.defaults = defaults
        self.cloud = cloud
        settings = DetailFieldSettings(stored: defaults.stringArray(forKey: Self.key))
        reward = defaults.string(forKey: Self.rewardKey) ?? ""
        stringLength = Self.length(defaults.integer(forKey: Self.stringLengthKey))
        stringSince = defaults.object(forKey: Self.stringSinceKey) as? Date
    }

    /// A stored or handed-in count held to the allowed range; zero (never set) is the standard.
    private static func length(_ stored: Int) -> Int {
        guard stored != 0 else { return ViewRules.stringLength }
        return min(max(stored, ViewRules.stringLengths.lowerBound), ViewRules.stringLengths.upperBound)
    }

    /// The app's own. Under the UI tests a fresh store each launch (their own defaults suite, wiped at
    /// start, no iCloud), so a switch one test flips never reaches the next; everything on unless the
    /// test asks for the standard. Outside them it reads the defaults handed in, so a unit test can pass
    /// its own suite instead of the app's (#638).
    static func forApp(
        arguments: [String] = ProcessInfo.processInfo.arguments, defaults: UserDefaults = .standard
    ) -> FieldSettingsStore {
        guard ModelContainerFactory.isUITesting else { return FieldSettingsStore(defaults: defaults) }
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

    /// "Dafür" (#647): trimmed, nothing checked; the same sentence again writes nothing.
    func setReward(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != reward else { return }
        reward = trimmed
        defaults.set(trimmed, forKey: Self.rewardKey)
        cloud.setWeekReward(trimmed)
    }

    /// "Perlen je Schnur" (#824): held to 3...20; the same number again writes nothing. The beads
    /// are not touched: the string is read from them with the new length (`ViewRules.currentString`).
    func setStringLength(_ count: Int) {
        let next = Self.length(count)
        guard next != stringLength else { return }
        stringLength = next
        defaults.set(next, forKey: Self.stringLengthKey)
        cloud.setBeadsPerString(next)
    }

    /// "Neue Schnur beginnen" (#825): the full string is confirmed, the count starts empty. The mark
    /// never moves back (a device with a slow clock), and the later of two devices' taps wins.
    func beginNewString(now: Date = Date()) {
        let next = max(now, stringSince ?? now)
        stringSince = next
        defaults.set(next, forKey: Self.stringSinceKey)
        cloud.setStringSince(next)
    }

    /// Another device chose (or this launch is the first to see it): take it over, the switches,
    /// "Dafür" and the string's length alike. Returns whether anything local changed.
    @discardableResult
    func takeCloud() -> Bool {
        var changed = false
        if let stored = cloud.offeredFields {
            let next = DetailFieldSettings(stored: stored)
            if next != settings {
                settings = next
                defaults.set(stored, forKey: Self.key)
                changed = true
            }
        }
        if let text = cloud.weekReward, text != reward {
            reward = text
            defaults.set(text, forKey: Self.rewardKey)
            changed = true
        }
        if let count = cloud.beadsPerString {
            let next = Self.length(count)
            if next != stringLength {
                stringLength = next
                defaults.set(next, forKey: Self.stringLengthKey)
                changed = true
            }
        }
        if let date = cloud.stringSince, date > (stringSince ?? .distantPast) {
            stringSince = date
            defaults.set(date, forKey: Self.stringSinceKey)
            changed = true
        }
        return changed
    }
}

/// The part of the iCloud key-value store the field settings use; unit tests hand in their own.
@MainActor
protocol FieldSettingsCloud {
    var offeredFields: [String]? { get }
    func setOfferedFields(_ fields: [String])
    var weekReward: String? { get }
    func setWeekReward(_ text: String)
    var beadsPerString: Int? { get }
    func setBeadsPerString(_ count: Int)
    var stringSince: Date? { get }
    func setStringSince(_ date: Date)
}

/// No iCloud under the UI tests: nothing read, nothing written.
@MainActor
private final class SilentCloud: FieldSettingsCloud {
    var offeredFields: [String]? { nil }
    func setOfferedFields(_ fields: [String]) {}
    var weekReward: String? { nil }
    func setWeekReward(_ text: String) {}
    var beadsPerString: Int? { nil }
    func setBeadsPerString(_ count: Int) {}
    var stringSince: Date? { nil }
    func setStringSince(_ date: Date) {}
}

extension NSUbiquitousKeyValueStore: FieldSettingsCloud {
    var offeredFields: [String]? { array(forKey: FieldSettingsStore.key) as? [String] }

    func setOfferedFields(_ fields: [String]) {
        set(fields, forKey: FieldSettingsStore.key)
    }

    var weekReward: String? { string(forKey: FieldSettingsStore.rewardKey) }

    func setWeekReward(_ text: String) {
        set(text, forKey: FieldSettingsStore.rewardKey)
    }

    /// Absent reads as nil (an `Int64` of 0 is "never set"), so a device that never chose follows the others.
    var beadsPerString: Int? {
        object(forKey: FieldSettingsStore.stringLengthKey) == nil ? nil : Int(longLong(forKey: FieldSettingsStore.stringLengthKey))
    }

    func setBeadsPerString(_ count: Int) {
        set(Int64(count), forKey: FieldSettingsStore.stringLengthKey)
    }

    /// Stored as seconds since the reference date; absent reads as nil.
    var stringSince: Date? {
        object(forKey: FieldSettingsStore.stringSinceKey) == nil
            ? nil : Date(timeIntervalSinceReferenceDate: double(forKey: FieldSettingsStore.stringSinceKey))
    }

    func setStringSince(_ date: Date) {
        set(date.timeIntervalSinceReferenceDate, forKey: FieldSettingsStore.stringSinceKey)
    }
}
