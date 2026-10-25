import SwiftUI

/// The head of the start screen (#426, #643, #644): the date at the knot, or, while a task is the
/// Knäuel, the Knäuel's head (date at the Knäuel, the thread, the task's row), then the sentence of
/// the day. Rows of the start list, so the Knäuel's head takes the swipes and the menu like any row;
/// the host wraps it. When the Knäuel gets done, its head stays for the moment (#644): the Knäuel
/// loosens green into the knot, the thread draws in, the row goes; Reduce Motion shows the end at once.
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
        if let knaeuel {
            row(knaeuel, KnaeuelHead(task: knaeuel, untangling: false))
        } else if let leaving {
            KnaeuelHead(task: leaving.task, untangling: true)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
        } else {
            tapping(StartDateLine(knaeuel: false))
                // The draft: 14 above the date line (#463).
                .padding(.top, 14)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
        }
        // At the titles' edge like the date and the Knäuel's row (#677): one edge for every word.
        tapping(StartHeadlineLine(tasks: tasks, openDone: openDone).padding(.leading, metrics.marginWidth + 12))
            .padding(.top, 6)
            // The draft: 16 under the headline (#463).
            .padding(.bottom, 16)
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
    }

    private func tapping(_ line: some View) -> some View {
        line
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }
    }
}

/// Where the glyph and the row's title stand, for the thread between them (#644).
private struct KnaeuelAnchors: PreferenceKey {
    enum Part: Hashable { case glyph, title }
    static let defaultValue: [Part: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Part: Anchor<CGRect>], nextValue: () -> [Part: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// The Knäuel's head (#643, #644, board "Morgen"): the date at the Knäuel, the task's row 64 pt in
/// under it, and the loose thread from the Knäuel's tail end down to just before the first word. One
/// row of the start list. At accessibility sizes the thread stays away, the Knäuel stays.
/// `untangling` plays the completion moment: green loosening into the knot (0.3 s), then the grey
/// knot (0.8 s), the thread drawing in by its trim, the row fading.
struct KnaeuelHead: View {
    let task: TaskItem
    let untangling: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var loosening: CGFloat = 0
    @State private var drawn: CGFloat = 1
    @State private var green = false

    var body: some View {
        let metrics = StartMetrics(typeSize)
        VStack(alignment: .leading, spacing: 0) {
            StartDateLine(knaeuel: true, loosening: untangling ? loosening : nil, green: green)
                .padding(.top, 14)
            KnaeuelRow(task: task)
                .padding(.top, 10)
                .padding(.bottom, 2)
                .opacity(untangling ? 0 : 1)
        }
        .overlayPreferenceValue(KnaeuelAnchors.self) { anchors in
            if !typeSize.isAccessibilitySize, let glyph = anchors[.glyph], let title = anchors[.title] {
                GeometryReader { geometry in
                    let tail = ThreadShape.knaeuelTail(in: geometry[glyph].insetBy(dx: 0.75, dy: 0.75))
                    let titleRect = geometry[title]
                    // Just before the first word, at the middle of its first line.
                    let end = CGPoint(x: titleRect.minX - 6, y: titleRect.minY + metrics(11))
                    KnaeuelThread(start: tail.end, direction: tail.direction, end: end)
                        .trim(from: 0, to: drawn)
                        .stroke(.primary, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("knaeuelHead")
        .task(id: untangling) {
            guard untangling else { return }
            green = true
            withAnimation(.easeInOut(duration: 0.3)) {
                loosening = 0.4
                drawn = 0.6
            }
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            withAnimation(.easeInOut(duration: 0.8)) {
                loosening = 1
                drawn = 0
                green = false
            }
        }
    }
}

/// The date, small and grey, at the sign of the day (#180 rule 1, #643): the knot while every task
/// lies in the box, the Knäuel in the ink and a fifth larger while one is being avoided. The sign
/// stands in the margin column, the date flush over the titles, 64 pt in (Henning, 2026-10-23; the
/// knot too since #677), in plain words instead of spaced capitals. During the moment (#644)
/// `loosening` blends the Knäuel into the knot, green until it is the knot.
struct StartDateLine: View {
    let knaeuel: Bool
    var loosening: CGFloat?
    var green = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        // Once a minute, so the line turns with the day without a save (#426).
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            HStack(spacing: 12) {
                if knaeuel {
                    glyph
                        .frame(width: metrics(36), height: metrics(18))
                        .anchorPreference(key: KnaeuelAnchors.self, value: .bounds) { [.glyph: $0] }
                        .frame(width: metrics.marginWidth, alignment: .leading)
                } else {
                    // The knot, first of its three places (#180, rule 1). Grey like the date: it is
                    // the mark, not something to tap (ADR-14).
                    ThreadGlyph(form: .knot, lineWidth: 1.5)
                        .frame(width: metrics(30), height: metrics(16))
                        .frame(width: metrics.marginWidth, alignment: .leading)
                }
                Text(timeline.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(metrics.margin)
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("startHeader")
        }
    }

    /// The Knäuel in the ink; during the moment the loosening line, green while it loosens (the one
    /// green moment, ADR-14), grey as the knot.
    @ViewBuilder
    private var glyph: some View {
        if let loosening {
            LooseningKnaeuel(progress: loosening)
                .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .padding(0.75)
                .foregroundStyle(green ? Color("Completed") : Color.secondary)
                .accessibilityHidden(true)
        } else {
            ThreadGlyph(form: .knaeuel, lineWidth: 1.5)
                .foregroundStyle(.primary)
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
                Text(StartHeadlineText.sentence(headline))
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
                            WeekString(beads: beads)
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

/// The Knäuel's row under the date (#643, Henning 2026-10-23, board "Morgen"): the title in New York
/// 64 pt in, flush with the date, under it how long the task has been carried and its tag. The
/// margin stays empty: the thread from the Knäuel runs there (#644).
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
                    .anchorPreference(key: KnaeuelAnchors.self, value: .bounds) { [.title: $0] }
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
