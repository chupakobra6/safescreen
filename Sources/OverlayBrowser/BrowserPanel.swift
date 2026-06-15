import AppKit

final class BrowserPanel: NSPanel {
    private static let defaultContentSize = NSSize(width: 1280, height: 800)
    private static let minimumContentSize = NSSize(width: 980, height: 640)
    private static let defaultAlphaValue = 0.94

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
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        alphaValue = Self.defaultAlphaValue
        contentMinSize = Self.minimumContentSize
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
