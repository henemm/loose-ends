import SwiftUI

/// The zones of the iPhone start screen (#368). Each one is a few rows of the start list, so they
/// are built to sit inside a `List` and carry their own row look (`paperRow`).

/// A small grey heading above a zone.
struct ZoneCaption: View {
    private let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1)
            .foregroundStyle(.secondary)
            .listRowSeparator(.hidden)
            .paperRow()
    }
}

/// "New" is an inbox, not a list among lists: one bar, there only while something waits. The one
/// accent surface of the zone, since it is the one thing to tap (ADR-14). The caller tags the row
/// with the selection it opens.
struct InboxBar: View {
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tray")
            Text("\(count) to look over")
            Spacer()
            Image(systemName: "chevron.right")
                .imageScale(.small)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("inboxBar")
        .listRowSeparator(.hidden)
        .paperRow()
    }
}

/// What stands for now: the first five of the "Now" rule, the rest behind "N more", which unfolds
/// in place. The unfolded state is local and not kept. `row` builds one task's row, so the swipes,
/// the menu and the Done window stay with the caller.
struct NowBlock<Row: View>: View {
    private let tasks: [TaskItem]
    private let row: (TaskItem) -> Row
    @State private var expanded = false

    private static var limit: Int { 5 }

    init(tasks: [TaskItem], @ViewBuilder row: @escaping (TaskItem) -> Row) {
        self.tasks = tasks
        self.row = row
    }

    var body: some View {
        ZoneCaption("Now")
        if tasks.isEmpty {
            Text("Swipe left on any task to line it up here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .paperRow()
        } else {
            ForEach(expanded ? tasks : Array(tasks.prefix(Self.limit))) { task in
                row(task)
            }
            if tasks.count > Self.limit {
                moreButton(hidden: tasks.count - Self.limit)
            }
        }
    }

    /// Grey, not accent: it only folds the list, a hierarchy sign rather than a call to act.
    private func moreButton(hidden: Int) -> some View {
        Button {
            withAnimation(.snappy) { expanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                if expanded {
                    Text("Show less")
                } else {
                    Text("\(hidden) more")
                }
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Spacer()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("nowMore")
        .listRowSeparator(.hidden)
        .paperRow()
    }
}

/// A tag or a project with at least one open task, for its word in the index.
struct IndexWord: Identifiable {
    let id: String
    let name: String
    let count: Int
    let target: ViewSelection
}

/// One line of the index: a view, or a group (Tags, Projects) whose line opens its page (#428).
struct IndexLine: Identifiable {
    let id: String
    let title: String
    let count: Int
    /// The tags or projects that hold a task, set in italics below the group's line.
    var words: [IndexWord] = []
    let action: () -> Void
}

/// "Contents" (#421, Henning 2026-10-15): the quiet places of the iPhone start screen as the first
/// page of a notebook. Names in New York, a dotted leader, the count small in SF. A deliberate
/// exception to #180 rule 2, for this page only. Groups are kept apart by space, not by cards;
/// tags and projects with tasks follow their line as italic words, one tap to their list.
struct ContentsIndex: View {
    let groups: [[IndexLine]]
    let select: (ViewSelection) -> Void
    @ScaledMetric(relativeTo: .title3) private var groupGap: CGFloat = 12
    @ScaledMetric(relativeTo: .body) private var wordGap: CGFloat = 10

    var body: some View {
        ZoneCaption("Contents")
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    Spacer().frame(height: groupGap)
                }
                ForEach(group) { line in
                    lineButton(line)
                    if !line.words.isEmpty {
                        words(line.words)
                    }
                }
            }
        }
        .listRowSeparator(.hidden)
        .paperRow()
    }

    private func lineButton(_ line: IndexLine) -> some View {
        Button(action: line.action) {
            IndexLineLabel(title: line.title, count: line.count)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(line.id)
    }

    /// Accent, since each word opens its list (ADR-14); the count stays grey.
    private func words(_ words: [IndexWord]) -> some View {
        FlowLayout(spacing: wordGap) {
            ForEach(words) { word in
                Button {
                    select(word.target)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(word.name)
                            .font(.body)
                            .fontDesign(.serif)
                            .italic()
                            .foregroundStyle(.tint)
                        Text(verbatim: "\(word.count)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(word.id)
            }
        }
        .padding(.leading, 18)
        .padding(.bottom, 4)
    }
}

/// A line of the notebook index: the name in New York, a dotted leader, the count small in SF; a
/// zero is left out (#180). Shared by the index and the pages of tags and projects (#428).
struct IndexLineLabel: View {
    let title: String
    let count: Int
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.title3)
                .fontDesign(.serif)
                .foregroundStyle(.primary)
            if typeSize.isAccessibilitySize {
                Spacer(minLength: 4)
            } else {
                Leader()
                    .stroke(.tertiary, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0.5, 5]))
                    .frame(height: 1.5)
                    .accessibilityHidden(true)
            }
            if count > 0 {
                Text(verbatim: "\(count)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

/// The dotted line between a name and its count, drawn through the middle of its frame.
private struct Leader: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}
