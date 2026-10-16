import SwiftUI

/// The field editors as pages of the notebook (#482, Henning 2026-10-16: "liebevoller, ästhetischer"):
/// paper instead of grouped white cards, the current value large in New York under a small caption,
/// and a form that fits the field. Draft: https://claude.ai/artifact/TsJ3X8aTtdu1zysX8uGh3j
struct EditorPage<Content: View>: View {
    let caption: String
    let value: String?
    var pressing = false
    var note: String?
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(caption)
                    .captionHead()
                    .accessibilityAddTraits(.isHeader)
                Text(value ?? String(localized: "Not set"))
                    .font(.system(.title, design: .serif, weight: .medium))
                    .tracking(-0.3)
                    .foregroundStyle(value == nil ? AnyShapeStyle(.tertiary) : pressing ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .accessibilityIdentifier("editorValue")
                if let note {
                    Text(note)
                        .font(.system(.callout, design: .serif))
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                content
                    .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Paper.ground)
    }
}

/// A choice marked by a dot at the margin instead of a checkmark: the checkmark belongs to Done (#435).
struct ChoiceDot: View {
    let on: Bool
    var pressing = false

    var body: some View {
        Circle()
            .strokeBorder(on ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1.3)
            .background(Circle().fill(on ? (pressing ? Color.red : Color.accentColor) : Color.clear))
            .frame(width: 9, height: 9)
            .accessibilityHidden(true)
    }
}

/// None, low, medium, high as a rising ladder with small bars (#482); a tap sets the level.
struct LevelLadder: View {
    let current: String?
    /// Urgency "high" is time pressure, so it alone turns red (colour budget).
    let highIsPressing: Bool
    let choose: (String?) -> Void

    private static let levels: [(raw: String?, title: LocalizedStringKey, filled: Int)] = [
        (nil, "None", 0), ("low", "Low", 1), ("medium", "Medium", 2), ("high", "High", 3),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.levels.enumerated()), id: \.offset) { index, level in
                let on = level.raw == current
                let pressing = highIsPressing && level.raw == "high"
                Button { choose(level.raw) } label: {
                    HStack(alignment: .center, spacing: 12) {
                        ChoiceDot(on: on, pressing: pressing)
                        Text(level.title)
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(on ? (pressing ? AnyShapeStyle(.red) : AnyShapeStyle(.primary)) : AnyShapeStyle(.secondary))
                        Spacer()
                        if level.filled > 0 {
                            bars(filled: level.filled, on: on)
                        }
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(level.title))
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("levelOption_\(level.raw ?? "none")")
                if index < Self.levels.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func bars(filled: Int, on: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...3, id: \.self) { step in
                RoundedRectangle(cornerRadius: 1)
                    .fill(step <= filled && on ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                    .frame(width: 3, height: CGFloat(step) * 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The duration as a measuring tape (#482): five strokes on a line, the chosen one thick in accent.
struct DurationTape: View {
    let current: DurationBucket?
    let choose: (DurationBucket?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.primary)
                    .frame(height: 1.2)
                    .padding(.top, 24)
                    .padding(.horizontal, 8)
                    .accessibilityHidden(true)
                HStack(spacing: 0) {
                    ForEach(DurationBucket.allCases, id: \.self) { bucket in
                        let on = bucket == current
                        Button { choose(bucket) } label: {
                            VStack(spacing: 10) {
                                Capsule()
                                    .fill(on ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
                                    .frame(width: on ? 3.5 : 1.2, height: on ? 34 : 26)
                                    .padding(.top, on ? 8 : 12)
                                Text(FieldFormatting.duration(bucket))
                                    .font(.system(.body, design: .serif, weight: on ? .medium : .regular))
                                    .foregroundStyle(on ? .primary : .secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(FieldFormatting.duration(bucket))
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier("durationOption_\(bucket.rawValue)")
                    }
                }
            }
            if current != nil {
                Button("No duration") { choose(nil) }
                    .font(.callout)
                    .buttonStyle(.borderless)
                    .padding(.top, 26)
                    .accessibilityIdentifier("durationNone")
            }
        }
    }
}

/// The tags as a sentence, like the start screen's index (#482): the chosen in ink, underlined in
/// accent, the others grey. A tap adds or removes.
struct TagSentence: View {
    let contexts: [TaskContext]
    let chosen: Set<UUID>
    let toggle: (TaskContext) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(contexts.enumerated()), id: \.element.id) { index, context in
                let on = chosen.contains(context.id)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Button { toggle(context) } label: {
                        Text(context.name)
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(on ? .primary : .secondary)
                            .underline(on, color: .accentColor)
                            .padding(.vertical, 3)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(context.name)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("contextOption_\(context.id.uuidString)")
                    if index < contexts.count - 1 {
                        Text(verbatim: ",")
                            .font(.system(.title2, design: .serif))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }
}

/// The projects as an index (#482): name, dotted leader, open tasks; the chosen one carries the knot.
struct ProjectIndex: View {
    let projects: [Project]
    let current: Project?
    let choose: (Project?) -> Void
    @ScaledMetric(relativeTo: .body) private var knot: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            line(title: String(localized: "No project"), count: 0, on: current == nil, id: "projectOption_none") { choose(nil) }
                .padding(.bottom, 8)
            ForEach(projects) { project in
                let open = ViewRules.tasks(inProject: project, in: project.tasks ?? []).count
                line(title: project.name, count: open, on: project.id == current?.id,
                     id: "projectOption_\(project.id.uuidString)") { choose(project) }
            }
        }
    }

    private func line(title: String, count: Int, on: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ThreadGlyph(form: .knot, lineWidth: 1.5)
                    .foregroundStyle(.tint)
                    .frame(width: knot, height: knot * 0.55)
                    .opacity(on ? 1 : 0)
                IndexLineLabel(title: title, count: count)
                    .foregroundStyle(on ? .primary : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(count > 0 ? "\(count)" : "")
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier(id)
    }
}
