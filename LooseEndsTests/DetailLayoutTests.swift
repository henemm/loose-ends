import XCTest
@testable import LooseEnds

final class DetailLayoutTests: XCTestCase {
    func testSetFieldsComeFirstInTheirOrderAndEmptyOnesAreSeparate() {
        let entries: [DetailLayout.Entry] = [
            .init(field: .dueDate, value: nil),
            .init(field: .duration, value: "15 min"),
            .init(field: .energy, value: nil),
            .init(field: .contexts, value: "Garden"),
        ]
        let layout = DetailLayout.split(entries)
        XCTAssertEqual(layout.set.map(\.field), [.duration, .contexts])
        XCTAssertEqual(layout.empty.map(\.field), [.dueDate, .energy])
    }

    func testRawTextShowsWithoutTitle() {
        XCTAssertTrue(DetailLayout.showsRawText("mähen Rasen", title: nil))
        XCTAssertTrue(DetailLayout.showsRawText("mähen Rasen", title: "  "))
    }

    func testRawTextHidesWhenTitleHasTheSameWords() {
        XCTAssertFalse(DetailLayout.showsRawText("mähen Rasen", title: "Rasen mähen"))
        XCTAssertFalse(DetailLayout.showsRawText("Rasen mähen.", title: "rasen Mähen"))
    }

    func testRawTextShowsWhenTitleSaysSomethingElse() {
        XCTAssertTrue(DetailLayout.showsRawText("zahnarzt termin ausmachen morgen", title: "Zahnarzttermin ausmachen"))
    }

    // #216: the title field wraps; Return still ends the edit and leaves no line break.
    func testTitleWithoutLineBreakIsLeftAlone() {
        XCTAssertNil(DetailLayout.titleAfterReturn("Rasen mähen"))
    }

    func testReturnAtTheEndEndsTheEditWithoutStraySpace() throws {
        let result = try XCTUnwrap(DetailLayout.titleAfterReturn("Rasen mähen\n"))
        XCTAssertEqual(result.text, "Rasen mähen")
        XCTAssertTrue(result.ended)
    }

    func testLineBreakInsidePastedTextBecomesASpace() throws {
        let result = try XCTUnwrap(DetailLayout.titleAfterReturn("Rasen\nmähen"))
        XCTAssertEqual(result.text, "Rasen mähen")
        XCTAssertFalse(result.ended)
    }
}
