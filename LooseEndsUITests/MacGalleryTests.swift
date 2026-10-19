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

    /// #566 (Henning, 2026-10-19): the top of "Loose ends" on the Mac showed a light box over the list's
    /// column and "Needs a new date" in a style of its own. A task due today at 1:00 has passed (#548),
    /// so the list opens with that section; nine more let it scroll. Photographed at rest and scrolled a
    /// little, because the Mac draws its scroll edge only once content slides under the toolbar.
    @MainActor
    private func photographLooseEnds(dark: Bool) {
        let label = dark ? "dark" : "light"
        let app = macLaunch(dark: dark)
        _ = macOpenMainWindowIfNeeded(app)
        XCTAssertTrue(macElement("startCaptureField", in: app).waitForExistence(timeout: 20), "No start page")
        macCapture("Heute um 1 Uhr Rechnung bezahlen", in: app)
        for text in ["Rasen mähen", "Anna anrufen", "Steuer prüfen", "Fahrrad putzen", "Keller aufräumen",
                     "Brot kaufen", "Zahnarzt anrufen", "Blumen gießen", "Paket abholen",
                     // More than a window full, so the list really scrolls under its head (#566 round 3).
                     "Fenster putzen", "Auto waschen", "Oma schreiben", "Regal bauen", "Kuchen backen",
                     "Lampe tauschen", "Bücher sortieren", "Schuhe putzen"] {
            macCapture(text, in: app)
        }
        let window = macMainWindow(of: app)
        let openRow = macElement("viewRow_open", in: window)
        XCTAssertTrue(openRow.waitForExistence(timeout: 10), "Sidebar shows no Loose ends")
        openRow.click()
        let row = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Loose ends shows no task")
        macShot(window, "mac-gallery-\(label)-4-loose-ends")

        let list = window.scrollViews.containing(.any, identifier: row.identifier).firstMatch
        if list.exists { list.scroll(byDeltaX: 0, deltaY: -60) }
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        macShot(window, "mac-gallery-\(label)-5-loose-ends-scrolled")

        // Henning's screenshot had the sidebar hidden and the list scrolled further (2026-10-19):
        // the light box sat over the list's column up to the toolbar. ⌃⌘S hides the sidebar.
        app.typeKey("s", modifierFlags: [.command, .control])
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        macShot(window, "mac-gallery-\(label)-6-loose-ends-no-sidebar")
        if list.exists { list.scroll(byDeltaX: 0, deltaY: -240) }
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        macShot(window, "mac-gallery-\(label)-7-loose-ends-no-sidebar-scrolled")
        app.terminate()
    }

    @MainActor
    func testLooseEndsTopLight() throws {
        photographLooseEnds(dark: false)
    }

    @MainActor
    func testLooseEndsTopDark() throws {
        photographLooseEnds(dark: true)
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
