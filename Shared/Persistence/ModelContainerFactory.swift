import Foundation
import OSLog
import SwiftData

enum LooseEndsSchema {
    static let models: [any PersistentModel.Type] = [
        TaskItem.self, TaskContext.self, Project.self, Revision.self, CompletionRecord.self, SavedView.self,
    ]
}

enum ModelContainerFactory {
    static let appGroup = "group.com.henning.looseends"
    static let cloudContainer = "iCloud.com.henning.looseends"

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
    /// Test hosts get an in-memory store so tests never touch real data. Builds without the
    /// app-group entitlement (unsigned CI builds) fall back to a plain local store so the app
    /// still launches; sync is simply off in that case.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(LooseEndsSchema.models)
        if inMemory || isRunningTests || isUITesting {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        }
        return try cache.value {
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
