import SwiftUI

/// The loose thread from the Knäuel to its row (#644, Henning 2026-10-23, board "Morgen"): two loose
/// loops from the same trochoid as the logo's thread (`a` = 4.0, `b` = 4.9), starting exactly at the
/// Knäuel's tail end in its direction, ending just before the first word of the row. The Knäuel has
/// the weight, the thread is loose; both are one line of 1.6 pt. Knäuel and thread stay two elements:
/// this shape lives only in the head of the start page.
struct KnaeuelThread: Shape {
    var start: CGPoint
    var direction: CGVector
    var end: CGPoint

    static let a = 4.0
    static let b = 4.9
    static let loops = 2.0
    static let steps = 120

    func path(in rect: CGRect) -> Path {
        ThreadShape.path(through: Self.points(from: start, direction: direction, to: end))
    }

    /// The thread's points: the trochoid over two turns, phased so that, once its ends are laid onto
    /// `start` and `end`, it leaves the start in `direction`; the phase is searched on a grid, the
    /// closest one wins. A zero direction takes the first phase.
    nonisolated static func points(from start: CGPoint, direction: CGVector, to end: CGPoint) -> [CGPoint] {
        guard start != end else { return [start] }
        let wanted = atan2(direction.dy, direction.dx)
        var best: (phase: Double, error: Double) = (0, .infinity)
        for i in 0..<72 {
            let phase = Double(i) / 72 * 2 * .pi
            let raw = rawPoints(phase: phase)
            let laid = lay(raw, from: start, to: end)
            let tangent = atan2(laid[1].y - laid[0].y, laid[1].x - laid[0].x)
            var error = abs(tangent - wanted).truncatingRemainder(dividingBy: 2 * .pi)
            if error > .pi { error = 2 * .pi - error }
            if error < best.error { best = (phase, error) }
        }
        return lay(rawPoints(phase: best.phase), from: start, to: end)
    }

    /// `x = a·t − b·sin t`, `y = −b·cos t` over two turns from `phase`, y pointing down.
    nonisolated static func rawPoints(phase: Double) -> [CGPoint] {
        (0...steps).map { i in
            let t = phase + loops * 2 * .pi * Double(i) / Double(steps)
            return CGPoint(x: a * t - b * sin(t), y: -b * cos(t))
        }
    }

    /// Rotates, scales and moves the curve so its first point lands on `start` and its last on `end`.
    nonisolated static func lay(_ points: [CGPoint], from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        guard let first = points.first, let last = points.last, first != last else { return points }
        let fromAngle = atan2(last.y - first.y, last.x - first.x)
        let toAngle = atan2(end.y - start.y, end.x - start.x)
        let fromLength = hypot(last.x - first.x, last.y - first.y)
        let toLength = hypot(end.x - start.x, end.y - start.y)
        let scale = toLength / fromLength
        let rotation = toAngle - fromAngle
        let (cosR, sinR) = (cos(rotation), sin(rotation))
        return points.map { point in
            let dx = (point.x - first.x) * scale
            let dy = (point.y - first.y) * scale
            return CGPoint(x: start.x + dx * cosR - dy * sinR, y: start.y + dx * sinR + dy * cosR)
        }
    }
}

/// The Knäuel loosening into the knot (#644, the completion moment): the Knäuel's curve and the
/// knot's, resampled to the same count, blended by `progress`; 0 is the Knäuel, 1 the knot. Both are
/// fitted into the rect like the glyphs are, so the end state is the knot as the date line draws it.
struct LooseningKnaeuel: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    static let count = 145

    func path(in rect: CGRect) -> Path {
        let from = ThreadShape.mapped(Self.resampled(ThreadShape.curvePoints(form: .knaeuel)), in: rect)
        let to = ThreadShape.mapped(Self.resampled(ThreadShape.curvePoints(form: .knot)), in: rect)
        let blended = zip(from, to).map { a, b in
            CGPoint(x: a.x + (b.x - a.x) * progress, y: a.y + (b.y - a.y) * progress)
        }
        return ThreadShape.path(through: blended)
    }

    /// `count` points along the polyline, by index: the curves are sampled evenly in their
    /// parameter already, so this keeps each one's shape.
    nonisolated static func resampled(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count > 1 else { return Array(repeating: points.first ?? .zero, count: count) }
        return (0..<count).map { i in
            let position = Double(i) / Double(count - 1) * Double(points.count - 1)
            let index = Int(position)
            guard index < points.count - 1 else { return points[points.count - 1] }
            let t = position - Double(index)
            let a = points[index], b = points[index + 1]
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }
}
