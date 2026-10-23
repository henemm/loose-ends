import SwiftUI

/// The logo's thread (#180, step 3), drawn from the same curve as the icon
/// (`docs/design/logo/README.md`): a trochoid `x = a·t − b·sin t`, `y = −b·cos t`. With the
/// icon's values it loops once — the knot; with `b` below `a` it never crosses — the loose thread.
/// A shape, not a custom SF Symbol: the trim animates the drawing the same way `.drawOn` would,
/// and the curve stays one formula shared with the icon.
struct ThreadShape: Shape {
    enum Form {
        case knot, loose
        /// "Das Knäuel" (#643, Henning 2026-10-23): three dense loops and a short end running out flat
        /// to the right, the one task being avoided. Drawn by hand on the design canvas, not from the
        /// formula; the second exception to #350 after the thread itself.
        case knaeuel
    }

    var form: Form = .knot

    /// The Knäuel as decided on the canvas (board "Die Zeichen", viewBox 40 × 20): the start point
    /// and six cubic segments, each as control 1, control 2, end.
    nonisolated static let knaeuelStart = CGPoint(x: 6, y: 8)
    nonisolated static let knaeuelCurves: [(CGPoint, CGPoint, CGPoint)] = [
        (CGPoint(x: 8, y: 2), CGPoint(x: 16, y: 1), CGPoint(x: 19, y: 5.5)),
        (CGPoint(x: 21, y: 9), CGPoint(x: 14, y: 12), CGPoint(x: 11, y: 8.5)),
        (CGPoint(x: 9, y: 5.5), CGPoint(x: 15, y: 3.5), CGPoint(x: 18, y: 7)),
        (CGPoint(x: 20, y: 10), CGPoint(x: 15, y: 12), CGPoint(x: 13, y: 9.5)),
        (CGPoint(x: 12, y: 8), CGPoint(x: 15, y: 6.5), CGPoint(x: 17.5, y: 6.8)),
        (CGPoint(x: 21, y: 7.2), CGPoint(x: 24, y: 8.6), CGPoint(x: 26, y: 11)),
    ]

    /// The raw curve, unscaled, y pointing down: shared by this shape and the menu bar symbol (#366).
    /// The Knäuel's curves are sampled finely enough to stroke as a polyline like the others.
    nonisolated static func curvePoints(form: Form) -> [CGPoint] {
        if form == .knaeuel {
            var points = [knaeuelStart]
            var from = knaeuelStart
            for (c1, c2, to) in knaeuelCurves {
                for i in 1...24 {
                    let t = Double(i) / 24
                    let u = 1 - t
                    let x = u * u * u * from.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * to.x
                    let y = u * u * u * from.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * to.y
                    points.append(CGPoint(x: x, y: y))
                }
                from = to
            }
            return points
        }
        let a = 90.0
        let b = form == .knot ? 230.0 : 50.0
        let range = form == .knot ? -3.5...3.0 : -6.8...6.0
        let steps = 120
        return (0...steps).map { i -> CGPoint in
            let t = range.lowerBound + (range.upperBound - range.lowerBound) * Double(i) / Double(steps)
            return CGPoint(x: a * t - b * sin(t), y: -b * cos(t))
        }
    }

    func path(in rect: CGRect) -> Path {
        Self.path(through: Self.mapped(Self.curvePoints(form: form), in: rect))
    }

    /// The curve fitted into `rect`, aspect kept, centered: the one mapping of the glyph, so the
    /// thread of #644 finds the Knäuel's tail end exactly where it is drawn.
    nonisolated static func mapped(_ points: [CGPoint], in rect: CGRect) -> [CGPoint] {
        let xs = points.map(\.x), ys = points.map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 1
        let scale = min(rect.width / max(maxX - minX, 1), rect.height / max(maxY - minY, 1))
        let offsetX = rect.midX - (minX + maxX) / 2 * scale
        let offsetY = rect.midY - (minY + maxY) / 2 * scale
        return points.map { CGPoint(x: $0.x * scale + offsetX, y: $0.y * scale + offsetY) }
    }

    nonisolated static func path(through points: [CGPoint]) -> Path {
        var path = Path()
        for (index, point) in points.enumerated() {
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    /// Where the Knäuel's thread ends and which way it runs there (#644), in `rect`: the last point
    /// of the drawn curve and the direction of its last segment.
    nonisolated static func knaeuelTail(in rect: CGRect) -> (end: CGPoint, direction: CGVector) {
        let points = mapped(curvePoints(form: .knaeuel), in: rect)
        let end = points[points.count - 1]
        let before = points[points.count - 2]
        return (end, CGVector(dx: end.x - before.x, dy: end.y - before.y))
    }
}

/// The thread as a stroked glyph, decorative: VoiceOver reads the text beside it.
struct ThreadGlyph: View {
    var form: ThreadShape.Form = .knot
    var lineWidth: CGFloat = 2
    /// 0 draws nothing, 1 the whole thread.
    var drawn: CGFloat = 1

    var body: some View {
        ThreadShape(form: form)
            .trim(from: 0, to: drawn)
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .padding(lineWidth / 2)
            .accessibilityHidden(true)
    }
}

/// Counts completions so the knot can tie itself once per finished task, wherever it was
/// finished (list swipe, menu or detail, which closes right after).
@MainActor @Observable
final class CompletionPulse {
    private(set) var count = 0

    func fire() {
        count += 1
    }
}

/// The completion moment (#180, rule 1): the knot draws itself in the app's completion green
/// (`Completed`, the same as the swipe action, #494), then fades. Green is spent here and nowhere
/// else (ADR-14). Reduce Motion shows it drawn at once. Used by the app only: the app's catalog holds `Completed`.
struct CompletionKnot: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0
    @State private var visible = false
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56

    var body: some View {
        ThreadGlyph(form: .knot, lineWidth: size / 12, drawn: drawn)
            .foregroundStyle(Color("Completed"))
            .frame(width: size * 1.6, height: size)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(false)
            .sensoryFeedback(.success, trigger: trigger)
            .task(id: trigger) {
                guard trigger > 0 else { return }
                drawn = reduceMotion ? 1 : 0
                visible = true
                if !reduceMotion {
                    withAnimation(.easeOut(duration: 0.55)) { drawn = 1 }
                }
                do {
                    try await Task.sleep(for: .milliseconds(1100))
                } catch {
                    return // A newer completion took over.
                }
                withAnimation(.easeIn(duration: 0.3)) { visible = false }
            }
    }
}
