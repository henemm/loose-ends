import Foundation
import SwiftData

/// Projects are lists and the future sharing unit (ADR-8).
@Model
final class Project {
    var id: UUID = UUID()
    var ownerID: String = ""
    var name: String = ""
    var sortOrder: Int = 0
    var archivedAt: Date?
    @Relationship(inverse: \TaskItem.project) var tasks: [TaskItem]?

    init(name: String, ownerID: String = "", sortOrder: Int = 0) {
        self.name = name
        self.ownerID = ownerID
        self.sortOrder = sortOrder
    }
}
