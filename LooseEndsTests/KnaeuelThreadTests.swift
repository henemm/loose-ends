import Foundation
import Testing
@testable import LooseEnds

/// The thread from the Knäuel to its row and the loosening into the knot (#644).
@Suite("Der Faden zum Knäuel (#644)") struct KnaeuelThreadTests {
    private func angle(_ v: CGVector) -> Double { atan2(v.dy, v.dx) }

    private func degrees(between a: Double, and b: Double) -> Double {
        var d = abs(a - b).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d = 2 * .pi - d }
        return d * 180 / .pi
    }

    @Test("The thread starts at the Knäuel's tail end in its direction and ends before the word")
    func joinsTheKnaeuel() throws {
        let rect = CGRect(x: 0.75, y: 14.75, width: 34.5, height: 16.5)
        let tail = ThreadShape.knaeuelTail(in: rect)
        let end = CGPoint(x: 58, y: 66)
        let points = KnaeuelThread.points(from: tail.end, direction: tail.direction, to: end)
        #expect(points.count == KnaeuelThread.steps + 1)
        let first = try #require(points.first)
        let last = try #require(points.last)
        #expect(abs(first.x - tail.end.x) < 1e-6 && abs(first.y - tail.end.y) < 1e-6, "no gap at the Knäuel")
        #expect(abs(last.x - end.x) < 1e-6 && abs(last.y - end.y) < 1e-6, "ends before the word")
        let start = angle(CGVector(dx: points[1].x - first.x, dy: points[1].y - first.y))
        #expect(degrees(between: start, and: angle(tail.direction)) < 6, "tangent to the tail, the phase grid is 5°")
        // Two loops: the curve turns back on itself four times along the way.
        var turns = 0
        for i in 1..<(points.count - 1) {
            let before = points[i].x - points[i - 1].x, after = points[i + 1].x - points[i].x
            if (before < 0) != (after < 0) { turns += 1 }
        }
        #expect(turns == 4)
    }

    @Test("The Knäuel's tail end lies at the drawn curve's last point, bottom right of the glyph")
    func tailEnd() {
        let rect = CGRect(x: 0, y: 0, width: 36, height: 18)
        let tail = ThreadShape.knaeuelTail(in: rect)
        #expect(tail.end.x > 30 && tail.end.x <= 36)
        #expect(tail.end.y > 12 && tail.end.y <= 18)
        #expect(tail.direction.dx > 0 && tail.direction.dy > 0, "runs down to the right")
    }

    @Test("Laying the curve keeps its shape: the ends land, the middle scales with them")
    func lay() {
        let raw = KnaeuelThread.rawPoints(phase: 0)
        let laid = KnaeuelThread.lay(raw, from: CGPoint(x: 10, y: 10), to: CGPoint(x: 10, y: 110))
        #expect(abs(laid[0].x - 10) < 1e-9 && abs(laid[0].y - 10) < 1e-9)
        #expect(abs(laid[laid.count - 1].x - 10) < 1e-9 && abs(laid[laid.count - 1].y - 110) < 1e-9)
        let rawLength = hypot(raw[raw.count - 1].x - raw[0].x, raw[raw.count - 1].y - raw[0].y)
        let rawMid = hypot(raw[60].x - raw[0].x, raw[60].y - raw[0].y)
        let laidMid = hypot(laid[60].x - laid[0].x, laid[60].y - laid[0].y)
        #expect(abs(laidMid - rawMid * 100 / rawLength) < 1e-6)
        #expect(KnaeuelThread.points(from: .zero, direction: CGVector(dx: 1, dy: 1), to: .zero) == [.zero])
    }

    @Test("Loosening: 0 is the Knäuel, 1 the knot, both fitted into the same rect")
    func loosening() {
        let rect = CGRect(x: 0, y: 0, width: 36, height: 18)
        let knaeuel = LooseningKnaeuel(progress: 0).path(in: rect).boundingRect
        let knot = LooseningKnaeuel(progress: 1).path(in: rect).boundingRect
        let drawnKnaeuel = ThreadShape(form: .knaeuel).path(in: rect).boundingRect
        let drawnKnot = ThreadShape(form: .knot).path(in: rect).boundingRect
        #expect(abs(knaeuel.minX - drawnKnaeuel.minX) < 0.01 && abs(knaeuel.maxY - drawnKnaeuel.maxY) < 0.01)
        #expect(abs(knot.minX - drawnKnot.minX) < 0.01 && abs(knot.maxY - drawnKnot.maxY) < 0.01)
        #expect(LooseningKnaeuel.resampled(ThreadShape.curvePoints(form: .knot)).count == LooseningKnaeuel.count)
        #expect(LooseningKnaeuel.resampled(ThreadShape.curvePoints(form: .knaeuel)).first == ThreadShape.knaeuelStart)
        #expect(LooseningKnaeuel.resampled(ThreadShape.curvePoints(form: .knaeuel)).last == CGPoint(x: 26, y: 11))
    }
}
