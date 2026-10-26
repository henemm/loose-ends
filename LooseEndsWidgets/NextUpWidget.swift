import AppIntents
import OSLog
import SwiftData
import SwiftUI
import WidgetKit

struct NextUpEntry: TimelineEntry {
    typealias Line = NextUpWidgetActions.Line

    let date: Date
    let lines: [Line]
    /// How many tasks "Now" holds in all, the Knäuel included: the number in the head.
    let total: Int
}

/// How many tasks a family shows (design briefing, screen 9; the large one came with #488).
private extension WidgetFamily {
    var lineLimit: Int {
        switch self {
        case .systemSmall: 1
        case .systemLarge, .systemExtraLarge: NextUpWidgetActions.maxLines
        default: 3
        }
    }
}

struct NextUpProvider: TimelineProvider {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Widget")

    func placeholder(in context: Context) -> NextUpEntry {
        let line = NextUpEntry.Line(id: UUID(), title: String(localized: "Follow up on the offer"), margin: String(localized: "Today"), pressing: true)
        return NextUpEntry(date: .now, lines: [line], total: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) {
        let (lines, total) = load(limit: context.family.lineLimit)
        completion(NextUpEntry(date: .now, lines: lines, total: total))
    }

    /// Right after a tap on the check the first entry shows the knot in that line's place; the
    /// second, once the knot stood, the list moved up (#521). Then every 15 minutes as before.
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
        let now = Date()
        let limit = context.family.lineLimit
        let (lines, total) = load(limit: limit)
        let mark = NextUpWidgetActions.loadMark(from: UserDefaults(suiteName: ModelContainerFactory.appGroup))
        let entries = NextUpWidgetActions.plan(lines: lines, total: total, mark: mark, limit: limit, now: now)
            .map { NextUpEntry(date: $0.date, lines: $0.lines, total: $0.total) }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(15 * 60))))
    }

    private func load(limit: Int) -> (lines: [NextUpEntry.Line], total: Int) {
        do {
            // The context does not retain its container (CLAUDE.md): keep it alive while fetching.
            let container = try ModelContainerFactory.make(syncs: false)
            return try NextUpWidgetActions.nextUp(in: ModelContext(container), limit: limit)
        } catch {
            Self.logger.error("Loading Next up failed: \(error, privacy: .public)")
            return ([], 0)
        }
    }
}

