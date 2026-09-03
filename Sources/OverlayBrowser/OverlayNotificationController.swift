import AppKit
import OverlayBrowserCore

final class OverlayNotificationController: NSObject {
    private struct Notification {
        let identifier: String
        let title: String
        let message: String
        let duration: TimeInterval
    }

    private struct ActiveNotification {
        let notification: Notification
        let panel: OverlayNotificationPanel
    }

    private static let size = NSSize(width: 380, height: 104)
    private static let screenMargin: CGFloat = 16

    private weak var anchorWindow: NSWindow?
    private var queue: [Notification] = []
    private var activeNotification: ActiveNotification?
    private var dismissWorkItem: DispatchWorkItem?
    private var didWriteSnapshot = false

    func anchor(to window: NSWindow) {
        anchorWindow = window
    }

    func showHotKeyReminder() {
        enqueue(Notification(
            identifier: "hotkeys",
            title: "Горячие клавиши",
            message: "Левые Option + Shift или правые Option + Shift показывают и скрывают окно.",
            duration: 5.5
        ))
    }

    func showSessionRequired(for tab: BrowserServiceTab) {
        enqueue(Notification(
            identifier: "session-\(tab.rawValue)",
            title: "Требуется вход в \(tab.title)",
            message: "Откройте вкладку и войдите снова. Авторизация сохранится.",
            duration: 5.5
        ))
    }

    private func enqueue(_ notification: Notification) {
        let alreadyScheduled = activeNotification?.notification.identifier == notification.identifier
            || queue.contains { $0.identifier == notification.identifier }
        guard !alreadyScheduled else {
            AppLog.info(.notification, "duplicate-ignored", ["id": notification.identifier])
            return
        }

        queue.append(notification)
        AppLog.info(.notification, "queued", ["id": notification.identifier])
        showNextIfNeeded()
    }

    private func showNextIfNeeded() {
        guard activeNotification == nil, !queue.isEmpty else {
            return
        }

        let notification = queue.removeFirst()
        let panel = makePanel(for: notification)
        let targetFrame = frame(for: panel)
        var initialFrame = targetFrame
        initialFrame.origin.x += 28

        panel.alphaValue = 0
        panel.setFrame(initialFrame, display: false)
        activeNotification = ActiveNotification(notification: notification, panel: panel)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        }

        scheduleSnapshotIfRequested(for: panel, identifier: notification.identifier)
        scheduleDismiss(after: notification.duration)
        AppLog.info(.notification, "shown", [
            "id": notification.identifier,
            "sharing": "none"
        ])
    }

    private func makePanel(for notification: Notification) -> OverlayNotificationPanel {
        let panel = OverlayNotificationPanel(contentRect: NSRect(origin: .zero, size: Self.size))
        panel.title = "Overlay Browser Notification: \(notification.identifier)"
        panel.contentView = makeContentView(for: notification)
        return panel
    }

    private func makeContentView(for notification: Notification) -> NSView {
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.cornerCurve = .continuous
        background.layer?.borderWidth = 0.5
        background.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        background.layer?.masksToBounds = true

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: notification.title)
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .labelColor
        title.lineBreakMode = .byTruncatingTail

        let message = NSTextField(wrappingLabelWithString: notification.message)
        message.font = .systemFont(ofSize: 12)
        message.textColor = .secondaryLabelColor
        message.maximumNumberOfLines = 2
        message.lineBreakMode = .byWordWrapping

        let textStack = NSStackView(views: [title, message])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = NSButton(
            image: NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Закрыть")
                ?? NSImage(),
            target: self,
            action: #selector(dismissFromButton)
        )
        closeButton.isBordered = false
        closeButton.imagePosition = .imageOnly
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.refusesFirstResponder = true
        closeButton.toolTip = "Закрыть уведомление"
        closeButton.setAccessibilityLabel("Закрыть уведомление")
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        [icon, textStack, closeButton].forEach(background.addSubview)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),

            textStack.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -10),
            textStack.centerYAnchor.constraint(equalTo: background.centerYAnchor),

            closeButton.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -12),
            closeButton.topAnchor.constraint(equalTo: background.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 18)
        ])

        background.setAccessibilityElement(false)
        return background
    }

    private func frame(for panel: NSWindow) -> NSRect {
        let visibleFrame = anchorWindow?.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? NSRect(origin: .zero, size: Self.size)
        return NSRect(
            x: visibleFrame.maxX - panel.frame.width - Self.screenMargin,
            y: visibleFrame.maxY - panel.frame.height - Self.screenMargin,
            width: panel.frame.width,
            height: panel.frame.height
        )
    }

    private func scheduleDismiss(after duration: TimeInterval) {
        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissCurrent(reason: "timeout")
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    @objc private func dismissFromButton() {
        dismissCurrent(reason: "button")
    }

    private func dismissCurrent(reason: String) {
        guard let activeNotification else {
            return
        }

        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        self.activeNotification = nil

        var targetFrame = activeNotification.panel.frame
        targetFrame.origin.x += 20
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            activeNotification.panel.animator().alphaValue = 0
            activeNotification.panel.animator().setFrame(targetFrame, display: true)
        }, completionHandler: { [weak self, panel = activeNotification.panel] in
            panel.orderOut(nil)
            self?.showNextIfNeeded()
        })

        AppLog.info(.notification, "dismissed", [
            "id": activeNotification.notification.identifier,
            "reason": reason
        ])
    }

    private func scheduleSnapshotIfRequested(for panel: NSPanel, identifier: String) {
        guard !didWriteSnapshot,
              let path = ProcessInfo.processInfo.environment["OVERLAY_TOAST_SNAPSHOT_PATH"] else {
            return
        }
        let requestedIdentifier = ProcessInfo.processInfo.environment["OVERLAY_TOAST_SNAPSHOT_ID"]
        guard requestedIdentifier == nil || requestedIdentifier == identifier else {
            return
        }
        didWriteSnapshot = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak panel] in
            guard let view = panel?.contentView else {
                return
            }
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                AppLog.warning(.notification, "snapshot-failed", ["reason": "missing-bitmap"])
                return
            }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                AppLog.warning(.notification, "snapshot-failed", ["reason": "png-encoding"])
                return
            }

            do {
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
                AppLog.info(.notification, "snapshot-written", [
                    "id": identifier,
                    "path": path
                ])
            } catch {
                AppLog.warning(.notification, "snapshot-failed", [
                    "description": error.localizedDescription
                ])
            }
        }
    }
}

private final class OverlayNotificationPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovable = false
        animationBehavior = .none
        level = .statusBar
        sharingType = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        isExcludedFromWindowsMenu = true
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
