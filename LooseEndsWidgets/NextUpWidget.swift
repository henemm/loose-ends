import SwiftData
import SwiftUI
import WidgetKit

struct NextUpEntry: TimelineEntry {
    let date: Date
    let titles: [String]
}

struct NextUpProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextUpEntry { NextUpEntry(date: .now, titles: ["Follow up on the offer"]) }
    func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
        completion(Timeline(entries: [load()], policy: .after(Date().addingTimeInterval(15 * 60))))
    }

    private func load() -> NextUpEntry {
        guard let container = try? ModelContainerFactory.make() else { return NextUpEntry(date: .now, titles: []) }
        let context = ModelContext(container)
        let all = (try? context.fetch(FetchDescriptor<TaskItem>())) ?? []
        let titles = ViewRules.tasks(for: .next, in: all).prefix(3).map(\.displayTitle)
        return NextUpEntry(date: .now, titles: Array(titles))
    }
}

struct NextUpWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextUp", provider: NextUpProvider()) { entry in
            VStack(alignment: .leading, spacing: 6) {
                Label("Next up", systemImage: "list.bullet").font(.caption).foregroundStyle(.tint)
                ForEach(entry.titles, id: \.self) { Text($0).font(.subheadline).lineLimit(1) }
                if entry.titles.isEmpty { Text("Nothing lined up").foregroundStyle(.secondary) }
            }
            .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Next up")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
