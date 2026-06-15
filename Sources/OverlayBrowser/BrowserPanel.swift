import AppKit

final class BrowserPanel: NSPanel {
    private static let defaultContentSize = NSSize(width: 1280, height: 800)

    private var acceptsKeyboardFocus = false

    init() {
        let contentRect = NSRect(origin: .zero, size: Self.defaultContentSize)
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
        titleVisibility = .visible
        titlebarAppearsTransparent = false
        isOpaque = true
        backgroundColor = .windowBackgroundColor
        alphaValue = 1.0
        level = .floating
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool {
        acceptsKeyboardFocus
    }

    override var canBecomeMain: Bool {
        false
    }

    func applyDefaultContentSize() {
        setContentSize(Self.defaultContentSize)
    }

    func setInputMode(_ enabled: Bool) {
        acceptsKeyboardFocus = enabled

        if enabled {
            orderFrontRegardless()
            makeKey()
            NSCursor.arrow.set()
        } else {
            makeFirstResponder(nil)
            resignKey()
            orderFrontRegardless()
            NSCursor.arrow.set()
        }
    }
}
