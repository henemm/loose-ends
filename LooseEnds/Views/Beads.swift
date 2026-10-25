import SwiftUI

/// The bead (#645, Henning 2026-10-23, board "Die Zeichen"): a short string with one hollow bead and a
/// highlight. In a row's trait line it says "counts"; on the week's string every completion of a
/// counting task is one. Drawn, not an SF Symbol, like the thread (#350, the exceptions of #642).
struct PearlGlyph: View {
    /// Drawn 36 × 12 as on the canvas; the frame scales it.
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 36, size.height / 12)
            let origin = CGPoint(x: (size.width - 36 * scale) / 2, y: (size.height - 12 * scale) / 2)
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
            }
            var string = Path()
            string.move(to: point(0, 6))
            string.addLine(to: point(36, 6))
            context.stroke(string, with: .color(.secondary), style: StrokeStyle(lineWidth: 0.7 * scale, lineCap: .round))
            let bead = Path(ellipseIn: CGRect(x: point(18, 6).x - 4.3 * scale, y: point(18, 6).y - 4.3 * scale,
                                              width: 8.6 * scale, height: 8.6 * scale))
            context.fill(bead, with: .color(.secondary.opacity(0.15)))
            context.stroke(bead, with: .color(.secondary), lineWidth: 1 * scale)
            let shine = Path(ellipseIn: CGRect(x: point(16.6, 4.6).x - 1.1 * scale, y: point(16.6, 4.6).y - 1.1 * scale,
                                               width: 2.2 * scale, height: 2.2 * scale))
            context.fill(shine, with: .color(Paper.ground))
        }
        .accessibilityHidden(true)
    }
}

/// The week's string (#645, Henning 2026-10-23, version A): one sagging string, the beads packed from
/// the left at equal distances, no empty places, no goal. The newest bead is green for 1.1 s after it
/// came (the completion moment, ADR-14), grey after. Without a bead the caller leaves the row out.
struct WeekString: View {
    let beads: [ViewRules.Bead]
    /// The string's length (#655): the places still empty stand as fine dots. Nil draws no dots.
    var length: Int?
    @State private var fresh = false
    /// The newest bead the string has shown; a new one turns green, however the count changes.
    @State private var seen: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    static let height: CGFloat = 47
    /// The string's ends sit 10 pt in; the beads start 40 pt in and stand 40 pt apart while there is room.
    private static let inset: CGFloat = 10
    private static let firstBead: CGFloat = 40
    private static let spacing: CGFloat = 40
    private static let radius: CGFloat = 6

    var body: some View {
        let metrics = StartMetrics(typeSize)
        GeometryReader { geometry in
            let width = geometry.size.width
            let places = Self.centers(count: max(beads.count, length ?? 0), width: width)
            let centers = Array(places.prefix(beads.count))
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    context.stroke(Self.string(width: size.width), with: .color(.secondary),
                                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    for center in centers {
                        let bead = Path(ellipseIn: CGRect(x: center.x - Self.radius, y: center.y - Self.radius,
                                                          width: 2 * Self.radius, height: 2 * Self.radius))
                        context.fill(bead, with: .color(.secondary))
                    }
                    // The places still to fill (#655, Henning: "feine Punkte"): the goal without a number.
                    for place in places.dropFirst(beads.count) {
                        let dot = Path(ellipseIn: CGRect(x: place.x - 1.5, y: place.y - 1.5, width: 3, height: 3))
                        context.fill(dot, with: .color(.secondary.opacity(0.45)))
                    }
                }
                if let last = centers.last {
                    Circle()
                        .fill(Color("Completed"))
                        .frame(width: 2 * Self.radius, height: 2 * Self.radius)
                        .position(last)
                        .opacity(fresh ? 1 : 0)
                        .animation(.easeIn(duration: 0.3), value: fresh)
                }
            }
        }
        .frame(height: metrics(Self.height))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(length.map { Text("\(beads.count) of \($0) beads on the string") } ?? Text("\(beads.count) beads on the string"))
        .accessibilityIdentifier("weekString")
        .onChange(of: beads.last?.id, initial: true) { _, last in
            // Green only for a bead that came while the string was on screen, never on appear. By
            // the newest bead, not the count: a full string stays at seven when the eighth comes.
            defer { seen = last ?? "" }
            guard seen != nil, let last, last != seen else { return }
            fresh = true
        }
        .task(id: fresh) {
            guard fresh else { return }
            do {
                try await Task.sleep(for: .milliseconds(1100))
            } catch {
                return
            }
            fresh = false
        }
    }

    /// The string as on the canvas: a quadratic curve from 10 pt in to 10 pt before the end, sagging
    /// 12 pt in the middle (the control point at 26 draws the curve down to 20).
    nonisolated static func string(width: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: inset, y: 14))
        path.addQuadCurve(to: CGPoint(x: width - inset, y: 14), control: CGPoint(x: width / 2, y: 26))
        return path
    }

    /// Where the beads sit: from the left at 40 pt apart, closer only once the string is full, each
    /// on the curve.
    nonisolated static func centers(count: Int, width: CGFloat) -> [CGPoint] {
        guard count > 0 else { return [] }
        let room = width - firstBead - inset - radius
        let step = count > 1 ? min(spacing, room / CGFloat(count - 1)) : spacing
        return (0..<count).map { index in
            let x = firstBead + CGFloat(index) * step
            let t = (x - inset) / (width - 2 * inset)
            let y = (1 - t) * (1 - t) * 14 + 2 * (1 - t) * t * 26 + t * t * 14
            return CGPoint(x: x, y: y)
        }
    }
}

