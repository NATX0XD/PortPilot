import SwiftUI
import AppKit

@main
struct PortPilotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        // Menu-bar item with a live count of your services; same UI in the popover.
        MenuBarExtra {
            ContentView(model: model)
                .frame(width: 380, height: 460)
        } label: {
            Image(systemName: "dot.radiowaves.left.and.right")
            let n = model.userServiceCount
            if n > 0 { Text("\(n)") }
        }
        .menuBarExtraStyle(.window)
    }
}

/// Creates and manages the real desktop window with AppKit. The SwiftUI `Window` +
/// `MenuBarExtra` combination does not reliably show a window on this SDK, so we host
/// the SwiftUI ContentView inside an NSWindow ourselves.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.start()
        showMainWindow()
    }

    /// Closing the window must NOT quit the app — it keeps running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Re-open the window when the user clicks the Dock icon and nothing is visible.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    /// Window closed → drop the Dock icon and live purely as a menu-bar background app.
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    /// Shows the desktop window and restores the Dock icon. Callable from the menu bar.
    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)   // Dock icon + normal app
        if let window {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        win.title = "PortPilot"
        win.delegate = self
        win.isReleasedWhenClosed = false
        win.isOpaque = true
        win.backgroundColor = .windowBackgroundColor
        win.minSize = NSSize(width: 380, height: 440)
        win.collectionBehavior = [.moveToActiveSpace]   // appear on whatever Space is active

        let hosting = NSHostingView(rootView: ContentView(model: AppModel.shared))
        hosting.autoresizingMask = [.width, .height]
        win.contentView = hosting

        win.center()
        win.makeKeyAndOrderFront(nil)
        win.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }
}
