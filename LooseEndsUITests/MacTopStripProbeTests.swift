#if os(macOS)
import AppKit
import XCTest

/// Diagnosis for #829, not a check: which element lies over the top of a wide Mac list and reacts to the
/// pointer. Runs only in the workflow `mac-probe.yml`. For "Loose ends" (sections) it prints, at rest and
/// scrolled: the accessibility elements in the top 240 pt, a pixel column through the list (inside the
/// 720 pt column and outside it), then moves the pointer down the column in 6 pt steps and reports where
/// the picture changes. At each state the app writes its view tree (`TopStripProbe`). Lines start `PROBE|`.
final class MacTopStripProbeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    @MainActor
    func testProbeTopStrip() throws {
        let app = macLaunch(dark: false, extra: ["--ui-testing-view-probe"])
        _ = macOpenMainWindowIfNeeded(app)
        XCTAssertTrue(macElement("startCaptureField", in: app).waitForExistence(timeout: 20), "No start page")
        // A task due today with a duration: "Today" heads both Loose ends and Quick (Henning's picture).
        for text in ["Heute 5 Minuten Rechnung bezahlen", "Morgen 5 Minuten Anna anrufen", "Rasen mähen",
                     "Steuer prüfen", "Fahrrad putzen", "Keller aufräumen", "Brot kaufen", "Zahnarzt anrufen",
                     "Blumen gießen", "Paket abholen", "Fenster putzen", "Auto waschen", "Oma schreiben",
                     "Regal bauen", "Kuchen backen", "Lampe tauschen", "Bücher sortieren", "Schuhe putzen"] {
            macCapture(text, in: app)
        }
        let window = macMainWindow(of: app)
        report("window \(window.frame) screen \(macScreenSize())")
        for list in ["viewRow_quick", "viewRow_open"] {
            let sidebarRow = macElement(list, in: window)
            guard sidebarRow.waitForExistence(timeout: 5) else {
                report("\(list): not in the sidebar")
                continue
            }
            sidebarRow.click()
            let row = window.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
                .firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10), "\(list) shows no task")
            let scroll = window.scrollViews.containing(.any, identifier: row.identifier).firstMatch
            let column = scroll.exists ? scroll.frame : window.frame
            report("\(list): list scroll view \(column)")
            probe(app, window, column: column, name: "\(list)-rest")
            if scroll.exists {
                scroll.scroll(byDeltaX: 0, deltaY: -80)
                pause(1)
                probe(app, window, column: column, name: "\(list)-scrolled")
            }
        }
        app.terminate()
    }

    /// One state: elements, pixels at rest (pointer over the sidebar), then the hover sweep.
    @MainActor
    private func probe(_ app: XCUIApplication, _ window: XCUIElement, column: CGRect, name: String) {
        let origin = window.coordinate(withNormalizedOffset: .zero)
        let local = CGRect(x: column.minX - window.frame.minX, y: column.minY - window.frame.minY,
                           width: column.width, height: column.height)
        // Pointer away: over the sidebar, low down.
        origin.withOffset(CGVector(dx: 40, dy: window.frame.height - 40)).hover()
        pause(1)
        elements(in: window, name: name)
        let xs = [local.midX, local.minX + 12, max(4, local.minX - 24)]
        let rest = pixels(window, xs: xs)
        report("\(name) pixels at rest (x = column middle \(Int(xs[0])), column edge \(Int(xs[1])), outside \(Int(xs[2]))):")
        printRuns(rest, xs: xs, name: name)
        dump(app, "\(name)-rest")

        var dumped = false
        for top in stride(from: CGFloat(2), through: 200, by: 6) {
            origin.withOffset(CGVector(dx: local.midX, dy: top)).hover()
            pause(0.5)
            let now = pixels(window, xs: xs)
            let changed = zip(rest, now).enumerated().filter { _, pair in
                zip(pair.0, pair.1).contains { a, b in zip(a, b).contains { abs(Int($0.0) - Int($0.1)) > 6 } }
            }.map(\.offset)
            if changed.isEmpty {
                report("\(name) hover y=\(Int(top)): no change")
            } else {
                report("\(name) hover y=\(Int(top)): changed at y \(ranges(changed.map { $0 * 2 }))")
                if !dumped {
                    dumped = true
                    printRuns(now, xs: xs, name: "\(name) while hovering y=\(Int(top))")
                    elements(in: window, name: "\(name) while hovering y=\(Int(top))")
                    dump(app, "\(name)-hover-\(Int(top))")
                }
            }
        }
    }

    /// Accessibility elements whose frame starts in the window's top 240 pt.
    @MainActor
    private func elements(in window: XCUIElement, name: String) {
        let snapshot: XCUIElementSnapshot
        do {
            snapshot = try window.snapshot()
        } catch {
            report("\(name): no snapshot: \(error)")
            return
        }
        let top = window.frame.minY
        var lines: [String] = []
        func walk(_ element: XCUIElementSnapshot, depth: Int) {
            let frame = element.frame
            if frame.minY - top < 240 {
                lines.append(String(repeating: " ", count: depth)
                    + "type=\(element.elementType.rawValue) id='\(element.identifier)' label='\(element.label)' "
                    + "title='\(element.title)' x=\(Int(frame.minX - window.frame.minX)) top=\(Int(frame.minY - top)) "
                    + "w=\(Int(frame.width)) h=\(Int(frame.height))")
            }
            for child in element.children { walk(child, depth: depth + 1) }
        }
        walk(snapshot, depth: 0)
        report("\(name) elements:\n" + lines.map { "PROBE|   " + $0 }.joined(separator: "\n"))
    }

    /// Colours down three columns, every 2 pt from the window's top to 240 pt.
    @MainActor
    private func pixels(_ window: XCUIElement, xs: [CGFloat]) -> [[[UInt8]]] {
        let image = window.screenshot().image
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        let rep = NSBitmapImageRep(cgImage: cg)
        let scale = CGFloat(cg.width) / window.frame.width
        return stride(from: CGFloat(0), to: 240, by: 2).map { top in
            xs.map { x in
                guard let color = rep.colorAt(x: Int(x * scale), y: Int(top * scale))?.usingColorSpace(.sRGB) else {
                    return [0, 0, 0]
                }
                return [color.redComponent, color.greenComponent, color.blueComponent].map { UInt8(($0 * 255).rounded()) }
            }
        }
    }

    private func printRuns(_ rows: [[[UInt8]]], xs: [CGFloat], name: String) {
        guard !rows.isEmpty else {
            report("  \(name): no screenshot")
            return
        }
        var start = 0
        for index in 1...rows.count where index == rows.count || rows[index] != rows[start] {
            let colours = rows[start].map { $0.map(String.init).joined(separator: ",") }.joined(separator: "  ")
            report("  \(name) y \(start * 2)-\(index * 2 - 2): \(colours)")
            start = index
        }
    }

    private func ranges(_ values: [Int]) -> String {
        var parts: [String] = []
        var start = values[0], last = values[0]
        for value in values.dropFirst() {
            if value == last + 2 { last = value; continue }
            parts.append(start == last ? "\(start)" : "\(start)-\(last)")
            start = value; last = value
        }
        parts.append(start == last ? "\(start)" : "\(start)-\(last)")
        return parts.joined(separator: ",")
    }

    @MainActor
    private func dump(_ app: XCUIApplication, _ label: String) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.henning.looseends.viewProbe"), object: label, userInfo: nil, deliverImmediately: true)
        pause(1.5)
        let path = "/tmp/loose-ends-probe-\(label).txt"
        report("dump requested: \(path) exists=\(FileManager.default.fileExists(atPath: path))")
    }

    private func pause(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private func report(_ line: String) {
        print("PROBE| " + line)
    }
}
#endif
