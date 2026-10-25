import SwiftUI

/// The head of the start screen (#426, #643, #644; draft C3 since #677): the date in the margin
/// column beside the sentence of the day, then, while a task is the Knäuel, its row with the Knäuel
/// in the margin. Rows of the start list, so the Knäuel's row takes the swipes and the menu like any
/// row; the host wraps it. When the Knäuel gets done, its row stays for the moment (#644): the Knäuel
/// loosens green into the knot, the row goes; Reduce Motion shows the end at once.
struct StartHeaderRows<Row: View>: View {
    let tasks: [TaskItem]
    /// A tap on the date or the sentence; the iPhone ends the entry in the writing line with it (#601).
    var onTap: (() -> Void)?
    /// A tap on the Sunday sentence or its string opens "Completed" (#646).
    var openDone: (() -> Void)?
    private let row: (TaskItem, KnaeuelHead) -> Row
    /// The Knäuel just completed, kept for its moment.
    @State private var leaving: Leaving?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Leaving: Equatable {
        let task: TaskItem
        let id = UUID()
        static func == (a: Leaving, b: Leaving) -> Bool { a.id == b.id }
    }

    init(tasks: [TaskItem], onTap: (() -> Void)? = nil, openDone: (() -> Void)? = nil,
         @ViewBuilder row: @escaping (TaskItem, KnaeuelHead) -> Row) {
        self.tasks = tasks
        self.onTap = onTap
        self.openDone = openDone
        self.row = row
    }

    /// How long the moment takes: 0.3 s loosening, 0.8 s into the knot (#644).
    static var momentDuration: Duration { .milliseconds(1100) }

    var body: some View {
        let metrics = StartMetrics(typeSize)
        let knaeuel = ViewRules.knaeuel(in: tasks)
        HStack(alignment: .top, spacing: 12) {
            // The knot only while no task is the Knäuel: the Knäuel takes its place below (#180 rule 1).
            StartDateMargin(knot: knaeuel == nil && leaving == nil)
                .frame(width: metrics.marginWidth, alignment: .trailing)
            StartHeadlineLine(tasks: tasks, openDone: openDone)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        // The draft: 14 above, a little air under the sentence (#463, #677).
        .padding(.top, 14)
        .padding(.bottom, 10)
        .listRowSeparator(.hidden)
        .startRow(metrics)
        .paperRow()
        .onChange(of: knaeuel?.id) { old, new in
            // Gone because it got done: the moment. Released, parked or moved: no green.
            if new == nil, let old, let task = tasks.first(where: { $0.id == old }), task.status == .done, !reduceMotion {
                leaving = Leaving(task: task)
            } else {
                leaving = nil
            }
        }
        .task(id: leaving) {
            guard leaving != nil else { return }
            do {
                try await Task.sleep(for: Self.momentDuration + .milliseconds(150))
            } catch {
                return
            }
            withAnimation(.easeInOut(duration: 0.3)) { leaving = nil }
        }
        if let knaeuel {
            row(knaeuel, KnaeuelHead(task: knaeuel, untangling: false))
        } else if let leaving {
            KnaeuelHead(task: leaving.task, untangling: true)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
        }
    }
}

/// The Knäuel's row (#643, #644; draft C3 since #677): the Knäuel in the ink in the margin column,
/// beside it the task's title and how long it has been carried, at the titles' edge. One row of the
/// start list. `untangling` plays the completion moment: green loosening into the knot (0.3 s), then
/// the grey knot (0.8 s), the row fading.
struct KnaeuelHead: View {
    let task: TaskItem
    let untangling: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var loosening: CGFloat = 0
    @State private var green = false

