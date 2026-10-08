#if DEBUG
import CoreData
import Foundation
import OSLog
import SwiftData

/// Creates the full CloudKit schema of the model in the Development environment (#175).
///
/// Development only learns a record type or field when a record writes it with a value, so the
/// schema there lacked three types and eleven task fields. Deploying that to Production would break
/// every TestFlight sync the moment a missing field gets its first value. Apple's own generator
/// (`initializeCloudKitSchema`) writes every type and field of the model instead.
///
/// It never opens the app-group store and never goes through `ModelContainerFactory`: the factory
/// holds one live mirror per process (#50), and CloudKit forbids a second one for the same store.
/// So it works on a throwaway store in the temporary directory. Debug builds only.
enum CloudKitSchemaInitializer {
    static let launchArgument = "-LEInitializeCloudKitSchema"

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Persistence")

    /// True only for the argument in a debug build outside tests: a test run must never write
    /// into the user's CloudKit, even when the argument leaks in.
    static func shouldRun(arguments: [String], isDebugBuild: Bool, isTestRun: Bool) -> Bool {
        arguments.contains(launchArgument) && isDebugBuild && !isTestRun
    }

    /// The Core Data model CloudKit gets, built from the same types the app stores.
    /// SwiftData returns nil when it cannot translate the types; that is logged and yields an
    /// empty model, which `run()` refuses — never a partial schema.
    static func makeModel() -> NSManagedObjectModel {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: LooseEndsSchema.models) else {
            logger.error("SwiftData lieferte kein Core-Data-Modell für das Schema")
            return NSManagedObjectModel()
        }
        return model
    }

    /// A fresh store file in its own folder under the temporary directory, never the app group.
    static func scratchStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "LooseEnds-Schema-\(UUID().uuidString)", directoryHint: .isDirectory)
            .appending(path: "Schema.sqlite", directoryHint: .notDirectory)
    }

    /// Writes the full schema into Development of the bundle's CloudKit container.
    /// Throws; the caller decides the exit code. The scratch folder goes away on every path.
    static func run() throws {
        let model = makeModel()
        guard !model.entities.isEmpty else { throw InitializerError.emptyModel }
        let storeURL = scratchStoreURL()
        let folder = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let container = NSPersistentCloudKitContainer(name: "LooseEndsSchema", managedObjectModel: model)
        defer {
            detachStores(of: container)
            removeScratch(folder)
        }

        let identifier = ModelContainerFactory.cloudContainer
        logger.info("Schema-Initialisierung für \(identifier, privacy: .public) beginnt")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: identifier)
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: (any Error)?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        try container.initializeCloudKitSchema(options: [])
        logger.info("Schema-Initialisierung für \(identifier, privacy: .public) erfolgreich")
    }

    /// Detaches every store before its folder goes away, so the mirroring delegate does not write
    /// its event (ANSCKEVENT) into a deleted file. Failures are logged, not swallowed.
    private static func detachStores(of container: NSPersistentCloudKitContainer) {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            do {
                try coordinator.remove(store)
            } catch {
                logger.error("Wegwerf-Store nicht gelöst (\(store.url?.path ?? "?", privacy: .public)): \(error, privacy: .public)")
            }
        }
    }

    private static func removeScratch(_ folder: URL) {
        do {
            try FileManager.default.removeItem(at: folder)
        } catch {
            logger.error("Wegwerf-Speicher nicht entfernt (\(folder.path, privacy: .public)): \(error, privacy: .public)")
        }
    }

    enum InitializerError: Error {
        case emptyModel
    }
}
#endif
