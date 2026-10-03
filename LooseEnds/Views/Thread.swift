import SwiftUI

/// The logo's thread (#180, step 3), drawn from the same curve as the icon
/// (`docs/design/logo/README.md`): a trochoid `x = a·t − b·sin t`, `y = −b·cos t`. With the
/// icon's values it loops once — the knot; with `b` below `a` it never crosses — the loose thread.
/// A shape, not a custom SF Symbol: the trim animates the drawing the same way `.drawOn` would,
/// and the curve stays one formula shared with the icon.
struct ThreadShape: Shape {
    enum Form {
        case knot, loose
    }

    var form: Form = .knot

    func path(in rect: CGRect) -> Path {
        let a = 90.0
        let b = form == .knot ? 230.0 : 50.0
        let range = form == .knot ? -3.5...3.0 : -6.8...6.0
        let steps = 120
        let points = (0...steps).map { i -> CGPoint in
            let t = range.lowerBound + (range.upperBound - range.lowerBound) * Double(i) / Double(steps)
            return CGPoint(x: a * t - b * sin(t), y: -b * cos(t))
        }
        let xs = points.map(\.x), ys = points.map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 1
        let minY = ys.min() ?? 0, maxY = ys.max() ?? 1
        let scale = min(rect.width / max(maxX - minX, 1), rect.height / max(maxY - minY, 1))
        let offsetX = rect.midX - (minX + maxX) / 2 * scale
        let offsetY = rect.midY - (minY + maxY) / 2 * scale
        var path = Path()
        for (index, point) in points.enumerated() {
            let mapped = CGPoint(x: point.x * scale + offsetX, y: point.y * scale + offsetY)
            if index == 0 {
                path.move(to: mapped)
            } else {
                path.addLine(to: mapped)
            }
        }
        return path
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

/// The completion moment (#180, rule 1): the knot draws itself in green, then fades. Green is
/// spent here and nowhere else (ADR-14). Reduce Motion shows it drawn at once.
struct CompletionKnot: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0
    @State private var visible = false
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 56

    var body: some View {
        ThreadGlyph(form: .knot, lineWidth: size / 12, drawn: drawn)
            .foregroundStyle(.green)
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
