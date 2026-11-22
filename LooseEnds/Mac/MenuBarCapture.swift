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

/// The menu bar panel's own record (#978): one notice line when the panel becomes key and when it closes,
/// always on, so a panel that closes by itself leaves its cause behind (stack, current event, front app,
/// activation policy). No title, no task text: only names the system gives.
@MainActor
enum MenuBarPanelLog {
    private static let panelLogger = Logger(subsystem: "com.henning.looseends", category: "MenuBarPanel")

    /// `kind` is the window's class name only, never its title.
    static func record(_ name: Notification.Name, kind: String) {
        let event = name == NSWindow.willCloseNotification ? "close" : "key"
        // Frame 0 is this function; the next ones show who closed or keyed the panel.
        let stack = Thread.callStackSymbols.dropFirst().prefix(12)
            .map { $0.split(separator: " ", omittingEmptySubsequences: true).dropFirst(3).joined(separator: " ") }
            .joined(separator: " | ")
        let current = NSApp.currentEvent.map { "\($0.type.rawValue) \(String(describing: $0.type))" } ?? "nil"
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "nil"
        let policy = policyName(NSApp.activationPolicy())
        panelLogger.notice("panel \(event, privacy: .public) window=\(kind, privacy: .public) event=\(current, privacy: .public) front=\(front, privacy: .public) policy=\(policy, privacy: .public) stack=\(stack, privacy: .public)")
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
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.willCloseNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
                // At the moment it happens, so stack and current event are the cause's (#978).
                // Every NSPanel (the menu bar panel, but also open panels and alerts), so the line names the
                // window's class; only that string goes into the main actor, never the window.
                if let panel = note.object as? NSPanel {
                    let kind = String(describing: type(of: panel))
                    MainActor.assumeIsolated { MenuBarPanelLog.record(name, kind: kind) }
                }
                // After the close has gone through, not before.
                DispatchQueue.main.async { MainActor.assumeIsolated { MacWindows.applyDockPolicy() } }
            })
        }
        MacWindows.applyDockPolicy()
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
