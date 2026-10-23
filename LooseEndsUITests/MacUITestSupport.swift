#if os(macOS)
import AppKit
import XCTest

/// What every Mac UI test needs to reach the app (#511, shared since #544): launch with the gallery's
/// arguments, open the main window when the CI Mac shows none at launch, find that window, capture
/// on the start page and photograph the window. The `mac` prefix keeps them apart from the private
/// helpers of the iPhone test classes, which compile for the Mac too.
extension XCTestCase {
    /// The iPhone gallery's arguments (#182). Dark: `--ui-testing-dark` colors the window content,
    /// `-AppleInterfaceStyle Dark` the title bar and the sidebar material. `locale` (e.g. `de_DE`) sets
    /// language and region; `extra` adds fixture arguments such as `--ui-testing-speech-listening`.
    @MainActor
    func macLaunch(dark: Bool, locale: String = "en_US", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-AppleLanguages", "(\(locale.prefix(2)))", "-AppleLocale", locale,
            "-contextsEmptiedByUser", "NO",
            "-startShowsProjects", "NO", "-startShowsContexts", "NO",
        ] + (dark ? ["--ui-testing-dark", "-AppleInterfaceStyle", "Dark"] : []) + extra
        app.launch()
        app.activate()
        return app
    }

    @MainActor
    func macElement(_ id: String, in scope: XCUIElement) -> XCUIElement {
        scope.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// On the fresh CI Mac the app opens no window at launch (run 39015688624), only its menu bar
    /// symbol. The test then opens the window the way a user would, via the menu bar symbol and
    /// "Open Loose Ends"; whether that is an app bug is for a ticket of its own.
    /// Returns whether the start page was there without help. Either way the opened window goes
    /// through `macMainWindow`, so every Mac test that opens it checks that it fits the screen (#593).
    @MainActor
    func macOpenMainWindowIfNeeded(_ app: XCUIApplication) -> Bool {
        if macElement("startCaptureField", in: app).waitForExistence(timeout: 10) {
            _ = macMainWindow(of: app)
            return true
        }
        let statusItem = app.statusItems.firstMatch
        guard statusItem.waitForExistence(timeout: 10) else {
            XCTFail("No window at launch and no menu bar symbol to open one")
            return false
        }
        let openApp = app.buttons["menuBarOpenApp"]
        // A panel that is still closing (Return in the German gallery test, #596) swallows the first
        // click: wait until it is gone, then click, and once more if nothing opened within 10 s.
        _ = macWait(timeout: 5) { !openApp.exists }
        statusItem.click()
        if !openApp.waitForExistence(timeout: 10) {
            statusItem.click()
        }
        guard openApp.waitForExistence(timeout: 10) else {
            XCTFail("Menu bar panel shows no Open Loose Ends")
            return false
        }
        openApp.click()
        _ = macMainWindow(of: app)
        return false
    }

    /// Polls `condition` until it holds or `timeout` passes; returns whether it held. For values XCTest
    /// cannot wait on with a predicate, such as a frame that is still settling (#596).
    @MainActor
    @discardableResult
    func macWait(timeout: TimeInterval, until condition: @MainActor () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        }
        return condition()
    }

    /// The list window, not the menu bar panel: `MenuBarExtra` owns a window of its own under tests.
    /// Found by New in its sidebar, which stays on every screen; queries resolve anew on each use, so
    /// the start page's field would lose the window as soon as a list opens.
    @MainActor
    func macMainWindow(of app: XCUIApplication) -> XCUIElement {
        let window = app.windows.containing(.any, identifier: "viewRow_new").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "No main window with New in its sidebar")
        macAssertWindowFitsScreen(window)
        return window
    }

    /// The screen in points: `NSScreen` of the test process, else the screenshot's size (pixels on a
    /// Retina screen, so only a fallback).
    @MainActor
    func macScreenSize() -> CGSize {
        NSScreen.main?.frame.size ?? XCUIScreen.main.screenshot().image.size
    }

    /// The main window lies on the screen (#593): on the 1024 pt CI screen it opened 1200 pt wide in some
    /// runs and the pictures were cut at the edge. Waits first, since the frame settles after opening.
    @MainActor
    func macAssertWindowFitsScreen(_ window: XCUIElement) {
        let screen = macScreenSize()
        let fits = macWait(timeout: 5) {
            let frame = window.frame
            return !frame.isEmpty && frame.width <= screen.width
                && frame.maxX <= screen.width && frame.maxY <= screen.height
        }
        if fits { return }
        let frame = window.frame
        XCTFail("""
            Main window \(Int(frame.width)) x \(Int(frame.height)) pt at \(Int(frame.minX)), \(Int(frame.minY)) \
            does not fit the screen \(Int(screen.width)) x \(Int(screen.height)) pt
            """)
    }

    /// Only the main window: `app.screenshot()` takes the whole screen on the Mac. Names starting with
    /// `mac-gallery-` leave the CI job as the `MacGallery` artifact.
    @MainActor
    func macShot(_ window: XCUIElement, _ name: String) {
        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func macCapture(_ text: String, in app: XCUIApplication) {
        // Only the start page has this field; the menu bar panel's is `captureTextField`.
        let field = macElement("startCaptureField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Start page shows no capture field")
        field.click()
        field.typeText(text + "\n")
        // XCUITest reports an empty text field with its placeholder as value (Apple forum 86653).
        let emptied = NSPredicate(
            format: "value == nil OR value == '' OR value == placeholderValue OR value == %@",
            "What should I remember?"
        )
        let wait = expectation(for: emptied, evaluatedWith: field)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 5), .completed, "Field kept \(text)")
    }

    /// Captures one task on the start page, opens a list (New unless named) and the task's detail in
    /// the main window. `list` is the sidebar row's identifier, e.g. `viewRow_open` for Loose ends.
    @MainActor
    func macOpenDetail(of text: String, in app: XCUIApplication, list: String = "viewRow_new") -> XCUIElement {
        _ = macOpenMainWindowIfNeeded(app)
        XCTAssertTrue(macElement("startCaptureField", in: app).waitForExistence(timeout: 20), "No start page")
        macCapture(text, in: app)
        let window = macMainWindow(of: app)
        let listRow = macElement(list, in: window)
        XCTAssertTrue(listRow.waitForExistence(timeout: 10), "Sidebar shows no \(list)")
        listRow.click()
        let row = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        row.click()
        XCTAssertTrue(macElement("detailRawTextMarker", in: window).waitForExistence(timeout: 10), "Detail did not open")
        return window
    }
}
#endif
