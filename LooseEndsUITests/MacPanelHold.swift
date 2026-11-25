#if os(macOS)
import XCTest

/// #978 S5 v7: how long the test's click held the menu bar symbol, read from the accessibility value the app puts on
/// its status item under `--ui-testing` (`MenuBarPanelLog.showHold` in `MenuBarCapture.swift`). The value is one line,
/// `round=<n> pending` from the panel's `key`, then `round=<n> <seconds>` at the first mouse up within the monitor's
/// 3 s, or `round=<n> short` when the round ends without one: the evaluator's rule (`key_to_mouse_up` in
/// `scripts/mac_panel_repeat_summary.py`). The runner cannot read the app's log (v6: "Connection to logd failed").
@MainActor
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

    /// How long `read` waits for a new round that is no longer pending (the app's round runs 3 s from `key`).
    static let wait: TimeInterval = 4

    /// The round the status item shows now; 0 when it carries no value or one that is not readable.
    static func round(of statusItem: XCUIElement) -> Int {
        parse(statusItem.value as? String)?.round ?? 0
    }

    /// The hold of the first round after `round`, once it is no longer pending; at most `wait` seconds.
    static func read(_ statusItem: XCUIElement, after round: Int) -> Reading {
        let deadline = Date().addingTimeInterval(wait)
        var value = statusItem.value as? String
        while Date() < deadline {
            if let shown = parse(value), shown.round > round, shown.state != "pending" {
                return reading(shown.state)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
            value = statusItem.value as? String
        }
        if let shown = parse(value), shown.round > round, shown.state != "pending" { return reading(shown.state) }
        guard let value else { return .unknown("no value on the status item") }
        guard parse(value) != nil else { return .unknown("value not readable: \(value)") }
        return .unknown("no finished round after \(round) within \(Int(wait)) s, value \(value)")
    }

    private static func parse(_ value: String?) -> (round: Int, state: String)? {
        guard let value else { return nil }
        let parts = value.split(separator: " ")
        guard parts.count == 2, parts[0].hasPrefix("round="),
              let number = Int(parts[0].dropFirst("round=".count)) else { return nil }
        return (number, String(parts[1]))
    }

    private static func reading(_ state: String) -> Reading {
        if state == "short" { return .short }
        guard let seconds = TimeInterval(state) else { return .unknown("state not readable: \(state)") }
        return .seconds(seconds)
    }
}
#endif
