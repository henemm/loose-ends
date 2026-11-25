#if os(macOS)
import AppKit
import OSLog
import ServiceManagement
import SwiftUI

/// Quick capture from the Mac menu bar (#356, Henning, 2026-10-12): the symbol opens a small panel
/// right under it with the same capture as the window — text, microphone, Return saves — and the
/// panel closes again. No window opens; without one the app lives in the menu bar only.
struct MenuBarCaptureView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    let enrichment: EnrichmentCoordinator

    var body: some View {
        VStack(spacing: 0) {
            CaptureView(channel: .app) { saved in
                // Without a window ContentView does not see the new task; the rules run here.
                if saved { Task { await enrichment.processPending() } }
                // The panel closes through SwiftUI, so the symbol ends the status item's session too
                // and the next click opens it again (#862).
                dismiss()
            }
            // The panel takes the capture's ideal height: without it Cancel and Done slid under the footer.
            .fixedSize(horizontal: false, vertical: true)
            // A hairline from the ink itself (#479), so light and dark take the same rule.
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 1)
                .accessibilityHidden(true)
            HStack {
                Button("Open Loose Ends") {
                    dismiss()
                    MacWindows.showMain { openWindow(id: MacWindows.mainWindowID) }
                }
                .accessibilityIdentifier("menuBarOpenApp")
                Spacer()
                Button("Quit Loose Ends") { NSApp.terminate(nil) }
                    .accessibilityIdentifier("menuBarQuit")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .frame(width: 440)
        // Paper behind the whole panel (#479); the window's own corner stays the system's.
        .background(Paper.ground.ignoresSafeArea())
        .background(UITestDarkPanel())
    }
}

/// The gallery's dark run (#479, AC-10): `.preferredColorScheme` does not reach the menu bar panel's
/// window, so under `--ui-testing-dark` (the same argument as `uiTestColorScheme`) the window itself
/// turns dark. Without the argument it does nothing; the product follows the system.
private struct UITestDarkPanel: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DarkWindowView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DarkWindowView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard ProcessInfo.processInfo.arguments.contains("--ui-testing-dark") else { return }
            window?.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

/// Which window counts and what the Dock shows (#356): the Dock icon only while a main window is
/// open. The menu bar panel and the settings window do not count as main windows.
enum DockPolicy {
    static func showsDockIcon(openMainWindows: Int) -> Bool { openMainWindows > 0 }
}

@MainActor
enum MacWindows {
    static let mainWindowID = "main"

    /// The list's windows: visible, able to become main, not a panel (the menu bar panel is one).
    static var mainWindows: [NSWindow] {
        NSApp.windows.filter { $0.isVisible && $0.canBecomeMain && !($0 is NSPanel) && $0.identifier?.rawValue.hasPrefix("com_apple_SwiftUI_Settings") != true }
    }

    /// Dock icon and app switcher follow the open windows.
    static func applyDockPolicy() {
        let policy: NSApplication.ActivationPolicy = DockPolicy.showsDockIcon(openMainWindows: mainWindows.count) ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    /// Brings the list to the front, opening a window only when none is there.
    static func showMain(open: () -> Void) {
        NSApp.setActivationPolicy(.regular)
        if let window = mainWindows.first {
            window.makeKeyAndOrderFront(nil)
        } else {
            open()
        }
        NSApp.activate()
    }
}

/// The menu bar panel's own record (#978): one notice line when the panel becomes key, resigns key, is
/// hidden (SwiftUI orders its panel out instead of closing it) and when it closes, always on, so a panel that closes by itself leaves its cause behind (stack, current event, front app,
/// activation policy). No title, no task text: only names the system gives.
/// Schnitt 2: the stack up to 40 frames past this observer, the current event's CGEvent fields (never `subtype` or
/// `data1`, which throw for unknown types such as 21), activation and space lines, and for 3 s after `key` one pair
/// of event monitors that only write and hand every event back unchanged. Diagnosis only, no behaviour.
@MainActor
enum MenuBarPanelLog {
    private nonisolated static let panelLogger = Logger(subsystem: "com.henning.looseends", category: "MenuBarPanel")
    /// The one monitor pair after the last `key`; a new `key` replaces it.
    private static var monitors: [Any] = []
    private static var monitorRound = 0
    /// Under `--ui-testing` (#978 S5 v7): uptime at the round's `key` and the last round whose hold is shown.
    private static var roundStart: TimeInterval = 0
    private static var shownRound = 0

