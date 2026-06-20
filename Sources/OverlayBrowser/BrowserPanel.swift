import AppKit

final class BrowserPanel: NSPanel {
    private static let defaultContentSize = NSSize(width: 420, height: 820)
    private static let defaultScreenMargin: CGFloat = 20

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
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    func applyDefaultSidebarPlacement() {
        setContentSize(Self.defaultContentSize)

        guard let visibleFrame = (screen ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else {
            center()
            return
        }

        var newFrame = self.frame
        newFrame.origin.x = visibleFrame.maxX - newFrame.width - Self.defaultScreenMargin
        newFrame.origin.y = visibleFrame.midY - newFrame.height / 2
        let minY = visibleFrame.minY + Self.defaultScreenMargin
        let maxY = visibleFrame.maxY - newFrame.height - Self.defaultScreenMargin
        newFrame.origin.y = maxY >= minY ? min(max(newFrame.origin.y, minY), maxY) : visibleFrame.minY
        setFrame(newFrame, display: true)
    }

    func setInputMode(_ enabled: Bool) {
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