    var body: some View {
        let metrics = StartMetrics(typeSize)
        KnaeuelRow(task: task)
            .opacity(untangling ? 0 : 1)
            .overlay(alignment: .topLeading) {
                glyph
                    .frame(width: metrics(36), height: metrics(18))
                    .frame(width: metrics.marginWidth, alignment: .trailing)
                    .padding(.top, metrics(3))
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("knaeuelHead")
            .task(id: untangling) {
                guard untangling else { return }
                green = true
                withAnimation(.easeInOut(duration: 0.3)) { loosening = 0.4 }
                do {
                    try await Task.sleep(for: .milliseconds(300))
                } catch {
                    return
                }
                withAnimation(.easeInOut(duration: 0.8)) {
                    loosening = 1
                    green = false
                }
            }
    }

    /// The Knäuel in the ink; during the moment the loosening line, green while it loosens (the one
    /// green moment, ADR-14), grey as the knot.
    @ViewBuilder
    private var glyph: some View {
        if untangling {
            LooseningKnaeuel(progress: loosening)
                .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .padding(0.75)
                .foregroundStyle(green ? Color("Completed") : Color.secondary)
                .accessibilityHidden(true)
        } else {
            ThreadGlyph(form: .knaeuel, lineWidth: 1.5)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
        }
    }
}

/// The date in the margin column (#426, draft C3 since #677): the weekday over the day and month,
/// small and grey, right-aligned like the rows' times. Over it the knot while every task lies in the
/// box (#180 rule 1); while one is the Knäuel, the Knäuel stands in its own row below.
struct StartDateMargin: View {
    let knot: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        // Once a minute, so the line turns with the day without a save (#426).
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            VStack(alignment: .trailing, spacing: 2) {
                if knot {
                    // Grey like the date: it is the mark, not something to tap (ADR-14).
                    ThreadGlyph(form: .knot, lineWidth: 1.5)
                        .frame(width: metrics(30), height: metrics(16))
                        .padding(.bottom, 4)
                        .accessibilityHidden(true)
                }
                Text(timeline.date, format: .dateTime.weekday(.wide))
                Text(timeline.date, format: .dateTime.day().month(.abbreviated))
            }
            .font(metrics.margin)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.secondary)
            // The sentence's first line is larger: the date starts on its height, not above it.
            .padding(.top, knot ? 0 : metrics(7))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("startHeader")
        }
    }
}

/// The one sentence of the day (#426): the fact that stands out, from 16:00 a look back. On Sunday
/// evening and Monday morning the week's sentence (#646), with the string and the beads' titles under
/// it; a tap on the sentence or the string opens "Completed".
struct StartHeadlineLine: View {
    let tasks: [TaskItem]
    var openDone: (() -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let headline = StartHeadline.of(tasks, now: timeline.date)
            VStack(alignment: .leading, spacing: 0) {
                // Content, so New York.
                // The sentence names no task that stands below anyway (#677): the rows say it.
                Text(StartHeadlineText.sentence(headline, naming: false))
                    .font(metrics.headline)
                    .tracking(-0.3)
                    .lineSpacing(0)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("startHeadline")
                if case .week(_, let titles) = headline, let beads = ViewRules.weekToSpeakOf(in: tasks, now: timeline.date) {
                    Button(action: { openDone?() }) {
                        VStack(alignment: .leading, spacing: 2) {
                            QuietWeekString(beads: beads)
                                .padding(.leading, -QuietWeekString.inset)
                            ForEach(Array(titles.enumerated()), id: \.offset) { _, title in
                                Text(title)
                                    .font(metrics.rowMeta)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    .accessibilityHint(Text("Opens Completed"))
                    .accessibilityIdentifier("weekSentenceString")
                }
            }
        }
    }
}

/// The Knäuel's row under the sentence (#643, Henning 2026-10-23, board "Morgen"): the title in New
/// York at the titles' edge, under it how long the task has been carried and its tag. The margin stays
/// empty here: `KnaeuelHead` sets the Knäuel into it (#677).
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
                    // The word first (Henning, 2026-10-24, build 110): the sign alone did not say why
                    // the task stands up here.
                    Text("The Knäuel")
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

    /// Since when the task is the Knäuel (#647, the detail's line): "since this morning" (set before
    /// noon today), "since today", "since yesterday", the weekday within the week, else the date.
    static func setWords(from set: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        switch days(from: set, now: now, calendar: calendar) {
        case 0:
            return calendar.component(.hour, from: set) < 12 ? String(localized: "since this morning") : String(localized: "since today")
        case 1:
            return String(localized: "since yesterday")
        case 2...6:
            var style = Date.FormatStyle(date: .omitted, time: .omitted, locale: locale, calendar: calendar).weekday(.wide)
            style.timeZone = calendar.timeZone
            return String(localized: "since \(set.formatted(style))")
        default:
            var style = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: locale, calendar: calendar)
            style.timeZone = calendar.timeZone
            return String(localized: "since \(set.formatted(style))")
        }
    }
}