    /// `event` is `key`, `resign`, `hide` or `close`; `kind` is the window's class name only, never its title.
    /// `isKey` is the panel's `isKeyWindow`, given for `key` and `resign`.
    static func record(_ event: String, kind: String, isKey: Bool? = nil) {
        let stack = callers()
        let current = NSApp.currentEvent
        let type = current.map { "\($0.type.rawValue)" } ?? "nil"
        let cg = cgFields(current)
        let state = isKey.map { " active=\(NSApp.isActive) keyWindow=\($0)" } ?? ""
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        let policy = policyName(NSApp.activationPolicy())
        panelLogger.notice("panel \(event, privacy: .public) window=\(kind, privacy: .public) event=\(type, privacy: .public) cg=\(cg, privacy: .public)\(state, privacy: .public) front=\(front, privacy: .public) policy=\(policy, privacy: .public) stack=\(stack, privacy: .public)")
        if event == "key" { startMonitors() }
    }

    /// Up to 40 frames from the first one outside this observer (see `afterObserver`).
    private static func callers() -> String {
        let frames = Thread.callStackSymbols
            .map { $0.split(separator: " ", omittingEmptySubsequences: true).dropFirst(3).joined(separator: " ") }
        return afterObserver(frames).prefix(40).joined(separator: " | ")
    }

    /// The frames after the leading block of observer frames (`MenuBarPanelLog` or `MacAppDelegate`). The block starts
    /// at the first observer frame and runs on through observer frames and glue (`assumeIsolated`, Swift thunks whose
    /// mangled name ends in `TR`, `TRTA` or `TA`); the result starts right after the block's last observer frame, so glue
    /// after it stays visible and the first frame shown is who keyed or closed the panel. Deeper `MacAppDelegate`
    /// frames stay. Without any observer frame the whole stack stays.
    nonisolated static func afterObserver(_ frames: [String]) -> ArraySlice<String> {
        let isObserver = { (frame: String) in frame.contains("MenuBarPanelLog") || frame.contains("MacAppDelegate") }
        let isGlue = { (frame: String) -> Bool in
            if frame.contains("assumeIsolated") { return true }
            guard frame.hasPrefix("$s") else { return false }
            let symbol = frame.components(separatedBy: " + ").first ?? frame
            return symbol.hasSuffix("TR") || symbol.hasSuffix("TA")
        }
        guard let first = frames.firstIndex(where: isObserver) else { return frames[...] }
        var last = first
        for index in frames.indices[first...] {
            if isObserver(frames[index]) { last = index } else if !isGlue(frames[index]) { break }
        }
        return frames[(last + 1)...]
    }

    /// Only fields every CGEvent carries; `cgEvent` can be nil.
    private nonisolated static func cgFields(_ event: NSEvent?) -> String {
        guard let cg = event?.cgEvent else { return "nil" }
        let window = cg.getIntegerValueField(.mouseEventWindowUnderMousePointer)
        let target = cg.getIntegerValueField(.eventTargetUnixProcessID)
        let source = cg.getIntegerValueField(.eventSourceUnixProcessID)
        return "type=\(cg.type.rawValue),window=\(window),target=\(target),source=\(source),time=\(cg.timestamp)"
    }

