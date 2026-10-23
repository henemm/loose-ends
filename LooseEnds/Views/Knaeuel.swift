import SwiftUI

/// The head of the start screen (#426, #643): the date at the knot, or at the Knäuel while a task is
/// it, then that task as a row of its own, then the sentence of the day. Three rows of the start
/// list, so the Knäuel row takes the swipes and the menu like any row; the host builds that row.
struct StartHeaderRows<Row: View>: View {
    let tasks: [TaskItem]
    /// A tap on the date or the sentence; the iPhone ends the entry in the writing line with it (#601).
    var onTap: (() -> Void)?
    private let row: (TaskItem) -> Row
    @Environment(\.dynamicTypeSize) private var typeSize

    init(tasks: [TaskItem], onTap: (() -> Void)? = nil, @ViewBuilder row: @escaping (TaskItem) -> Row) {
        self.tasks = tasks
        self.onTap = onTap
        self.row = row
    }

    var body: some View {
        let metrics = StartMetrics(typeSize)
        let knaeuel = ViewRules.knaeuel(in: tasks)
        tapping(StartDateLine(knaeuel: knaeuel != nil))
            // The draft: 14 above the date line (#463).
            .padding(.top, 14)
            .listRowSeparator(.hidden)
            .startRow(metrics)
            .paperRow()
        if let knaeuel {
            row(knaeuel)
        }
        tapping(StartHeadlineLine(tasks: tasks))
            .padding(.top, 6)
            // The draft: 16 under the headline (#463).
            .padding(.bottom, 16)
            .listRowSeparator(.hidden)
            .startRow(metrics)
            .paperRow()
    }

    private func tapping(_ line: some View) -> some View {
        line
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
    }
}

/// The date, small and grey, at the sign of the day (#180 rule 1, #643): the knot while every task
/// lies in the box, the Knäuel in the ink and a fifth larger while one is being avoided. With the
/// Knäuel the date starts flush over the task's words, 64 pt in (Henning, 2026-10-23).
struct StartDateLine: View {
    let knaeuel: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        // Once a minute, so the line turns with the day without a save (#426).
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            HStack(spacing: knaeuel ? 12 : 8) {
                if knaeuel {
                    ThreadGlyph(form: .knaeuel, lineWidth: 1.5)
                        .foregroundStyle(.primary)
                        .frame(width: metrics(36), height: metrics(18))
                        .frame(width: metrics.marginWidth, alignment: .leading)
                } else {
                    // The knot, first of its three places (#180, rule 1). Grey like the date: it is
                    // the mark, not something to tap (ADR-14).
                    ThreadGlyph(form: .knot, lineWidth: 1.5)
                        .frame(width: metrics(30), height: metrics(16))
                }
                Text(timeline.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(metrics.caption)
                    .textCase(.uppercase)
                    .tracking(metrics.captionTracking)
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("startHeader")
        }
    }
}

/// The one sentence of the day (#426): the fact that stands out, from 16:00 a look back.
struct StartHeadlineLine: View {
    let tasks: [TaskItem]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            // Content, so New York.
            Text(StartHeadlineText.sentence(StartHeadline.of(tasks, now: timeline.date)))
                .font(metrics.headline)
                .tracking(-0.3)
                .lineSpacing(0)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("startHeadline")
        }
    }
}

/// The Knäuel's row under the date (#643, Henning 2026-10-23, board "Morgen"): the title in New York
/// 64 pt in, flush with the date, under it how long the task has been carried and its tag. The
/// margin stays empty: the thread from the Knäuel runs there (Schnitt 2, #644).
struct KnaeuelRow: View {
    let task: TaskItem
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // A deleted task can still be drawn once while the list animates it out (#194).
        if task.isDeleted || task.modelContext == nil {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        let metrics = StartMetrics(typeSize)
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Color.clear
                .frame(width: metrics.marginWidth, height: 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.displayTitle)
                    .font(metrics.rowTitle)
                    .fontDesign(.serif)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(KnaeuelSince.words(from: task.capturedAt))
                    if let context = (task.contexts ?? []).sorted(by: { $0.sortOrder < $1.sortOrder }).first {
                        HStack(spacing: 3) {
                            Image(systemName: ViewKind.context.symbol)
                            Text(context.name)
                        }
                    }
                }
                .font(metrics.rowMeta)
                .imageScale(.small)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("The Knäuel, \(task.displayTitle)"))
        .accessibilityIdentifier("knaeuelRow_\(task.id.uuidString)")
    }
}

/// "Since 11 days" (#643): how long the task has been carried, counted in days from its capture.
enum KnaeuelSince {
    static func days(from captured: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        max(calendar.dateComponents([.day], from: calendar.startOfDay(for: captured), to: calendar.startOfDay(for: now)).day ?? 0, 0)
    }

    static func words(from captured: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        switch days(from: captured, now: now, calendar: calendar) {
        case 0: String(localized: "Since today")
        case 1: String(localized: "Since yesterday")
        case let days: String(localized: "Since \(days) days")
        }
    }
}
