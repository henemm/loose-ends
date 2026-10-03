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
}