    /// A line for the app's own activation and hiding, the app the system activated (bundle id only) and a
    /// space change. The caller keeps the returned observers.
    static func observeActivation() -> [NSObjectProtocol] {
        let center = NotificationCenter.default
        let names: [(Notification.Name, String)] = [
            (NSApplication.didBecomeActiveNotification, "become-active"),
            (NSApplication.didResignActiveNotification, "resign-active"), (NSApplication.didHideNotification, "hide"),
        ]
        var observers = names.map { name, line in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { recordApp(line, detail: "") }
            }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                               object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundle = app?.bundleIdentifier ?? "nil"
            MainActor.assumeIsolated { recordApp("activate", detail: " app=\(bundle)") }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                               object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { recordApp("space", detail: "") }
        })
        return observers
    }

    private static func recordApp(_ line: String, detail: String) {
        let type = NSApp.currentEvent.map { "\($0.type.rawValue)" } ?? "nil"
        panelLogger.notice("app \(line, privacy: .public)\(detail, privacy: .public) active=\(NSApp.isActive, privacy: .public) event=\(type, privacy: .public)")
    }

    /// From `key` on for 3 s: a local monitor for every event of this app and a global one for mouse events
    /// elsewhere (no permission needed). The local one hands each event back unchanged.
    private static func startMonitors() {
        stopMonitors()
        monitorRound += 1
        let round = monitorRound
        roundStart = ProcessInfo.processInfo.systemUptime
        showHold(round: round, "pending")
        if let local = NSEvent.addLocalMonitorForEvents(matching: .any, handler: { event in
            logMonitored("local", event)
            if ModelContainerFactory.isUITesting, event.type == .leftMouseUp {
                let time = event.timestamp
                DispatchQueue.main.async { MainActor.assumeIsolated { mouseUp(round: round, at: time) } }
            }
            return event
        }) { monitors.append(local) }
        let mouse: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
                                            .otherMouseDown, .otherMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mouse, handler: { event in
            logMonitored("global", event)
            if ModelContainerFactory.isUITesting, event.type == .leftMouseUp {
                let time = event.timestamp
                DispatchQueue.main.async { MainActor.assumeIsolated { mouseUp(round: round, at: time) } }
            }
        }) { monitors.append(global) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            MainActor.assumeIsolated {
                guard monitorRound == round else { return }
                stopMonitors()
                panelLogger.notice("monitor end")
                if shownRound != round { showHold(round: round, "short") }
            }
        }
    }

    private static func stopMonitors() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
    }

    /// The first mouse up (type 2, local or global) of the running round: seconds from its `key`, as the evaluator's
    /// `key_to_mouse_up` counts them. Later ones and those of an old round change nothing. Both monitors pass it only
    /// under `--ui-testing` and hop to the main thread with the event's own time (`event.timestamp`, seconds since boot
    /// like `systemUptime`), so the hop does not change the hold and no handler assumes a thread.
    private static func mouseUp(round: Int, at time: TimeInterval) {
        guard monitorRound == round, shownRound != round else { return }
        let held = time - roundStart
        showHold(round: round, String(format: "%.3f", held))
    }

    /// #978 S5 v7: the round's hold as the accessibility value of the menu bar's status item, which the UI test holds
    /// as `statusItems.firstMatch` (`round=<n> pending|<seconds>|short`). Only under `--ui-testing`.
    private static func showHold(round: Int, _ state: String) {
        guard ModelContainerFactory.isUITesting else { return }
        if state != "pending" { shownRound = round }
        let button = NSApp.windows
            .filter { String(describing: type(of: $0)) == "NSStatusBarWindow" }
            .lazy.compactMap { statusButton(in: $0.contentView) }.first
        button?.setAccessibilityValue("round=\(round) \(state)")
    }

    private static func statusButton(in view: NSView?) -> NSStatusBarButton? {
        guard let view else { return nil }
        if let button = view as? NSStatusBarButton { return button }
        return view.subviews.lazy.compactMap { statusButton(in: $0) }.first
    }

    /// Raw type, window number and timestamp only.
    private nonisolated static func logMonitored(_ scope: String, _ event: NSEvent) {
        let type = event.type.rawValue
        let window = event.windowNumber
        let time = event.timestamp
        panelLogger.notice("monitor \(scope, privacy: .public) type=\(type, privacy: .public) window=\(window, privacy: .public) time=\(time, privacy: .public)")
    }

    private static func policyName(_ policy: NSApplication.ActivationPolicy) -> String {
        switch policy {
        case .regular: "regular"
        case .accessory: "accessory"
        case .prohibited: "prohibited"
        @unknown default: "unknown \(policy.rawValue)"
        }
    }
}

