import AppKit
import WebKit

final class AddressTextField: NSTextField {
    var onInteraction: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.arrow.set()
        onInteraction?()
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        onInteraction?()
        return super.becomeFirstResponder()
    }
}

final class FocusAwareWebView: WKWebView {
    var onInputIntent: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .arrow)
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        NSCursor.arrow.set()
        onInputIntent?()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        NSCursor.arrow.set()
        onInputIntent?()
        super.rightMouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        onInputIntent?()
        super.keyDown(with: event)
    }
}
