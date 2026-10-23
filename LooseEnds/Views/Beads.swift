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
    @State private var fresh = false
    @State private var seen: Int?
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
            let centers = Self.centers(count: beads.count, width: width)
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    context.stroke(Self.string(width: size.width), with: .color(.secondary),
                                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    for center in centers {
                        let bead = Path(ellipseIn: CGRect(x: center.x - Self.radius, y: center.y - Self.radius,
                                                          width: 2 * Self.radius, height: 2 * Self.radius))
                        context.fill(bead, with: .color(.secondary))
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
        .accessibilityLabel(Text("\(beads.count) beads this week"))
        .accessibilityIdentifier("weekString")
        .onChange(of: beads.count, initial: true) { _, count in
            // Green only for a bead that came while the string was on screen, never on appear.
            defer { seen = count }
            guard let seen, count > seen else { return }
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

/// "This week" on the start screen (#645): the caption and the string as two rows under "Now", only
/// while the week has a bead.
struct WeekStringRows: View {
    let beads: [ViewRules.Bead]
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if !beads.isEmpty {
            let metrics = StartMetrics(typeSize)
            ZoneCaption("This week")
            WeekString(beads: beads)
                .listRowSeparator(.hidden)
                .startRow(metrics)
                .paperRow()
        }
    }
}
