#if os(macOS)
import Foundation
import OSLog

/// #978 S5 v6: how long the test's click held the menu bar symbol, read from the app's own panel log
/// (`MenuBarCapture`, subsystem `com.henning.looseends`, category `MenuBarPanel`) through `OSLogStore.local()`.
/// The rule is the evaluator's (`key_to_mouse_up` in `scripts/mac_panel_repeat_summary.py`): from the first
/// `panel key` line after the click to the first mouse up (monitor line `type=2`) within the monitor's 3 s after it.
enum MacPanelHold {
    enum Reading: Equatable {
        /// Seconds from `key` to the mouse going up.
        case seconds(TimeInterval)
        /// `key`, but no mouse up within the monitor's window: the event stayed with the status item.
        case short
        /// No hold could be read; the reason says why.
        case unknown(String)

        var text: String {
            switch self {
            case .seconds(let value): String(format: "%.3f s", value)
            case .short: "short (no mouse up)"
            case .unknown(let reason): "unknown (\(reason))"
            }
        }
    }

    /// The app's monitor runs for 3 s after `key`; only a mouse up inside it belongs to the click.
    static let window: TimeInterval = 3
    /// How long after the click a `key` line still belongs to it (the evaluator's timeline).
    static let keyWindow: TimeInterval = 15

    /// The hold of the click made at `since`.
    static func read(since: Date) -> Reading {
        let lines: [(date: Date, message: String)]
        do {
            lines = try panelLines(since: since)
        } catch {
            return .unknown("log not readable: \(error.localizedDescription)")
        }
        return hold(in: lines, since: since)
    }

    private static func panelLines(since: Date) throws -> [(date: Date, message: String)] {
        let store = try OSLogStore.local()
        let predicate = NSPredicate(format: "subsystem == %@ AND category == %@", "com.henning.looseends", "MenuBarPanel")
        return try store.getEntries(at: store.position(date: since), matching: predicate)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { $0.date >= since }
            .map { (date: $0.date, message: $0.composedMessage) }
            .sorted { $0.date < $1.date }
    }

    private static func hold(in lines: [(date: Date, message: String)], since: Date) -> Reading {
        let key = lines.first { line in
            line.message.hasPrefix("panel key ") && line.date.timeIntervalSince(since) < keyWindow
        }
        guard let key else {
            return .unknown("no panel key line within \(Int(keyWindow)) s of the click, \(lines.count) panel lines")
        }
        let up = lines.first { line in
            let offset = line.date.timeIntervalSince(key.date)
            return offset >= 0 && offset < window && line.message.hasPrefix("monitor ")
                && line.message.split(separator: " ").contains("type=2")
        }
        guard let up else { return .short }
        return .seconds(up.date.timeIntervalSince(key.date))
    }
}
#endif
