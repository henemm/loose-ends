import Foundation
import SwiftData

/// One captured thing. `rawText` is the only user input and is never changed.
/// Every derived field is optional and carries a source and a confidence (ADR-3).
/// Named `TaskItem` to avoid clashing with Swift Concurrency's `Task`.
@Model
final class TaskItem {
    // Identity and capture
    var id: UUID = UUID()
    var ownerID: String = ""
    var rawText: String = ""
    var capturedAt: Date = Date()
    var capturedViaRaw: String = CaptureChannel.app.rawValue
    var sourceURL: URL?

    // Lifecycle
    var statusRaw: String = TaskStatus.unprocessed.rawValue
    var processedAt: Date?
    /// "Der Regelschritt lief" — unabhängig davon, ob das Modell verfügbar war oder sein Aufruf
    /// glückte (#144). `processedAt` bleibt der Modell-Vermerk (ADR-4): das Modell lief oder hat die
    /// Aufgabe endgültig abgelehnt (Guardrail, Kontextfenster, #535).
    var rulesAppliedAt: Date?
    var nextRank: Double?
    var completedAt: Date?
    var parkedAt: Date?

    // Calendar (ADR-13)
    var showInCalendar: Bool = false
    var calendarEventID: String?
    /// The calendar the event goes to (#203 Teil C), by account and calendar name: a calendar id holds
    /// on one device only. Both nil: the device's default, "Loose Ends". A setting, not a derived field.
    var calendarAccount: String?
    var calendarName: String?

    // Repeat (ADR-7)
    var repeatRule: RepeatRule?

    // Place (#226): set by the user or Siri, never guessed
    var place: TaskPlace?
    var placeSourceRaw: String?
    /// Set when the place reminded (#226, Schnitt 4): a one-shot system trigger is gone after it fired,
    /// and every save re-plans, so without this the same place would be armed again. A state, not a
    /// derived field: no source, no revision.
    var placeRemindedAt: Date?

    /// The note (#439): a long text for numbers, addresses, links, anything beside the title. Mostly
    /// the user's own; a rule may move a dictated phone number here (marked by `notesSourceRaw`).
    /// Added 2026-10-15, additive for CloudKit.
    var notes: String?
    var notesSourceRaw: String?

    // Derived: title
    var title: String?
    var titleSourceRaw: String?
    var titleConfidence: Double?

    // Derived: due
    var dueDate: Date?
    var dueHasTime: Bool = false
    var dueSourceRaw: String?
    var dueConfidence: Double?

    // Derived: importance, urgency, duration, energy
    var importanceRaw: String?
    var importanceSourceRaw: String?
    var importanceConfidence: Double?

    var urgencyRaw: String?
    var urgencySourceRaw: String?
    var urgencyConfidence: Double?

    var durationRaw: String?
    var durationSourceRaw: String?
    var durationConfidence: Double?

    var energyRaw: String?
    var energySourceRaw: String?
    var energyConfidence: Double?

    // Retired with #301 (Henning, 2026-10-09, #105: no use case, never measured): nothing reads or
    // writes these any more. They stay only because the CloudKit schema is additive from the first
    // deploy (#175); old values are kept in the store and shown nowhere.
    var people: [String] = []
    var peopleSourceRaw: String?
    var peopleConfidence: Double?

    // Derived: contexts
    var contextsSourceRaw: String?
    var contextsConfidence: Double?

    // Relationships (all optional: CloudKit requirement)
    var project: Project?
    var parent: TaskItem?
    /// Deleting a task lifts its subtasks one level instead of taking them along (Henning, 2026-10-21,
    /// #605): they stay as tasks of their own, with what they carry.
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.parent) var subtasks: [TaskItem]?
    @Relationship(inverse: \TaskItem.blocks) var blockedBy: [TaskItem]?
    var blocks: [TaskItem]?
    var contexts: [TaskContext]?
    @Relationship(deleteRule: .cascade, inverse: \Revision.task) var revisions: [Revision]?
    @Relationship(deleteRule: .cascade, inverse: \CompletionRecord.task) var completions: [CompletionRecord]?
    /// Photos, scans and documents (#442); they go with the task.
    @Relationship(deleteRule: .cascade, inverse: \TaskAttachment.task) var attachments: [TaskAttachment]?

    init(rawText: String, capturedVia: CaptureChannel = .app, sourceURL: URL? = nil, ownerID: String = "") {
        self.rawText = rawText
        self.capturedViaRaw = capturedVia.rawValue
        self.sourceURL = sourceURL
        self.ownerID = ownerID
    }
}

// MARK: - Typed accessors

extension TaskItem {
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .unprocessed }
        set { statusRaw = newValue.rawValue }
    }
    var capturedVia: CaptureChannel {
        get { CaptureChannel(rawValue: capturedViaRaw) ?? .app }
        set { capturedViaRaw = newValue.rawValue }
    }
    var importance: Importance? {
        get { importanceRaw.flatMap(Importance.init(rawValue:)) }
        set { importanceRaw = newValue?.rawValue }
    }
    var urgency: Urgency? {
        get { urgencyRaw.flatMap(Urgency.init(rawValue:)) }
        set { urgencyRaw = newValue?.rawValue }
    }
    var duration: DurationBucket? {
        get { durationRaw.flatMap(DurationBucket.init(rawValue:)) }
        set { durationRaw = newValue?.rawValue }
    }
    /// A legacy "low"/"medium"/"high" reads as nil (#112).
    var energy: Energy? {
        get { energyRaw.flatMap(Energy.init(stored:)) }
        set { energyRaw = newValue?.stored }
    }

    /// What the list shows: the title, or the raw text when there is none (#202).
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return rawText
    }

    var isOpen: Bool {
        status == .unprocessed || status == .unverified || status == .active
    }

    /// Blocked means at least one blocker is still open.
    var isBlocked: Bool {
        (blockedBy ?? []).contains { $0.isOpen }
    }

    /// Unseen revisions by the model or a rule drive the marker in the list (Variante C, #101).
    /// A retired field's old revision (people, #301) keeps no task in New.
    var hasUnseenAutomaticRevisions: Bool {
        (revisions ?? []).contains { $0.author.isAutomatic && $0.seenAt == nil && $0.field != .people }
    }
}
