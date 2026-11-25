import SwiftUI
import AppIntents
import ItsytvCore

@main
struct AtvKbdApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        Window("ATV KBD", id: "main") {
            KeyboardWindowView()
                .environment(appDelegate.manager)
                .frame(minWidth: 260, minHeight: 240)
        }
        .defaultSize(width: 280, height: 250)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    let manager = AppleTVManager()
    /// Set by the Open Remote shortcut until that Apple TV is discovered.
    var requestedDeviceID: String?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // A normal app: Dock icon and ⌘Tab, including over an older "show in Dock" preference.
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        ItsytvCoreLog.verbose = true
        #endif
        Self.shared = self
        AtvKbdShortcuts.updateAppShortcutParameters()
        manager.startScanning()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first { $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.windows.first { $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        manager.disconnect()
    }

    /// Connect once the requested Apple TV is on the network. Called from the shortcut and from discovery.
    func openAppleTV(id: String) {
        requestedDeviceID = id
        connectRequestedDeviceIfAvailable()
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.canBecomeKey }?.makeKeyAndOrderFront(nil)
    }

    func connectRequestedDeviceIfAvailable() {
        guard let id = requestedDeviceID,
              let device = manager.discoveredDevices.first(where: { $0.id == id }) else { return }
        requestedDeviceID = nil
        manager.connect(to: device)
    }
}
