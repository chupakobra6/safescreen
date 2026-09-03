import AppKit
import Carbon
import OverlayBrowserCore
import OverlayBrowserWebKit

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
        AppLog.info(.app, "launch", ["arguments": arguments.dropFirst().joined(separator: " ")])
        NSApp.setActivationPolicy(.accessory)
        guard prepareBrowserProfile() else {
            return
        }
        setupBrowserPanel()
        setupHotKey()
        setupKeyDownMonitor()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        AppLog.info(.app, "reopen", ["hasVisibleWindows": String(flag)])
        showBrowserPanel()
        return true
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
        AppLog.info(.app, "ready")
    }

    private func prepareBrowserProfile() -> Bool {
        do {
            switch try BrowserProfile.migrateLegacyProfileIfNeeded() {
            case .notCanonicalBundle:
                AppLog.info(.profile, "migration-skipped-noncanonical-bundle")
            case .noLegacyProfile:
                AppLog.info(.profile, "legacy-profile-not-found")
            case .alreadyCompleted:
                AppLog.info(.profile, "migration-already-completed")
            case .migrated(let backupURL):
                var fields = ["source": "legacy-overlaybrowser"]
                if let backupURL {
                    fields["backup"] = backupURL.path
                }
                AppLog.info(.profile, "migration-completed", fields)
            }
            return true
        } catch {
            AppLog.error(.profile, "migration-failed", ["description": error.localizedDescription])
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Не удалось открыть профиль браузера"
            alert.informativeText = "Приложение остановлено, чтобы не создать новый пустой профиль. \(error.localizedDescription)"
            alert.addButton(withTitle: "Закрыть")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            NSApp.terminate(nil)
            return false
        }
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
            AppLog.info(.input, "escape")
            browserViewController?.exitInputMode()
            return nil
        }

        guard isCommandPasteShortcut(event), isBrowserPanelEvent(event) else {
            return event
        }

        _ = browserViewController?.pasteFromClipboard()
        return nil
    }

    private func isCommandPasteShortcut(_ event: NSEvent) -> Bool {
        guard event.keyCode == UInt16(kVK_ANSI_V) else {
            return false
        }

        let relevantFlags = event.modifierFlags.intersection([.command, .control, .option, .shift, .function])
        return relevantFlags == .command
    }

    private func isBrowserPanelEvent(_ event: NSEvent) -> Bool {
        guard let panel = browserPanel else {
            return false
        }

        return event.window === panel || NSApp.keyWindow === panel
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
        AppLog.info(.window, "show")
    }

    private func hideBrowserPanel() {
        browserViewController?.exitInputMode()
        browserPanel?.orderOut(nil)
        AppLog.info(.window, "hide")
    }
}
