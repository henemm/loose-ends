import XCTest

/// The paper ground on the iPad (#746): in a wide window the detail column's rows stood on the system's white, only as
/// high as the rows, with the paper's beige beneath them. Each test probes one pixel inside a row and one in the empty
/// area below it; both must be the same colour. iPad only, in portrait; on an iPhone the tests are skipped. Locally:
/// `LOOSEENDS_SIM="iPad Pro 13-inch (M5)" ./scripts/sim.sh test PaperGroundTests`.
final class PaperGroundTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "The wide window is the iPad's")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The colour of the screen at `point` (in points), as 8-bit red, green, blue.
    @MainActor
    private func colour(at point: CGPoint) throws -> [Int] {
        let image = try XCTUnwrap(XCUIScreen.main.screenshot().image.cgImage)
        let scale = CGFloat(image.width) / XCUIScreen.main.screenshot().image.size.width
        let x = Int(point.x * scale), y = Int(point.y * scale)
        let cropped = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel.prefix(3).map(Int.init)
    }

    @MainActor
    private func assertSameGround(row: CGPoint, empty: CGPoint, _ what: String) throws {
        let inRow = try colour(at: row), below = try colour(at: empty)
        let apart = zip(inRow, below).map { abs($0 - $1) }.max() ?? 0
        XCTAssertLessThanOrEqual(apart, 3, "\(what): the row stands on \(inRow), the area below on \(below)")
    }

    /// Writes one task into the start page's line; it lands in "New".
    @MainActor
    private func capture(_ text: String, in app: XCUIApplication) {
        let line = element("startCaptureField", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 10), "No writing line on the start page")
        line.tap()
        line.typeText(text + "\n")
    }

    /// Holds the first task row until the menu shows `menuID`, then taps it.
    @MainActor
    private func holdFirstRow(until menuID: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No task row")
        let entry = element(menuID, in: app)
        for seconds in [1.0, 1.5, 2.0] where !entry.exists {
            row.press(forDuration: seconds)
            _ = entry.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(entry.exists, "The long-press menu shows no \(menuID)")
        entry.tap()
    }

    /// The start page: its header rows stand on the paper like the empty area under them.
    @MainActor
    func testStartPageRowsShareThePaperGround() throws {
        let app = try launch()
        let page = element("startPage", in: app)
        XCTAssertTrue(page.waitForExistence(timeout: 10), "No start page")
        let header = element("startHeader", in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 5), "No header on the start page")
        shot("746-start")
        let x = page.frame.maxX - 40
        try assertSameGround(
            row: CGPoint(x: x, y: header.frame.midY),
            empty: CGPoint(x: x, y: page.frame.maxY - 150),
            "Start page")
    }

    /// "Completed": the week's string (a row of its own) stands on the paper like the empty area under the list.
    @MainActor
    func testDoneRowsShareThePaperGround() throws {
        let app = try launch()
        capture("Apfel kaufen", in: app)
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "No New in the sidebar")
        newRow.tap()
        holdFirstRow(until: "menuCounts", in: app)
        holdFirstRow(until: "menuDone", in: app)
        let doneRow = element("viewRow_done", in: app)
        XCTAssertTrue(doneRow.waitForExistence(timeout: 5), "No Completed in the sidebar")
        doneRow.tap()
        let string = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "doneWeekString_")).firstMatch
        XCTAssertTrue(string.waitForExistence(timeout: 15), "Completed shows no week string")
        shot("746-erledigt")
        let window = app.windows.firstMatch.frame
        let x = window.maxX - 40
        try assertSameGround(
            row: CGPoint(x: x, y: string.frame.midY),
            // Half way down: the keyboard of the writing line may still stand below 70 % of the height.
            empty: CGPoint(x: x, y: window.minY + window.height * 0.55),
            "Completed")
    }
}
