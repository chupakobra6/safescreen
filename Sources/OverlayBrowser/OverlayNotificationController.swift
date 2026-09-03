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
        let view: NSView
        let trailingConstraint: NSLayoutConstraint
    }

    private static let size = NSSize(width: 380, height: 104)
    private static let margin: CGFloat = 12

    private weak var containerView: NSView?
    private var queue: [Notification] = []
    private var activeNotification: ActiveNotification?
    private var dismissWorkItem: DispatchWorkItem?
    private var didWriteSnapshot = false

    func attach(to view: NSView) {
        containerView = view
        showNextIfNeeded()
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
        guard activeNotification == nil,
              !queue.isEmpty,
              let containerView else {
            return
        }

        let notification = queue.removeFirst()
        let notificationView = makeView(for: notification)
        notificationView.translatesAutoresizingMaskIntoConstraints = false
        notificationView.alphaValue = 0
        containerView.addSubview(notificationView)

        let widthConstraint = notificationView.widthAnchor.constraint(equalToConstant: Self.size.width)
        widthConstraint.priority = .defaultHigh
        let trailingConstraint = notificationView.trailingAnchor.constraint(
            equalTo: containerView.trailingAnchor,
            constant: 20
        )
        NSLayoutConstraint.activate([
            notificationView.topAnchor.constraint(
                equalTo: containerView.topAnchor,
                constant: Self.margin
            ),
            trailingConstraint,
            notificationView.leadingAnchor.constraint(
                greaterThanOrEqualTo: containerView.leadingAnchor,
                constant: Self.margin
            ),
            widthConstraint,
            notificationView.heightAnchor.constraint(equalToConstant: Self.size.height)
        ])
        containerView.layoutSubtreeIfNeeded()

        activeNotification = ActiveNotification(
            notification: notification,
            view: notificationView,
            trailingConstraint: trailingConstraint
        )

        trailingConstraint.constant = -Self.margin
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            notificationView.animator().alphaValue = 1
            containerView.animator().layoutSubtreeIfNeeded()
        }

        scheduleSnapshotIfRequested(for: notificationView, identifier: notification.identifier)
        scheduleDismiss(after: notification.duration)
        AppLog.info(.notification, "shown", [
            "container": "browser-window",
            "id": notification.identifier,
            "sharing": "inherited-none"
        ])
    }

    private func makeView(for notification: Notification) -> NSView {
        let wrapper = OverlayNotificationView()
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = NSColor.clear.cgColor
        wrapper.layer?.shadowColor = NSColor.black.cgColor
        wrapper.layer?.shadowOpacity = 0.22
        wrapper.layer?.shadowRadius = 12
        wrapper.layer?.shadowOffset = NSSize(width: 0, height: -3)
        wrapper.setAccessibilityIdentifier("overlay-notification-\(notification.identifier)")
        wrapper.setAccessibilityLabel(notification.title)

        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .withinWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.cornerCurve = .continuous
        background.layer?.borderWidth = 0.5
        background.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor
        background.layer?.masksToBounds = true
        background.translatesAutoresizingMaskIntoConstraints = false

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

        wrapper.addSubview(background)
        [icon, textStack, closeButton].forEach(background.addSubview)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            background.topAnchor.constraint(equalTo: wrapper.topAnchor),
            background.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),

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
        return wrapper
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
        activeNotification.trailingConstraint.constant = 8

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            activeNotification.view.animator().alphaValue = 0
            activeNotification.view.superview?.animator().layoutSubtreeIfNeeded()
        }, completionHandler: { [weak self, view = activeNotification.view] in
            view.removeFromSuperview()
            self?.showNextIfNeeded()
        })

        AppLog.info(.notification, "dismissed", [
            "id": activeNotification.notification.identifier,
            "reason": reason
        ])
    }

    private func scheduleSnapshotIfRequested(for view: NSView, identifier: String) {
        guard !didWriteSnapshot,
              let path = ProcessInfo.processInfo.environment["OVERLAY_TOAST_SNAPSHOT_PATH"] else {
            return
        }
        let requestedIdentifier = ProcessInfo.processInfo.environment["OVERLAY_TOAST_SNAPSHOT_ID"]
        guard requestedIdentifier == nil || requestedIdentifier == identifier else {
            return
        }
        didWriteSnapshot = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak view] in
            guard let view else {
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

private final class OverlayNotificationView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let target = super.hitTest(point)
        return target is NSButton ? target : nil
    }
}
