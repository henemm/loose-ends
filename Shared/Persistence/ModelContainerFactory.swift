import Foundation
import SwiftData

enum LooseEndsSchema {
    static let models: [any PersistentModel.Type] = [
        TaskItem.self, TaskContext.self, Project.self, Revision.self, CompletionRecord.self, SavedView.self,
    ]
}

enum ModelContainerFactory {
    static let appGroup = "group.com.henning.looseends"
    static let cloudContainer = "iCloud.com.henning.looseends"

    /// Production container: app group store, private CloudKit database (ADR-2).
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(LooseEndsSchema.models)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(
                "LooseEnds",
                schema: schema,
                groupContainer: .identifier(appGroup),
                cloudKitDatabase: .private(cloudContainer)
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
