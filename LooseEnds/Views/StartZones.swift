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

/// A context with at least one open task, for its chip.
struct FitPlace: Identifiable {
    let context: TaskContext
    let count: Int
    var id: UUID { context.id }
}

/// "Fits right now" (#368): Quick first, then each context that holds a task, one tap to its view.
/// The numbers come from the same functions as the lists behind them. No chip, no block. Chips
/// wrap (`FlowLayout`) and carry the accent, since they are tappable (ADR-14); the count is grey.
struct FitChips: View {
    let quick: Int
    let places: [FitPlace]
    let select: (ViewSelection) -> Void
    @ScaledMetric(relativeTo: .subheadline) private var gap: CGFloat = 8

    var body: some View {
        if quick > 0 || !places.isEmpty {
            ZoneCaption("Fits now")
            FlowLayout(spacing: gap) {
                if quick > 0 {
                    chip(String(localized: ViewKind.quick.titleKey), symbol: ViewKind.quick.symbol, count: quick,
                         target: .system(.quick), id: "chip_quick")
                }
                ForEach(places) { place in
                    chip(place.context.name, symbol: nil, count: place.count, target: .context(place.context.id),
                         id: "chip_\(place.id.uuidString)")
                }
            }
            .listRowSeparator(.hidden)
            .paperRow()
        }
    }

    private func chip(_ title: String, symbol: String?, count: Int, target: ViewSelection, id: String) -> some View {
        Button {
            select(target)
        } label: {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                }
                Text(title)
                Text(verbatim: "\(count)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(.tint)
            .overlay(Capsule().stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }
}
