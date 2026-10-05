import Foundation
import SwiftData

/// Seeds the deletable default contexts (design briefing, screen 2) whenever the store holds no
/// context at all — unless the user emptied the catalog on purpose (#146).
///
/// Until #146 a "seeded once" marker in `UserDefaults` decided this, while the contexts themselves
/// live in SwiftData: two memories that get lost independently. A store rebuilt or restored
/// without its defaults (or the in-memory store of `--ui-testing`) then never saw a context again.
/// Now the store itself answers "is anything there", and the marker only says what the store
/// cannot: that the user deleted the last context, so nothing should come back. Deleting a single
/// context never brings the defaults back either, because others remain. Only after a lost store
/// do the defaults return, the deleted one included — after data loss that is the expected start.
enum ContextSeeder {
    /// Set when the user deletes the last context, cleared when they add one. UI tests that need
    /// the defaults pass `-contextsEmptiedByUser NO` (argument domain), whatever earlier runs left.
    static let emptiedByUserKey = "contextsEmptiedByUser"

    @discardableResult
    static func seedIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) throws -> [TaskContext] {
        guard try context.fetchCount(FetchDescriptor<TaskContext>()) == 0,
              !defaults.bool(forKey: emptiedByUserKey) else { return [] }
        var created: [TaskContext] = []
        for (index, key) in TaskContext.defaultNameKeys.enumerated() {
            let item = TaskContext(name: String(localized: key), isSystemDefault: true, sortOrder: index)
            context.insert(item)
            created.append(item)
        }
        try context.save()
        return created
    }

    /// Called by the catalog after a user deletes or adds a context, with how many remain.
    static func noteCatalog(remaining: Int, defaults: UserDefaults = .standard) {
        defaults.set(remaining == 0, forKey: emptiedByUserKey)
    }
}
