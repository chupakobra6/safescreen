import Foundation

enum OverlayBrowserProcessMode {
    static let helperArgument = "--overlay-helper"
    static let hostPIDEnvironment = "OVERLAY_BROWSER_HOST_PID"
    static let showBrowserNotification = Notification.Name(
        "com.igor.safescreen.overlay-browser.show-browser"
    )

    static func applicationArguments(from arguments: [String]) -> [String] {
        arguments.filter { $0 != helperArgument }
    }
}
