import AppKit
import Carbon
import OverlayBrowserCore

final class OverlayBrowserAppDelegate: NSObject, NSApplicationDelegate {
    private let arguments: [String]
    private var browserPanel: BrowserPanel?
    private var browserViewController: BrowserViewController?
    private var hotKeyController: HotKeyController?
    private var keyDownMonitor: Any?

    init(arguments: [String]) {
        self.arguments = arguments
    }

    deinit {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupBrowserPanel()
        setupHotKey()
        setupKeyDownMonitor()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupBrowserPanel() {
        let viewController = BrowserViewController(
            initialDestination: URLArgumentParser.destination(from: arguments)
        )
        let panel = BrowserPanel()

        viewController.onInputModeChanged = { [weak panel] enabled in
            panel?.setInputMode(enabled)
        }

        panel.contentViewController = viewController
        panel.applyDefaultSidebarPlacement()
        browserViewController = viewController
        browserPanel = panel

        panel.setInputMode(false)
        showBrowserPanel()
    }

    private func setupHotKey() {
        let controller = HotKeyController { [weak self] in
            self?.toggleBrowserPanel()
        }
        controller.register()
        hotKeyController = controller
    }

    private func setupKeyDownMonitor() {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == UInt16(kVK_Escape) {
            browserViewController?.exitInputMode()
            return nil
        }

        return event
    }

    private func toggleBrowserPanel() {
        guard let panel = browserPanel else {
            return
        }

        if panel.isVisible {
            hideBrowserPanel()
        } else {
            showBrowserPanel()
        }
    }

    private func showBrowserPanel() {
        browserPanel?.orderFrontRegardless()
    }

    private func hideBrowserPanel() {
        browserViewController?.exitInputMode()
        browserPanel?.orderOut(nil)
    }
}
