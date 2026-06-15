import AppKit
import Carbon
import OverlayBrowserCore

final class OverlayBrowserAppDelegate: NSObject, NSApplicationDelegate {
    private let arguments: [String]
    private var browserPanel: BrowserPanel?
    private var browserViewController: BrowserViewController?
    private var hotKeyController: HotKeyController?
    private var escapeMonitor: Any?
    private var outsideMouseDownMonitor: Any?
    private var outsideMouseDownEnabledAt = Date.distantFuture
    private let outsideMouseDownActivationDelay: TimeInterval = 0.6

    init(arguments: [String]) {
        self.arguments = arguments
    }

    deinit {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
        }

        if let outsideMouseDownMonitor {
            NSEvent.removeMonitor(outsideMouseDownMonitor)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupBrowserPanel()
        setupHotKey()
        setupEscapeMonitor()
        setupOutsideMouseDownMonitor()
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

    private func setupEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == UInt16(kVK_Escape) else {
                return event
            }

            self?.browserViewController?.exitInputMode()
            return nil
        }
    }

    private func setupOutsideMouseDownMonitor() {
        outsideMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.hideBrowserPanelIfMouseIsOutside()
            }
        }
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

    private func hideBrowserPanelIfMouseIsOutside() {
        guard let panel = browserPanel, panel.isVisible else {
            return
        }

        guard Date() >= outsideMouseDownEnabledAt else {
            return
        }

        if panel.frame.contains(NSEvent.mouseLocation) {
            return
        }

        fputs("OverlayBrowser hidden by outside mouse down\n", stderr)
        hideBrowserPanel()
    }

    private func showBrowserPanel() {
        outsideMouseDownEnabledAt = Date().addingTimeInterval(outsideMouseDownActivationDelay)
        browserPanel?.orderFrontRegardless()
    }

    private func hideBrowserPanel() {
        outsideMouseDownEnabledAt = .distantFuture
        browserPanel?.orderOut(nil)
        browserViewController?.exitInputMode()
    }
}
