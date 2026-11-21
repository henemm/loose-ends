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
                    Diag862.log.notice("#862 openAppTap before dismiss active=\(NSApp.isActive, privacy: .public)")
                    dismiss()
                    Diag862.log.notice("#862 openAppTap after dismiss active=\(NSApp.isActive, privacy: .public)")
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
        let old = NSApp.activationPolicy()
        Diag862.log.notice("#862 applyDockPolicy old=\(old.rawValue, privacy: .public) new=\(policy.rawValue, privacy: .public) mainWindows=\(mainWindows.count, privacy: .public) switch=\(old != policy, privacy: .public) active=\(NSApp.isActive, privacy: .public)")
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    /// Brings the list to the front, opening a window only when none is there.
    static func showMain(open: () -> Void) {
        Diag862.log.notice("#862 showMain enter mainWindows=\(mainWindows.count, privacy: .public) policy=\(NSApp.activationPolicy().rawValue, privacy: .public) active=\(NSApp.isActive, privacy: .public)")
        NSApp.setActivationPolicy(.regular)
        if let window = mainWindows.first {
            window.makeKeyAndOrderFront(nil)
        } else {
            open()
        }
        NSApp.activate()
    }
}

/// Diagnosis only (#862, throw-away branch): logs window, app and activation events with timestamps.
@MainActor
enum Diag862 {
    nonisolated static let log = Logger(subsystem: "com.henning.looseends", category: "Mac862")

    static func observe(into observers: inout [NSObjectProtocol]) {
        let center = NotificationCenter.default
        let windowEvents: [(NSNotification.Name, String)] = [
            (NSWindow.didBecomeKeyNotification, "didBecomeKey"),
            (NSWindow.didResignKeyNotification, "didResignKey"),
            (NSWindow.willCloseNotification, "willClose"),
            (NSWindow.didChangeOcclusionStateNotification, "didChangeOcclusionState"),
            (NSWindow.didBecomeMainNotification, "didBecomeMain"),
        ]
        for (name, label) in windowEvents {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { note in
                let window = note.object as? NSWindow
                let kind = window.map { String(describing: type(of: $0)) } ?? "nil"
                let id = window?.identifier?.rawValue ?? "nil"
                let visible = window?.isVisible ?? false
                let key = window?.isKeyWindow ?? false
                MainActor.assumeIsolated {
                    log.notice("#862 \(label, privacy: .public) class=\(kind, privacy: .public) id=\(id, privacy: .public) visible=\(visible, privacy: .public) key=\(key, privacy: .public) active=\(NSApp.isActive, privacy: .public) policy=\(NSApp.activationPolicy().rawValue, privacy: .public)")
                    // Who closes the panel: the call stack of every close or loss of key outside the main window.
                    if (label == "willClose" || label == "didResignKey"), !id.hasPrefix("main") {
                        for (index, frame) in Thread.callStackSymbols.prefix(40).enumerated() {
                            log.notice("#862 stack \(label, privacy: .public) \(index, privacy: .public) \(frame, privacy: .public)")
                        }
                        let event = NSApp.currentEvent.map { "\($0.type.rawValue) window=\($0.windowNumber)" } ?? "nil"
                        log.notice("#862 currentEvent \(label, privacy: .public) \(event, privacy: .public)")
                    }
                }
            })
        }
        let appEvents: [(NSNotification.Name, String)] = [
            (NSApplication.didBecomeActiveNotification, "didBecomeActive"),
            (NSApplication.didResignActiveNotification, "didResignActive"),
        ]
        for (name, label) in appEvents {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    log.notice("#862 \(label, privacy: .public) policy=\(NSApp.activationPolicy().rawValue, privacy: .public) mainWindows=\(MacWindows.mainWindows.count, privacy: .public)")
                }
            })
        }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundle = app?.bundleIdentifier ?? "nil"
            log.notice("#862 workspaceDidActivateApplication bundle=\(bundle, privacy: .public)")
        })
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
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                // After the close has gone through, not before.
                DispatchQueue.main.async { MainActor.assumeIsolated { MacWindows.applyDockPolicy() } }
            })
        }
        Diag862.observe(into: &observers)
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
