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
    /// The task's place in "Next up" (#509): shown as a star with the number at the row's end. Nil in
    /// that view itself and on the start screen, where every row is lined up anyway.
    var nextRank: Int?
    /// Opens the date choice (#548). With it, a task whose deadline passed shows "New date" in the
    /// margin instead of its old time; without it the margin only says what had been planned.
    var onNewDate: (() -> Void)?
    /// The evening look (#550) asks for a new date for every task it lists, a day-only date still
    /// standing on its day among them: the button shows regardless of the margin's own reading.
    var asksNewDate = false
    /// "Completed" by weeks (#646): the weekday in the margin instead of the day heads.
    var marginWords: String?
    /// The margin with the one time that counts (#424); wide enough for "12:00" and "Neues Datum" in two lines.
    @ScaledMetric(relativeTo: .caption) private var marginWidth: CGFloat = 54
    /// The start screen's draft sizes (#463); everywhere else the row keeps the text styles.
    @Environment(\.startMetrics) private var startMetrics

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
                .frame(maxWidth: .infinity, alignment: .leading)
            marker
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(identifierPrefix)\(task.id.uuidString)")
    }

    /// Like a diary (#424): the time at the left edge, red only for time pressure, accent while the
    /// AI's date is unseen. Empty without a date or duration, but always the same width. A deadline
    /// that passed is no deadline (#548): then the margin is the "New date" button over its grey trace.
    @ViewBuilder
    private var margin: some View {
        let mark = ViewRules.marginMark(of: task)
        if let marginWords {
            Text(marginWords)
                .font(startMetrics?.margin ?? .caption)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.secondary)
                .frame(width: startMetrics?.marginWidth ?? marginWidth, alignment: .trailing)
        } else if let onNewDate, let trace = newDateTrace(mark) {
            newDateButton(trace, action: onNewDate)
        } else {
            let unseenAI = task.hasUnseenAutomaticRevisions
                && FieldSource.isAutomatic(task.dueDate == nil ? task.durationSourceRaw : task.dueSourceRaw)
            let style: AnyShapeStyle = mark.pressing ? AnyShapeStyle(.red) : unseenAI ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
            Text(mark.text)
                .font(startMetrics?.margin ?? .caption.monospacedDigit())
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .foregroundStyle(style)
                .frame(width: startMetrics?.marginWidth ?? marginWidth, alignment: .trailing)
        }
    }

    /// The trace under the button: the margin's own when the deadline passed, else the date as it
    /// stands when the evening look asks anyway.
    private func newDateTrace(_ mark: ViewRules.MarginMark) -> NewDateRule.Trace? {
        if case .passed(let trace) = mark { return trace }
        return asksNewDate ? NewDateRule.trace(of: task) : nil
    }

    /// Accent = tappable (ADR-14); the trace in grey below, never red: there is no pressure left.
    private func newDateButton(_ trace: NewDateRule.Trace, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .trailing, spacing: 1) {
                Text("New date")
                    .font((startMetrics?.margin ?? .caption).weight(.medium))
                    .foregroundStyle(.tint)
                    .lineLimit(2)
                Text(trace.text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.trailing)
            .minimumScaleFactor(0.8)
            .frame(width: startMetrics?.marginWidth ?? marginWidth, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text("New date, \(trace.text)"))
        .accessibilityIdentifier("newDate_\(task.id.uuidString)")
    }

    /// The same signs as the swipe actions and the menu (#509): the star with the place in "Next up"
    /// in the ink, the moon for a parked task in grey. Nothing tappable, so no accent.
    @ViewBuilder
    private var marker: some View {
        if let nextRank {
            HStack(spacing: 3) {
                Image(systemName: "star")
                Text("\(nextRank)")
                    .monospacedDigit()
            }
            .font((startMetrics?.rowMeta ?? .caption).weight(.semibold))
            .foregroundStyle(.primary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Next up, number \(nextRank)")
            .accessibilityIdentifier("nextMarker_\(task.id.uuidString)")
        } else if marksParked, task.status == .parked {
            Image(systemName: "moon.zzz")
                .font(startMetrics?.rowMeta ?? .caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Parked")
                .accessibilityIdentifier("parkedMarker_\(task.id.uuidString)")
        }
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // Serif is the content, SF is the app (#180, rule 2).
                Text(task.displayTitle)
                    .font(startMetrics?.rowTitle ?? .body)
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
                        if trait.id == "counts" {
                            // The bead (#645): the task counts on the week's string.
                            PearlGlyph()
                                .frame(width: 30, height: 10)
                                .accessibilityLabel(Text("Counts"))
                                .accessibilityIdentifier("countsMarker_\(task.id.uuidString)")
                        } else if trait.id == "knaeuel" {
                            // The small grey Knäuel (#646): the task is, or was, the Knäuel.
                            ThreadGlyph(form: .knaeuel, lineWidth: 1.2)
                                .frame(width: 22, height: 11)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(Text("The Knäuel"))
                                .accessibilityIdentifier("knaeuelMarker_\(task.id.uuidString)")
                        } else {
                            HStack(spacing: 3) {
                                if let symbol = trait.symbol {
                                    Image(systemName: symbol)
                                }
                                Text(trait.text)
                            }
                            .foregroundStyle(trait.style)
                        }
                    }
                }
                .font(startMetrics?.rowMeta ?? .caption)
                .imageScale(.small)
                .lineLimit(1)
            }
            if let note = note ?? parentNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    /// A subtask in a list names its task (#548, #565), wherever it stands: "Due", "Now", a tag.
    private var parentNote: String? {
        task.parent.map { String(localized: "Subtask of \($0.displayTitle)") }
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

    /// Ranked: the bead, waiting, place, duration, subtasks, tag; the date moved to the margin (#424).
    /// The first three win. A tag carries its symbol, as in the detail and on the start screen (#420).
    /// The bead stands first (#645): a task that counts says so before anything else.
    private var traits: [Trait] {
        let unseen = task.hasUnseenAutomaticRevisions
        var all: [Trait] = []
        // Open or done (#646): "Completed" shows what counted, the Knäuel among it.
        if task.isOpen || task.status == .done {
            if task.knaeuelAt != nil {
                all.append(Trait(id: "knaeuel", text: ""))
            } else if task.countsAt != nil {
                all.append(Trait(id: "counts", text: ""))
            }
        }
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
}
