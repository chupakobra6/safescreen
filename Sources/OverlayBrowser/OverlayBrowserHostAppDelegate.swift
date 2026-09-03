import AppKit

final class OverlayBrowserHostAppDelegate: NSObject, NSApplicationDelegate {
    private let arguments: [String]
    private var helperProcess: Process?

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()
        launchHelperIfNeeded()
        AppLog.info(.app, "host-ready")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        AppLog.info(.app, "host-reopen")
        launchHelperIfNeeded()
        DistributedNotificationCenter.default().postNotificationName(
            OverlayBrowserProcessMode.showBrowserNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppLog.info(.app, "host-terminate")
        if helperProcess?.isRunning == true {
            helperProcess?.terminate()
        }
    }

    private func launchHelperIfNeeded() {
        guard helperProcess?.isRunning != true else {
            return
        }
        guard let executableURL = Bundle.main.executableURL else {
            AppLog.error(.app, "helper-launch-failed", ["reason": "missing-executable"])
            NSApp.terminate(nil)
            return
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = [OverlayBrowserProcessMode.helperArgument] + Array(arguments.dropFirst())
        var environment = ProcessInfo.processInfo.environment
        environment[OverlayBrowserProcessMode.hostPIDEnvironment] = "\(ProcessInfo.processInfo.processIdentifier)"
        process.environment = environment
        process.terminationHandler = { process in
            AppLog.warning(.app, "helper-terminated", ["status": "\(process.terminationStatus)"])
        }

        do {
            try process.run()
            helperProcess = process
            AppLog.info(.app, "helper-launched", ["pid": "\(process.processIdentifier)"])
        } catch {
            AppLog.error(.app, "helper-launch-failed", ["description": error.localizedDescription])
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = "Не удалось запустить Overlay Browser"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "Закрыть")
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Завершить Overlay Browser",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
