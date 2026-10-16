import SwiftUI

/// The right column of the wide start page (#473, draft "Main"): Quick, recently captured and the
/// next five days. Reads only; a tap on a task opens it. Grey headings, serif lines (content), the
/// number of a day in SF (the app).
struct SideColumnView: View {
    let tasks: [TaskItem]
    @Binding var selection: ViewSelection?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        VStack(alignment: .leading, spacing: 0) {
            block("Quick") {
                ForEach(SideColumn.quick(in: tasks)) { line($0, trailing: $0.duration.map(FieldFormatting.duration)) }
            }
            block("Recently captured") {
                ForEach(SideColumn.recent(in: tasks)) { line($0, trailing: Self.age(of: $0.capturedAt)) }
            }
            block("Next days") { dayTiles }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.edge)
        .frame(width: 300, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Paper.ground)
        .overlay(alignment: .leading) { Rectangle().fill(.separator).frame(width: 0.5) }
        .accessibilityIdentifier("sideColumn")
    }

    private func block<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZoneCaptionText(title: title)
                .padding(.top, 22)
                .padding(.bottom, 6)
            content()
        }
    }

    private func line(_ task: TaskItem, trailing: String?) -> some View {
        Button { selection = .task(task.id) } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(task.displayTitle)
                    .font(.system(size: 14, design: .serif))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(.separator).frame(height: 0.5) }
    }

    /// Five tiles; today is outlined in the ink, the others stay quiet. A day with tasks shows its number.
    private var dayTiles: some View {
        HStack(spacing: 6) {
            ForEach(SideColumn.days(in: tasks), id: \.date) { day in
                VStack(spacing: 2) {
                    Text(day.date, format: .dateTime.weekday(.abbreviated))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("\(day.count)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(day.count == 0 ? .secondary : .primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(day.isToday ? Color.primary : Color.secondary.opacity(0.25), lineWidth: day.isToday ? 1 : 0.5))
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// "Today", "Yesterday", else the weekday.
    private static func age(of date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}
