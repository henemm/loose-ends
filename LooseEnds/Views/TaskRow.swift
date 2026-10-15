import SwiftData
import SwiftUI

/// One row (design briefing, screen 3): the title, or the raw text while nothing better exists,
/// then one line of at most three traits. High importance and urgency are black glyphs at the
/// start of that line. Traits the AI set are accent-tinted until seen; an AI title carries the spark.
/// Never taller than title plus one trait line.
struct TaskRow: View {
    let task: TaskItem
    /// In a context view the context itself is noise.
    var hidesContext = false
    /// One extra line the view adds, such as the age and postponements in Old.
    var note: String?
    /// The start screen's "Next up" preview shows the same task as the list; its own prefix keeps
    /// `taskRow_*` unique for the UI tests.
    var identifierPrefix = "taskRow_"
    /// "All open" holds parked tasks among the rest (#319); there the moon tells them apart.
    var marksParked = false
    /// The margin with the one time that counts (#424); wide enough for "12:00" and "Seit gestern" in two lines.
    @ScaledMetric(relativeTo: .caption) private var marginWidth: CGFloat = 54

    /// A deleted task can still be drawn once while the list animates it out; reading any of its
    /// properties then traps inside SwiftData (#194: delete from Repeating with New still on the
    /// navigation stack). Saved deletions lose their context, unsaved ones carry `isDeleted`.
    var body: some View {
        if task.isDeleted || task.modelContext == nil {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            margin
            lines
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(identifierPrefix)\(task.id.uuidString)")
    }

    /// Like a diary (#424): the time at the left edge, red only for time pressure, accent while the
    /// AI's date is unseen. Empty without a date or duration, but always the same width.
    private var margin: some View {
        let mark = ViewRules.marginMark(of: task)
        let unseenAI = task.hasUnseenAutomaticRevisions
            && FieldSource.isAutomatic(task.dueDate == nil ? task.durationSourceRaw : task.dueSourceRaw)
        let style: AnyShapeStyle = mark.pressing ? AnyShapeStyle(.red) : unseenAI ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
        return Text(Self.marginText(mark))
            .font(.caption)
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .foregroundStyle(style)
            .frame(width: marginWidth, alignment: .trailing)
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // Serif is the content, SF is the app (#180, rule 2).
                Text(task.displayTitle)
                    .fontDesign(.serif)
                    .italic(task.title == nil || task.status == .unverified)
                    // Two lines before the "…": one cut "Termin beim Hautarzt für O…" (Henning, 2026-10-15, #433).
                    .lineLimit(2)
                if task.hasUnseenAutomaticRevisions, task.titleSourceRaw == FieldSource.ai.rawValue {
                    Image(systemName: "sparkle")
                        .imageScale(.small)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Changed by AI")
                        .accessibilityIdentifier("aiMarker_\(task.id.uuidString)")
                }
                if marksParked, task.status == .parked {
                    Image(systemName: "moon.zzz")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Parked")
                        .accessibilityIdentifier("parkedMarker_\(task.id.uuidString)")
                }
            }
            if task.importance == .high || task.urgency == .high || !traits.isEmpty {
                HStack(spacing: 8) {
                    if task.importance == .high {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Important")
                    }
                    if task.urgency == .high {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.primary)
                            .accessibilityLabel("Urgent")
                    }
                    ForEach(traits) { trait in
                        HStack(spacing: 3) {
                            if let symbol = trait.symbol {
                                Image(systemName: symbol)
                            }
                            Text(trait.text)
                        }
                        .foregroundStyle(trait.style)
                    }
                }
                .font(.caption)
                .imageScale(.small)
                .lineLimit(1)
            }
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private struct Trait: Identifiable {
        let id: String
        let text: String
        var symbol: String?
        var tinted = false

        var style: AnyShapeStyle {
            if tinted { return AnyShapeStyle(.tint) }
            return AnyShapeStyle(.secondary)
        }
    }

    /// Ranked: waiting, place, duration, subtasks, tag, person; the date moved to the margin (#424).
    /// The first three win. A tag carries its symbol, as in the detail and on the start screen (#420).
    private var traits: [Trait] {
        let unseen = task.hasUnseenAutomaticRevisions
        var all: [Trait] = []
        if let waitingOn = WaitingOn.rowLabel(for: task) {
            all.append(Trait(id: "waiting", text: String(localized: "Waiting on: \(waitingOn)"), symbol: "lock"))
        }
        if let place = task.place {
            all.append(Trait(id: "place", text: place.name, symbol: "location"))
        }
        // Without a date the margin shows the duration (#424); with one, the duration stays a trait.
        if let duration = task.duration, task.dueDate != nil {
            all.append(Trait(id: "duration", text: FieldFormatting.duration(duration), symbol: "clock", tinted: unseen && FieldSource.isAutomatic(task.durationSourceRaw)))
        }
        let progress = Subtasks.progress(of: task)
        if progress.total > 0 {
            all.append(Trait(id: "subtasks", text: "\(progress.done)/\(progress.total)", symbol: "checklist"))
        }
        if !hidesContext, let context = (task.contexts ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).first {
            all.append(Trait(id: "context", text: context.name, symbol: ViewKind.context.symbol, tinted: unseen && FieldSource.isAutomatic(task.contextsSourceRaw)))
        }
        return Array(all.prefix(3))
    }

    /// The margin's words (#424). A day-only date past its day says how long it has been carried (#414).
    private static func marginText(_ mark: ViewRules.MarginMark) -> String {
        switch mark {
        case .time(let date): date.formatted(date: .omitted, time: .shortened)
        case .today: String(localized: "Today")
        case .missed(let days) where days == 1: String(localized: "Yesterday")
        case .missed(let days): String(localized: "\(days) days ago")
        case .carried(let days) where days == 1: String(localized: "Since yesterday")
        case .carried(let days): String(localized: "Since \(days) days")
        case .tomorrow: String(localized: "Tomorrow")
        case .weekday(let date): date.formatted(.dateTime.weekday(.abbreviated))
        case .date(let date): date.formatted(.dateTime.day().month(.abbreviated))
        case .duration(let bucket): FieldFormatting.duration(bucket)
        case .none: ""
        }
    }
}