/// The widget follows the app's lists (#521, Henning 2026-10-17; design:
/// https://claude.ai/artifact/XCazDXib75oqQSHxP8Sqmj): paper, the knot in the head, the margin with
/// the one time that counts (#424), titles in New York, no circle before a task. At the end of a line
/// the check as the app's swipe shows it, white on green; a tap completes without opening the app and
/// the check becomes the knot, tied in green, before the list moves up. The title opens the task.
/// Small: the top task, set large. Medium: three. Large: six and "Neue Aufgabe".
struct NextUpWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextUpEntry

    private var shown: [NextUpEntry.Line] {
        Array(entry.lines.prefix(family.lineLimit))
    }

    /// Tasks "Now" holds beyond the lines shown; the line tying its knot is no longer counted.
    private var more: Int {
        max(entry.total - shown.filter { !$0.done }.count, 0)
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
                if family == .systemLarge || family == .systemExtraLarge {
                    footer
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) { Color("Paper") }
    }

    /// The knot and the name of the list, small and grey like the heads of the start screen; on the
    /// right how many tasks wait there, small like the numbers in the start screen's contents.
    private var header: some View {
        HStack(spacing: 7) {
            ThreadGlyph(form: .knot, lineWidth: 1.4)
                .frame(width: 21, height: 15)
            Text("Now")
                .font(.system(size: 10.5, weight: .semibold))
                .textCase(.uppercase)
                .tracking(1.2)
            Spacer(minLength: 4)
            if entry.total > 0 {
                Text(entry.total, format: .number)
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .contentTransition(.numericText(value: Double(entry.total)))
            }
        }
        .foregroundStyle(.secondary)
        .padding(.bottom, family == .systemSmall ? 0 : 6)
        .accessibilityElement(children: .combine)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Nothing lined up yet.")
                .font(.system(size: 17, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(.secondary)
                .padding(.top, 14)
            Spacer(minLength: 0)
        }
    }

    /// One task, set large, its time above it; the check at the foot finishes it.
    private func small(_ line: NextUpEntry.Line) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !margin(of: line).isEmpty {
                Text(margin(of: line))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(marginStyle(of: line))
                    .padding(.top, 13)
            }
            Button(intent: OpenTaskIntent(taskID: line.id)) {
                Text(line.title)
                    .font(.system(size: 19, weight: .medium, design: .serif))
                    .foregroundStyle(line.done ? .secondary : .primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.top, 3)
            Spacer(minLength: 6)
            HStack {
                if line.done {
                    tiedKnot
                } else {
                    Button(intent: CompleteTaskIntent(taskID: line.id)) {
                        CheckBadge(word: Text("Complete"))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.35).combined(with: .opacity))
                }
                Spacer(minLength: 4)
                if more > 0 {
                    Text(verbatim: "+\(more)")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(.easeOut(duration: 0.55), value: line.done)
    }

    /// Medium and large: margin, title and check per line, a hairline from the title column on.
    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, line in
                row(line)
                    .overlay(alignment: .top) {
                        if index > 0 {
                            Rectangle()
                                .fill(.secondary.opacity(0.3))
                                .frame(height: 0.5)
                                .padding(.leading, Self.marginWidth + Self.columnGap)
                        }
                    }
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private static let marginWidth: CGFloat = 44
    private static let columnGap: CGFloat = 10

    private func row(_ line: NextUpEntry.Line) -> some View {
        HStack(alignment: .center, spacing: Self.columnGap) {
            Text(margin(of: line))
                .font(.system(size: 11.5, weight: .medium).monospacedDigit())
                .foregroundStyle(marginStyle(of: line))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .minimumScaleFactor(0.85)
                .frame(width: Self.marginWidth, alignment: .trailing)
            Button(intent: OpenTaskIntent(taskID: line.id)) {
                Text(line.title)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(line.done ? .secondary : .primary)
                    .lineLimit(family == .systemMedium ? 1 : 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            ZStack {
                if line.done {
                    tiedKnot
                } else {
                    Button(intent: CompleteTaskIntent(taskID: line.id)) {
                        CheckBadge(word: nil)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale(scale: 0.35).combined(with: .opacity))
                }
            }
            .frame(width: 34)
        }
        .frame(maxHeight: .infinity)
        .animation(.easeOut(duration: 0.55), value: line.done)
    }

    /// "Neue Aufgabe" opens capture by link (#521); on the right how many wait beyond the six.
    private var footer: some View {
        HStack {
            Link(destination: NextUpWidgetActions.captureURL) {
                Label("New task", systemImage: "mic")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .widgetAccentable()
            }
            Spacer(minLength: 4)
            if more > 0 {
                Text("\(more) more")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 30)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.secondary.opacity(0.3))
                .frame(height: 0.5)
        }
    }

    /// The completion moment, as in the app (#180, rule 1): the knot ties itself in green.
    private var tiedKnot: some View {
        ThreadGlyph(form: .knot, lineWidth: 1.8)
            .foregroundStyle(Color("Completed"))
            .frame(width: 32, height: 23)
            .transition(KnotTying())
            .accessibilityLabel(Text("Completed"))
    }

    private func margin(of line: NextUpEntry.Line) -> String {
        line.done ? String(localized: "Completed") : line.margin
    }

    private func marginStyle(of line: NextUpEntry.Line) -> Color {
        if line.done { return Color("Completed") }
        return line.pressing ? .red : .secondary
    }
}

/// The check as the app's swipe shows it (`checkmark` on `Completed`, #494), white on green. In the
/// tinted and clear home screen the check is cut out of the badge, so it stays legible in one colour.
private struct CheckBadge: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let word: Text?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark")
                .font(.system(size: word == nil ? 13 : 12, weight: .bold))
            if let word {
                word.font(.system(size: 13, weight: .semibold))
            }
        }
        .padding(.horizontal, word == nil ? 0 : 11)
        .frame(width: word == nil ? 34 : nil, height: word == nil ? 26 : 28)
        .foregroundStyle(renderingMode == .fullColor ? Color.white : Color.black)
        .blendMode(renderingMode == .fullColor ? .normal : .destinationOut)
        .background(Capsule().fill(Color("Completed")))
        .compositingGroup()
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Complete"))
    }
}

/// The knot draws itself from its loose end on, like the app's `CompletionKnot` trims its thread: a
/// mask grows from the leading edge. Without motion WidgetKit shows it tied at once.
private struct KnotTying: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content.mask(alignment: .leading) {
            Rectangle()
                .scaleEffect(x: phase.isIdentity ? 1 : 0, anchor: .leading)
        }
    }
}

struct NextUpWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextUp", provider: NextUpProvider()) { entry in
            NextUpWidgetView(entry: entry)
        }
        .configurationDisplayName("Now")
        .description("The Knäuel and what is on now, one tap to finish it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
