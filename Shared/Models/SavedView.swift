import Foundation
import SwiftData

/// System views are seeded, not deletable, but can be hidden. No free filter rules in v1.
@Model
final class SavedView {
    var id: UUID = UUID()
    var name: String = ""
    var kindRaw: String = ViewKind.next.rawValue
    var contextID: UUID?
    var projectID: UUID?
    var isSystem: Bool = false
    var isHidden: Bool = false
    var sortOrder: Int = 0

    init(name: String, kind: ViewKind, isSystem: Bool = false, sortOrder: Int = 0, contextID: UUID? = nil, projectID: UUID? = nil) {
        self.name = name
        self.kindRaw = kind.rawValue
        self.isSystem = isSystem
        self.sortOrder = sortOrder
        self.contextID = contextID
        self.projectID = projectID
    }

    var kind: ViewKind {
        get { ViewKind(rawValue: kindRaw) ?? .next }
        set { kindRaw = newValue.rawValue }
    }
}