/// Launch at login (#356): on by default from the first start, switchable in the settings. Never
/// under tests, which host this app on the Mac.
@MainActor
enum LoginItem {
    private static let offeredKey = "loginItemOffered"
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Mac")

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            logger.error("Login item \(enabled ? "on" : "off", privacy: .public) failed: \(error, privacy: .public)")
        }
    }

    /// The first start switches it on once; after that only the user does.
    static func enableOnFirstStart() {
        guard !ModelContainerFactory.isRunningTests, !ModelContainerFactory.isUITesting else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: offeredKey) else { return }
        defaults.set(true, forKey: offeredKey)
        setEnabled(true)
    }
}

/// App delegate for the Mac: a start as login item opens no window, and the Dock icon follows
/// the windows (#356).
@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private var observers: [NSObjectProtocol] = []
    private var launchedAsLoginItem = false

    /// The launch event is current only here, before launching finishes.
    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAsLoginItem = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItem.enableOnFirstStart()
        if launchedAsLoginItem {
            // SwiftUI puts its first window up after this call; close it on the next turn.
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    for window in MacWindows.mainWindows { window.close() }
                    MacWindows.applyDockPolicy()
                }
            }
        }
        observeWindows()
        MacWindows.applyDockPolicy()
    }

    /// Key and close keep the Dock policy current; resign and hide only leave a line (#978), so the
    /// policy runs exactly as often as before.
    private func observeWindows() {
        let center = NotificationCenter.default
        let events: [(Notification.Name, String)] = [
            (NSWindow.didBecomeKeyNotification, "key"), (NSWindow.willCloseNotification, "close"),
        ]
        for (name, event) in events {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
                // At the moment it happens, so stack and current event are the cause's (#978).
                // Every NSPanel (the menu bar panel, but also open panels and alerts), so the line names the
                // window's class and, for `key`, whether it is the key window; never its title.
                if let panel = note.object as? NSPanel {
                    let kind = String(describing: type(of: panel))
                    MainActor.assumeIsolated {
                        MenuBarPanelLog.record(event, kind: kind, isKey: event == "key" ? panel.isKeyWindow : nil)
                    }
                }
                // After the close has gone through, not before.
                DispatchQueue.main.async { MainActor.assumeIsolated { MacWindows.applyDockPolicy() } }
            })
        }
        observePanelHiding(center)
        observers += MenuBarPanelLog.observeActivation()
    }

    /// SwiftUI's menu bar panel is ordered out, never closed, so `willClose` stays silent when it vanishes
    /// (CI run 44994038524). Resign key is the moment of the cause; hide only once the panel is no longer visible.
    private func observePanelHiding(_ center: NotificationCenter) {
        observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: nil,
                                            queue: .main) { note in
            guard let panel = note.object as? NSPanel else { return }
            let kind = String(describing: type(of: panel))
            MainActor.assumeIsolated { MenuBarPanelLog.record("resign", kind: kind, isKey: panel.isKeyWindow) }
        })
        observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: nil,
                                            queue: .main) { note in
            guard let panel = note.object as? NSPanel else { return }
            let kind = String(describing: type(of: panel))
            let hidden = MainActor.assumeIsolated { !panel.isVisible || !panel.occlusionState.contains(.visible) }
            guard hidden else { return }
            MainActor.assumeIsolated { MenuBarPanelLog.record("hide", kind: kind) }
        })
    }

    /// A menu bar app stays when its last window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// The device token and the silent wake-up go to `PushWakeUp.current` (#795 S5c-2a).
    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await PushWakeUp.current?.didReceive(token: deviceToken) }
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        Logger(subsystem: "com.henning.looseends", category: "push-wake-up")
            .info("no device token: \(String(describing: type(of: error)), privacy: .public)")
    }

    /// AppKit has no completion here; `userInfo` is read here and never carried into the task.
    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        let isWake = PushWakeUp.isWake(userInfo)
        guard let node = PushWakeUp.current else { return }
        Task { _ = await node.handle(isWake: isWake) }
    }
}
#endif
