import Foundation
import SwiftData

/// Seeds the deletable default contexts once (design briefing, screen 2). Never re-adds a deleted one.
enum ContextSeeder {
    static let seededKey = "contextsSeeded"

    @discardableResult
    static func seedIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) throws -> [TaskContext] {
        guard !defaults.bool(forKey: seededKey) else { return [] }
        let existing = try context.fetchCount(FetchDescriptor<TaskContext>())
        var created: [TaskContext] = []
        if existing == 0 {
            for (index, key) in TaskContext.defaultNameKeys.enumerated() {
                let item = TaskContext(name: String(localized: key), isSystemDefault: true, sortOrder: index)
                context.insert(item)
                created.append(item)
            }
            try context.save()
        }
        defaults.set(true, forKey: seededKey)
        return created
    }
}
