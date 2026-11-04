#if os(iOS)
import XCTest

/// The wide iPad's sidebar is the index alone, as on the Mac (#828): one start page (in the detail column), one "+",
/// "Start page" first in the index. iPad only, landscape and portrait; on an iPhone the tests are skipped. Locally:
/// `LOOSEENDS_SIM="iPad Pro 13-inch (M5)" ./scripts/sim.sh test-proof IPadSidebarTests`.
final class IPadSidebarTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    private func launch(_ orientation: UIDeviceOrientation) throws -> XCUIApplication {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "The sidebar beside the start page is the iPad's")
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func count(_ id: String, in app: XCUIApplication) -> Int {
        app.descendants(matching: .any).matching(identifier: id).count
    }

    @MainActor
    private func assertIndexBesideOneStart(in app: XCUIApplication, _ label: String) {
        let start = app.descendants(matching: .any).matching(identifier: "viewRow_start").firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 10), "\(label): the index shows no Start page line")
        XCTAssertEqual(count("startCaptureField", in: app), 1, "\(label): more than one start page")
        XCTAssertEqual(count("captureButton", in: app), 1, "\(label): more than one +")
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "828-ipad-\(label)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLandscapeShowsIndexBesideOneStartPage() throws {
        let app = try launch(.landscapeLeft)
        assertIndexBesideOneStart(in: app, "landscape")
    }

    @MainActor
    func testPortraitShowsIndexBesideOneStartPage() throws {
        let app = try launch(.portrait)
        assertIndexBesideOneStart(in: app, "portrait")
    }

    /// A task opened from the start page offers Back to the start page (#830).
    @MainActor
    func testTaskFromStartPageLeadsBack() throws {
        let app = try launch(.landscapeLeft)
        let line = app.descendants(matching: .any).matching(identifier: "startCaptureField").firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 10), "No writing line on the start page")
        line.tap()
        app.typeText("Rechnung heute bezahlen\n")
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "startNowRow_", "Rechnung")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Now shows no Rechnung")
        row.tap()
        let back = app.descendants(matching: .any).matching(identifier: "detailBackButton").firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "The detail offers no Back")
        back.tap()
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Back did not lead to the start page")
    }
}
#endif