/// The week's string as the start page draws it (draft C3, #677): at three fifths, so beads of 3.6 pt
/// on a 0.9 pt line, 24 pt apart, five places within 200 pt, a shade lighter than the rows' grey as in
/// the draft. Used at the end of the page and under the Sunday sentence.
struct QuietWeekString: View {
    let beads: [ViewRules.Bead]
    var length: Int?
    @Environment(\.dynamicTypeSize) private var typeSize

    static let scale: CGFloat = 0.6
    static let width: CGFloat = 340
    /// The string's own 10 pt inset at this scale: where its line starts.
    static var inset: CGFloat { 10 * scale }

    var body: some View {
        let metrics = StartMetrics(typeSize)
        WeekString(beads: beads, length: length)
            .frame(width: Self.width)
            .scaleEffect(Self.scale, anchor: .topLeading)
            .frame(width: Self.width * Self.scale, height: metrics(WeekString.height) * Self.scale, alignment: .topLeading)
            // The draft's lighter grey (#9A9B93 on the paper instead of #77786F); the new bead's green stays clear.
            .opacity(0.75)
    }
}

/// "Beads" on the start screen (#645, #647, #655): the string of five with its empty places as dots,
/// and under it the sentence: "For the beads: …" while the string fills, "The string is full. For the
/// beads: …" once it is (the win, Henning 2026-10-24); the next bead starts a new string. Shown once a
/// bead exists or a sentence is set; before that nothing, as before. Quiet since #677 (draft C3): no
/// caption, at the end of the page, at the titles' edge, the string shorter, the sentence small.
struct WeekStringRows: View {
    let string: ViewRules.BeadString
    /// Every task, for the Sunday rule.
    let all: [TaskItem]
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(FieldSettingsStore.self) private var fieldSettings: FieldSettingsStore?

    var body: some View {
        let reward = fieldSettings?.reward ?? ""
        let inUse = !string.beads.isEmpty || string.filled > 0 || !reward.isEmpty
        if inUse {
            let metrics = StartMetrics(typeSize)
            let titlesEdge = metrics.marginWidth + 12
            QuietWeekString(beads: string.beads, length: ViewRules.stringLength)
                // The string's own inset, scaled, brings its start back to the titles' edge.
                .padding(.leading, titlesEdge - QuietWeekString.inset)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 36)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
            if string.isFull {
                FullStringLine(reward: reward)
                    .padding(.leading, titlesEdge)
                    .listRowSeparator(.hidden)
                    .startRow(metrics)
                    .paperRow()
            } else if !reward.isEmpty, let fieldSettings {
                RewardLine(store: fieldSettings)
                    .padding(.leading, titlesEdge)
                    .listRowSeparator(.hidden)
                    .startRow(metrics)
                    .paperRow()
            }
        }
    }
}

/// The win (#655): the string is full, the sentence is due. In the ink, not green: the green was the
/// fifth bead's moment (ADR-14). It stands until the next bead starts a new string.
struct FullStringLine: View {
    let reward: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        Group {
            if reward.isEmpty {
                Text("The string is full.")
            } else {
                Text("The string is full. For the beads: \(reward).")
            }
        }
        .font(.system(size: metrics(14), design: .serif))
        .italic()
        .foregroundStyle(.primary)
        .padding(.vertical, 4)
        .accessibilityIdentifier("fullStringLine")
    }
}

/// "Für die Perlen: Samstag Kino." (#647, Milkman's bundling at its simplest): one free sentence for
/// the beads, in italics under the string. A tap puts the cursor into it; Return or leaving saves;
/// nothing is checked. Empty means no line, so the first sentence is written in Settings › Fields.
struct RewardLine: View {
    let store: FieldSettingsStore
    @State private var draft = ""
    @State private var editing = false
    @FocusState private var focused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let metrics = StartMetrics(typeSize)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("For the beads:")
                .accessibilityHidden(true)
            if editing {
                TextField("For the beads", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .accessibilityIdentifier("rewardField")
            } else {
                Text(verbatim: store.reward + ".")
            }
        }
        .font(.system(size: metrics(14), design: .serif))
        .italic()
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !editing else { return }
            draft = store.reward
            editing = true
            focused = true
        }
        .onChange(of: focused) { _, isFocused in
            if !isFocused, editing { commit() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("For the beads: \(store.reward)"))
        .accessibilityIdentifier("rewardLine")
    }

    private func commit() {
        store.setReward(draft)
        editing = false
        focused = false
    }
}
