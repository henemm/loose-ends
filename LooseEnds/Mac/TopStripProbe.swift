#if os(macOS) && DEBUG
import AppKit
import OSLog

/// Diagnosis for #829 (Henning, 2026-11-04): a light strip over the top of a wide Mac list that reacts to
/// the pointer. Only in debug builds and only under `--ui-testing-view-probe`: `MacTopStripProbeTests` posts
/// a distributed notification, and the app writes every view in the top 240 pt of its windows (class, frame
/// from the top, flags, tracking areas, which make a view react to hover) plus a hit-test grid and the views
/// under the pointer into `/tmp/loose-ends-probe-<label>.txt`. Nothing in the product calls it.
@MainActor
enum TopStripProbe {
    static let argument = "--ui-testing-view-probe"
    static let notification = Notification.Name("com.henning.looseends.viewProbe")
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Probe")
    private static var observer: NSObjectProtocol?
    private static let band: CGFloat = 240

    static func startIfAsked() {
        guard ProcessInfo.processInfo.arguments.contains(argument), observer == nil else { return }
        observer = DistributedNotificationCenter.default().addObserver(
            forName: notification, object: nil, queue: .main
        ) { note in
            let label = (note.object as? String) ?? "probe"
            MainActor.assumeIsolated { write(label: label) }
        }
    }

    private static func write(label: String) {
        var lines: [String] = ["PROBE \(label) mouse=\(NSEvent.mouseLocation)"]
        for window in NSApp.windows where window.isVisible {
            guard let root = window.contentView?.superview else { continue }
            let height = root.bounds.height
            lines.append("WINDOW \(type(of: window)) '\(window.title)' frame=\(window.frame) "
                + "contentLayout=\(window.contentLayoutRect) toolbar=\(window.toolbar.map { "\($0.displayMode.rawValue)" } ?? "none") "
                + "titlebarSep=\(window.titlebarSeparatorStyle.rawValue) style=\(window.styleMask.rawValue)")
            // The views under the pointer, deepest first.
            let mouse = window.convertPoint(fromScreen: NSEvent.mouseLocation)
            if root.bounds.contains(mouse) {
                var chain: [String] = []
                var view = root.hitTest(mouse)
                while let current = view {
                    chain.append(describe(current, in: height))
                    view = current.superview
                }
                lines.append("UNDER POINTER (\(Int(mouse.x)), \(Int(height - mouse.y)) from top):")
                lines += chain.map { "  " + $0 }
            }
            // Which view takes the click where: one line per height, runs of the same view folded.
            lines.append("HIT GRID (x from left, y from top):")
            for top in stride(from: CGFloat(2), through: band, by: 6) {
                var runs: [(from: Int, to: Int, name: String)] = []
                for x in stride(from: CGFloat(4), to: root.bounds.width, by: 16) {
                    let hit = root.hitTest(NSPoint(x: x, y: height - top))
                    let name = hit.map { "\(type(of: $0))#\(ObjectIdentifier($0).hashValue & 0xFFFF)" } ?? "nil"
                    if let last = runs.last, last.name == name {
                        runs[runs.count - 1].to = Int(x)
                    } else {
                        runs.append((Int(x), Int(x), name))
                    }
                }
                lines.append("  y=\(Int(top)): " + runs.map { "\($0.from)-\($0.to) \($0.name)" }.joined(separator: " | "))
            }
            lines.append("VIEWS (top \(Int(band)) pt):")
            walk(root, depth: 0, height: height, into: &lines)
        }
        let url = URL(fileURLWithPath: "/tmp/loose-ends-probe-\(label).txt")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            logger.info("Probe \(label, privacy: .public) written: \(lines.count) lines")
        } catch {
            logger.error("Probe \(label, privacy: .public) not written: \(error, privacy: .public)")
        }
    }

    private static func walk(_ view: NSView, depth: Int, height: CGFloat, into lines: inout [String]) {
        let frame = view.convert(view.bounds, to: nil)
        let top = height - frame.maxY
        guard top < band else { return }
        lines.append(String(repeating: "  ", count: depth) + describe(view, in: height))
        for subview in view.subviews {
            walk(subview, depth: depth + 1, height: height, into: &lines)
        }
    }

    private static func describe(_ view: NSView, in height: CGFloat) -> String {
        let frame = view.convert(view.bounds, to: nil)
        var parts = ["\(type(of: view))#\(ObjectIdentifier(view).hashValue & 0xFFFF)",
                     "x=\(Int(frame.minX)) top=\(Int(height - frame.maxY)) w=\(Int(frame.width)) h=\(Int(frame.height))"]
        if view.isHidden { parts.append("HIDDEN") }
        if view.alphaValue < 1 { parts.append("alpha=\(view.alphaValue)") }
        if view.isOpaque { parts.append("opaque") }
        if let color = view.layer?.backgroundColor, color.alpha > 0 { parts.append("layerBG=\(color.components ?? [])") }
        if let effect = view as? NSVisualEffectView {
            parts.append("effect(material=\(effect.material.rawValue) blending=\(effect.blendingMode.rawValue) state=\(effect.state.rawValue))")
        }
        if let scroll = view as? NSScrollView {
            parts.append("scroll(insets=\(scroll.contentInsets) auto=\(scroll.automaticallyAdjustsContentInsets) "
                + "drawsBG=\(scroll.drawsBackground) bg=\(scroll.backgroundColor))")
        }
        if let table = view as? NSTableView {
            parts.append("table(outline=\(table is NSOutlineView) style=\(table.style.rawValue) "
                + "floatsGroupRows=\(table.floatsGroupRows) bg=\(table.backgroundColor) rows=\(table.numberOfRows))")
        }
        if let row = view as? NSTableRowView {
            parts.append("row(group=\(row.isGroupRowStyle) floating=\(row.isFloating) selected=\(row.isSelected) emphasized=\(row.isEmphasized))")
        }
        if let control = view as? NSControl { parts.append("control(enabled=\(control.isEnabled))") }
        let areas = view.trackingAreas
        if !areas.isEmpty {
            parts.append("TRACKING[" + areas.map { area in
                let owner = area.owner.map { "\(type(of: $0))" } ?? "nil"
                return "opts=0x\(String(area.options.rawValue, radix: 16)) rect=\(area.rect) owner=\(owner)"
            }.joined(separator: "; ") + "]")
        }
        let role = view.accessibilityRole()?.rawValue ?? ""
        let identifier = view.accessibilityIdentifier()
        if !role.isEmpty || !identifier.isEmpty { parts.append("ax(\(role) '\(identifier)')") }
        return parts.joined(separator: " ")
    }
}
#endif
