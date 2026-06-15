import AppKit

final class BrowserPanel: NSPanel {
    private var acceptsKeyboardFocus = false

    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 980, height: 720)
        let styleMask: NSWindow.StyleMask = [
            .titled,
            .closable,
            .miniaturizable,
            .resizable,
            .nonactivatingPanel
        ]

        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        title = "Overlay Browser"
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        level = .floating
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setFrameAutosaveName("OverlayBrowser.BrowserPanel")
    }

    override var canBecomeKey: Bool {
        acceptsKeyboardFocus
    }

    override var canBecomeMain: Bool {
        false
    }

    func setInputMode(_ enabled: Bool) {
        acceptsKeyboardFocus = enabled

        if enabled {
            orderFrontRegardless()
            makeKey()
            NSCursor.arrow.set()
        } else {
            makeFirstResponder(nil)
            orderFrontRegardless()
            NSCursor.arrow.set()
        }
    }
}
