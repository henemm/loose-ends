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

    // Launch, window, capture and photo helpers: `MacUITestSupport` (shared with #544).

    /// Start page with three tasks, the New list and a detail; the window size goes along as text.
    @MainActor
    private func photograph(dark: Bool) {
        let label = dark ? "dark" : "light"
        let app = macLaunch(dark: dark)
        let hadWindow = macOpenMainWindowIfNeeded(app)
        XCTAssertTrue(macElement("startCaptureField", in: app).waitForExistence(timeout: 20), "No start page")
        for text in Self.tasks {
            macCapture(text, in: app)
        }
        let window = macMainWindow(of: app)
        let newRow = macElement("viewRow_new", in: window)
        XCTAssertTrue(newRow.waitForExistence(timeout: 10), "Sidebar shows no New")
        macShot(window, "mac-gallery-\(label)-1-start")

        let size = window.frame.size
        let sizeNote = XCTAttachment(
            string: "\(Int(size.width)) x \(Int(size.height)) pt; window at launch: \(hadWindow ? "yes" : "no, opened from the menu bar")"
        )
        sizeNote.name = "mac-gallery-\(label)-window-size"
        sizeNote.lifetime = .keepAlways
        add(sizeNote)

        newRow.click()
        let row = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        macShot(window, "mac-gallery-\(label)-2-list-new")

        row.click()
        XCTAssertTrue(macElement("detailRawTextMarker", in: window).waitForExistence(timeout: 10), "Detail did not open")
        macShot(window, "mac-gallery-\(label)-3-detail")

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

    /// #478: the settings window (⌘,) on paper. Asserts every entry is there and the window is 640 pt wide
    /// (the board's width); that it reads as paper with hairlines is judged on the pictures.
    @MainActor
    private func photographSettings(dark: Bool) {
        let label = dark ? "dark" : "light"
        let app = launch(dark: dark)
        _ = openMainWindowIfNeeded(app)
        XCTAssertTrue(element("startCaptureField", in: app).waitForExistence(timeout: 20), "No start page")
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows.containing(.any, identifier: "reminderTimePicker").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "⌘, opened no settings window")
        for id in ["reminderTimePicker", "eveningToggle", "morningToggle", "iCloudSyncRow",
                   "defaultCalendarRow", "openAtLoginToggle", "appVersionRow"] {
            XCTAssertTrue(element(id, in: window).waitForExistence(timeout: 5), "Settings show no \(id)")
        }
        let size = window.frame.size
        let note = XCTAttachment(string: "\(Int(size.width)) x \(Int(size.height)) pt")
        note.name = "mac-gallery-settings-\(label)-window-size"
        note.lifetime = .keepAlways
        add(note)
        shot(window, "mac-gallery-settings-\(label)")
        XCTAssertEqual(size.width, 640, accuracy: 2, "Settings window is not 640 pt wide")
        app.terminate()
    }

    @MainActor
    func testSettingsLight() throws {
        photographSettings(dark: false)
    }

    @MainActor
    func testSettingsDark() throws {
        photographSettings(dark: true)
    }
}
#endif
