import AppKit

let app = NSApplication.shared
let delegate = SafeScreenAppDelegate(arguments: CommandLine.arguments)

app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
