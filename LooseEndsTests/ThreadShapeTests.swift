import SwiftUI
import Testing
@testable import LooseEnds

@Suite("Thread from the logo curve (#180, step 3)") struct ThreadShapeTests {
    @Test("Knot and loose thread stay inside the rect they are drawn in", arguments: [ThreadShape.Form.knot, .loose])
    func fitsRect(form: ThreadShape.Form) {
        let rect = CGRect(x: 10, y: 20, width: 96, height: 28)
        let bounds = ThreadShape(form: form).path(in: rect).boundingRect
        #expect(bounds.minX >= rect.minX - 0.5)
        #expect(bounds.maxX <= rect.maxX + 0.5)
        #expect(bounds.minY >= rect.minY - 0.5)
        #expect(bounds.maxY <= rect.maxY + 0.5)
        // Fills one side of the rect: the curve is scaled, not left at its raw size.
        #expect(bounds.width >= rect.width - 1 || bounds.height >= rect.height - 1)
    }

    @Test("The knot is taller for its width than the loose thread: only the knot loops")
    func knotLoops() {
        let rect = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let knot = ThreadShape(form: .knot).path(in: rect).boundingRect
        let loose = ThreadShape(form: .loose).path(in: rect).boundingRect
        #expect(knot.height / knot.width > loose.height / loose.width * 2)
    }
}
