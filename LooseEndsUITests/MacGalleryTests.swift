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
        addWindowSizeNote(size, hadWindow: hadWindow, name: "mac-gallery-\(label)-window-size")

        newRow.click()
        let row = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        macShot(window, "mac-gallery-\(label)-2-list-new")

        row.click()
        XCTAssertTrue(macElement("detailRawTextMarker", in: window).waitForExistence(timeout: 10), "Detail did not open")
        macShot(window, "mac-gallery-\(label)-3-detail")

        // The sidebar's first line leads back to the start page (#583).
        let startRow = macElement("viewRow_start", in: window)
        XCTAssertTrue(startRow.waitForExistence(timeout: 10), "Sidebar shows no Start")
        startRow.click()
        XCTAssertTrue(macElement("startCaptureField", in: window).waitForExistence(timeout: 10), "Start page did not come back")
        macShot(window, "mac-gallery-\(label)-4-start-again")

        // "Completed" by weeks (#646): one task done from its detail, then the list with the week's head and string.
        newRow.click()
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task for Completed")
        row.click()
        let more = macElement("detailMoreMenu", in: window)
        XCTAssertTrue(more.waitForExistence(timeout: 10), "Detail shows no … menu")
        more.click()
        let complete = macElement("menuCompleteButton", in: app)
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "The … menu offers no Complete")
        complete.click()
        let doneRow = macElement("viewRow_done", in: window)
        XCTAssertTrue(doneRow.waitForExistence(timeout: 10), "Sidebar shows no Completed")
        // The Done window (#32) takes three seconds; the list fills after it.
        RunLoop.current.run(until: Date().addingTimeInterval(4))
        doneRow.click()
        let doneTask = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
        XCTAssertTrue(doneTask.waitForExistence(timeout: 10), "Completed shows no task")
        macShot(window, "mac-gallery-\(label)-5-completed-weeks")

        // After the pictures, so a narrow window still delivers them.
        XCTAssertGreaterThanOrEqual(size.width, Self.minimumWidth, "Window \(size) too narrow for sidebar and list")
        app.terminate()
    }

    /// Window and screen size as text, with the way the window opened (#593, AC-6).
    @MainActor
    private func addWindowSizeNote(_ size: CGSize, hadWindow: Bool, name: String) {
        let screen = macScreenSize()
        let sizeNote = XCTAttachment(
            string: "\(Int(size.width)) x \(Int(size.height)) pt on screen \(Int(screen.width)) x \(Int(screen.height)) pt; "
                + "window at launch: \(hadWindow ? "yes" : "no, opened from the menu bar")"
        )
        sizeNote.name = name
        sizeNote.lifetime = .keepAlways
        add(sizeNote)
    }

    /// #593 AC-6: which way `photograph` opens the window is up to the CI Mac, so this test forces the
    /// menu bar way in every run. It closes the main window (the app stays, it lives in the menu bar),
    /// opens it again via the symbol and "Open Loose Ends", and checks that it fits the screen.
    @MainActor
    func testWindowFromMenuBarFitsScreen() throws {
        let app = macLaunch(dark: false)
        _ = macOpenMainWindowIfNeeded(app)
        let first = macMainWindow(of: app)
        app.activate()
        app.typeKey("w", modifierFlags: .command)
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: first)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "⌘W did not close the main window")

        XCTAssertFalse(macOpenMainWindowIfNeeded(app), "The window came back without the menu bar")
        let window = macMainWindow(of: app)
        addWindowSizeNote(window.frame.size, hadWindow: false, name: "mac-gallery-menu-bar-window-size")
        macShot(window, "mac-gallery-menu-bar-window")
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

    /// #574 (Henning, 2026-10-19): "Add to calendar" on the Mac was a column of wide grey buttons with
    /// ticks. A task with a day but no time asks for the timing; photographed as it opens and after
    /// "At a time", the sheet on its own.
    @MainActor
    private func photographCalendarAsk(dark: Bool) {
        let label = dark ? "dark" : "light"
        let app = macLaunch(dark: dark)
        let window = macOpenDetail(of: "Zahnarzt anrufen morgen", in: app)
        let word = macElement("field_calendar", in: window)
        let scroll = window.scrollViews.containing(.any, identifier: "detailRawTextMarker").firstMatch
        for _ in 0..<8 where !(word.exists && word.isHittable) {
            if scroll.exists { scroll.scroll(byDeltaX: 0, deltaY: -200) }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(word.waitForExistence(timeout: 5), "Detail offers no Calendar")
        word.click()
        let sheet = app.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "Calendar should ask first for a day without a time")
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        macShot(sheet, "mac-gallery-\(label)-8-calendar-ask")

        let timed = sheet.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "At a time")).firstMatch
        XCTAssertTrue(timed.waitForExistence(timeout: 5), "The sheet offers no \"At a time\"")
        timed.click()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        macShot(sheet, "mac-gallery-\(label)-9-calendar-ask-timed")
        app.terminate()
    }

    @MainActor
    func testCalendarAskLight() throws {
        photographCalendarAsk(dark: false)
    }

    @MainActor
    func testCalendarAskDark() throws {
        photographCalendarAsk(dark: true)
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

    /// #478: the settings window (⌘,) on paper. Asserts every entry is there and the window is 640 pt wide
    /// (the board's width); that it reads as paper with hairlines is judged on the pictures.
    @MainActor
    private func photographSettings(dark: Bool) {
        let label = dark ? "dark" : "light"
        let app = macLaunch(dark: dark)
        _ = macOpenMainWindowIfNeeded(app)
        XCTAssertTrue(macElement("startCaptureField", in: app).waitForExistence(timeout: 20), "No start page")
        app.typeKey(",", modifierFlags: .command)
        let window = app.windows.containing(.any, identifier: "reminderTimePicker").firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 10), "⌘, opened no settings window")
        for id in ["reminderTimePicker", "eveningToggle", "morningToggle", "iCloudSyncRow",
                   "defaultCalendarRow", "fieldsRow", "openAtLoginToggle", "appVersionRow"] {
            XCTAssertTrue(macElement(id, in: window).waitForExistence(timeout: 5), "Settings show no \(id)")
        }
        let size = window.frame.size
        let note = XCTAttachment(string: "\(Int(size.width)) x \(Int(size.height)) pt")
        note.name = "mac-gallery-settings-\(label)-window-size"
        note.lifetime = .keepAlways
        add(note)
        macShot(window, "mac-gallery-settings-\(label)")
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

    /// #479: the menu bar panel on paper. Asserts what can be measured: the head with the knot, the resting
    /// hint, a field of at least five lines, and that Cancel, Done and both footer rows lie inside the panel
    /// and can be hit (#400). That it reads as paper without a grey box is judged on the pictures.
    @MainActor
    private func photographPanel(dark: Bool) {
        let label = dark ? "dark" : "light"
        let app = macLaunch(dark: dark)
        guard let panel = openPanel(in: app, label: label) else { return }
        for id in ["capturePanelHeader", "captureRestHint", "captureTextField", "micButton",
                   "captureCancelButton", "captureDoneButton", "menuBarOpenApp", "menuBarQuit"] {
            XCTAssertTrue(macElement(id, in: panel).waitForExistence(timeout: 5), "Panel shows no \(id)")
        }
        macShot(panel, "mac-gallery-panel-\(label)")
        assertPanelFits(panel, label: label)
        app.terminate()
    }

    /// Clicks the menu bar symbol and returns the window, popover or group holding the panel. The footer
    /// row is found directly (as `macOpenMainWindowIfNeeded` does); the hierarchy goes along as text.
    @MainActor
    private func openPanel(in app: XCUIApplication, label: String) -> XCUIElement? {
        let statusItem = app.statusItems.firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 20), "No menu bar symbol")
        statusItem.click()
        XCTAssertTrue(app.buttons["menuBarOpenApp"].waitForExistence(timeout: 10), "The symbol opened no panel")
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "mac-gallery-panel-\(label)-hierarchy"
        tree.lifetime = .keepAlways
        add(tree)
        let holders = [app.windows, app.popovers, app.groups]
            .map { $0.containing(.any, identifier: "menuBarOpenApp").firstMatch }
        guard let panel = holders.first(where: { $0.exists }) else {
            XCTFail("No window, popover or group holds the panel")
            return nil
        }
        return panel
    }

    /// Five lines of the panel's 22 pt serif field, as the CI Mac measures them at the least (#596).
    private static let fiveLinesHeight: CGFloat = 105

    /// #400, AC-6/AC-7: Cancel, Done and both footer rows can be hit inside the panel, the field keeps
    /// its five lines; the panel's size goes along as text so the states can be compared.
    @MainActor
    private func assertPanelFits(_ panel: XCUIElement, label: String) {
        let frame = panel.frame
        for id in ["captureCancelButton", "captureDoneButton", "menuBarOpenApp", "menuBarQuit"] {
            let element = macElement(id, in: panel)
            XCTAssertTrue(element.isHittable, "\(id) cannot be hit")
            XCTAssertTrue(frame.contains(element.frame), "\(id) lies outside the panel: \(element.frame) in \(frame)")
        }
        // The product promises five lines (`lineLimit(5...10)`, 22 pt serif), not a point value: the CI Mac
        // measures those five lines at 107 pt in one run and 110 pt in the next, also after a 5 s wait
        // (runs 39486128730 and 39509147972, #596). Five lines are at least 105 pt; four would be under 90.
        let field = macElement("captureTextField", in: panel)
        macWait(timeout: 5) { field.frame.height >= Self.fiveLinesHeight }
        XCTAssertGreaterThanOrEqual(field.frame.height, Self.fiveLinesHeight, "Field is lower than five lines")
        let note = XCTAttachment(string: "\(Int(frame.width)) x \(Int(frame.height)) pt")
        note.name = "mac-gallery-panel-\(label)-size"
        note.lifetime = .keepAlways
        add(note)
    }

    @MainActor
    func testPanelLight() throws {
        photographPanel(dark: false)
    }

    @MainActor
    func testPanelDark() throws {
        photographPanel(dark: true)
    }

    /// #479 AC-6: the wave and the diagnosis line push nothing out; compare the sizes with `light`.
    @MainActor
    private func photographPanelState(_ argument: String, label: String, shows id: String) {
        let app = macLaunch(dark: false, extra: [argument])
        guard let panel = openPanel(in: app, label: label) else { return }
        XCTAssertTrue(macElement(id, in: panel).waitForExistence(timeout: 5), "Panel shows no \(id) under \(argument)")
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        macShot(panel, "mac-gallery-panel-\(label)")
        assertPanelFits(panel, label: label)
        app.terminate()
    }

    @MainActor
    func testPanelListening() throws {
        photographPanelState("--ui-testing-speech-listening", label: "listening", shows: "listeningHint")
    }

    @MainActor
    func testPanelDiagnosis() throws {
        photographPanelState("--ui-testing-speech-diagnosis", label: "diagnosis", shows: "speechDiagnosisLabel")
    }

    /// #479 AC-9, AC-12: in German the panel reads "Neue Aufgabe", "Abbrechen", "Fertig"; typed text turns
    /// Done on, and Return saves and closes the panel. The task then shows in New.
    @MainActor
    func testPanelTypedGerman() throws {
        let app = macLaunch(dark: false, locale: "de_DE")
        guard let panel = openPanel(in: app, label: "typed-de") else { return }
        let hint = macElement("captureRestHint", in: panel)
        XCTAssertTrue(hint.waitForExistence(timeout: 5), "Panel shows no resting hint")
        macShot(panel, "mac-gallery-panel-de")
        // A Mac `Text` reports its words as value with an empty label (run 39407681767: hint and head are
        // static texts with only a value; buttons carry a label, the field only a placeholder value).
        XCTAssertEqual(hint.value as? String, "Sprich los oder tippe. Return speichert.", "Resting hint is not in German")
        XCTAssertEqual(macElement("capturePanelHeader", in: panel).value as? String, "Neue Aufgabe", "Head is not in German")
        let field = macElement("captureTextField", in: panel)
        field.click()
        field.typeText("Müll rausbringen")
        let done = macElement("captureDoneButton", in: panel)
        let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: done)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 5), .completed, "Done is not on after typing")
        XCTAssertTrue(done.isHittable, "Done cannot be hit after typing")
        for (id, text) in [("captureDoneButton", "Fertig"), ("captureCancelButton", "Abbrechen"),
                           ("menuBarOpenApp", "Loose Ends öffnen"), ("menuBarQuit", "Loose Ends beenden")] {
            XCTAssertEqual(macElement(id, in: panel).label, text, "\(id) is not in German")
        }
        macShot(panel, "mac-gallery-panel-typed-de")
        assertPanelFits(panel, label: "typed-de")

        // The panel's field is vertical: Return arrives as a newline, which `submitOnReturn` saves.
        field.typeText("\n")
        // `closeMenuBarPanel` closes the panel's window, so its elements leave the tree.
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["menuBarOpenApp"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed, "Return did not close the panel")
        _ = macOpenMainWindowIfNeeded(app)
        let window = macMainWindow(of: app)
        let newRow = macElement("viewRow_new", in: window)
        XCTAssertTrue(newRow.waitForExistence(timeout: 10), "Sidebar shows no New")
        // With the panel gone no window may be key; activate, so the first click selects New.
        app.activate()
        newRow.click()
        let row = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_")).firstMatch
        if !row.waitForExistence(timeout: 5) { newRow.click() }
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task after Return")
        // Only once New shows rows, so the start page's recent list cannot answer. Label or value as in
        // `MacDetailClickTests.shows`: a combined row may keep its words as value.
        let saved = window.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Müll rausbringen", "Müll rausbringen"))
            .firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10), "New shows no \"Müll rausbringen\" after Return")
        macShot(window, "mac-gallery-panel-de-saved-in-new")
        app.terminate()
    }
}
#endif
