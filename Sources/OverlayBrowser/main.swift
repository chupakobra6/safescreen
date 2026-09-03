import AppKit

let app = NSApplication.shared
let processMode = OverlayBrowserProcessMode.self
let isHelper = CommandLine.arguments.contains(processMode.helperArgument)
let arguments = processMode.applicationArguments(from: CommandLine.arguments)
let delegate: NSApplicationDelegate = isHelper
    ? OverlayBrowserAppDelegate(arguments: arguments)
    : OverlayBrowserHostAppDelegate(arguments: arguments)

app.delegate = delegate
app.setActivationPolicy(isHelper ? .accessory : .regular)
app.run()
