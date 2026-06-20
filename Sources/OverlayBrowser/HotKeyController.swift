import AppKit
import Carbon

final class HotKeyController {
    private static let signature = OSType(0x53465330) // SFS0
    private struct HotKeyDefinition {
        let identifier: UInt32
        let keyCode: UInt32
        let modifiers: UInt32
        let label: String
    }

    private static let hotKeyDefinitions = [
        HotKeyDefinition(
            identifier: 1,
            keyCode: UInt32(kVK_ANSI_Z),
            modifiers: UInt32(optionKey) | UInt32(shiftKey),
            label: "Option+Shift+Z"
        ),
        HotKeyDefinition(
            identifier: 2,
            keyCode: UInt32(kVK_ANSI_Slash),
            modifiers: UInt32(optionKey) | UInt32(shiftKey),
            label: "Option+Shift+/"
        )
    ]

    private let onPressed: () -> Void
    private var eventHandler: EventHandlerRef?
    private var hotKeys: [EventHotKeyRef] = []

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    deinit {
        for hotKey in hotKeys {
            UnregisterEventHotKey(hotKey)
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard handlerStatus == noErr else {
            writeHotKeyError("InstallEventHandler", status: handlerStatus)
            return
        }

        for definition in Self.hotKeyDefinitions {
            let hotKeyID = EventHotKeyID(
                signature: Self.signature,
                id: definition.identifier
            )

            var hotKey: EventHotKeyRef?
            let registerStatus = RegisterEventHotKey(
                definition.keyCode,
                definition.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKey
            )

            if registerStatus == noErr, let hotKey {
                hotKeys.append(hotKey)
            } else {
                writeHotKeyError("RegisterEventHotKey \(definition.label)", status: registerStatus)
            }
        }
    }

    fileprivate func handleHotKeyPressed(event: EventRef?) -> OSStatus {
        guard let event else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        guard hotKeyID.signature == Self.signature,
              Self.hotKeyDefinitions.contains(where: { $0.identifier == hotKeyID.id }) else {
            return noErr
        }

        DispatchQueue.main.async { [weak self] in
            self?.onPressed()
        }

        return noErr
    }

    private func writeHotKeyError(_ operation: String, status: OSStatus) {
        fputs("OverlayBrowser hotkey error: \(operation) failed with status \(status)\n", stderr)
    }
}

private let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let userData else {
        return noErr
    }

    let controller = Unmanaged<HotKeyController>
        .fromOpaque(userData)
        .takeUnretainedValue()

    return controller.handleHotKeyPressed(event: event)
}
