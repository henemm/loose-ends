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

struct NextUpProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Widget")

    func placeholder(in context: Context) -> NextUpEntry {
        NextUpEntry(date: .now, lines: [NextUpEntry.Line(id: UUID(), title: "Follow up on the offer")])
    }

    func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) { completion(load()) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
        completion(Timeline(entries: [load()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    /// Always three: the small widget shows the first of them (design briefing, screen 9).
    private func load() -> NextUpEntry {
        do {
            // The context does not retain its container (CLAUDE.md): keep it alive while fetching.
            let container = try ModelContainerFactory.make()
            let next = try NextUpWidgetActions.nextUp(in: ModelContext(container), limit: 3)
            return NextUpEntry(date: .now, lines: next.map { NextUpEntry.Line(id: $0.id, title: $0.title) })
        } catch {
            Self.logger.error("Loading Next up failed: \(error, privacy: .public)")
            return NextUpEntry(date: .now, lines: [])
        }
    }
}

/// Small: the top task of "Next up", medium: the top three (design briefing, screen 9). Each line
/// has a check mark that completes the task without opening the app; the title opens it (#307).
struct NextUpWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextUpEntry

    private var shown: [NextUpEntry.Line] {
        Array(entry.lines.prefix(family == .systemSmall ? 1 : 3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Next up", systemImage: "list.bullet").font(.caption).foregroundStyle(.tint)
            if shown.isEmpty {
                Text("Nothing lined up").foregroundStyle(.secondary)
            }
            ForEach(shown) { line in
                HStack(spacing: 8) {
                    Button(intent: CompleteTaskIntent(taskID: line.id)) {
                        Image(systemName: "circle")
                            .imageScale(.large)
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Complete"))
                    Button(intent: OpenTaskIntent(taskID: line.id)) {
                        Text(line.title)
                            .font(.subheadline)
                            .lineLimit(family == .systemSmall ? 3 : 1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }
}

struct NextUpWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextUp", provider: NextUpProvider()) { entry in
            NextUpWidgetView(entry: entry)
        }
        .configurationDisplayName("Next up")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
