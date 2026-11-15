import XCTest

/// What Claude changed is visible in the detail (#622 Schnitt 2, draft A): `--ui-testing-claude-change`
/// runs one real order from Claude (set the due date to today) on a seeded task. The detail's line at
/// the end names Claude with day and time, and the change list behind it shows "Claude" as the author,
/// without a reset button and without the reason repeated underneath.
final class ClaudeChangeTests: XCTestCase {
    private let title = "Zahnarzt anrufen"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-claude-change", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
            + (dark ? ["--ui-testing-dark"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func scrolledTo(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let target = element(id, in: app)
        for _ in 0..<6 {
            if target.waitForExistence(timeout: 2), target.isHittable { break }
            app.swipeUp()
        }
        return target
    }

    /// The seeded task is due today, so it stands under "Now" on the start page.
    @MainActor
    private func openSeededTask(in app: XCUIApplication) {
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "(identifier BEGINSWITH %@ OR identifier BEGINSWITH %@) AND label CONTAINS %@",
                                  "nowRow_", "taskRow_", title))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The start page shows no row for \(title)")
        row.tap()
    }

    /// AC-3, AC-5, AC-10: the line appears for a change by Claude alone and names it with today's time.
    @MainActor
    func testDetailLineNamesClaudeWithToday() throws {
        let app = launch()
        openSeededTask(in: app)
        let summary = scrolledTo("originSummary", in: app)
        XCTAssertTrue(summary.exists, "The detail shows no line for Claude's change")
        XCTAssertTrue(summary.label.contains("Zuletzt von Claude"), "The line does not name Claude: \(summary.label)")
        XCTAssertTrue(summary.label.contains("heute"), "The line does not say today: \(summary.label)")
        shot(app, "622-detail-zuletzt-von-claude-hell")
    }

    /// AC-6, AC-7: the change list names Claude as the author, offers no reset and does not repeat the reason.
    @MainActor
    func testChangeListShowsClaudeAsAuthor() throws {
        let app = launch()
        openSeededTask(in: app)
        let show = scrolledTo("revisionsButton", in: app)
        XCTAssertTrue(show.exists, "The detail offers no change list")
        show.tap()
        let claude = app.staticTexts.matching(NSPredicate(format: "label == %@", "Claude"))
        XCTAssertTrue(claude.firstMatch.waitForExistence(timeout: 5), "The change list does not name Claude")
        XCTAssertEqual(claude.count, 1, "\"Claude\" should stand once: as the author, not again as the reason")
        let resets = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "resetRevision_"))
        XCTAssertEqual(resets.count, 0, "A change by Claude must not offer a reset")
        shot(app, "622-aenderungsblatt-claude-hell")
    }

    /// Test 9: line and change list in dark mode.
    @MainActor
    func testDarkScreenshots() throws {
        let app = launch(dark: true)
        openSeededTask(in: app)
        let summary = scrolledTo("originSummary", in: app)
        XCTAssertTrue(summary.label.contains("Zuletzt von Claude"), "The line does not name Claude: \(summary.label)")
        shot(app, "622-detail-zuletzt-von-claude-dunkel")
        let show = scrolledTo("revisionsButton", in: app)
        show.tap()
        XCTAssertTrue(app.staticTexts["Claude"].waitForExistence(timeout: 5), "The change list does not name Claude")
        shot(app, "622-aenderungsblatt-claude-dunkel")
    }
}
