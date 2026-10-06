import Foundation
import SwiftData

enum SiriFieldsError: LocalizedError, Equatable {
    /// No context carries this tag's name; the name is the one Siri delivered.
    case unknownTag(String)
    /// Siri delivered this many different links; a task keeps one source.
    case multipleLinks(Int)

    var errorDescription: String? {
        switch self {
        case .unknownTag(let name): String(localized: "There is no context named “\(name)”.")
        case .multipleLinks(let count): String(localized: "A task can keep one link, not \(count).")
        }
    }
}

/// Siri's link, flag and tags on a new task (#225, precondition for #25). Two steps so Siri never
/// leaves a task behind when it reports an error: `resolve` checks before the save and writes
/// nothing, `apply` writes on the saved task. Flag and tags count as the user's (they said them);
/// the link is source material like sharing, without a revision. The caller saves.
struct SiriFields: Sendable {
    var urls: [URL]
    var isFlagged: Bool?
    var tags: Set<String>

    struct Resolved {
        let url: URL?
        let flagged: Bool
        let contexts: [TaskContext]
    }

    /// Reads only. Throws on more than one distinct link or a tag that matches no context.
    static func resolve(_ fields: SiriFields, in context: ModelContext) throws -> Resolved {
        var links: [URL] = []
        for url in fields.urls where !links.contains(url) { links.append(url) }
        guard links.count <= 1 else { throw SiriFieldsError.multipleLinks(links.count) }
        let contexts = try matchingContexts(for: fields.tags, in: context)
        return Resolved(url: links.first, flagged: fields.isFlagged == true, contexts: contexts)
    }

    /// Each tag by the catalog's name rule (#157); duplicates resolve to the merge's survivor.
    private static func matchingContexts(for tags: Set<String>, in context: ModelContext) throws -> [TaskContext] {
        guard !tags.isEmpty else { return [] }
        let all = try context.fetch(FetchDescriptor<TaskContext>())
        var found: [TaskContext] = []
        for tag in tags.sorted() {
            let key = CatalogService.nameKey(tag)
            let matches = all.filter { CatalogService.nameKey($0.name) == key }
            guard let survivor = matches.sorted(by: CatalogService.survivesBefore).first else {
                throw SiriFieldsError.unknownTag(tag)
            }
            if !found.contains(where: { $0.id == survivor.id }) { found.append(survivor) }
        }
        return found.sorted {
            $0.sortOrder != $1.sortOrder ? $0.sortOrder < $1.sortOrder : $0.id.uuidString < $1.id.uuidString
        }
    }

    /// Writes on the task only: link as source, flag as high importance, tags as contexts.
    static func apply(_ resolved: Resolved, to task: TaskItem, now: Date = Date()) {
        if let url = resolved.url { task.sourceURL = url }
        if resolved.flagged {
            let old = task.importanceRaw
            task.importance = .high
            task.importanceSourceRaw = FieldSource.user.rawValue
            task.importanceConfidence = nil
            record(.importance, from: old, to: Importance.high.rawValue, on: task, now: now)
        }
        if !resolved.contexts.isEmpty {
            let previous = task.contexts ?? []
            let old = previous.isEmpty ? nil : EnrichmentWriter.encode(previous.map(\.name))
            task.contexts = resolved.contexts
            task.contextsSourceRaw = FieldSource.user.rawValue
            task.contextsConfidence = nil
            record(.contexts, from: old, to: EnrichmentWriter.encode(resolved.contexts.map(\.name)), on: task, now: now)
        }
    }

    /// A user revision with reason "Siri", seen at once like `RevisionService.set`.
    private static func record(_ field: RevisedField, from old: String?, to new: String?, on task: TaskItem, now: Date) {
        let revision = Revision(task: task, field: field, oldValue: old, newValue: new, author: .user, reason: "Siri")
        revision.createdAt = now
        revision.seenAt = now
        task.revisions = (task.revisions ?? []) + [revision]
    }
}
