import SwiftUI

/// The zones of the iPhone start screen (#368). Each one is a few rows of the start list, so they
/// are built to sit inside a `List` and carry their own row look (`paperRow`).

/// The heading of a zone, as a row of its own: since #677 (draft C3) a word in the margin column, grey,
/// instead of spaced capitals; no line beside it, the writing line just above is line enough.
struct ZoneCaption: View {
    private let title: LocalizedStringKey
    /// The number after the caption (#637): "Now" carries the app icon's number. In ink, not accent:
    /// it is not tappable (ADR-14).
    private let count: Int?
    private let countID: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    init(_ title: LocalizedStringKey, count: Int? = nil, countID: String? = nil) {
        self.title = title
        self.count = count
        self.countID = countID
    }

    var body: some View {
        let metrics = StartMetrics(typeSize)
        MarginCaption(title: title, count: count, countID: countID)
            // Space above, little below: the caption belongs to what follows (draft: 22 above, 4 below, #463).
            .padding(.top, 22)
            .padding(.bottom, 4)
            .listRowSeparator(.hidden)
            .startRow(metrics)
            .paperRow()
    }
}

/// The margin word (#677): right-aligned in the rows' margin column, where the rows keep their time.
struct MarginCaption: View {
    let title: LocalizedStringKey
    var count: Int?
    var countID: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            if let count {
                Text(verbatim: "\(count)")
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .accessibilityLabel(Text(verbatim: "\(count)"))
                    .accessibilityIdentifier(countID ?? "")
            }
        }
        .font(metrics.margin)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: metrics.marginWidth, alignment: .trailing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The caption's text alone, for a zone that sets it inside its own row (the index, #433).
struct ZoneCaptionText: View {
    let title: LocalizedStringKey
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        Text(title)
            .font(metrics.caption)
            .textCase(.uppercase)
            .tracking(metrics.captionTracking)
            .foregroundStyle(.secondary)
    }
}

/// What stands for now: the Knäuel first (#703), then the first five of the "Now" rule, the rest
/// behind "N more", which unfolds in place. The unfolded state is local and not kept: once five or
/// fewer are left it folds again, so a later sixth task never finds the block open unasked (#398).
/// `row` builds one task's row and `knaeuelRow` the Knäuel's, so the swipes, the menu and the Done
/// window stay with the caller. When the Knäuel gets done its row stays for the moment (#644): the
/// state sits on the caption, which always stands.
struct NowBlock<Row: View, KnaeuelRow: View>: View {
    private let now: ViewRules.NowTasks
    private let all: [TaskItem]
    private let row: (TaskItem) -> Row
    private let knaeuelRow: (TaskItem, KnaeuelHead) -> KnaeuelRow
    @State private var ownExpanded = false
    /// The Knäuel just completed, kept for its moment.
    @State private var leaving: Leaving?
    /// The host's fold state, so the Mac's keys see the same rows (#480); the sidebar keeps its own.
    private let hostExpanded: Binding<Bool>?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Leaving: Equatable {
        let task: TaskItem
        let id = UUID()
        static func == (a: Leaving, b: Leaving) -> Bool { a.id == b.id }
    }

    static var limit: Int { 5 }

    init(tasks all: [TaskItem], expanded: Binding<Bool>? = nil,
         @ViewBuilder row: @escaping (TaskItem) -> Row,
         @ViewBuilder knaeuelRow: @escaping (TaskItem, KnaeuelHead) -> KnaeuelRow) {
        self.now = ViewRules.now(in: all)
        self.all = all
        self.hostExpanded = expanded
        self.row = row
        self.knaeuelRow = knaeuelRow
    }

    private var tasks: [TaskItem] { now.all }

    private var expanded: Bool {
        get { hostExpanded?.wrappedValue ?? ownExpanded }
        nonmutating set {
            if let hostExpanded { hostExpanded.wrappedValue = newValue } else { ownExpanded = newValue }
        }
    }

