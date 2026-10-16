import AppIntents
import OSLog
import SwiftData
import SwiftUI
import WidgetKit

struct NextUpEntry: TimelineEntry {
    struct Line: Identifiable {
        let id: UUID
        let title: String
    }

    let date: Date
    let lines: [Line]
}

/// How many tasks a family shows (design briefing, screen 9; the large one came with #488).
private extension WidgetFamily {
    var lineLimit: Int {
        switch self {
        case .systemSmall: 1
        case .systemLarge, .systemExtraLarge: 6
        default: 3
        }
    }
}

struct NextUpProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Widget")

    func placeholder(in context: Context) -> NextUpEntry {
        NextUpEntry(date: .now, lines: [NextUpEntry.Line(id: UUID(), title: String(localized: "Follow up on the offer"))])
    }

    func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) {
        completion(load(limit: context.family.lineLimit))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
        completion(Timeline(entries: [load(limit: context.family.lineLimit)], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func load(limit: Int) -> NextUpEntry {
        do {
            // The context does not retain its container (CLAUDE.md): keep it alive while fetching.
            let container = try ModelContainerFactory.make(syncs: false)
            let next = try NextUpWidgetActions.nextUp(in: ModelContext(container), limit: limit)
            return NextUpEntry(date: .now, lines: next.map { NextUpEntry.Line(id: $0.id, title: $0.title) })
        } catch {
            Self.logger.error("Loading Next up failed: \(error, privacy: .public)")
            return NextUpEntry(date: .now, lines: [])
        }
    }
}

/// The app's paper, the logo's knot, titles in New York (#488, Henning 2026-10-16: lovingly and
/// beautifully made). Small: the top task of "Next up", large type, one tap to finish it. Medium:
/// the top three, large: the top six, each with its own circle that completes the task without
/// opening the app; the title opens it (#307). Accent only where something can be tapped (ADR-14).
struct NextUpWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextUpEntry

    private var shown: [NextUpEntry.Line] {
        Array(entry.lines.prefix(family.lineLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if shown.isEmpty {
                empty
            } else if family == .systemSmall, let line = shown.first {
                small(line)
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color("Paper") }
    }

    /// The knot and the name of the list, small and grey like the heads of the start screen.
    private var header: some View {
        HStack(spacing: 7) {
            ThreadGlyph(form: .knot, lineWidth: 1.4)
                .frame(width: 24, height: 13)
            Text("Next up")
                .font(.system(size: 10.5, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, family == .systemSmall ? 8 : 10)
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nothing lined up yet.")
                .font(.system(size: 17, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    /// One task, set large; the circle at the foot finishes it.
    private func small(_ line: NextUpEntry.Line) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(intent: OpenTaskIntent(taskID: line.id)) {
                Text(line.title)
                    .font(.system(size: 17, weight: .medium, design: .serif))
                    .lineSpacing(1)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 6)
            Button(intent: CompleteTaskIntent(taskID: line.id)) {
                HStack(spacing: 7) {
                    circle
                    Text("Complete")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .widgetAccentable()
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Complete"))
        }
    }

    /// Medium and large: a circle and a title per line, a hairline between the lines.
    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, line in
                if index > 0 {
                    Rectangle()
                        .fill(.secondary.opacity(0.25))
                        .frame(height: 0.5)
                }
                HStack(alignment: .center, spacing: 11) {
                    Button(intent: CompleteTaskIntent(taskID: line.id)) {
                        circle
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Complete"))
                    Button(intent: OpenTaskIntent(taskID: line.id)) {
                        Text(line.title)
                            .font(.system(size: 15, design: .serif))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, family == .systemMedium ? 6 : 9)
                .frame(maxHeight: .infinity)
            }
        }
    }

    /// A thin open circle in the accent: it waits to be closed, like the knot the app ties on completion.
    private var circle: some View {
        Image(systemName: "circle")
            .font(.system(size: 22, weight: .light))
            .foregroundStyle(Color.accentColor)
            .widgetAccentable()
    }
}

struct NextUpWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextUp", provider: NextUpProvider()) { entry in
            NextUpWidgetView(entry: entry)
        }
        .configurationDisplayName("Next up")
        .description("What you lined up, one tap to finish it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
