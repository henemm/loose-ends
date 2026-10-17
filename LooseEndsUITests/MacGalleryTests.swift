#if os(macOS)
import XCTest

/// #511: photographs the Mac app, light and dark, so the Mac tickets (#477–#480) get a picture of
/// "today" and a proof without Henning's Mac. Runs only in the CI job "Mac Gallery (macOS)", which
/// exports the attachments named `mac-gallery-*` as the `MacGallery` artifact. Asserts only that each
/// screen is reached and the window has room for sidebar and list; the pictures are the point.
final class MacGalleryTests: XCTestCase {
    private static let tasks = ["Steuerbescheid morgen prüfen", "Anna wegen Sonntag anrufen", "Rasen mähen"]
    /// Sidebar (from 220 pt) plus a readable list. The full start page with its right column needs
    /// about 1120 pt (220 + 900, `StartPage`, #473); that is judged on the picture, not asserted.
    private static let minimumWidth: CGFloat = 700

    override func setUp() {
        continueAfterFailure = false
    }

    /// The iPhone gallery's arguments (#182). Dark: `--ui-testing-dark` colors the window content,
    /// `-AppleInterfaceStyle Dark` the title bar and the sidebar material.
    @MainActor
    private func launch(dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-contextsEmptiedByUser", "NO",
            "-startShowsProjects", "NO", "-startShowsContexts", "NO",
        ] + (dark ? ["--ui-testing-dark", "-AppleInterfaceStyle", "Dark"] : [])
        app.launch()
        app.activate()
        return app
    }

    @MainActor
    private func element(_ id: String, in scope: XCUIElement) -> XCUIElement {
        scope.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// The list window, not the menu bar panel: `MenuBarExtra` owns a window of its own under tests.
    /// Found by New in its sidebar, which stays on every screen; queries resolve anew on each use, so
    /// the start page's field would lose the window as soon as a list opens.
    @MainActor
    private func mainWindow(of app: XCUIApplication) -> XCUIElement {
        let window = app.windows.containing(.any, identifier: "viewRow_new").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "No main window with New in its sidebar")
        return window
    }

    /// Only the main window: `app.screenshot()` takes the whole screen on the Mac.
    @MainActor
    private func shot(_ window: XCUIElement, _ name: String) {
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func capture(_ text: String, in app: XCUIApplication) {
        // Only the start page has this field; the menu bar panel's is `captureTextField`.
        let field = element("startCaptureField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Start page shows no capture field")
        field.click()
        field.typeText(text + "\n")
        let emptied = NSPredicate(format: "value == nil OR value == ''")
        let wait = expectation(for: emptied, evaluatedWith: field)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 5), .completed, "Field kept \(text)")
    }

    /// Start page with three tasks, the New list and a detail; the window size goes along as text.
    @MainActor
    private func photograph(dark: Bool) {
        let label = dark ? "dark" : "light"
        let app = launch(dark: dark)
        XCTAssertTrue(element("startCaptureField", in: app).waitForExistence(timeout: 20), "No start page")
        for text in Self.tasks {
            capture(text, in: app)
        }
        let window = mainWindow(of: app)
        let newRow = element("viewRow_new", in: window)
        XCTAssertTrue(newRow.waitForExistence(timeout: 10), "Sidebar shows no New")
        shot(window, "mac-gallery-\(label)-1-start")

        let size = window.frame.size
        let sizeNote = XCTAttachment(string: "\(Int(size.width)) x \(Int(size.height)) pt")
        sizeNote.name = "mac-gallery-\(label)-window-size"
        sizeNote.lifetime = .keepAlways
        add(sizeNote)

        newRow.click()
        let row = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        shot(window, "mac-gallery-\(label)-2-list-new")

        row.click()
        XCTAssertTrue(element("detailRawTextMarker", in: window).waitForExistence(timeout: 10), "Detail did not open")
        shot(window, "mac-gallery-\(label)-3-detail")

        // After the pictures, so a narrow window still delivers them.
        XCTAssertGreaterThanOrEqual(size.width, Self.minimumWidth, "Window \(size) too narrow for sidebar and list")
        app.terminate()
    }

    @MainActor
    func testGalleryLight() throws {
        photograph(dark: false)
    }

    @MainActor
    func testGalleryDark() throws {
        photograph(dark: true)
    }
}
#endif