    var body: some View {
        let metrics = StartMetrics(typeSize)
        // The app icon's number, the same everywhere (#637): every task it counts stands below, the
        // Knäuel first (#703).
        ZoneCaption("Now", count: now.count, countID: "nowCount")
            // On the caption, which always stands: the button is gone at five or fewer, the hint with rows.
            .onChange(of: tasks.count) { _, count in
                if count <= Self.limit { expanded = false }
            }
            .onChange(of: now.knaeuel?.id) { old, new in
                // Gone because it got done: the moment. Released, parked or moved: no green.
                if new == nil, let old, let task = all.first(where: { $0.id == old }), task.status == .done, !reduceMotion {
                    leaving = Leaving(task: task)
                } else {
                    leaving = nil
                }
            }
            .task(id: leaving) {
                guard leaving != nil else { return }
                do {
                    try await Task.sleep(for: KnaeuelHead.momentDuration + .milliseconds(150))
                } catch {
                    return
                }
                withAnimation(.easeInOut(duration: 0.3)) { leaving = nil }
            }
        if let knaeuel = now.knaeuel {
            knaeuelRow(knaeuel, KnaeuelHead(task: knaeuel, untangling: false))
        } else if let leaving {
            KnaeuelHead(task: leaving.task, untangling: true)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
        }
        if tasks.isEmpty {
            if now.knaeuel == nil && leaving == nil {
                Text("Swipe left on any task to line it up here.")
                    .font(metrics.rowMeta)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 11)
                    .startRow(metrics)
                    .paperRow()
            }
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
            .font(StartMetrics(typeSize).rowMeta)
            .foregroundStyle(.secondary)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The label stays the visible words ("2 more"); the hint says what a tap does (#398).
        .accessibilityHint(expanded ? Text("Shows only the first five tasks") : Text("Shows the remaining tasks"))
        .accessibilityIdentifier("nowMore")
        .listRowSeparator(.hidden)
        .startRow(StartMetrics(typeSize))
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
    /// What the line opens; the Mac sidebar marks the line of the open view (#476).
    var target: ViewSelection?
    /// The "Start" line of the Mac sidebar (#583): opens the start page, marked while no view is open.
    var opensStart = false
    /// ⌘1 on the Start line (#583).
    var shortcut: KeyboardShortcut?
    let action: () -> Void
}

/// "Contents" (#421, Henning 2026-10-15): the quiet places of the iPhone start screen as the first
/// page of a notebook. Names in New York, a dotted leader, the count small in SF. A deliberate
/// exception to #180 rule 2, for this page only. Groups are kept apart by space, not by cards;
/// tags and projects with tasks follow their line as italic words, one tap to their list.
struct ContentsIndex: View {
    let groups: [[IndexLine]]
    /// The open view, marked in the sidebar on Mac and iPad (#334); nil on the iPhone after Back,
    /// where the index is a page and not a sidebar.
    var selected: ViewSelection?
    /// The iPhone's page (#677): "Contents" as a margin word, the lines at the titles' edge. The Mac
    /// sidebar keeps its caption and its full width.
    var inMargin = false
    let select: (ViewSelection) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        VStack(alignment: .leading, spacing: 0) {
            if inMargin {
                // Draft C3 (#677): a hairline at the titles' edge closes "Now", the word "Contents" stands
                // in the margin beside the first line.
                Rectangle()
                    .fill(.separator)
                    .frame(height: 0.5)
                    .padding(.leading, metrics.marginWidth + 12)
                    .padding(.top, 18)
                    .padding(.bottom, 14)
                    .accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Contents")
                        .font(metrics.margin)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: metrics.marginWidth, alignment: .trailing)
                        .accessibilityAddTraits(.isHeader)
                    lines(metrics)
                }
            } else {
                // Inside the index's row, so no row inset lies between the caption and the first line (#433).
                ZoneCaptionText(title: "Contents")
                    .padding(.top, 22)
                    .padding(.bottom, 4)
                lines(metrics)
            }
        }
        .padding(.bottom, 28)
        .listRowSeparator(.hidden)
        .indexRow(metrics)
        .paperRow()
    }

    private func lines(_ metrics: StartMetrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    // The draft keeps the groups apart by 10 pt of space, not by a card or a line.
                    Spacer().frame(height: metrics(10))
                }
                ForEach(group) { line in
                    lineButton(line, metrics: metrics)
                    if !line.words.isEmpty {
                        words(line.words, metrics: metrics)
                    }
                }
            }
        }
    }

    /// Whether a line is marked as the open one: the Start line while nothing is chosen (#583), a
    /// view's line while that view is.
    static func isOpen(_ line: IndexLine, selected: ViewSelection?) -> Bool {
        if line.opensStart { return selected == nil }
        return selected != nil && line.target == selected
    }

    private func lineButton(_ line: IndexLine, metrics: StartMetrics) -> some View {
        let isOpen = Self.isOpen(line, selected: selected)
        return Button(action: line.action) {
            IndexLineLabel(title: line.title, count: line.count, metrics: metrics)
                .padding(.horizontal, isOpen ? 8 : 0)
                .background(isOpen ? Color.primary.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, isOpen ? -8 : 0)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(line.shortcut)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .accessibilityIdentifier(line.id)
    }

    /// Accent, since each word opens its list (ADR-14); the count stays grey. Upright in New York with a
    /// grey comma between, so the words read as a sentence, as in the draft (#433). Set like a paragraph
    /// at line height 1.5: no padding around the words, so a second line follows at the draft's distance (#463).
    private func words(_ words: [IndexWord], metrics: StartMetrics) -> some View {
        FlowLayout(spacing: metrics(5)) {
            ForEach(Array(words.enumerated()), id: \.element.id) { index, word in
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Button {
                        select(word.target)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(word.name)
                                .font(metrics.word)
                                .foregroundStyle(.tint)
                            Text(verbatim: "\(word.count)")
                                .font(metrics.wordCount)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(word.id)
                    if index < words.count - 1 {
                        Text(verbatim: ",")
                            .font(metrics.word)
                            .italic()
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.leading, metrics(18))
        .padding(.bottom, metrics(6))
    }
}

/// A line of the notebook index: the name in New York, a dotted leader, the count small in SF; a
/// zero is left out (#180). Shared by the index and the pages of tags and projects (#428).
struct IndexLineLabel: View {
    let title: String
    let count: Int
    /// The start screen passes its draft sizes (#463); the pages of tags and projects keep the text styles.
    var metrics: StartMetrics?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(metrics?.indexLine ?? .title3)
                .fontDesign(.serif)
                .foregroundStyle(.primary)
                // The name keeps its width; the dotted leader gives way (a narrow sidebar cut it to "Als nä…", #526).
                .lineLimit(1)
                .layoutPriority(1)
            if typeSize.isAccessibilitySize {
                Spacer(minLength: 4)
            } else {
                // Close, fine dots on the baseline, as the draft's dotted rule (#463).
                Leader()
                    .stroke(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [0, 3.5]))
                    .frame(height: 1.5)
                    .accessibilityHidden(true)
            }
            // A zero is left out (#180), but its place stays, so every leader ends at the same edge (#433).
            Text(verbatim: "\(max(count, 0))")
                .font(metrics?.indexCount ?? .subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .opacity(count > 0 ? 1 : 0)
                .accessibilityHidden(count == 0)
        }
        .padding(.vertical, metrics.map { $0(7) } ?? 6)
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
