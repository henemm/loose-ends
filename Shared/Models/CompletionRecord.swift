import Foundation
import SwiftData

/// One row per completion. Repeating tasks write one per cycle and roll forward.
@Model
final class CompletionRecord {
    var id: UUID = UUID()
    var task: TaskItem?
    var completedAt: Date = Date()
    var dueDateAtCompletion: Date?

    init(task: TaskItem?, completedAt: Date = Date(), dueDateAtCompletion: Date?) {
        self.task = task
        self.completedAt = completedAt
        self.dueDateAtCompletion = dueDateAtCompletion
    }
}
