import Foundation
import OSLog
import SwiftData

enum LooseEndsSchema {
    static let models: [any PersistentModel.Type] = [
        TaskItem.self, TaskContext.self, Project.self, Revision.self, CompletionRecord.self, SavedView.self,
    ]
}

enum ModelContainerFactory {
    // Internal, not private: Swift forbids a private value as the default argument of an internal function.
    static let fallbackAppGroup = "group.com.henning.looseends"
    static let fallbackCloudContainer = "iCloud.com.henning.looseends"

    /// Reads app group and CloudKit container from the bundle (`LEAppGroup`, `LECloudContainer`),
    /// so a probe build (#156, ADR-18) carries its own and never reaches the production data.
    /// A missing key falls back to the production identifier and is logged, never silent.
    static func resolveIdentifiers(
        from infoDictionary: [String: Any]?,
        fallbackGroup: String = fallbackAppGroup,
        fallbackContainer: String = fallbackCloudContainer
    ) -> (group: String, container: String) {
        let group = infoDictionary?["LEAppGroup"] as? String
        let container = infoDictionary?["LECloudContainer"] as? String
        if group == nil { logger.error("LEAppGroup fehlt im Info-Dictionary, Rückfall auf Konstante") }
        if container == nil { logger.error("LECloudContainer fehlt im Info-Dictionary, Rückfall auf Konstante") }
        return (group ?? fallbackGroup, container ?? fallbackContainer)
    }

    /// Resolved once per process: the bundle does not change at runtime.
    private static let identifiers = resolveIdentifiers(from: Bundle.main.infoDictionary)
    static let appGroup = identifiers.group
    static let cloudContainer = identifiers.container

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Persistence")
    private static let cache = ProcessCache<ModelContainer>()

    /// True while the process hosts a test bundle (xcodebuild test launches the app with this variable).
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// UI tests launch the app with this argument so they never touch real data.
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }

    /// Production container: app group store, private CloudKit database (ADR-2). One per process.
    ///
    /// CloudKit forbids a second live mirroring delegate for the same store in one process — it
    /// tears the store down with "Illegal attempt to register a second handler for activity
    /// identifier...". `CaptureTextIntent` has no extension target of its own, so it runs in the
    /// main app's process when that's already alive; without caching, its own call here raced the
    /// app's own container for the exact same store and crashed the sync every time (#50). So the
    /// real (non-test) container is built once per process and reused.
    ///
    /// Test hosts get an in-memory store so tests never touch real data, and it never syncs: the
    /// configuration's default `cloudKitDatabase` is `.automatic`, which mirrors even an in-memory
    /// store into the iCloud container of the entitlements. A signed device run under `--ui-testing`
    /// (2026-09-30, #153, then still under the production identifier) did exactly that: it pulled the
    /// user's German contexts into the test and pushed the English defaults into the user's iCloud
    /// ("Garden, Garten, Garden", #163). Builds without the
    /// app-group entitlement (unsigned CI builds) fall back to a plain local store so the app
    /// still launches; sync is simply off in that case.
    ///
    /// The entitlement check happens before touching SwiftData: `ModelContainer(for:configurations:)`
    /// doesn't throw a catchable error when the app-group entitlement is missing, it hits a
    /// `fatalError` deep inside SwiftData (#55) — a `do/catch` around it can't help.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(LooseEndsSchema.models)
        if inMemory || isRunningTests || isUITesting {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
        return try cache.value {
            guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil else {
                logger.error("App-group entitlement unavailable, using local store without sync")
                let fallback = ModelConfiguration("LooseEnds", schema: schema, groupContainer: .none, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: [fallback])
            }
            do {
                let configuration = ModelConfiguration(
                    "LooseEnds",
                    schema: schema,
                    groupContainer: .identifier(appGroup),
                    cloudKitDatabase: .private(cloudContainer)
                )
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                logger.error("App-group store unavailable, using local store without sync: \(error, privacy: .public)")
                let fallback = ModelConfiguration("LooseEnds", schema: schema, groupContainer: .none, cloudKitDatabase: .none)
                return try ModelContainer(for: schema, configurations: [fallback])
            }
        }
    }
}
