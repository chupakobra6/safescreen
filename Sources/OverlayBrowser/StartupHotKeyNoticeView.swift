import AppKit

final class StartupHotKeyNoticeView: NSView {
    var onDismiss: (() -> Void)?

    private let messageLabel: NSTextField = {
        let label = NSTextField(
            wrappingLabelWithString: "Показать или скрыть окно: левый Option + Shift или правый Option + Shift."
        )
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var dismissButton: NSButton = {
        let button = NSButton(
            image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Закрыть напоминание")
                ?? NSImage(),
            target: self,
            action: #selector(dismiss)
        )
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.toolTip = "Закрыть напоминание"
        button.setAccessibilityLabel("Закрыть напоминание")
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor

        let content = NSStackView(views: [messageLabel, dismissButton])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 8
        content.edgeInsets = NSEdgeInsets(top: 7, left: 10, bottom: 7, right: 8)
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)

        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Напоминание о горячих клавишах")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func dismiss() {
        isHidden = true
        onDismiss?()
    }
}
