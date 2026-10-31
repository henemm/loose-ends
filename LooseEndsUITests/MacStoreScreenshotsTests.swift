#if os(macOS)
import XCTest

/// #742 Schnitt 2b: the App Store pictures for the Mac, German and light. The window opens 1280 x 800
/// (`--ui-testing-store-window`, 16:10) and only the window is photographed, five attachments
/// `store-<nn>-<name>`. Runs in the workflow `store-mac.yml`, never on Henning's Mac. The tasks are made up
/// and live only in memory (`--ui-testing`).
final class MacStoreScreenshotsTests: XCTestCase {
    private static let tasks = ["Steuerbescheid heute prüfen", "Anna heute wegen Sonntag anrufen", "Blumen heute gießen",
                                "Rasen mähen"]

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testPhotographStoreScreens() throws {
        let app = macLaunch(dark: false, locale: "de_DE", extra: ["--ui-testing-store-window"])
        _ = macOpenMainWindowIfNeeded(app)
        XCTAssertTrue(macElement("startCaptureField", in: app).waitForExistence(timeout: 20), "Keine Startseite")
        for text in Self.tasks { macCapture(text, in: app) }
        let window = macMainWindow(of: app)
        let newRow = macElement("viewRow_new", in: window)
        XCTAssertTrue(newRow.waitForExistence(timeout: 10), "Seitenleiste zeigt kein „Neu“")
        shot(window, "01-start")

        newRow.click()
        let row = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "„Neu“ zeigt keine Aufgabe")
        shot(window, "03-neu")

        row.click()
        XCTAssertTrue(macElement("detailRawTextMarker", in: window).waitForExistence(timeout: 10), "Detail öffnet nicht")
        shot(window, "04-detail")

        let more = macElement("detailMoreMenu", in: window)
        XCTAssertTrue(more.waitForExistence(timeout: 10), "Detail zeigt kein „…“-Menü")
        more.click()
        let complete = macElement("menuDone", in: app)
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "Das „…“-Menü bietet kein „Erledigt“")
        complete.click()
        let doneRow = macElement("viewRow_done", in: window)
        XCTAssertTrue(doneRow.waitForExistence(timeout: 10), "Seitenleiste zeigt kein „Erledigt“")
        RunLoop.current.run(until: Date().addingTimeInterval(4))   // the Done window takes three seconds
        doneRow.click()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "„Erledigt“ zeigt keine Aufgabe")
        shot(window, "05-erledigt")
        app.terminate()
    }

    @MainActor
    private func shot(_ window: XCUIElement, _ name: String) {
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = "store-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
#endif
