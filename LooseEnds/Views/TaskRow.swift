import SwiftUI

/// One row (design briefing, screen 3): the title, or the raw text while nothing better exists,
/// then one line of at most three traits. High importance and urgency are black glyphs at the
/// start of that line. Traits the AI set are accent-tinted until seen; an AI title carries the spark.
/// Never taller than title plus one trait line.
struct TaskRow: View {
    let task: TaskItem
    /// In a context view the context itself is noise.
    var hidesContext = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(task.displayTitle)
                    .italic(task.title == nil || task.status == .unverified)
                    .lineLimit(1)
                if task.hasUnseenAIRevisions, task.titleSourceRaw == FieldSource.ai.rawValue {
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("taskRow_\(task.id.uuidString)")
    }

    private struct Trait: Identifiable {
        let id: String
        let text: String
        var symbol: String?
        var tinted = false
        var red = false

        var style: AnyShapeStyle {
            if red { return AnyShapeStyle(.red) }
            if tinted { return AnyShapeStyle(.tint) }
            return AnyShapeStyle(.secondary)
        }
    }

    /// Ranked: waiting, due, duration, context, person. The first three win.
    private var traits: [Trait] {
        let unseen = task.hasUnseenAIRevisions
        let ai = FieldSource.ai.rawValue
        var all: [Trait] = []
        if task.isBlocked {
            all.append(Trait(id: "waiting", text: String(localized: "Waiting"), symbol: "lock"))
        }
        if let due = task.dueDate {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
            all.append(Trait(
                id: "due",
                text: due.formatted(date: .abbreviated, time: task.dueHasTime ? .shortened : .omitted),
                symbol: "calendar",
                tinted: unseen && task.dueSourceRaw == ai,
                red: task.isOpen && due < tomorrow
            ))
        }
        if let duration = task.duration {
            all.append(Trait(id: "duration", text: FieldFormatting.duration(duration), symbol: "clock", tinted: unseen && task.durationSourceRaw == ai))
        }
        if !hidesContext, let context = (task.contexts ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).first {
            all.append(Trait(id: "context", text: context.name, tinted: unseen && task.contextsSourceRaw == ai))
        }
        if let person = task.people.first {
            all.append(Trait(id: "person", text: person, symbol: "person", tinted: unseen && task.peopleSourceRaw == ai))
        }
        return Array(all.prefix(3))
    }
}
