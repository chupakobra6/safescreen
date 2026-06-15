import AppKit
import Carbon
import OverlayBrowserCore

final class OverlayBrowserAppDelegate: NSObject, NSApplicationDelegate {
    private let arguments: [String]
    private var browserPanel: BrowserPanel?
    private var browserViewController: BrowserViewController?
    private var hotKeyController: HotKeyController?
    private var escapeMonitor: Any?

    init(arguments: [String]) {
        self.arguments = arguments
    }

    deinit {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupBrowserPanel()
        setupHotKey()
        setupEscapeMonitor()
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
        panel.applyDefaultContentSize()
        panel.center()
        panel.setInputMode(false)
        panel.orderFrontRegardless()

        browserViewController = viewController
        browserPanel = panel
    }

    private func setupHotKey() {
        let controller = HotKeyController { [weak self] in
            self?.toggleBrowserPanel()
        }
        controller.register()
        hotKeyController = controller
    }

    private func setupEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape) else {
                return event
            }

            self?.browserViewController?.exitInputMode()
            return nil
        }
    }

    private func toggleBrowserPanel() {
        guard let panel = browserPanel else {
            return
        }

        if panel.isVisible {
            panel.orderOut(nil)
            browserViewController?.exitInputMode()
        } else {
            panel.orderFrontRegardless()
        }
    }
}
